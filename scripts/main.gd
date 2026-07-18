extends Node2D
## Character select + scrolling HOME VILLAGE hub. Organic island (~7 screens) with
## a follow-camera, boundary collision, a general store and a hot-air-balloon launch
## station you can walk up to, depth-sorted trees. Start menu (Resume/Test Battle/
## Quit) and FF-style Funk-Off battles. Gamepad-first (Steam Deck) + touch.

const HEROES: Array[String] = ["isla", "emmy"]
const SCREEN := Vector2(1280, 800)
const WORLD := Vector2(3600, 2000)
const BATTLE := preload("res://battle.tscn")
const SPEED := 340.0
const STORY_TEXT := "Long ago, the 12 lucky Zodiac animals lived happily on the Moon.\n\nBut someone did something... and they all tumbled down onto the Funky Islands!\n\nFar from the Moon, they lost their good luck — and grumpy, they started causing trouble in the village.\n\nOnly Isla & Emmy can calm them with a funky dance-off and send each one back home to the Moon.\n\nCalm all 12 and bring back the good luck!"

var state: String = "select"        # select / intro / play / battle
var sel: int = 0
var pending_hero: String = "isla"
var ui: CanvasLayer

# village
var world: Node2D
var camera: Camera2D
var player: Node2D
var player_base_scale: Vector2 = Vector2.ONE
var anim_t: float = 0.0
var island_poly: PackedVector2Array
var obstacles: Array[Dictionary] = []   # {c: base center, e: ellipse extents} — blocks walking
var spawn_pos := Vector2(1750, 1500)
var store_pos := Vector2(2560, 980)
var balloon_pos := Vector2(1820, 470)
var interact_target: String = ""

# store interior — one fixed screen-sized room, built lazily far east of the island.
# Camera limits clamp to the room so it plays as a single non-scrolling screen.
const SHOP_RECT := Rect2(4400, 600, 1280, 800)
var shop_root: Node2D
var in_shop: bool = false
var shop_obstacles: Array[Dictionary] = []
var transitioning: bool = false

# hud
var hud: CanvasLayer
var prompt_label: Label
var popup_label: Label
var popup_t: float = 0.0
var score_label: Label
var present_nodes: Array[Sprite2D] = []
var chest_nodes: Array[Sprite2D] = []

# music
var music: AudioStreamPlayer

# battle / transition
var creature: Sprite2D
var battle_node: Node
var flash_layer: CanvasLayer
var flash_rect: ColorRect

# pause / test / store menu
var menu_open: bool = false
var menu_mode: String = "pause"     # "pause" or "store"
var menu_layer: CanvasLayer
var menu_vbox: VBoxContainer
var menu_title: Label
var menu_cursor: int = 0
var menu_items: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.is_debug_build() and args.has("--shop"):
		_debug_jump_shop(args)
		return
	show_select()


## Layout iteration aid (debug builds only, inert in releases):
##   godot --path . -- --shop [--shot=/abs/out.png]
## boots straight into the store interior, optionally saves a screenshot + quits.
func _debug_jump_shop(args: PackedStringArray) -> void:
	Globals.hero = "isla"
	pending_hero = "isla"
	ui = CanvasLayer.new()   # _enter_village expects one to free
	add_child(ui)
	_enter_village("isla")
	await _enter_shop()
	for a in args:
		if a.begins_with("--shot="):
			await get_tree().create_timer(0.6).timeout
			get_viewport().get_texture().get_image().save_png(a.trim_prefix("--shot="))
			get_tree().quit()


# ---------------------------------------------------------------- select
func show_select() -> void:
	state = "select"
	sel = 0
	ui = CanvasLayer.new()
	add_child(ui)

	var bg := ColorRect.new()
	bg.color = Color(0.66, 0.85, 0.95)
	bg.size = SCREEN
	ui.add_child(bg)

	var logo := Sprite2D.new()
	logo.texture = load("res://assets/logo.png")
	_fit_height(logo, 270.0)
	logo.position = Vector2(SCREEN.x * 0.5, 160)
	ui.add_child(logo)
	ui.add_child(_label("Tap a hero  —  or  <  Left / Right  >  then  A", 28, Vector2(0, 312), true))

	for i in HEROES.size():
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/%s.png" % HEROES[i])
		spr.position = Vector2(440 + i * 400, 540)
		spr.name = "portrait_%d" % i
		ui.add_child(spr)
		var nm := _label(HEROES[i].to_upper(), 40, Vector2(440 + i * 400 - 140, 724), false)
		nm.size = Vector2(280, 50)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.add_child(nm)

	_update_cursor()


func _update_cursor() -> void:
	for i in HEROES.size():
		var spr := ui.get_node("portrait_%d" % i) as Sprite2D
		var on := i == sel
		_fit_height(spr, 360.0 if on else 300.0)
		spr.modulate = Color(1, 1, 1) if on else Color(0.7, 0.7, 0.7, 0.85)


# ---------------------------------------------------------------- input
func _event_is_menu(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var b := (event as InputEventJoypadButton).button_index
		return b == JOY_BUTTON_START or b == JOY_BUTTON_BACK
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		return true
	return false


func _a_pressed(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		return true
	return event.is_action_pressed("ui_accept")


func _pointer_pos(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		return (event as InputEventMouseButton).position
	return Vector2(-1, -1)


func _input(event: InputEvent) -> void:
	if _event_is_menu(event) and state != "battle":
		_toggle_menu()
		return
	if menu_open:
		if _a_pressed(event) or _pointer_pos(event).x >= 0.0:
			_menu_select()
		return

	if state == "select":
		if _a_pressed(event):
			start_game(HEROES[sel]); return
		var p := _pointer_pos(event)
		if p.x >= 0.0:
			sel = 0 if p.x < SCREEN.x * 0.5 else 1
			_update_cursor()
			start_game(HEROES[sel])
	elif state == "intro":
		if _a_pressed(event) or _pointer_pos(event).x >= 0.0:
			_enter_village(pending_hero)
	elif state == "play":
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
				and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			_reset_to_select(); return
		if _a_pressed(event) or _pointer_pos(event).x >= 0.0:
			_interact()


# ---------------------------------------------------------------- intro story
func start_game(hero: String) -> void:
	pending_hero = hero
	Globals.hero = hero
	state = "intro"
	ui.queue_free()

	ui = CanvasLayer.new()
	add_child(ui)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.24)
	bg.size = SCREEN
	ui.add_child(bg)
	ui.add_child(_label("🌙   THE MOON ZODIAC   🌙", 48, Vector2(0, 70), true))
	var story := _label(STORY_TEXT, 30, Vector2(140, 190), false)
	story.size = Vector2(SCREEN.x - 280, 470)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_color_override("font_color", Color(1, 1, 1))
	story.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	story.add_theme_constant_override("outline_size", 5)
	ui.add_child(story)
	ui.add_child(_label("Press A  (or tap)  to begin", 28, Vector2(0, 722), true))


# ---------------------------------------------------------------- village
func _enter_village(hero: String) -> void:
	state = "play"
	ui.queue_free()
	_play_island_music()
	in_shop = false
	transitioning = false
	shop_root = null
	shop_obstacles.clear()

	_build_island_poly()

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	var sky := ColorRect.new()
	sky.color = Color(0.56, 0.8, 0.95)
	sky.position = Vector2(-3000, -3000)
	sky.size = WORLD + Vector2(6000, 6000)
	sky.z_index = -100
	world.add_child(sky)

	var ground := Polygon2D.new()
	ground.polygon = island_poly
	ground.texture = load("res://assets/home_island/grass.png")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.texture_scale = Vector2(2, 2)   # 1024 tile renders ~512px on screen
	ground.z_index = -10
	world.add_child(ground)

	var edge := Line2D.new()
	var pts := island_poly.duplicate()
	pts.append(island_poly[0])
	edge.points = pts
	edge.width = 16.0
	edge.default_color = Color(0.36, 0.24, 0.16)
	edge.joint_mode = Line2D.LINE_JOINT_ROUND
	edge.z_index = -9
	world.add_child(edge)

	obstacles.clear()
	for tp in [Vector2(950, 720), Vector2(2750, 680), Vector2(1300, 1230),
			Vector2(2300, 1360), Vector2(820, 1300), Vector2(2950, 1180),
			Vector2(1520, 640), Vector2(2150, 860)]:
		world.add_child(_make_sprite("res://assets/home_island/tree.png", tp, 330.0))
		_add_obstacle(tp, Vector2(50, 24))          # trunk base only — canopy stays walk-behind
	for bp in [Vector2(700, 980), Vector2(2600, 1480), Vector2(1150, 1520), Vector2(2880, 880)]:
		world.add_child(_make_sprite("res://assets/home_island/bush.png", bp, 120.0))
		_add_obstacle(bp, Vector2(48, 22))
	for rp in [Vector2(1650, 1430), Vector2(2450, 760), Vector2(1000, 600)]:
		world.add_child(_make_sprite("res://assets/home_island/rock.png", rp, 95.0))
		_add_obstacle(rp, Vector2(44, 22))
	world.add_child(_make_sprite("res://assets/home_island/well.png", Vector2(1500, 1100), 150.0))
	_add_obstacle(Vector2(1500, 1100), Vector2(62, 30))
	world.add_child(_make_sprite("res://assets/home_island/signpost.png", Vector2(1950, 1380), 140.0))
	_add_obstacle(Vector2(1950, 1380), Vector2(22, 12))

	world.add_child(_make_sprite("res://assets/home_island/store.png", store_pos, 440.0))
	_add_obstacle(store_pos, Vector2(180, 65))
	world.add_child(_make_sprite("res://assets/home_island/balloon_station.png", balloon_pos, 520.0))
	_add_obstacle(balloon_pos, Vector2(150, 60))

	# presents = currency, scattered around the village
	present_nodes.clear()
	for pp in [Vector2(1100, 900), Vector2(2200, 1100), Vector2(2850, 1400),
			Vector2(900, 1550), Vector2(1700, 800), Vector2(2600, 550),
			Vector2(1350, 1650), Vector2(3050, 950)]:
		var pres := _make_sprite("res://assets/present.png", pp, 90.0)
		world.add_child(pres)
		present_nodes.append(pres)

	# treasure chests (gold!) tucked around the island edges — one-time finds
	chest_nodes.clear()
	for cp in [Vector2(560, 640), Vector2(3150, 700), Vector2(2450, 1680), Vector2(760, 1450)]:
		var chest := _make_sprite("res://assets/ui/chest.png", cp, 110.0)
		world.add_child(chest)
		chest_nodes.append(chest)

	player = Node2D.new()
	player.position = spawn_pos
	world.add_child(player)
	var spr := _make_sprite("res://assets/%s.png" % hero, Vector2.ZERO, 170.0)
	spr.name = "spr"
	player_base_scale = spr.scale
	player.add_child(spr)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.make_current()

	hud = CanvasLayer.new()
	add_child(hud)
	hud.add_child(_label("Home Village   (B = title,  ☰ = menu)", 22, Vector2(24, 18), false))
	score_label = _label("", 30, Vector2(1010, 18), false)
	hud.add_child(score_label)
	_update_hud_counts()
	prompt_label = _label("", 30, Vector2(0, 700), true)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hud.add_child(prompt_label)
	popup_label = _label("", 32, Vector2(0, 380), true)
	popup_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hud.add_child(popup_label)


func _build_island_poly() -> void:
	island_poly = PackedVector2Array([
		Vector2(620, 360), Vector2(1300, 230), Vector2(1850, 330), Vector2(2500, 210),
		Vector2(3050, 420), Vector2(3360, 820), Vector2(3300, 1300), Vector2(2900, 1640),
		Vector2(2350, 1820), Vector2(1750, 1720), Vector2(1180, 1830), Vector2(640, 1600),
		Vector2(360, 1150), Vector2(420, 680),
	])


func _process(delta: float) -> void:
	if menu_open:
		if Input.is_action_just_pressed("ui_up"):
			menu_cursor = (menu_cursor - 1 + menu_items.size()) % menu_items.size()
			_refresh_menu()
		elif Input.is_action_just_pressed("ui_down"):
			menu_cursor = (menu_cursor + 1) % menu_items.size()
			_refresh_menu()
		elif menu_mode == "settings" and menu_cursor < 2:
			if Input.is_action_just_pressed("ui_right"):
				_adjust_setting(menu_cursor, 1)
			elif Input.is_action_just_pressed("ui_left"):
				_adjust_setting(menu_cursor, -1)
		return

	if state == "select":
		if Input.is_action_just_pressed("ui_left"):
			sel = (sel - 1 + HEROES.size()) % HEROES.size()
			_update_cursor()
		elif Input.is_action_just_pressed("ui_right"):
			sel = (sel + 1) % HEROES.size()
			_update_cursor()
		if Input.is_action_just_pressed("ui_accept"):
			start_game(HEROES[sel])
		return

	if state != "play":
		return

	if popup_t > 0.0:
		popup_t -= delta
		if popup_t <= 0.0:
			popup_label.text = ""

	if transitioning:
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var moving := dir.length() > 0.1
	var move := dir * SPEED * delta
	var here := player.position
	if _can_walk(here + move):
		player.position = here + move
	elif _can_walk(here + Vector2(move.x, 0)):
		player.position = here + Vector2(move.x, 0)
	elif _can_walk(here + Vector2(0, move.y)):
		player.position = here + Vector2(0, move.y)

	# open doorway at the bottom of the shop: walk down through it to leave
	if in_shop and player.position.y > SHOP_RECT.end.y - 32.0 \
			and absf(player.position.x - (SHOP_RECT.position.x + SHOP_RECT.size.x * 0.5)) < 110.0:
		_exit_shop()
		return

	anim_t += delta * (10.0 if moving else 2.5)
	var s := sin(anim_t)
	var spr := player.get_node("spr") as Sprite2D
	if moving:
		spr.position.y = -absf(s) * 13.0
		spr.scale = player_base_scale * Vector2(1.0 - 0.05 * s, 1.0 + 0.05 * s)
		if dir.x != 0.0:
			spr.flip_h = dir.x < 0.0
	else:
		spr.position.y = -absf(s) * 3.0
		spr.scale = player_base_scale * Vector2(1.0 + 0.03 * s, 1.0 - 0.03 * s)

	# collect presents (collectible, not money; respawn only on re-entering the island)
	for p in present_nodes:
		if p.visible and player.position.distance_to(p.position) < 75.0:
			p.visible = false
			Globals.presents += 1
			Globals.play_sfx("gift")
			_update_hud_counts()

	# open treasure chests -> GOLD (one-time; pops open with a bounce + coin burst)
	for ch in chest_nodes:
		if not ch.has_meta("opened") and player.position.distance_to(ch.position) < 80.0:
			ch.set_meta("opened", true)
			ch.texture = load("res://assets/ui/chest_open.png")
			Globals.play_sfx("chest")
			Globals.play_sfx("coin")
			var base := ch.scale
			var tw := create_tween()
			tw.tween_property(ch, "scale", base * 1.22, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(ch, "scale", base, 0.14)
			for i in 5:
				var coin := Label.new()
				coin.text = "🪙"
				coin.add_theme_font_size_override("font_size", 30)
				coin.position = ch.position + Vector2(randf_range(-30, 30), -60)
				coin.z_index = 50
				world.add_child(coin)
				var ct := create_tween()
				ct.tween_property(coin, "position:y", coin.position.y - randf_range(70, 130), 0.7)
				ct.parallel().tween_property(coin, "modulate:a", 0.0, 0.7)
				ct.tween_callback(coin.queue_free)
			var loot := 4 + randi() % 4
			Globals.gold += loot
			_update_hud_counts()
			_popup("Treasure!  +%d gold 🪙" % loot)

	# interaction prompt
	interact_target = ""
	var ptxt := ""
	if in_shop:
		if player.position.distance_to(SHOP_RECT.position + Vector2(640, 470)) < 140.0:
			interact_target = "counter"; ptxt = "Ⓐ  Shop with Grandpa"
		elif player.position.distance_to(SHOP_RECT.position + Vector2(240, 400)) < 130.0:
			interact_target = "cards"; ptxt = "Ⓐ  Zodiac Cards"
	elif player.position.distance_to(store_pos) < 150.0:
		interact_target = "store"; ptxt = "Ⓐ  General Store"
	elif player.position.distance_to(balloon_pos) < 180.0:
		interact_target = "balloon"; ptxt = "Ⓐ  Launch Balloon"
	prompt_label.text = ptxt


## All tracks are delivered as true seamless loops (crossfade wrap), so we just
## loop the stream — no fade/gap handling needed. One shared player; it survives
## _reset_to_select's child sweep by being recreated on demand.
func _ensure_music() -> void:
	if is_instance_valid(music):
		return
	music = AudioStreamPlayer.new()
	music.volume_db = -6.0   # base headroom under SFX; user level rides the Music bus
	music.bus = "Music"
	add_child(music)


func _play_music(path: String) -> void:
	_ensure_music()
	var stream := load(path) as AudioStreamOggVorbis
	stream.loop = true
	if music.stream != stream or not music.playing:
		music.stream = stream
		music.play()


func _play_island_music() -> void:
	_play_music("res://assets/audio/island_theme.ogg")


func _play_battle_music() -> void:
	# two delivered battle loops — Andy's call: pick one at random per battle
	_play_music("res://assets/audio/battle_theme_%d.ogg" % (1 + randi() % 2))


func _inside(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, island_poly)


func _add_obstacle(c: Vector2, e: Vector2) -> void:
	obstacles.append({"c": c, "e": e})


func _blocked(p: Vector2) -> bool:
	var obs: Array[Dictionary] = shop_obstacles if in_shop else obstacles
	for o in obs:
		var d: Vector2 = (p - o.c) / o.e
		if d.length_squared() < 1.0:
			return true
	return false


func _can_walk(p: Vector2) -> bool:
	if in_shop:
		# inside the room: below the back wall, inset from the side/bottom edges
		return Rect2(SHOP_RECT.position.x + 30.0, SHOP_RECT.position.y + 320.0,
				SHOP_RECT.size.x - 60.0, SHOP_RECT.size.y - 340.0).has_point(p) and not _blocked(p)
	return _inside(p) and not _blocked(p)


func _interact() -> void:
	if transitioning:
		return
	match interact_target:
		"store":
			_enter_shop()
		"counter":
			Globals.play_sfx("ui")
			_open_menu("store")
		"cards":
			Globals.play_sfx("ui")
			_popup("Zodiac cards coming soon — Grandpa's still stocking the display! 🌙")
		"balloon":
			_popup("The balloon isn't fueled up yet — adventure soon! 🎈")


# ---------------------------------------------------------------- store interior
## Build the walk-in shop per the art kit: seamless floor, wall band across the
## top, Grandpa behind the counter, card display + shelf, moose head hung flat
## on the back wall, rug as the doormat marking the open exit doorway (bottom).
func _build_shop() -> void:
	shop_root = Node2D.new()
	shop_root.y_sort_enabled = true   # merges with world's Y-sort pool
	world.add_child(shop_root)
	shop_obstacles.clear()

	var o := SHOP_RECT.position
	var flr := Polygon2D.new()
	flr.polygon = PackedVector2Array([o, o + Vector2(SHOP_RECT.size.x, 0),
			o + SHOP_RECT.size, o + Vector2(0, SHOP_RECT.size.y)])
	flr.texture = load("res://assets/store/floor.png")
	flr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	flr.texture_scale = Vector2(2, 2)
	flr.z_index = -8
	shop_root.add_child(flr)

	var wt := load("res://assets/store/wall.png") as Texture2D
	var wall_h := 300.0
	var tile_w := wt.get_width() * (wall_h / wt.get_height())
	var step := tile_w - 2.0   # 2px overlap hides the hairline seam at tile edges
	for i in int(ceil(SHOP_RECT.size.x / step)):
		var w := _make_sprite("res://assets/store/wall.png",
				o + Vector2(step * (i + 0.5), wall_h), wall_h)
		w.z_index = -3   # out of Y-sort so wall-mounted decor can layer on it
		shop_root.add_child(w)

	# --- wall-mounted (z -2: over the wall, under everyone on the floor) ---
	# "GRANDPA'S GENERAL STORE" sign takes center stage; window left, moose right
	var sign := _make_sprite("res://assets/store/sign.png", o + Vector2(640, 185), 185.0)
	sign.z_index = -2
	shop_root.add_child(sign)
	var window := _make_sprite("res://assets/store/window.png", o + Vector2(400, 225), 170.0)
	window.z_index = -2
	shop_root.add_child(window)
	var moose := _make_sprite("res://assets/store/moose_head.png", o + Vector2(870, 170), 150.0)
	moose.z_index = -2
	shop_root.add_child(moose)
	# the lamp art is a lantern — hang one near each end of the wall
	for lx in [70.0, 1210.0]:
		var lantern := _make_sprite("res://assets/store/lamp.png", o + Vector2(lx, 220), 190.0)
		lantern.z_index = -2
		shop_root.add_child(lantern)

	# --- rugs (z -1: flat on the floor) — big center carpet + doormat at the exit ---
	var carpet := _make_sprite("res://assets/store/rug.png", o + Vector2(640, 700), 440.0)
	carpet.z_index = -1
	shop_root.add_child(carpet)
	var mat := _make_sprite("res://assets/store/rug.png", o + Vector2(640, 798), 130.0)
	mat.z_index = -1
	shop_root.add_child(mat)

	# --- counter island: Grandpa behind the desk (counter v2: register faces him) ---
	shop_root.add_child(_make_sprite("res://assets/store/clerk.png", o + Vector2(640, 355), 220.0))
	_add_shop_obstacle(o + Vector2(640, 355), Vector2(55, 24))
	shop_root.add_child(_make_sprite("res://assets/store/counter.png", o + Vector2(640, 445), 210.0))
	_add_shop_obstacle(o + Vector2(640, 445), Vector2(205, 42))

	# --- furniture against the back wall (bases just under the wall band) ---
	shop_root.add_child(_make_sprite("res://assets/store/card_display.png", o + Vector2(240, 350), 260.0))
	_add_shop_obstacle(o + Vector2(240, 350), Vector2(85, 32))
	shop_root.add_child(_make_sprite("res://assets/store/shelf.png", o + Vector2(1050, 340), 290.0))
	_add_shop_obstacle(o + Vector2(1050, 340), Vector2(95, 32))

	# --- stock + greenery filling the open floor ---
	shop_root.add_child(_make_sprite("res://assets/store/crate.png", o + Vector2(395, 505), 125.0))
	_add_shop_obstacle(o + Vector2(395, 505), Vector2(56, 26))
	var crate2 := _make_sprite("res://assets/store/crate.png", o + Vector2(925, 550), 115.0)
	crate2.flip_h = true
	shop_root.add_child(crate2)
	_add_shop_obstacle(o + Vector2(925, 550), Vector2(52, 24))
	for b in [[1180.0, 690.0, 150.0, 55.0, 28.0], [1080.0, 750.0, 135.0, 50.0, 25.0]]:
		shop_root.add_child(_make_sprite("res://assets/home_island/barrel.png",
				o + Vector2(b[0], b[1]), b[2]))
		_add_shop_obstacle(o + Vector2(b[0], b[1]), Vector2(b[3], b[4]))
	shop_root.add_child(_make_sprite("res://assets/store/plant.png", o + Vector2(80, 760), 170.0))
	_add_shop_obstacle(o + Vector2(80, 760), Vector2(40, 20))
	shop_root.add_child(_make_sprite("res://assets/store/plant.png", o + Vector2(1220, 450), 160.0))
	_add_shop_obstacle(o + Vector2(1220, 450), Vector2(38, 19))


func _add_shop_obstacle(c: Vector2, e: Vector2) -> void:
	shop_obstacles.append({"c": c, "e": e})


func _enter_shop() -> void:
	transitioning = true
	await _flash_to_white()
	if not is_instance_valid(shop_root):
		_build_shop()
	in_shop = true
	player.position = SHOP_RECT.position + Vector2(640, 715)   # just inside the doorway
	camera.limit_left = int(SHOP_RECT.position.x)
	camera.limit_top = int(SHOP_RECT.position.y)
	camera.limit_right = int(SHOP_RECT.end.x)
	camera.limit_bottom = int(SHOP_RECT.end.y)
	camera.reset_smoothing()
	_popup("Grandpa:  Well hello, %s!  Come on in! 💛" % Globals.hero.capitalize())
	await _flash_from_white()
	transitioning = false


func _exit_shop() -> void:
	transitioning = true
	await _flash_to_white()
	in_shop = false
	player.position = store_pos + Vector2(0, 110)   # back out front of the store
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.reset_smoothing()
	await _flash_from_white()
	transitioning = false


func _popup(text: String) -> void:
	if popup_label:
		popup_label.text = text
		popup_t = 2.4


func _update_hud_counts() -> void:
	if is_instance_valid(score_label):
		score_label.text = "🎁 %d    🪙 %d" % [Globals.presents, Globals.gold]


func _reset_to_select() -> void:
	for c in get_children():
		c.queue_free()
	world = null
	player = null
	camera = null
	hud = null
	call_deferred("show_select")


# ---------------------------------------------------------------- battle
func _start_battle() -> void:
	state = "battle"
	_play_battle_music()
	await _flash_to_white()
	var b := BATTLE.instantiate()
	b.enemy_sign = "horse"
	b.battle_finished.connect(_on_battle_finished)
	add_child(b)
	battle_node = b
	await _flash_from_white()


func _on_battle_finished(_win: bool) -> void:
	await _flash_to_white()
	if is_instance_valid(battle_node):
		battle_node.queue_free()
		battle_node = null
	if is_instance_valid(player):
		player.position = spawn_pos
	if in_shop:   # battles dump you back outside — unwind the shop camera/walk state
		in_shop = false
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
	if is_instance_valid(camera):
		camera.reset_smoothing()
	state = "play"
	_play_island_music()
	_update_hud_counts()   # battle rewards gold on a win
	await _flash_from_white()


func _flash_to_white() -> void:
	flash_layer = CanvasLayer.new()
	flash_layer.layer = 100
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1)
	flash_rect.modulate = Color(1, 1, 1, 0)
	flash_rect.size = SCREEN
	flash_layer.add_child(flash_rect)
	var tw := create_tween()
	tw.tween_property(flash_rect, "modulate:a", 1.0, 0.18)
	await tw.finished


func _flash_from_white() -> void:
	if flash_rect:
		var tw := create_tween()
		tw.tween_property(flash_rect, "modulate:a", 0.0, 0.28)
		await tw.finished
	if flash_layer:
		flash_layer.queue_free()
		flash_layer = null
		flash_rect = null


# ---------------------------------------------------------------- test / pause menu
func _toggle_menu() -> void:
	Globals.play_sfx("ui")
	if menu_open:
		_close_menu()
	else:
		_open_menu()


func _open_menu(mode: String = "pause") -> void:
	menu_open = true
	menu_mode = mode
	menu_cursor = 0
	_build_menu_items()

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 80
	add_child(menu_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6); dim.size = SCREEN
	menu_layer.add_child(dim)
	var title := "— MENU —"
	if mode == "store":
		title = "🛒  GRANDPA'S GENERAL STORE  🛒"
	elif mode == "settings":
		title = "⚙  SETTINGS — AUDIO  ⚙"
	menu_title = _label(title, 44, Vector2(0, 180), true)
	menu_title.add_theme_color_override("font_color", Color(1, 1, 1))
	menu_layer.add_child(menu_title)
	menu_vbox = VBoxContainer.new()
	menu_vbox.position = Vector2(SCREEN.x * 0.5 - 280, 330)
	menu_layer.add_child(menu_vbox)
	if mode == "settings":
		var hint := _label("◀ ▶  adjust volume      Ⓐ on Back to return", 26, Vector2(0, 640), true)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		menu_layer.add_child(hint)
	_refresh_menu()


func _sword_cost() -> int:
	return 10 + (Globals.sword_level - 1) * 5   # gets pricier each level


func _snack_cost() -> int:
	return 8


func _build_menu_items() -> void:
	if menu_mode == "store":
		menu_items = [
			"Sharpen Star Sword  (+2 atk)  — %d 🪙   [Lv %d]" % [_sword_cost(), Globals.sword_level],
			"Bigger Snacks  (+4 heal)  — %d 🪙" % _snack_cost(),
			"Leave     (you have %d 🪙)" % Globals.gold,
		]
	elif menu_mode == "settings":
		menu_items = [
			"Game Music     %s" % _slider_bar(Globals.music_volume),
			"Sound Effects  %s" % _slider_bar(Globals.sfx_volume),
			"Back",
		]
	else:
		menu_items = ["Resume"]
		if state == "play":
			menu_items.append("Test Battle")
		menu_items.append("Settings")
		menu_items.append("Quit Game")


func _slider_bar(v: int) -> String:
	return "◀ %s%s ▶  %d" % ["█".repeat(v), "░".repeat(10 - v), v]


func _close_menu() -> void:
	menu_open = false
	if is_instance_valid(menu_layer):
		menu_layer.queue_free()
	menu_layer = null


func _refresh_menu() -> void:
	if not is_instance_valid(menu_vbox):
		return
	for ch in menu_vbox.get_children():
		menu_vbox.remove_child(ch)
		ch.queue_free()
	for i in menu_items.size():
		var l := _label(("> " if i == menu_cursor else "   ") + menu_items[i], 36, Vector2.ZERO, false)
		l.add_theme_color_override("font_color", Color(1, 1, 0.7) if i == menu_cursor else Color(1, 1, 1))
		menu_vbox.add_child(l)


func _adjust_setting(row: int, dv: int) -> void:
	if row == 0:
		Globals.set_music_volume(Globals.music_volume + dv)
	else:
		Globals.set_sfx_volume(Globals.sfx_volume + dv)
	Globals.play_sfx("ui")   # doubles as a live preview of the SFX level
	_build_menu_items()
	_refresh_menu()


func _menu_select() -> void:
	if not (menu_mode == "settings" and menu_cursor < 2):
		Globals.play_sfx("ui")   # slider rows chirp via _adjust_setting instead
	if menu_mode == "settings":
		match menu_cursor:
			0, 1:
				# A / tap bumps the level, wrapping past max — keeps sliders touch-usable
				var cur: int = Globals.music_volume if menu_cursor == 0 else Globals.sfx_volume
				_adjust_setting(menu_cursor, -cur if cur >= 10 else 1)
			2:
				_close_menu()
				_open_menu("pause")
		return

	if menu_mode == "store":
		match menu_cursor:
			0:
				if Globals.gold >= _sword_cost():
					Globals.gold -= _sword_cost()
					Globals.atk_bonus += 2
					Globals.sword_level += 1
					Globals.play_sfx("coin")
					_popup("Star Sword sharpened! ⚔ attack +2")
				else:
					_popup("Not enough gold! Calm creatures & find chests 🪙")
				_build_menu_items()
				_refresh_menu()
				_update_hud_counts()
			1:
				if Globals.gold >= _snack_cost():
					Globals.gold -= _snack_cost()
					Globals.heal_bonus += 4
					Globals.play_sfx("coin")
					_popup("Snacks upgraded! 🍪 heal +4")
				else:
					_popup("Not enough gold! Calm creatures & find chests 🪙")
				_build_menu_items()
				_refresh_menu()
				_update_hud_counts()
			2:
				_close_menu()
		return

	var item := menu_items[menu_cursor]
	_close_menu()
	match item:
		"Resume":
			pass
		"Test Battle":
			if state == "play":
				_start_battle()
		"Settings":
			_open_menu("settings")
		"Quit Game":
			get_tree().quit()


# ---------------------------------------------------------------- helpers
func _fit_height(spr: Sprite2D, target_px: float) -> Vector2:
	var h := spr.texture.get_height()
	var sc := target_px / float(h)
	spr.scale = Vector2(sc, sc)
	return spr.scale


## Anchored world sprite per the art manifest: bottom-center pivot (baked base
## shadow sits on the ground), scaled to a target on-screen height. Place at the
## ground-contact point; Y-sort then handles front/behind overlap. flip_h still
## mirrors cleanly because the rect stays horizontally centered on the origin.
func _make_sprite(path: String, world_pos: Vector2, height: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	var tw := float(s.texture.get_width())
	var th := float(s.texture.get_height())
	var sc := height / th
	s.scale = Vector2(sc, sc)
	s.offset = Vector2(-tw / 2.0, -th)
	s.position = world_pos
	return s


func _label(text: String, size: int, pos: Vector2, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.12, 0.12, 0.2))
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	if centered:
		l.size = Vector2(SCREEN.x, float(size) + 12.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

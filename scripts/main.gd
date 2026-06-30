extends Node2D
## Overworld + character select. Pick Emmy/Isla, walk the island collecting
## presents, walk into the grumpy creature (or use the Start test menu) to enter
## an FF-style Funk-Off battle. Gamepad-first (Steam Deck) with touch fallbacks.

const HEROES: Array[String] = ["isla", "emmy"]
const SCREEN := Vector2(1280, 800)
const AREA_MIN := Vector2(150, 230)
const AREA_MAX := Vector2(1130, 700)
const BATTLE := preload("res://battle.tscn")

var state: String = "select"        # select / play / battle
var sel: int = 0
var ui: CanvasLayer
var player: Node2D
var player_base_scale: Vector2 = Vector2.ONE
var presents: Array[Sprite2D] = []
var creature: Sprite2D
var score: int = 0
var score_label: Label
var anim_t: float = 0.0
var encounter_cd: float = 0.0

# battle transition
var battle_node: Node
var flash_layer: CanvasLayer
var flash_rect: ColorRect

# pause / test menu
var menu_open: bool = false
var menu_layer: CanvasLayer
var menu_vbox: VBoxContainer
var menu_cursor: int = 0
var menu_items: Array[String] = []


func _ready() -> void:
	show_select()


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
func _input(event: InputEvent) -> void:
	# Open/close the test menu with Start (☰) or Back (⧉) or Escape.
	var menu_btn := false
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var bi := (event as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_START or bi == JOY_BUTTON_BACK:
			menu_btn = true
	elif event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		menu_btn = true
	if menu_btn and state != "battle":
		_toggle_menu()
		return

	if menu_open:
		if _confirm_pressed(event):
			_menu_select()
		return

	# gamepad face buttons handled directly (Deck-robust)
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var b := (event as InputEventJoypadButton).button_index
		if state == "select" and b == JOY_BUTTON_A:
			start_game(HEROES[sel]); return
		if state == "play" and b == JOY_BUTTON_B:
			_reset_to_select(); return

	if state != "select":
		return

	# touch/click to pick a hero (left = Isla, right = Emmy)
	var pos := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and \
			(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	if pos != Vector2.INF:
		sel = 0 if pos.x < SCREEN.x * 0.5 else 1
		_update_cursor()
		start_game(HEROES[sel])


func _confirm_pressed(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		return true
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


# ---------------------------------------------------------------- world
func start_game(hero: String) -> void:
	state = "play"
	Globals.hero = hero
	ui.queue_free()

	var bg := Sprite2D.new()
	bg.texture = load("res://assets/island_bg.png")
	bg.position = SCREEN * 0.5
	bg.z_index = -10
	add_child(bg)

	var hud := CanvasLayer.new()
	add_child(hud)
	score_label = _label("Presents: 0", 30, Vector2(30, 18), false)
	hud.add_child(score_label)
	hud.add_child(_label("Playing as " + hero.to_upper() + "   (B = change hero,  ☰ = menu)", 22, Vector2(30, 58), false))
	for h in 3:
		var heart := Sprite2D.new()
		heart.texture = load("res://assets/heart.png")
		_fit_height(heart, 46.0)
		heart.position = Vector2(1130 + h * 48, 40)
		hud.add_child(heart)

	creature = Sprite2D.new()
	creature.texture = load("res://assets/grumpy.png")
	_fit_height(creature, 120.0)
	creature.position = Vector2(850, 350)
	creature.z_index = 5
	add_child(creature)

	player = Node2D.new()
	player.position = Vector2(400, 500)
	player.z_index = 10
	add_child(player)
	var spr := Sprite2D.new()
	spr.name = "spr"
	spr.texture = load("res://assets/%s.png" % hero)
	player_base_scale = _fit_height(spr, 185.0)
	player.add_child(spr)

	var spots := [
		Vector2(250, 300), Vector2(1000, 320), Vector2(360, 600),
		Vector2(930, 600), Vector2(640, 270), Vector2(640, 640),
	]
	for s in spots:
		var p := Sprite2D.new()
		p.texture = load("res://assets/present.png")
		_fit_height(p, 78.0)
		p.position = s
		add_child(p)
		presents.append(p)


func _process(delta: float) -> void:
	if menu_open:
		if Input.is_action_just_pressed("ui_up"):
			menu_cursor = (menu_cursor - 1 + menu_items.size()) % menu_items.size()
			_refresh_menu()
		elif Input.is_action_just_pressed("ui_down"):
			menu_cursor = (menu_cursor + 1) % menu_items.size()
			_refresh_menu()
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

	if encounter_cd > 0.0:
		encounter_cd -= delta

	if Input.is_action_just_pressed("ui_cancel"):
		_reset_to_select()
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var moving := dir.length() > 0.1
	player.position += dir * 330.0 * delta
	player.position.x = clampf(player.position.x, AREA_MIN.x, AREA_MAX.x)
	player.position.y = clampf(player.position.y, AREA_MIN.y, AREA_MAX.y)

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

	# walk into the grumpy creature -> battle
	if is_instance_valid(creature) and creature.visible and encounter_cd <= 0.0 \
			and player.position.distance_to(creature.position) < 85.0:
		_start_battle()
		return

	var any_left := false
	for p in presents:
		if p.visible and player.position.distance_to(p.position) < 70.0:
			p.visible = false
			score += 1
			score_label.text = "Presents: %d" % score
		any_left = any_left or p.visible
	if not any_left:
		for p in presents:
			p.visible = true


func _reset_to_select() -> void:
	for c in get_children():
		c.queue_free()
	player = null
	creature = null
	presents.clear()
	score = 0
	call_deferred("show_select")


# ---------------------------------------------------------------- battle
func _start_battle() -> void:
	state = "battle"
	await _flash_to_white()
	var b := BATTLE.instantiate()
	b.enemy_sign = "horse"
	b.battle_finished.connect(_on_battle_finished)
	add_child(b)
	battle_node = b
	await _flash_from_white()


func _on_battle_finished(win: bool) -> void:
	await _flash_to_white()
	if is_instance_valid(battle_node):
		battle_node.queue_free()
		battle_node = null
	if win and is_instance_valid(creature):
		creature.queue_free()
	if is_instance_valid(player):
		player.position = Vector2(400, 500)
	encounter_cd = 1.5
	state = "play"
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
	if menu_open:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	menu_open = true
	menu_cursor = 0
	menu_items = ["Resume"]
	if state == "play":
		menu_items.append("Test Battle")
	menu_items.append("Quit Game")

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 80
	add_child(menu_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6); dim.size = SCREEN
	menu_layer.add_child(dim)
	menu_layer.add_child(_label("— MENU —", 44, Vector2(0, 230), true))
	menu_vbox = VBoxContainer.new()
	menu_vbox.position = Vector2(SCREEN.x * 0.5 - 140, 340)
	menu_layer.add_child(menu_vbox)
	_refresh_menu()


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


func _menu_select() -> void:
	var item := menu_items[menu_cursor]
	_close_menu()
	match item:
		"Resume":
			pass
		"Test Battle":
			if state == "play":
				_start_battle()
		"Quit Game":
			get_tree().quit()


# ---------------------------------------------------------------- helpers
func _fit_height(spr: Sprite2D, target_px: float) -> Vector2:
	var h := spr.texture.get_height()
	var s := target_px / float(h)
	spr.scale = Vector2(s, s)
	return spr.scale


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

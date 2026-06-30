extends Node2D
## "Funk-Off" battle — a separate FF-style view. Both sisters vs one grumpy
## creature. Turn-based with a rhythm-timing bonus and Korean-zodiac clash bonus.
## Losable: if both sisters are downed you lose and retreat. Emits battle_finished.

signal battle_finished(win)

const SCREEN := Vector2(1280, 800)
const CLASH := {
	"rat": "horse", "horse": "rat", "ox": "sheep", "sheep": "ox",
	"tiger": "monkey", "monkey": "tiger", "rabbit": "rooster", "rooster": "rabbit",
	"dragon": "dog", "dog": "dragon", "snake": "pig", "pig": "snake",
}

var enemy_sign: String = "horse"

var ui: CanvasLayer
var msg: Label
var menu_box: VBoxContainer
var sisters: Array = []
var enemy: Dictionary = {}
var order: Array = []
var turn_idx: int = -1
var state: String = "intro"      # intro/choosing/rhythm/resolving/enemy/done
var actor: Dictionary = {}
var move_cursor: int = 0
var pending_move: Dictionary = {}

var rhythm_marker: ColorRect
var rhythm_pos: float = 0.0
var rhythm_vel: float = 1.7
var rhythm_x: float = 360.0
var rhythm_w: float = 560.0


func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 50
	add_child(ui)

	var bg := Sprite2D.new()
	bg.texture = load("res://assets/island_bg.png")
	bg.position = SCREEN * 0.5
	bg.modulate = Color(0.55, 0.5, 0.68)
	ui.add_child(bg)
	var tint := ColorRect.new()
	tint.color = Color(0.14, 0.09, 0.24, 0.35)
	tint.size = SCREEN
	ui.add_child(tint)

	msg = _label("A grumpy moon creature is causing trouble!", 30, Vector2(0, 26), true)
	ui.add_child(msg)

	enemy = _make_combatant("Grumblehoof", enemy_sign, 70, false,
		"res://assets/enemies/grumpy.png", Vector2(390, 360), 300.0, false)
	_make_bar(enemy, Vector2(255, 150), 250)
	ui.add_child(_label("GRUMBLEHOOF", 22, Vector2(255, 118), false))

	var isla := _make_combatant("Isla", "rat", 48, true,
		"res://assets/isla.png", Vector2(960, 420), 180.0, true)
	isla["moves"] = [
		{"name": "Funk Jab", "sign": "rat", "power": 11, "hits": 1, "kind": "attack"},
		{"name": "Nibble Flurry", "sign": "rat", "power": 5, "hits": 3, "kind": "attack"},
		{"name": "Snack Share", "sign": "rat", "power": 16, "hits": 1, "kind": "heal"},
	]
	var emmy := _make_combatant("Emmy", "monkey", 52, true,
		"res://assets/emmy.png", Vector2(1115, 500), 180.0, true)
	emmy["moves"] = [
		{"name": "Funk Jab", "sign": "monkey", "power": 11, "hits": 1, "kind": "attack"},
		{"name": "Silly Dance", "sign": "monkey", "power": 9, "hits": 1, "kind": "attack"},
		{"name": "Snack Share", "sign": "monkey", "power": 16, "hits": 1, "kind": "heal"},
	]
	sisters = [isla, emmy]
	_make_bar(isla, Vector2(60, 662), 280)
	_make_bar(emmy, Vector2(60, 724), 280)
	ui.add_child(_label("ISLA", 22, Vector2(348, 656), false))
	ui.add_child(_label("EMMY", 22, Vector2(348, 718), false))

	order = [isla, emmy, enemy]

	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(70, 470)
	ui.add_child(menu_box)

	await get_tree().create_timer(0.9).timeout
	_next_turn()


func _process(delta: float) -> void:
	if state == "choosing":
		if Input.is_action_just_pressed("ui_up"):
			move_cursor = (move_cursor - 1 + actor["moves"].size()) % actor["moves"].size()
			_refresh_menu()
		elif Input.is_action_just_pressed("ui_down"):
			move_cursor = (move_cursor + 1) % actor["moves"].size()
			_refresh_menu()
	elif state == "rhythm":
		rhythm_pos += rhythm_vel * delta
		if rhythm_pos >= 1.0:
			rhythm_pos = 1.0
			rhythm_vel = -absf(rhythm_vel)
		elif rhythm_pos <= 0.0:
			rhythm_pos = 0.0
			rhythm_vel = absf(rhythm_vel)
		if rhythm_marker:
			rhythm_marker.position.x = rhythm_x + rhythm_pos * rhythm_w


func _input(event: InputEvent) -> void:
	if state != "choosing" and state != "rhythm":
		return
	var confirm := false
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		confirm = true
	elif event.is_action_pressed("ui_accept"):
		confirm = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		confirm = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		confirm = true
	if confirm:
		if state == "choosing":
			_start_rhythm()
		elif state == "rhythm":
			_lock_rhythm()


# ---------------------------------------------------------------- turn flow
func _next_turn() -> void:
	if not enemy["alive"]:
		_finish(true); return
	if not sisters[0]["alive"] and not sisters[1]["alive"]:
		_finish(false); return
	for i in order.size():
		turn_idx = (turn_idx + 1) % order.size()
		if order[turn_idx]["alive"]:
			break
	actor = order[turn_idx]
	if actor["is_player"]:
		state = "choosing"
		move_cursor = 0
		msg.text = actor["name"] + "'s turn — pick a move (A)"
		_refresh_menu()
	else:
		_enemy_turn()


func _start_rhythm() -> void:
	state = "rhythm"
	pending_move = actor["moves"][move_cursor]
	_clear_menu()
	rhythm_pos = 0.0
	rhythm_vel = absf(rhythm_vel)
	var y := 600.0
	var track := ColorRect.new()
	track.name = "rtrack"; track.color = Color(0, 0, 0, 0.5)
	track.position = Vector2(rhythm_x, y); track.size = Vector2(rhythm_w, 40)
	ui.add_child(track)
	var zw := rhythm_w * 0.18
	var zone := ColorRect.new()
	zone.name = "rzone"; zone.color = Color(0.3, 0.9, 0.5, 0.7)
	zone.position = Vector2(rhythm_x + rhythm_w * 0.5 - zw * 0.5, y); zone.size = Vector2(zw, 40)
	ui.add_child(zone)
	rhythm_marker = ColorRect.new()
	rhythm_marker.color = Color(1, 1, 1)
	rhythm_marker.position = Vector2(rhythm_x, y - 6); rhythm_marker.size = Vector2(8, 52)
	ui.add_child(rhythm_marker)
	msg.text = "Hit A in the green zone!"


func _lock_rhythm() -> void:
	state = "resolving"
	var d := absf(rhythm_pos - 0.5) * 2.0
	var mult := 0.6
	var q := "Miss"
	if d < 0.10:
		mult = 1.5; q = "PERFECT!"
	elif d < 0.25:
		mult = 1.15; q = "Good!"
	elif d < 0.45:
		mult = 0.9; q = "Ok"
	_clear_rhythm()
	await _resolve_move(actor, pending_move, mult, q)
	_next_turn()


func _resolve_move(c: Dictionary, move: Dictionary, mult: float, q: String) -> void:
	if move["kind"] == "heal":
		var amt := int(move["power"] * mult)
		for s in sisters:
			if s["alive"]:
				s["hp"] = min(int(s["max"]), int(s["hp"]) + amt)
				_update_bar(s)
		msg.text = "%s — %s  +%d funk to all!" % [move["name"], q, amt]
		await _hop(c["spr"])
		await get_tree().create_timer(0.7).timeout
		return

	var clash: bool = CLASH.get(move["sign"], "") == enemy["sign"]
	var total := 0
	for h in int(move["hits"]):
		var dmg := int(move["power"] * mult * (1.5 if clash else 1.0))
		enemy["hp"] = max(0, int(enemy["hp"]) - dmg)
		total += dmg
		_update_bar(enemy)
		await _hop(c["spr"])
		await _shake(enemy["spr"])
	var txt := "%s — %s  (%d funk)" % [move["name"], q, total]
	if clash:
		txt += "   ⚡ ZODIAC CLASH! x1.5"
	msg.text = txt
	if int(enemy["hp"]) <= 0:
		enemy["alive"] = false
	await get_tree().create_timer(0.7).timeout


func _enemy_turn() -> void:
	state = "enemy"
	_clear_menu()
	var targets := sisters.filter(func(s): return s["alive"])
	if targets.is_empty():
		_next_turn(); return
	var t: Dictionary = targets[randi() % targets.size()]
	msg.text = enemy["name"] + " grumbles angrily!"
	await get_tree().create_timer(0.6).timeout
	await _hop(enemy["spr"])
	var dmg := 7 + (randi() % 7)
	t["hp"] = max(0, int(t["hp"]) - dmg)
	_update_bar(t)
	await _shake(t["spr"])
	if int(t["hp"]) <= 0:
		t["alive"] = false
		t["spr"].modulate = Color(1, 1, 1, 0.4)
		msg.text = t["name"] + " is too dizzy to dance!"
	else:
		msg.text = "%s took %d funk damage!" % [t["name"], dmg]
	await get_tree().create_timer(0.7).timeout
	_next_turn()


func _finish(win: bool) -> void:
	state = "done"
	_clear_menu()
	msg.text = "Grumblehoof is calm again — it floats home to the Moon! 🌙" if win else "Out of funk! You retreat to rest..."
	await get_tree().create_timer(1.4).timeout
	battle_finished.emit(win)


# ---------------------------------------------------------------- helpers
func _make_combatant(nm: String, sign: String, hp: int, is_player: bool,
		tex: String, pos: Vector2, height: float, flip: bool) -> Dictionary:
	var spr := Sprite2D.new()
	spr.texture = load(tex)
	spr.position = pos
	spr.flip_h = flip
	var sc := height / float(spr.texture.get_height())
	spr.scale = Vector2(sc, sc)
	ui.add_child(spr)
	return {"name": nm, "sign": sign, "hp": hp, "max": hp, "is_player": is_player, "spr": spr, "alive": true}


func _make_bar(c: Dictionary, pos: Vector2, w: float) -> void:
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.5); back.position = pos; back.size = Vector2(w, 22)
	ui.add_child(back)
	var fill := ColorRect.new()
	fill.color = Color(0.3, 0.85, 0.4); fill.position = pos; fill.size = Vector2(w, 22)
	ui.add_child(fill)
	c["bar_fill"] = fill
	c["bar_w"] = w


func _update_bar(c: Dictionary) -> void:
	var f := clampf(float(c["hp"]) / float(c["max"]), 0.0, 1.0)
	c["bar_fill"].size.x = c["bar_w"] * f
	c["bar_fill"].color = Color(0.85, 0.3, 0.3) if f < 0.3 else Color(0.3, 0.85, 0.4)


func _refresh_menu() -> void:
	_clear_menu()
	var moves: Array = actor["moves"]
	for i in moves.size():
		var l := Label.new()
		l.text = ("> " if i == move_cursor else "   ") + str(moves[i]["name"])
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color(1, 1, 0.7) if i == move_cursor else Color(1, 1, 1))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 5)
		menu_box.add_child(l)


func _clear_menu() -> void:
	for ch in menu_box.get_children():
		menu_box.remove_child(ch)
		ch.queue_free()


func _clear_rhythm() -> void:
	for n in ["rtrack", "rzone"]:
		var x := ui.get_node_or_null(n)
		if x:
			x.queue_free()
	if rhythm_marker:
		rhythm_marker.queue_free()
		rhythm_marker = null


func _hop(spr: Sprite2D) -> void:
	var base := spr.position
	var tw := create_tween()
	tw.tween_property(spr, "position", base + Vector2(0, -25), 0.1)
	tw.tween_property(spr, "position", base, 0.1)
	await tw.finished


func _shake(spr: Sprite2D) -> void:
	var base := spr.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(spr, "position", base + Vector2(9, 0), 0.04)
		tw.tween_property(spr, "position", base + Vector2(-9, 0), 0.04)
	tw.tween_property(spr, "position", base, 0.04)
	await tw.finished


func _label(text: String, size: int, pos: Vector2, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	if centered:
		l.size = Vector2(SCREEN.x, float(size) + 12.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

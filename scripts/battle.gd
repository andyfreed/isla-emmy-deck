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

const SIGN_EMOJI := {
	"rat": "🐀", "ox": "🐂", "tiger": "🐅", "rabbit": "🐇", "dragon": "🐉",
	"snake": "🐍", "horse": "🐎", "sheep": "🐑", "monkey": "🐒",
	"rooster": "🐓", "dog": "🐕", "pig": "🐖",
}

var ui: CanvasLayer
var msg: Label
var menu_box: Control
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
var active_marker: Label


func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 50
	add_child(ui)

	var bg := Sprite2D.new()
	bg.texture = load("res://assets/island_bg.png")
	bg.position = SCREEN * 0.5
	bg.modulate = Color(0.62, 0.5, 0.52)          # warm dusk (pastel-blue creatures pop)
	ui.add_child(bg)
	var tint := ColorRect.new()
	tint.color = Color(0.2, 0.09, 0.16, 0.38)     # warm plum, not blue
	tint.size = SCREEN
	ui.add_child(tint)

	# moon-glow halo behind the creature — guarantees contrast for any coat color
	var glow_grad := Gradient.new()
	glow_grad.colors = PackedColorArray([Color(1.0, 0.95, 0.78, 0.5), Color(1.0, 0.95, 0.78, 0.0)])
	glow_grad.offsets = PackedFloat32Array([0.0, 1.0])
	var glow_tex := GradientTexture2D.new()
	glow_tex.width = 512
	glow_tex.height = 512
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(0.98, 0.5)
	glow_tex.gradient = glow_grad
	var glow := Sprite2D.new()
	glow.texture = glow_tex
	glow.position = Vector2(390, 330)
	glow.scale = Vector2(1.7, 1.7)
	ui.add_child(glow)

	msg = _label("A grumpy moon creature is causing trouble!", 30, Vector2(0, 26), true)
	ui.add_child(msg)

	enemy = _make_combatant("Grumblehoof", enemy_sign, 70, false,
		"res://assets/enemies/grumpy.png", Vector2(390, 360), 300.0, false)
	_make_bar(enemy, Vector2(255, 150), 250)
	ui.add_child(_label("GRUMBLEHOOF  %s %s" % [SIGN_EMOJI.get(enemy_sign, ""), enemy_sign.to_upper()], 22, Vector2(255, 118), false))

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

	menu_box = Control.new()
	menu_box.position = Vector2(0, 0)
	ui.add_child(menu_box)

	active_marker = _label("▼", 44, Vector2.ZERO, false)
	active_marker.add_theme_color_override("font_color", Color(1, 1, 0.3))
	active_marker.visible = false
	ui.add_child(active_marker)

	await get_tree().create_timer(0.9).timeout
	_next_turn()


func _process(delta: float) -> void:
	if state == "choosing":
		if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_up"):
			move_cursor = (move_cursor - 1 + actor["moves"].size()) % actor["moves"].size()
			_refresh_menu()
		elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_down"):
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
		msg.add_theme_color_override("font_color", Color(1, 1, 1))
		msg.text = actor["name"] + "'s turn — choose a card!  (◀ ▶ then A)"
		_show_active(actor)
		_refresh_menu()
	else:
		_hide_active()
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
		await _hop(c["spr"])
		for s in sisters:
			if s["alive"]:
				s["hp"] = min(int(s["max"]), int(s["hp"]) + amt)
				_update_bar(s)
				_popup_dmg(s["spr"].position, "+%d" % amt, Color(0.4, 1.0, 0.5), false)
		msg.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
		msg.text = "%s — %s   heal!" % [move["name"], q]
		await get_tree().create_timer(0.7).timeout
		return

	var clash: bool = CLASH.get(move["sign"], "") == enemy["sign"]
	var total := 0
	var big := clash or q == "PERFECT!"
	var home: Vector2 = c["spr"].position
	await _lunge_to(c["spr"], enemy["spr"].position + Vector2(190, 30))
	for h in int(move["hits"]):
		var dmg := int(move["power"] * mult * (1.5 if clash else 1.0))
		await _strike(c["spr"])
		enemy["hp"] = max(0, int(enemy["hp"]) - dmg)
		total += dmg
		_update_bar(enemy)
		_flash_white(enemy["spr"])
		_scale_punch(enemy["spr"])
		_popup_dmg(enemy["spr"].position, str(dmg), Color(1, 0.85, 0.2) if big else Color(1, 1, 1), big)
		_shake_screen(16.0 if big else 8.0)
		await get_tree().create_timer(0.08).timeout   # hit-stop beat
		await _shake(enemy["spr"])
	_lunge_back(c["spr"], home)
	var txt := "%s — %s   (%d funk)" % [move["name"], q, total]
	if clash:
		txt += "    ⚡ ZODIAC CLASH! ×1.5"
	_color_msg(q, clash)
	msg.text = txt
	if int(enemy["hp"]) <= 0:
		enemy["alive"] = false
	await get_tree().create_timer(0.55).timeout


func _enemy_turn() -> void:
	state = "enemy"
	_clear_menu()
	var targets := sisters.filter(func(s): return s["alive"])
	if targets.is_empty():
		_next_turn(); return
	var t: Dictionary = targets[randi() % targets.size()]
	msg.add_theme_color_override("font_color", Color(1, 1, 1))
	msg.text = enemy["name"] + " grumbles angrily!"
	await get_tree().create_timer(0.5).timeout
	var ehome: Vector2 = enemy["spr"].position
	await _lunge_to(enemy["spr"], t["spr"].position + Vector2(-200, -40))
	var dmg := 7 + (randi() % 7)
	t["hp"] = max(0, int(t["hp"]) - dmg)
	_update_bar(t)
	_flash_white(t["spr"])
	_scale_punch(t["spr"])
	_popup_dmg(t["spr"].position, str(dmg), Color(1, 0.5, 0.5), false)
	_shake_screen(9.0)
	await get_tree().create_timer(0.08).timeout
	await _shake(t["spr"])
	_lunge_back(enemy["spr"], ehome)
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
	_hide_active()
	if win:
		msg.add_theme_color_override("font_color", Color(0.6, 1, 0.7))
		msg.text = "Grumblehoof is calm again! 🌙"
		await _calm_sequence()
		await get_tree().create_timer(0.6).timeout
	else:
		msg.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
		msg.text = "Out of funk! You retreat to rest..."
		await get_tree().create_timer(1.2).timeout
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
	if c.has("bar_tween") and c["bar_tween"] != null and (c["bar_tween"] as Tween).is_valid():
		(c["bar_tween"] as Tween).kill()
	var tw := create_tween()
	c["bar_tween"] = tw
	tw.tween_property(c["bar_fill"], "size:x", c["bar_w"] * f, 0.25)
	c["bar_fill"].color = Color(0.85, 0.3, 0.3) if f < 0.3 else Color(0.3, 0.85, 0.4)


func _refresh_menu() -> void:
	_clear_menu()
	var moves: Array = actor["moves"]
	var cw := 196.0
	var ch := 236.0
	var gap := 22.0
	var x0 := 64.0
	for i in moves.size():
		var m: Dictionary = moves[i]
		var on := i == move_cursor
		var card := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.24, 0.5, 0.32) if m["kind"] == "heal" else Color(0.42, 0.28, 0.5)
		if on:
			sb.bg_color = sb.bg_color.lightened(0.22)
		sb.set_corner_radius_all(16)
		sb.border_color = Color(1, 0.95, 0.6) if on else Color(0.1, 0.08, 0.15)
		sb.set_border_width_all(5 if on else 3)
		card.add_theme_stylebox_override("panel", sb)
		card.position = Vector2(x0 + i * (cw + gap), (500.0 if on else 540.0))
		card.size = Vector2(cw, ch)
		card.modulate = Color(1, 1, 1) if on else Color(0.82, 0.82, 0.85)
		menu_box.add_child(card)

		var nm := Label.new()
		nm.text = str(m["name"])
		nm.add_theme_font_size_override("font_size", 26)
		nm.add_theme_color_override("font_color", Color(1, 1, 1))
		nm.position = Vector2(0, 10)
		nm.size = Vector2(cw, 34)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(nm)

		var art := Label.new()
		art.text = SIGN_EMOJI.get(m["sign"], "✨")
		art.add_theme_font_size_override("font_size", 74)
		art.position = Vector2(0, 52)
		art.size = Vector2(cw, 96)
		art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(art)

		var info := Label.new()
		var hits := int(m["hits"])
		if m["kind"] == "heal":
			info.text = "heals %d" % int(m["power"])
		elif hits > 1:
			info.text = "%d × %d hits" % [int(m["power"]), hits]
		else:
			info.text = "power %d" % int(m["power"])
		info.add_theme_font_size_override("font_size", 22)
		info.add_theme_color_override("font_color", Color(1, 1, 0.75))
		info.position = Vector2(0, 156)
		info.size = Vector2(cw, 30)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(info)

		var sign_l := Label.new()
		sign_l.text = str(m["sign"]).to_upper()
		sign_l.add_theme_font_size_override("font_size", 17)
		sign_l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
		sign_l.position = Vector2(0, 198)
		sign_l.size = Vector2(cw, 24)
		sign_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(sign_l)


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


func _lunge_to(spr: Sprite2D, target: Vector2) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "position", target, 0.16)
	await tw.finished


func _lunge_back(spr: Sprite2D, home: Vector2) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position", home, 0.2)


func _strike(spr: Sprite2D) -> void:
	var base := spr.position
	var tw := create_tween()
	tw.tween_property(spr, "position", base + Vector2(-46, -14), 0.06)
	tw.tween_property(spr, "position", base, 0.08)
	await tw.finished


func _scale_punch(spr: Sprite2D) -> void:
	var base := spr.scale
	var tw := create_tween()
	tw.tween_property(spr, "scale", base * 1.16, 0.06)
	tw.tween_property(spr, "scale", base, 0.14)


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


func _popup_dmg(pos: Vector2, text: String, color: Color, big: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 56 if big else 38)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos + Vector2(-18, -150)
	l.z_index = 60
	ui.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 90, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func _flash_white(spr: Sprite2D) -> void:
	spr.modulate = Color(1.8, 1.8, 1.8)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color(1, 1, 1), 0.22)


func _shake_screen(amount: float) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(ui, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	tw.tween_property(ui, "offset", Vector2.ZERO, 0.04)


func _color_msg(q: String, clash: bool) -> void:
	var col := Color(1, 1, 1)
	if clash:
		col = Color(1, 0.8, 0.2)
	elif q == "PERFECT!":
		col = Color(0.5, 1, 0.6)
	msg.add_theme_color_override("font_color", col)


func _sparkle(pos: Vector2) -> void:
	var s := Label.new()
	s.text = "✦"
	s.add_theme_font_size_override("font_size", 44)
	s.add_theme_color_override("font_color", Color(1, 1, 0.6))
	s.position = pos + Vector2(randf_range(-90, 90), randf_range(-90, 40))
	s.z_index = 70
	ui.add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position:y", s.position.y - 130, 0.9)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.9)
	tw.tween_callback(s.queue_free)


func _calm_sequence() -> void:
	var spr: Sprite2D = enemy["spr"]
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color(1.3, 1.25, 1.1), 0.3)
	await tw.finished
	await _hop(spr)
	await _hop(spr)
	for i in 10:
		_sparkle(spr.position)
	var tw2 := create_tween()
	tw2.tween_property(spr, "position:y", spr.position.y - 600, 1.3)
	tw2.parallel().tween_property(spr, "modulate:a", 0.0, 1.3)
	await tw2.finished


func _show_active(c: Dictionary) -> void:
	active_marker.visible = true
	var sp: Sprite2D = c["spr"]
	active_marker.position = sp.position + Vector2(-14, -150)


func _hide_active() -> void:
	if active_marker:
		active_marker.visible = false


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

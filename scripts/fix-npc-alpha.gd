extends SceneTree
## Bake NPC garment interiors opaque. Run from the repo root:
##   godot --headless -s scripts/fix-npc-alpha.gd
## (pull-art.sh runs it automatically after syncing npcs/)
##
## Some art exports paint clothing at 40-70% alpha, so the ground shows through
## characters in-game. Any pixel deeper than EDGE px from transparency is lifted
## to full alpha; soft anti-aliased rims and true see-through gaps keep theirs.

const DIR := "assets/npcs"
const SOLID_A := 25   # 0-255; >= this counts as painted figure
const EDGE := 3       # px of soft rim left untouched

func _init() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		print("fix-npc-alpha: run from the repo root (assets/npcs not found)")
		quit(1)
		return
	for f in dir.get_files():
		if f.ends_with(".png"):
			_fix(DIR + "/" + f)
	quit()


func _fix(path: String) -> void:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var mask := PackedByteArray()
	mask.resize(w * h)
	for i in w * h:
		mask[i] = 1 if data[i * 4 + 3] >= SOLID_A else 0
	# erode EDGE times (4-neighbour): what survives is > EDGE px from any
	# transparent pixel — the garment interior, never the soft rim
	for pass_i in EDGE:
		var nxt := mask.duplicate()
		for y in h:
			var row := y * w
			for x in w:
				var i := row + x
				if mask[i] == 0:
					continue
				if x == 0 or y == 0 or x == w - 1 or y == h - 1 \
						or mask[i - 1] == 0 or mask[i + 1] == 0 \
						or mask[i - w] == 0 or mask[i + w] == 0:
					nxt[i] = 0
		mask = nxt
	var changed := 0
	for i in w * h:
		if mask[i] == 1 and data[i * 4 + 3] < 255:
			data[i * 4 + 3] = 255
			changed += 1
	if changed == 0:
		print("%s: already solid" % path)
		return
	Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data).save_png(path)
	print("%s: solidified %d px" % [path, changed])

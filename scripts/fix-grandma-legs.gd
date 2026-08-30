extends SceneTree
## One-off surgery for grandma.png: background removal ate chunks of her pants,
## leaving transparent voids INSIDE the figure (grass showed through in-game).
## Morphologically close the silhouette over the legs region, fill the enclosed
## voids, and inpaint their color from the surrounding solid pixels.
##   godot --headless -s scripts/fix-grandma-legs.gd   (from the repo root)
## Superseded whenever the art side delivers a grandma v2 with a solid lower
## body — re-run only if that export shows the same voids.

const PATH := "assets/npcs/grandma.png"
const ROI := Rect2i(250, 550, 450, 602)   # below the shoulders: hem + legs + shoes
const K := 12                             # closes silhouette gaps up to ~24 px wide

func _init() -> void:
	var img := Image.load_from_file(PATH)
	img.convert(Image.FORMAT_RGBA8)
	var roi := img.get_region(ROI)
	var w := roi.get_width()
	var h := roi.get_height()
	var data := roi.get_data()
	var n := w * h
	var mask := PackedByteArray()
	mask.resize(n)
	for i in n:
		mask[i] = 1 if data[i * 4 + 3] >= 25 else 0
	var closed := _morph(_morph(mask, w, h, K, true), w, h, K, false)
	# grow color into the enclosed voids from solid neighbours, one px per sweep
	var filled := 0
	var frontier := true
	while frontier:
		frontier = false
		for y in h:
			for x in w:
				var i := y * w + x
				if mask[i] == 1 or closed[i] == 0:
					continue
				var r := 0
				var g := 0
				var b := 0
				var c := 0
				for o: Array in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
					var xx: int = x + o[0]
					var yy: int = y + o[1]
					if xx < 0 or yy < 0 or xx >= w or yy >= h:
						continue
					var j := yy * w + xx
					if mask[j] == 1 and data[j * 4 + 3] >= 200:
						r += data[j * 4]
						g += data[j * 4 + 1]
						b += data[j * 4 + 2]
						c += 1
				if c > 0:
					data[i * 4] = r / c
					data[i * 4 + 1] = g / c
					data[i * 4 + 2] = b / c
					data[i * 4 + 3] = 255
					mask[i] = 1
					filled += 1
					frontier = true
	# solidify leftover semi-alpha fuzz inside the closed figure
	var lifted := 0
	for i in n:
		if closed[i] == 1 and data[i * 4 + 3] >= 25 and data[i * 4 + 3] < 255:
			data[i * 4 + 3] = 255
			lifted += 1
	print("filled %d void px, lifted %d semi px" % [filled, lifted])
	var out := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	img.blit_rect(out, Rect2i(0, 0, w, h), ROI.position)
	img.save_png(PATH)
	print("saved %s" % PATH)
	quit()


func _morph(src: PackedByteArray, w: int, h: int, k: int, grow: bool) -> PackedByteArray:
	var cur := src.duplicate()
	for pass_i in k:
		var nxt := cur.duplicate()
		for y in h:
			for x in w:
				var i := y * w + x
				var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
				if grow:
					if cur[i] == 0 and not edge and (cur[i - 1] == 1 or cur[i + 1] == 1
							or cur[i - w] == 1 or cur[i + w] == 1):
						nxt[i] = 1
				else:
					if cur[i] == 1 and (edge or cur[i - 1] == 0 or cur[i + 1] == 0
							or cur[i - w] == 0 or cur[i + w] == 0):
						nxt[i] = 0
		cur = nxt
	return cur

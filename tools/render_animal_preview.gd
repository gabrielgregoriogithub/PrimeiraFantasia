extends SceneTree

const OUTPUT := "res://tools/animal_preview.png"

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 760))
	root.size = Vector2i(1280, 760)
	var canvas := Node2D.new()
	root.add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1280, 760)
	backdrop.color = Color("18202b")
	canvas.add_child(backdrop)
	var catalog := AnimalSpriteCatalog.build()
	var keys := ["spd_rat", "spd_snake", "spd_gnoll", "spd_slime", "spd_goo"]
	var actions := ["idle_down", "walk_down", "attack", "hit", "death"]
	for column in actions.size():
		_add_label(canvas, actions[column], Vector2(105 + column * 135, 28), 15)
	for row in keys.size():
		var sprite_key: String = keys[row]
		var spec: Dictionary = catalog[sprite_key]
		_add_label(canvas, sprite_key.trim_prefix("spd_").to_upper(), Vector2(18, 105 + row * 135), 20)
		for column in actions.size():
			var action: String = actions[column]
			var frames: Array = spec["anims"][action][0]
			var frame_index := 0
			if action == "walk_down": frame_index = frames.size() - 1
			if action == "attack": frame_index = mini(int(spec["anims"]["contact"]), frames.size() - 1)
			if action == "death": frame_index = frames.size() - 1
			var rect: Array = frames[frame_index]
			var atlas := AtlasTexture.new()
			atlas.atlas = load(AnimalSpriteCatalog.SHEET_ROOT + str(spec["sheet"]))
			atlas.region = Rect2(rect[0], rect[1], rect[2], rect[3])
			var sprite := Sprite2D.new()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.texture = atlas
			sprite.scale = Vector2.ONE * float(spec["scale"])
			sprite.offset = Vector2(0, -float(rect[3]) * 0.5)
			sprite.position = Vector2(135 + column * 135, 205 + row * 135)
			canvas.add_child(sprite)
			var baseline := Line2D.new()
			baseline.points = PackedVector2Array([Vector2(85 + column * 135, 205 + row * 135), Vector2(185 + column * 135, 205 + row * 135)])
			baseline.default_color = Color(0.35, 0.65, 0.75, 0.35)
			canvas.add_child(baseline)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(OUTPUT)
	quit()

func _add_label(parent: Node, value: String, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f3e9d2"))
	parent.add_child(label)

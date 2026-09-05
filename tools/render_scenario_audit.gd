extends SceneTree

const IDS := [ScenarioManager.FIELD, ScenarioManager.TOWER, ScenarioManager.LUA_VALLEY, ScenarioManager.VILLAGE]

func _initialize() -> void:
	call_deferred("_capture_all")

func _capture_all() -> void:
	DisplayServer.window_set_size(Vector2i(920, 920))
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for scenario_id: String in IDS:
		scene.scenario_manager.active_id = scenario_id
		scene._start_new_game()
		await process_frame
		await process_frame
		for child in scene.get_children():
			if child is CanvasLayer:
				child.visible = false
		for token in scene.unit_tokens.values():
			token.visible = false
		if scene.effects_layer != null:
			scene.effects_layer.visible = false
		await process_frame
		var image := root.get_texture().get_image()
		image.save_png("res://tools/scenario_%s_after.png" % scenario_id)
	quit()

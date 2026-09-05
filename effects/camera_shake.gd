extends Node
class_name CameraShake2D

const VisualPolicy = preload("res://data/visual_policy.gd")

var target: Camera2D
var _tween: Tween

func setup(camera: Camera2D) -> void:
	target = camera

func shake(direction: Vector2 = Vector2.RIGHT, intensity: float = 1.25, duration: float = 0.10, critical: bool = false) -> void:
	if target == null: return
	if _tween != null and _tween.is_valid(): _tween.kill()
	target.offset = Vector2.ZERO
	intensity = minf(maxf(0.0, intensity), VisualPolicy.MAX_CAMERA_SHAKE)
	duration = maxf(0.01, duration)
	var axis := direction.normalized()
	if axis == Vector2.ZERO: axis = Vector2.RIGHT
	var normal := axis.orthogonal()
	var noise := normal * (intensity * (0.28 if critical else 0.10))
	_tween = create_tween()
	_tween.tween_property(target, "offset", axis * intensity + noise, duration * 0.25)
	_tween.tween_property(target, "offset", axis * -intensity * 0.68 - noise * 0.55, duration * 0.25)
	_tween.tween_property(target, "offset", axis * intensity * 0.28 + noise * 0.25, duration * 0.25)
	_tween.tween_property(target, "offset", Vector2.ZERO, duration * 0.25)

func cancel_and_reset() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null
	if target != null: target.offset = Vector2.ZERO

func _exit_tree() -> void:
	cancel_and_reset()

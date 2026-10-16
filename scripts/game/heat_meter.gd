class_name HeatMeter
extends Control
## Row of flame icons showing how close the player is to being scorched.

const LIT_TOP := Color(1.0, 0.92, 0.5)
const LIT_BOTTOM := Color(1.0, 0.3, 0.05)
const UNLIT := Color(0.2, 0.1, 0.1, 0.85)
const OUTLINE := Color(0.75, 0.42, 0.18)

var heat: int = 0
var max_heat: int = 3


func _init() -> void:
	custom_minimum_size = Vector2(190, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_heat(new_heat: int, new_max: int) -> void:
	var rose: bool = new_heat > heat
	heat = new_heat
	max_heat = new_max
	queue_redraw()
	if rose:
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE * 1.18, 0.08)
		tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var slot: float = size.x / float(max_heat)
	for i in max_heat:
		var center := Vector2(slot * (i + 0.5), size.y * 0.5)
		_draw_flame(center, size.y * 0.42, i < heat)


func _draw_flame(center: Vector2, h: float, lit: bool) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var steps: int = 14
	for k in range(steps + 1):
		var t: float = float(k) / steps
		var ang: float = PI * 0.5 + (t - 0.5) * TAU
		# Teardrop: wide round bottom, pointed tip.
		var radius: float = h * (0.55 + 0.45 * (1.0 - absf(sin(ang * 0.5))))
		var x: float = cos(ang) * radius * 0.62
		var y: float = -sin(ang) * radius * (1.15 if sin(ang) > 0.0 else 0.8)
		pts.append(center + Vector2(x, y + h * 0.1))
	for p in pts:
		var f: float = clampf((p.y - (center.y - h)) / (2.0 * h), 0.0, 1.0)
		cols.append(LIT_TOP.lerp(LIT_BOTTOM, f) if lit else UNLIT)
	draw_polygon(pts, cols)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, OUTLINE if lit else OUTLINE.darkened(0.5), 2.5, true)

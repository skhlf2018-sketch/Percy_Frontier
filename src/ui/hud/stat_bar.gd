class_name StatBar
extends Control
## 자원 막대(HP·스태미나·공명). 줄어든 양은 잠시 밝은 잔상으로 남아 피해량을 읽기 쉽게 한다.

var label: String = ""
var fill_color := Color(0.85, 0.25, 0.25)
var back_color := Color(0.05, 0.07, 0.09, 0.7)
## 0..1
var value: float = 1.0
## 보호막 등 덧표시(0..1)
var overlay: float = 0.0
var overlay_color := Color(1.0, 0.8, 0.35)
var value_text: String = ""
## 사용 불가 상태(탈진 등) 표시
var warning: bool = false

var _trail: float = 1.0


func set_state(ratio: float, text: String, overlay_ratio: float = 0.0, is_warning: bool = false) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio > _trail:
		_trail = ratio
	value = ratio
	value_text = text
	overlay = clampf(overlay_ratio, 0.0, 1.0)
	warning = is_warning


func _process(delta: float) -> void:
	if _trail > value:
		_trail = move_toward(_trail, value, delta * 0.6)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, back_color)
	if _trail > value:
		draw_rect(Rect2(0, 0, size.x * _trail, size.y), Color(1, 1, 1, 0.35))
	var fill := fill_color
	if warning:
		fill = fill.darkened(0.45)
	draw_rect(Rect2(0, 0, size.x * value, size.y), fill)
	if overlay > 0.0:
		draw_rect(Rect2(0, 0, size.x * overlay, size.y * 0.35), overlay_color)
	draw_rect(r, Color(1, 1, 1, 0.22), false, 1.0)
	var font := get_theme_default_font()
	var fs := int(size.y * 0.72)
	var baseline := size.y * 0.5 + fs * 0.36
	draw_string_outline(font, Vector2(8, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.75))
	draw_string(font, Vector2(8, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	draw_string_outline(font, Vector2(0, baseline), value_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, fs, 3, Color(0, 0, 0, 0.75))
	draw_string(font, Vector2(0, baseline), value_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, fs, Color(1, 1, 1, 0.95))

class_name SkillSlot
extends Control
## 스킬·소모품 빠른 슬롯 하나. 키, 이름, 비용 또는 개수, 재사용 대기를 그린다.
## 빈 슬롯은 '비어 있음'으로 정직하게 표시한다.

var key_text: String = ""
var title: String = ""
var sub_text: String = ""
var accent := Color(0.6, 0.85, 1.0)
## 0..1, 남은 재사용 대기 비율
var cooldown_ratio: float = 0.0
var cooldown_text: String = ""
var available: bool = true
var empty: bool = false
var highlight: float = 0.0


func flash() -> void:
	highlight = 1.0


func _process(delta: float) -> void:
	highlight = maxf(0.0, highlight - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var font := get_theme_default_font()
	draw_rect(r, Color(0.03, 0.05, 0.07, 0.72))
	if empty:
		draw_rect(r, Color(1, 1, 1, 0.18), false, 1.0)
		_text(font, Vector2(size.x * 0.5, size.y * 0.58), "비어 있음", 15, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
		_text(font, Vector2(6, 17), key_text, 15, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_LEFT)
		return
	var border := accent if available else Color(0.45, 0.47, 0.5)
	draw_rect(Rect2(0, size.y - 4.0, size.x, 4.0), Color(border, 0.9 if available else 0.4))
	var title_col := Color(1, 1, 1, 0.95 if available else 0.5)
	_text(font, Vector2(size.x * 0.5, size.y * 0.56), title, 20, title_col, HORIZONTAL_ALIGNMENT_CENTER)
	_text(font, Vector2(size.x * 0.5, size.y - 9.0), sub_text, 14,
		Color(1, 1, 1, 0.75) if available else Color(1.0, 0.55, 0.45, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	if cooldown_ratio > 0.0:
		draw_rect(Rect2(0, 0, size.x, size.y * cooldown_ratio), Color(0, 0, 0, 0.6))
		_text(font, Vector2(size.x * 0.5, size.y * 0.4), cooldown_text, 22, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	if highlight > 0.0:
		draw_rect(r, Color(accent, highlight * 0.5))
	draw_rect(r, Color(border, 0.55), false, 1.5)
	_text(font, Vector2(6, 17), key_text, 15, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT)


func _text(font: Font, pos: Vector2, text: String, fs: int, col: Color, align: HorizontalAlignment) -> void:
	var p := pos
	var width := -1.0
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p = Vector2(0, pos.y)
		width = size.x
	draw_string_outline(font, p, text, align, width, fs, 3, Color(0, 0, 0, 0.75))
	draw_string(font, p, text, align, width, fs, col)

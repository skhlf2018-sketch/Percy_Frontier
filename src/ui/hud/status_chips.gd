class_name StatusChips
extends Control
## 플레이어 상태이상 표시. 발동 중이면 남은 시간, 쌓이는 중이면 축적도를 보여 준다.
## 색 외에 글자로 상태 이름을 항상 표시한다(기획서 §21.3).

const COLORS := {
	StatusEffects.Type.BURN: Color(1.0, 0.5, 0.15),
	StatusEffects.Type.CHILL: Color(0.55, 0.85, 1.0),
	StatusEffects.Type.SHOCK: Color(0.55, 0.95, 1.0),
	StatusEffects.Type.BLEED: Color(0.9, 0.2, 0.3),
}
const CHIP_SIZE := Vector2(118, 28)

var status: StatusEffects
var immunity: float = 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if status == null:
		return
	var font := get_theme_default_font()
	var x := 0.0
	var list := status.describe()
	if status.immunity_time > 0.0:
		_chip(font, x, "정화 %.1f초" % status.immunity_time, Color(0.35, 0.9, 0.8), 1.0, true)
		x += CHIP_SIZE.x + 6.0
	for s in list:
		var col: Color = COLORS.get(s.type, Color.WHITE)
		var name := StatusEffects.type_name(s.type)
		if s.active:
			var total: float = StatusEffects.DURATIONS[s.type]
			_chip(font, x, "%s %.1f초" % [name, s.remaining], col, s.remaining / total, true)
		else:
			var label := "냉각" if s.type == StatusEffects.Type.CHILL else name
			_chip(font, x, "%s %d%%" % [label, int(s.buildup)], col, s.buildup / StatusEffects.THRESHOLD, false)
		x += CHIP_SIZE.x + 6.0


func _chip(font: Font, x: float, text: String, col: Color, ratio: float, active: bool) -> void:
	var r := Rect2(Vector2(x, 0), CHIP_SIZE)
	draw_rect(r, Color(0.03, 0.05, 0.07, 0.75))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), Color(col, 0.55 if active else 0.25))
	draw_rect(r, Color(col, 0.9 if active else 0.5), false, 1.5)
	draw_string_outline(font, r.position + Vector2(8, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(0, 0, 0, 0.75))
	draw_string(font, r.position + Vector2(8, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))

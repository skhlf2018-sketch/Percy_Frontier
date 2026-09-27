class_name CompassBar
extends Control
## 화면 위 가운데의 나침반 띠. 바라보는 방향과 추적 중인 의뢰 목표, 부활 거점의 방향을 보여 준다.
## 정확한 위치 대신 방향과 거리만 알려 준다(기획서 §13.3). 유니크 몬스터는 표시하지 않는다.

const SPAN_DEG := 180.0
const LABELS := ["북", "북동", "동", "남동", "남", "남서", "서", "북서"]
const ACCENT := Color(0.55, 0.92, 1.0)
const QUEST_COLOR := Color(1.0, 0.82, 0.35)

## 북쪽을 0으로 시계 방향 각도(도)
var heading: float = 0.0
## 표식: {"bearing": 도, "color": Color, "text": String, "kind": &"quest"|&"home"}
var markers: Array = []


static func bearing_deg(from: Vector3, to: Vector2) -> float:
	var d := to - Vector2(from.x, from.z)
	return fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)


static func direction_name(bearing: float) -> String:
	return LABELS[int(round(fposmod(bearing, 360.0) / 45.0)) % 8]


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _x_for(bearing: float) -> float:
	var rel := wrapf(bearing - heading, -180.0, 180.0)
	return size.x * 0.5 + rel / SPAN_DEG * size.x


func _draw() -> void:
	var w := size.x
	var h := size.y
	var font := get_theme_default_font()
	# 가장자리로 갈수록 옅어지는 바탕
	var slices := 24
	for i in slices:
		var t := (float(i) + 0.5) / slices
		var a := 0.58 * (1.0 - pow(absf(t - 0.5) * 2.0, 2.0))
		draw_rect(Rect2(w * float(i) / slices, 0, w / slices + 1.0, h * 0.62), Color(0.02, 0.06, 0.09, a))
	# 눈금과 방위
	var step := 15
	for deg in range(0, 360, step):
		var x := _x_for(deg)
		if x < 0.0 or x > w:
			continue
		var fade := 1.0 - pow(absf(x / w - 0.5) * 2.0, 2.0)
		var major := deg % 45 == 0
		if major:
			var txt: String = LABELS[int(deg / 45.0)]
			var fs := 20 if deg % 90 == 0 else 15
			var col := Color(1.0, 0.55, 0.45, fade) if deg == 0 else Color(1, 1, 1, 0.9 * fade)
			draw_string_outline(font, Vector2(x - 40, h * 0.42), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 3, Color(0, 0, 0, 0.6 * fade))
			draw_string(font, Vector2(x - 40, h * 0.42), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, col)
		else:
			draw_line(Vector2(x, h * 0.12), Vector2(x, h * 0.3), Color(1, 1, 1, 0.45 * fade), 1.0)
	# 가운데 표시
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 6, h * 0.62), Vector2(w * 0.5 + 6, h * 0.62),
		Vector2(w * 0.5, h * 0.62 - 8)]), ACCENT)
	# 표식
	for m in markers:
		var rel := wrapf(float(m.bearing) - heading, -180.0, 180.0)
		var clamped := clampf(rel, -SPAN_DEG * 0.5 + 4.0, SPAN_DEG * 0.5 - 4.0)
		var x := w * 0.5 + clamped / SPAN_DEG * w
		var col: Color = m.color
		var y := h * 0.5
		if m.kind == &"quest":
			var r := 7.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, y - r), Vector2(x + r, y), Vector2(x, y + r), Vector2(x - r, y)]), col)
			draw_polyline(PackedVector2Array([Vector2(x, y - r), Vector2(x + r, y), Vector2(x, y + r), Vector2(x - r, y), Vector2(x, y - r)]),
				Color(0, 0, 0, 0.6), 1.5)
		else:
			draw_circle(Vector2(x, y), 4.5, col)
			draw_arc(Vector2(x, y), 4.5, 0.0, TAU, 12, Color(0, 0, 0, 0.6), 1.2)
		# 띠 밖에 있으면 화살표로 방향만
		if absf(rel) > SPAN_DEG * 0.5 - 4.0:
			var dir := signf(rel)
			draw_colored_polygon(PackedVector2Array([Vector2(x + dir * 16, y), Vector2(x + dir * 9, y - 5), Vector2(x + dir * 9, y + 5)]), col)
		var text: String = m.get("text", "")
		if text != "":
			draw_string_outline(font, Vector2(x - 60, h - 2), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, 3, Color(0, 0, 0, 0.7))
			draw_string(font, Vector2(x - 60, h - 2), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, col)

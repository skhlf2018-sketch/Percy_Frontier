class_name ScopeOverlay
extends Control
## 저격 조준경 화면. 원형 시야 바깥을 가리고 조준선을 그린다.


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var radius := minf(s.x, s.y) * 0.46
	var dark := Color(0, 0, 0, 0.94)
	# 원 바깥을 네 개의 사각형과 원 둘레 띠로 가린다.
	draw_rect(Rect2(0, 0, c.x - radius, s.y), dark)
	draw_rect(Rect2(c.x + radius, 0, s.x - c.x - radius, s.y), dark)
	draw_rect(Rect2(c.x - radius, 0, radius * 2.0, c.y - radius), dark)
	draw_rect(Rect2(c.x - radius, c.y + radius, radius * 2.0, s.y - c.y - radius), dark)
	# 가림 띠가 사각 영역의 모서리(반지름의 √2배)까지 덮도록 넓게 그린다.
	var ring := radius * 0.5
	draw_arc(c, radius + ring * 0.5, 0.0, TAU, 96, dark, ring)
	draw_arc(c, radius, 0.0, TAU, 96, Color(0.1, 0.1, 0.1), 3.0)
	var line := Color(0.05, 0.05, 0.05, 0.9)
	draw_line(Vector2(c.x - radius, c.y), Vector2(c.x - 14.0, c.y), line, 2.0)
	draw_line(Vector2(c.x + 14.0, c.y), Vector2(c.x + radius, c.y), line, 2.0)
	draw_line(Vector2(c.x, c.y - radius), Vector2(c.x, c.y - 14.0), line, 2.0)
	draw_line(Vector2(c.x, c.y + 14.0), Vector2(c.x, c.y + radius), line, 2.0)
	for i in range(1, 5):
		var y := c.y + i * radius * 0.12
		draw_line(Vector2(c.x - 6.0, y), Vector2(c.x + 6.0, y), line, 1.5)
	draw_circle(c, 1.6, Color(0.9, 0.15, 0.1))

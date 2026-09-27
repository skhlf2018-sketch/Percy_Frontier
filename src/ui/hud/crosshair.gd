class_name Crosshair
extends Control
## 조준선. 총기는 현재 탄퍼짐만큼 벌어지고, 근접 무기는 원형으로 바뀐다.

enum Mode { GUN, MELEE, HIDDEN }

var mode: int = Mode.GUN
## 화면상 탄퍼짐 반지름(픽셀)
var spread_px: float = 8.0
var color := Color(1, 1, 1, 0.92)

var _shown_spread: float = 8.0


func _process(delta: float) -> void:
	_shown_spread = lerpf(_shown_spread, spread_px, 1.0 - exp(-20.0 * delta))
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var outline := Color(0, 0, 0, 0.7)
	match mode:
		Mode.GUN:
			var gap := 3.0 + _shown_spread
			var length := 9.0
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var a: Vector2 = c + dir * gap
				var b: Vector2 = c + dir * (gap + length)
				draw_line(a, b, outline, 3.5)
				draw_line(a, b, color, 1.6)
			draw_circle(c, 2.2, outline)
			draw_circle(c, 1.3, color)
		Mode.MELEE:
			draw_arc(c, 11.0, 0.0, TAU, 32, outline, 3.5)
			draw_arc(c, 11.0, 0.0, TAU, 32, color, 1.6)
			draw_circle(c, 2.0, color)

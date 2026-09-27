class_name HitMarkers
extends Control
## 명중 표시. 일반·약점·장갑·장갑 파괴·처치를 색과 모양 모두로 구분한다(기획서 §8.7, §21.3).
## - 일반: 흰 작은 X
## - 약점: 주황 X + 원
## - 장갑: 회청색 괄호 [ ]
## - 장갑 파괴: 흰 방사형 폭발선
## - 처치: 붉은 굵은 X

enum Type { NORMAL, WEAK, ARMOR, BREAK, KILL }

const LIFE := 0.3
const COLORS := {
	Type.NORMAL: Color(1, 1, 1),
	Type.WEAK: Color(1.0, 0.62, 0.15),
	Type.ARMOR: Color(0.62, 0.74, 0.86),
	Type.BREAK: Color(1.0, 0.95, 0.8),
	Type.KILL: Color(1.0, 0.25, 0.2),
}

var _markers: Array[Dictionary] = []


func add(type: int) -> void:
	# 같은 프레임의 산탄 여러 발은 가장 중요한 표시 하나로 합친다.
	for m in _markers:
		if m.t < 0.02:
			if type > m.type:
				m.type = type
			return
	_markers.append({"type": type, "t": 0.0})
	if _markers.size() > 6:
		_markers.pop_front()


func _process(delta: float) -> void:
	if _markers.is_empty():
		return
	for m in _markers:
		m.t += delta
	_markers = _markers.filter(func(m: Dictionary) -> bool: return m.t < LIFE)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	for m in _markers:
		var alpha: float = 1.0 - m.t / LIFE
		var col: Color = COLORS[m.type]
		col.a = alpha
		var shadow := Color(0, 0, 0, 0.6 * alpha)
		var grow: float = 1.0 + m.t * 1.2
		match m.type:
			Type.NORMAL:
				_x(c, 6.0 * grow, 12.0 * grow, col, shadow, 1.8)
			Type.WEAK:
				_x(c, 6.0 * grow, 15.0 * grow, col, shadow, 2.4)
				draw_arc(c, 18.0 * grow, 0.0, TAU, 32, shadow, 3.5)
				draw_arc(c, 18.0 * grow, 0.0, TAU, 32, col, 2.0)
			Type.ARMOR:
				var r: float = 15.0 * grow
				for side in [-1.0, 1.0]:
					var pts := PackedVector2Array([
						c + Vector2(side * (r - 5.0), -r), c + Vector2(side * r, -r),
						c + Vector2(side * r, r), c + Vector2(side * (r - 5.0), r)])
					draw_polyline(pts, shadow, 4.0)
					draw_polyline(pts, col, 2.2)
			Type.BREAK:
				for i in 8:
					var dir := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
					draw_line(c + dir * 10.0 * grow, c + dir * 28.0 * grow, shadow, 4.0)
					draw_line(c + dir * 10.0 * grow, c + dir * 28.0 * grow, col, 2.2)
			Type.KILL:
				_x(c, 7.0 * grow, 19.0 * grow, col, shadow, 3.4)


func _x(c: Vector2, inner: float, outer: float, col: Color, shadow: Color, width: float) -> void:
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var dir: Vector2 = d.normalized()
		draw_line(c + dir * inner, c + dir * outer, shadow, width + 2.0)
		draw_line(c + dir * inner, c + dir * outer, col, width)


## 명중 결과를 표시 종류로 바꾼다.
static func type_for(result: HitResult) -> int:
	if result.killed:
		return Type.KILL
	if result.armor_broken:
		return Type.BREAK
	if result.hit_armor:
		return Type.ARMOR
	if result.is_weak_point():
		return Type.WEAK
	return Type.NORMAL

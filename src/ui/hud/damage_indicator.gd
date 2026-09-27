class_name DamageIndicator
extends Control
## 피격 방향 표시. 화면 중심 둘레에 공격이 온 방향을 호로 그린다(기획서 §8.7).
## 방어한 공격은 회색, 막지 못한 공격은 붉은색.

const LIFE := 1.3
const RADIUS := 150.0

var player: Player
var _hits: Array[Dictionary] = []


func add(source_position: Vector3, blocked: bool) -> void:
	if player == null:
		return
	var to := source_position - player.global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		return
	_hits.append({"dir": to.normalized(), "t": 0.0, "blocked": blocked})
	if _hits.size() > 8:
		_hits.pop_front()


func _process(delta: float) -> void:
	if _hits.is_empty():
		return
	for h in _hits:
		h.t += delta
	_hits = _hits.filter(func(h: Dictionary) -> bool: return h.t < LIFE)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var c := size * 0.5
	var fwd := -player.look_basis().z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	for h in _hits:
		var d: Vector3 = h.dir
		var angle := atan2(d.dot(right), d.dot(fwd))
		var alpha: float = 1.0 - h.t / LIFE
		var col := Color(0.7, 0.72, 0.75, alpha * 0.8) if h.blocked else Color(1.0, 0.2, 0.15, alpha * 0.9)
		var start := angle - PI / 2.0 - 0.28
		draw_arc(c, RADIUS, start, start + 0.56, 16, Color(0, 0, 0, alpha * 0.5), 12.0)
		draw_arc(c, RADIUS, start, start + 0.56, 16, col, 8.0)

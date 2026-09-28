class_name EnemyOverlay
extends Control
## 적 머리 위 정보: 최근 피해를 입은 적의 체력바, 공격 전조 표시, 피해 수치.
## 전조는 모양으로도 구분한다: 패링 가능 ◇(노랑), 패링 불가 ▲(빨강)(기획서 §8.4).
## '전조 강화' 옵션을 켜면 표시가 커지고, 화면 밖에서 준비하는 공격도 가장자리에 알린다(§21.3).

const MAX_DISTANCE := 60.0
const NUMBER_LIFE := 0.9
const PARRY_COLOR := Color(1.0, 0.82, 0.2)
const HEAVY_COLOR := Color(1.0, 0.22, 0.15)

var player: Player
var camera: Camera3D
var _numbers: Array[Dictionary] = []


func add_damage_number(position: Vector3, amount: float, zone: int, armor: bool) -> void:
	if not bool(Settings.get_value(&"damage_numbers")) or amount <= 0.05:
		return
	var col := Color(1, 1, 1)
	if zone == Hurtbox.Zone.WEAK_POINT:
		col = Color(1.0, 0.65, 0.2)
	elif armor:
		col = Color(0.65, 0.75, 0.88)
	_numbers.append({
		"pos": position + Vector3(randf_range(-0.2, 0.2), 0.2, randf_range(-0.2, 0.2)),
		"text": str(int(round(amount))) if amount >= 1.0 else "%.1f" % amount,
		"color": col, "t": 0.0,
	})
	if _numbers.size() > 24:
		_numbers.pop_front()


func _process(delta: float) -> void:
	for n in _numbers:
		n.t += delta
	_numbers = _numbers.filter(func(n: Dictionary) -> bool: return n.t < NUMBER_LIFE)
	queue_redraw()


func _draw() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var font := get_theme_default_font()
	var boost := bool(Settings.get_value(&"telegraph_boost"))
	var view := get_viewport_rect().size
	for node in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var world_pos := e.marker_position()
		var dist := camera.global_position.distance_to(world_pos)
		if dist > MAX_DISTANCE:
			continue
		var tele := e.telegraph_info()
		var behind := camera.is_position_behind(world_pos)
		var screen := camera.unproject_position(world_pos) if not behind else Vector2.ZERO
		var on_screen := not behind and Rect2(Vector2.ZERO, view).has_point(screen)
		if on_screen:
			if e.shows_overhead_health() and ((e.recently_damaged() and e.health_ratio() < 1.0) or (e.is_engaged() and dist < 32.0)):
				_draw_health(font, screen, e)
			if not tele.is_empty():
				_draw_telegraph(screen + Vector2(0, -26), tele, boost, dist)
		elif boost and not tele.is_empty() and dist < 35.0:
			_draw_edge_warning(e, tele, view)
	for n in _numbers:
		if camera.is_position_behind(n.pos):
			continue
		var p: Vector2 = camera.unproject_position(n.pos) + Vector2(0, -40.0 * n.t)
		var alpha: float = 1.0 - n.t / NUMBER_LIFE
		var col: Color = n.color
		col.a = alpha
		draw_string_outline(font, p, n.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, 5, Color(0, 0, 0, 0.8 * alpha))
		draw_string(font, p, n.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, col)


func _draw_health(font: Font, screen: Vector2, e: Enemy) -> void:
	var w := 70.0
	var r := Rect2(screen + Vector2(-w * 0.5, -6.0), Vector2(w, 7.0))
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(r.position, Vector2(w * e.health_ratio(), r.size.y)), Color(0.9, 0.25, 0.2))
	var label := e.display_label()
	# 적 레벨이 내 레벨보다 한참 높으면 이름 색으로 알린다(기획서 §4.3: 위험을 명확히 전달).
	var gap := e.data.level - GameState.progress.level
	var col := Color(1, 1, 1, 0.92)
	if gap >= 6:
		col = Color(1.0, 0.4, 0.35, 0.95)
	elif gap >= 3:
		col = Color(1.0, 0.72, 0.35, 0.95)
	draw_string_outline(font, screen + Vector2(0, -12), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, 3, Color(0, 0, 0, 0.75))
	draw_string(font, screen + Vector2(0, -12), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, col)


func _draw_telegraph(center: Vector2, tele: Dictionary, boost: bool, dist: float) -> void:
	var s := (22.0 if boost else 13.0) * clampf(18.0 / maxf(dist, 1.0), 0.8, 1.4)
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03)
	var progress: float = tele.progress
	if tele.parryable:
		var pts := PackedVector2Array([center + Vector2(0, -s), center + Vector2(s, 0),
			center + Vector2(0, s), center + Vector2(-s, 0), center + Vector2(0, -s)])
		draw_colored_polygon(pts.slice(0, 4), Color(PARRY_COLOR, 0.35 * pulse))
		draw_polyline(pts, Color(0, 0, 0, 0.8), 5.0)
		draw_polyline(pts, Color(PARRY_COLOR, pulse), 3.0)
	else:
		var pts := PackedVector2Array([center + Vector2(0, -s * 1.1), center + Vector2(s, s * 0.8),
			center + Vector2(-s, s * 0.8), center + Vector2(0, -s * 1.1)])
		draw_colored_polygon(pts.slice(0, 3), Color(HEAVY_COLOR, 0.45 * pulse))
		draw_polyline(pts, Color(0, 0, 0, 0.8), 5.0)
		draw_polyline(pts, Color(HEAVY_COLOR, pulse), 3.0)
	# 전조 진행도: 아래쪽 막대
	var bar := Rect2(center + Vector2(-s, s + 5.0), Vector2(s * 2.0, 3.0))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)),
		PARRY_COLOR if tele.parryable else HEAVY_COLOR)


func _draw_edge_warning(e: Enemy, tele: Dictionary, view: Vector2) -> void:
	if player == null:
		return
	var fwd := -player.look_basis().z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var to := e.global_position - player.global_position
	to.y = 0.0
	var angle := atan2(to.dot(right), to.dot(fwd))
	var dir := Vector2(sin(angle), -cos(angle))
	var c := view * 0.5
	var pos := c + dir * minf(view.x, view.y) * 0.42
	var col := PARRY_COLOR if tele.parryable else HEAVY_COLOR
	var tip := pos + dir * 22.0
	var side := Vector2(-dir.y, dir.x) * 14.0
	var pts := PackedVector2Array([tip, pos + side, pos - side])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([tip, pos + side, pos - side, tip]), Color(0, 0, 0, 0.8), 2.0)

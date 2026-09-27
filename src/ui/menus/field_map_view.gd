class_name FieldMapView
extends Control
## 공명 장치 지도(기본 키 M). 가 본 곳만 드러나고(기획서 §13.3), 발견한 지역 이름과 거점,
## 의뢰의 탐색 범위, 현재 위치를 보여 준다. 유니크 몬스터와 비밀 장소는 표시하지 않는다.

const FOG := Color(0.015, 0.045, 0.07)
const GRID := Color(0.45, 0.88, 0.98, 0.1)
const ACCENT := Color(0.45, 0.88, 0.98)

var field: FieldWorld
var player: Player

var _fog_image: Image
var _fog_texture: ImageTexture


func _init() -> void:
	custom_minimum_size = Vector2(560, 560)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 드러난 칸을 다시 읽는다.
func refresh() -> void:
	var n := GameState.MAP_CELLS
	if _fog_image == null:
		_fog_image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for iz in n:
		for ix in n:
			var shown := GameState.map_cells[iz * n + ix] != 0
			_fog_image.set_pixel(ix, iz, Color(FOG, 0.0 if shown else 0.93))
	if _fog_texture == null:
		_fog_texture = ImageTexture.create_from_image(_fog_image)
	else:
		_fog_texture.update(_fog_image)
	queue_redraw()


func _map_rect() -> Rect2:
	var s := minf(size.x, size.y)
	return Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))


## 월드 좌표(x, z) → 화면 좌표
func to_map(p: Vector2) -> Vector2:
	var r := _map_rect()
	var half := FieldLayout.HALF_SIZE
	return r.position + (p + Vector2(half, half)) / (half * 2.0) * r.size.x


func _draw() -> void:
	var r := _map_rect()
	var font := get_theme_default_font()
	if field == null:
		draw_rect(r, Color(0.02, 0.06, 0.09))
		draw_string(font, r.get_center() - Vector2(200, 0), "이 공간에는 지도가 없습니다.", HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color(1, 1, 1, 0.7))
		return
	draw_texture_rect(field.map_texture(), r, false)
	if _fog_texture:
		draw_texture_rect(_fog_texture, r, false)
	var cells := 8
	for i in range(1, cells):
		var t := float(i) / cells
		draw_line(r.position + Vector2(r.size.x * t, 0), r.position + Vector2(r.size.x * t, r.size.y), GRID, 1.0)
		draw_line(r.position + Vector2(0, r.size.y * t), r.position + Vector2(r.size.x, r.size.y * t), GRID, 1.0)
	draw_rect(r, Color(ACCENT, 0.7), false, 2.0)
	# 거점
	for sp in field.supply_points:
		var p2 := Vector2(sp.global_position.x, sp.global_position.z)
		if not GameState.is_map_revealed(p2):
			continue
		var m := to_map(p2)
		draw_circle(m, 6.0, Color(0.35, 0.95, 0.9))
		draw_arc(m, 6.0, 0.0, TAU, 16, Color(0, 0, 0, 0.7), 1.5)
	# 발견한 지역 이름
	for area: StringName in FieldWorld.AREA_LABELS:
		if not GameState.discovered_areas.has(area):
			continue
		var m := to_map(FieldWorld.AREA_LABELS[area]) + Vector2(0, -12)
		var text: String = FieldWorld.AREAS[area]
		draw_string_outline(font, m - Vector2(80, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 160, 17, 4, Color(0, 0, 0, 0.8))
		draw_string(font, m - Vector2(80, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 160, 17, Color(0.95, 0.97, 0.92))
	# 의뢰 탐색 범위(추적 중인 의뢰는 밝게)
	var q := GameState.quests
	for id in q.active_ids():
		var step := q.current_step(id)
		var hint := field.quest_hint(step)
		if hint == Vector2.INF:
			continue
		var tracked := id == q.tracked
		var col := Color(1.0, 0.82, 0.35, 1.0 if tracked else 0.55)
		var m := to_map(hint)
		var radius := float(step.get("radius", 0.0 if step.get("type", &"") == &"talk" else 28.0))
		if radius > 0.0:
			var pr := radius / (FieldLayout.HALF_SIZE * 2.0) * r.size.x
			draw_circle(m, pr, Color(col, 0.16 if tracked else 0.08))
			draw_arc(m, pr, 0.0, TAU, 32, col, 2.0 if tracked else 1.2)
		var d := 7.0 if tracked else 5.0
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -d), m + Vector2(d, 0), m + Vector2(0, d), m + Vector2(-d, 0)]), col)
	# 현재 위치
	if player and is_instance_valid(player):
		var m := to_map(Vector2(player.global_position.x, player.global_position.z))
		var heading := -player.yaw
		var fwd := Vector2(sin(heading), -cos(heading))
		var right := Vector2(-fwd.y, fwd.x)
		var tri := PackedVector2Array([m + fwd * 11.0, m - fwd * 7.0 + right * 7.0, m - fwd * 3.5, m - fwd * 7.0 - right * 7.0])
		draw_colored_polygon(tri, Color(1.0, 0.45, 0.35))
		var outline := tri.duplicate()
		outline.append(tri[0])
		draw_polyline(outline, Color(0, 0, 0, 0.8), 1.5)
	# 방위
	draw_string_outline(font, r.position + Vector2(r.size.x * 0.5 - 20, 26), "북", HORIZONTAL_ALIGNMENT_CENTER, 40, 20, 4, Color(0, 0, 0, 0.8))
	draw_string(font, r.position + Vector2(r.size.x * 0.5 - 20, 26), "북", HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color(1.0, 0.6, 0.5))

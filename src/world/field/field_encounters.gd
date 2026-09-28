class_name FieldEncounters
extends Node3D
## 퍼시 외곽권의 야외 무리(기획서 §14.5, §19.3).
## - 지역마다 어울리는 종이 무리를 이룬다(FieldLayout.ENCOUNTERS). 밤·낮에만 나오는 종도 있다.
## - 내비게이션 메시는 지도를 96m 칸으로 나눠 무리가 있는 칸만 백그라운드에서 굽는다(칸끼리는 가장자리로 이어진다).
## - 플레이어에게서 멀리 떨어진 무리는 잠시 멈춰 두어 계산을 아낀다.
## - 전멸한 무리는 휴식하면 다시 나타나고, 플레이어가 멀리 있으면 일정 시간 뒤 저절로 다시 나타난다.
## - 낮과 밤이 바뀌면 시간을 타는 무리는 플레이어가 멀리 있을 때 새 구성으로 바뀐다.

const NAV_TILE := 96.0
const NAV_REACH := 40.0
## 플레이어 둘레 이 거리 안의 칸만 굽는다(멀리 있는 무리는 멈춰 있으니 길이 필요 없다).
const STREAM_RADIUS := 200.0
const MAX_CONCURRENT_BAKES := 2
const EDGE_LINK_MARGIN := 1.3
const ACTIVE_DISTANCE := 120.0
const RESPAWN_TIME := 240.0
const RESPAWN_DISTANCE := 90.0
const CHECK_INTERVAL := 1.0

var groups: Array[EncounterGroup] = []
var regions: Array[NavigationRegion3D] = []
var focus: Node3D

var _field: FieldWorld
var _cleared_at: Dictionary = {}
var _clock: float = 0.0
var _check: float = 0.0
var _baked: int = 0
var _was_night: bool = false
var _stale: Dictionary = {}
var _template: NavigationMesh
var _source: NavigationMeshSourceGeometryData3D
var _pending_tiles: Array[Rect2] = []
var _baking: int = 0


func build(field: FieldWorld) -> void:
	_field = field
	_was_night = _is_night()
	var i := 0
	for spec: Array in FieldLayout.ENCOUNTERS:
		var opts: Dictionary = spec[3]
		var g := EncounterGroup.new()
		var mix: Array = spec[2]
		g.name = "Enc_%s_%d" % [String((mix[0] as Array)[0]), i]
		g.mix = mix
		g.ambush = bool(opts.get("ambush", false))
		g.condition = String(opts.get("cond", ""))
		g.is_night = _is_night
		var total := 0
		for m: Array in mix:
			total += int(m[1])
		g.spread = float(opts.get("spread", 3.0 if total > 1 else 0.0))
		g.position = field.terrain.point_at(Vector2(float(spec[0]), float(spec[1])))
		g.rotation.y = randf() * TAU
		add_child(g)
		groups.append(g)
		i += 1
	_bake_navigation(field)


func _is_night() -> bool:
	return _field != null and _field.day_night != null and _field.day_night.is_night()


## 지형·나무·바위·건물 충돌체를 한 번 읽어 두고, 칸은 플레이어 가까운 것부터 필요할 때 굽는다.
func _bake_navigation(field: FieldWorld) -> void:
	_template = NavigationMesh.new()
	_template.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_template.geometry_collision_mask = CombatLayers.WORLD
	_template.agent_radius = 0.5
	_template.agent_height = 1.5
	_template.agent_max_climb = 0.5
	_template.agent_max_slope = 42.0
	# 칸은 가장자리가 에이전트 반지름만큼 깎여 이웃 칸과 1m 벌어진다. 지도의 가장자리 잇기 여유를 넓혀 이어 준다.
	NavigationServer3D.map_set_edge_connection_margin(field.get_world_3d().navigation_map, EDGE_LINK_MARGIN)
	_source = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_template, _source, field)
	for area: Rect2 in nav_areas():
		_pending_tiles.append(area)
	_stream_tiles()


## 무리 둘레 NAV_REACH 안에 걸치는 지도 칸들(서로 겹치지 않고 가장자리로 맞닿는다).
func nav_areas() -> Array[Rect2]:
	var cells := {}
	for g in groups:
		var c := g.global_position
		var x0 := floori((c.x - NAV_REACH) / NAV_TILE)
		var x1 := floori((c.x + NAV_REACH) / NAV_TILE)
		var z0 := floori((c.z - NAV_REACH) / NAV_TILE)
		var z1 := floori((c.z + NAV_REACH) / NAV_TILE)
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				cells[Vector2i(x, z)] = true
	var areas: Array[Rect2] = []
	var keys := cells.keys()
	keys.sort()
	for k: Vector2i in keys:
		areas.append(Rect2(k.x * NAV_TILE, k.y * NAV_TILE, NAV_TILE, NAV_TILE))
	return areas


func _stream_origin() -> Vector2:
	if focus and is_instance_valid(focus):
		return Vector2(focus.global_position.x, focus.global_position.z)
	return FieldLayout.DROP_SITE


## 플레이어 둘레 STREAM_RADIUS 안의 칸을 가까운 것부터 굽는다(한 번에 둘까지).
func _stream_tiles() -> void:
	if _source == null or _pending_tiles.is_empty():
		return
	var origin := _stream_origin()
	_pending_tiles.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.get_center().distance_squared_to(origin) < b.get_center().distance_squared_to(origin))
	while _baking < MAX_CONCURRENT_BAKES and not _pending_tiles.is_empty():
		var area: Rect2 = _pending_tiles[0]
		if area.get_center().distance_to(origin) > STREAM_RADIUS:
			break
		_pending_tiles.remove_at(0)
		var region := NavigationRegion3D.new()
		region.name = "Nav_%d_%d" % [int(area.position.x), int(area.position.y)]
		add_child(region)
		# 칸이 많아도 구운 결과가 곧바로 지도에 들어가도록 구역 갱신을 주 스레드에서 한다.
		NavigationServer3D.region_set_use_async_iterations(region.get_region_rid(), false)
		regions.append(region)
		var nm: NavigationMesh = _template.duplicate()
		nm.filter_baking_aabb = AABB(Vector3(area.position.x, -40.0, area.position.y), Vector3(area.size.x, 120.0, area.size.y))
		_baking += 1
		NavigationServer3D.bake_from_source_geometry_data_async(nm, _source, _on_baked.bind(region, nm))


func _on_baked(region: NavigationRegion3D, nm: NavigationMesh) -> void:
	if is_instance_valid(region):
		region.navigation_mesh = nm
	_baked += 1
	_baking -= 1
	_stream_tiles.call_deferred()


func baked_count() -> int:
	return _baked


## 플레이어 둘레의 칸을 모두 구웠는지
func is_baked() -> bool:
	if _baking > 0:
		return false
	var origin := _stream_origin()
	for area in _pending_tiles:
		if area.get_center().distance_to(origin) <= STREAM_RADIUS:
			return false
	return true


func _process(delta: float) -> void:
	_clock += delta
	_check -= delta
	if _check > 0.0 or focus == null or not is_instance_valid(focus):
		return
	_check = CHECK_INTERVAL
	_stream_tiles()
	var p := focus.global_position
	var night := _is_night()
	if night != _was_night:
		_was_night = night
		for g in groups:
			if g.has_time_condition():
				_stale[g] = true
	for g in groups:
		var d := Vector2(p.x - g.global_position.x, p.z - g.global_position.z).length()
		# 낮·밤이 바뀐 무리는 플레이어가 멀리 있을 때 새 구성으로 바꾼다.
		if _stale.has(g) and d > RESPAWN_DISTANCE and not g.is_engaged():
			_stale.erase(g)
			g.reset()
		# 멀리 있는 무리는 멈춰 둔다(교전 중인 무리는 그대로).
		var active := d < ACTIVE_DISTANCE or g.is_engaged()
		for e in g.members:
			if is_instance_valid(e):
				e.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		# 전멸한 무리는 시간이 지나고 플레이어가 멀리 있으면 다시 나타난다.
		if g.alive_count() == 0:
			if not _cleared_at.has(g):
				_cleared_at[g] = _clock
			elif _clock - float(_cleared_at[g]) >= RESPAWN_TIME and d > RESPAWN_DISTANCE:
				_cleared_at.erase(g)
				g.reset()
		else:
			_cleared_at.erase(g)

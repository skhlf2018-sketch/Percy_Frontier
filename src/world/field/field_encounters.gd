class_name FieldEncounters
extends Node3D
## 퍼시 외곽권의 야외 무리(기획서 §14.5, §19.3).
## - 무리마다 주변 80m 구역의 내비게이션 메시를 백그라운드에서 굽는다(적이 나무와 바위를 돌아 다닌다).
##   구역이 겹치는 무리들은 한 구역으로 합쳐 굽는다(겹친 구역은 경계가 서로 어긋난다).
## - 플레이어에게서 멀리 떨어진 무리는 잠시 멈춰 두어 계산을 아낀다.
## - 전멸한 무리는 휴식하면 다시 나타나고, 플레이어가 멀리 있으면 일정 시간 뒤 저절로 다시 나타난다.

const SCENES := {
	&"rabbits": preload("res://src/enemies/killer_rabbit.tscn"),
	&"charger": preload("res://src/enemies/rock_charger.tscn"),
	&"spitters": preload("res://src/enemies/spore_spitter.tscn"),
}
const NAV_HALF_EXTENT := 40.0
const ACTIVE_DISTANCE := 150.0
const RESPAWN_TIME := 240.0
const RESPAWN_DISTANCE := 90.0
const CHECK_INTERVAL := 1.0

var groups: Array[EncounterGroup] = []
var regions: Array[NavigationRegion3D] = []
var focus: Node3D

var _cleared_at: Dictionary = {}
var _clock: float = 0.0
var _check: float = 0.0
var _baked: int = 0


func build(field: FieldWorld) -> void:
	var i := 0
	for spec in FieldLayout.ENCOUNTERS:
		var kind: StringName = spec[0]
		var g := EncounterGroup.new()
		g.name = "Enc_%s_%d" % [kind, i]
		g.enemy_scene = SCENES[kind]
		g.count = int(spec[3])
		g.ambush = bool(spec[4])
		g.spread = 3.0 if kind == &"rabbits" else 4.5
		g.position = field.terrain.point_at(Vector2(float(spec[1]), float(spec[2])))
		g.rotation.y = randf() * TAU
		add_child(g)
		groups.append(g)
		i += 1
	_bake_navigation(field)


## 지형·나무·바위·건물 충돌체를 한 번 읽고, 무리 구역마다 따로 굽는다.
func _bake_navigation(field: FieldWorld) -> void:
	var template := NavigationMesh.new()
	template.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	template.geometry_collision_mask = CombatLayers.WORLD
	template.agent_radius = 0.5
	template.agent_height = 1.5
	template.agent_max_climb = 0.5
	template.agent_max_slope = 42.0
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(template, source, field)
	var i := 0
	for area: Rect2 in nav_areas():
		var region := NavigationRegion3D.new()
		region.name = "Nav_%d" % i
		add_child(region)
		regions.append(region)
		var nm: NavigationMesh = template.duplicate()
		nm.filter_baking_aabb = AABB(Vector3(area.position.x, -40.0, area.position.y), Vector3(area.size.x, 120.0, area.size.y))
		NavigationServer3D.bake_from_source_geometry_data_async(nm, source, _on_baked.bind(region, nm))
		i += 1


## 무리마다 둘레 80m 구역을 잡고, 겹치는 구역은 겹치지 않을 때까지 합친다(x, z 평면의 사각형).
func nav_areas() -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for g in groups:
		var c := g.global_position
		areas.append(Rect2(c.x - NAV_HALF_EXTENT, c.z - NAV_HALF_EXTENT, NAV_HALF_EXTENT * 2.0, NAV_HALF_EXTENT * 2.0))
	var merged := true
	while merged:
		merged = false
		for a in areas.size():
			for b in range(a + 1, areas.size()):
				if areas[a].intersects(areas[b]):
					areas[a] = areas[a].merge(areas[b])
					areas.remove_at(b)
					merged = true
					break
			if merged:
				break
	return areas


func _on_baked(region: NavigationRegion3D, nm: NavigationMesh) -> void:
	if is_instance_valid(region):
		region.navigation_mesh = nm
	_baked += 1


func baked_count() -> int:
	return _baked


## 모든 구역을 다 구웠는지
func is_baked() -> bool:
	return _baked >= regions.size()


func _process(delta: float) -> void:
	_clock += delta
	_check -= delta
	if _check > 0.0 or focus == null or not is_instance_valid(focus):
		return
	_check = CHECK_INTERVAL
	var p := focus.global_position
	for g in groups:
		var d := Vector2(p.x - g.global_position.x, p.z - g.global_position.z).length()
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

extends TestCase
## 전투 시험장 장면: 불러오기, 내비게이션, 야외 무리 배치, 시험 단말기 소환, 초기화 규칙.

const ARENA := preload("res://src/world/combat_arena.tscn")

var arena: CombatArena


func before_each() -> void:
	GameState.reset_session()
	arena = ARENA.instantiate()
	runner.add_child(arena)
	await wait_physics_frames(3)


func after_each() -> void:
	GameState.reset_session()


func test_arena_loads_with_navigation() -> void:
	# 내비게이션 맵은 굽기 후 두 번 동기화되어야 경로를 돌려준다.
	await wait_physics_frames(4)
	var map := arena.get_world_3d().navigation_map
	assert_gt(arena.navigation.navigation_mesh.get_polygon_count(), 20, "내비게이션 메시가 구워진다")
	var path := NavigationServer3D.map_get_path(map, Vector3(0, 0, 50), Vector3(40, 0, -34), true)
	assert_gt(path.size(), 1, "기지에서 돌격수 들판까지 길이 이어진다")
	var ridge_path := NavigationServer3D.map_get_path(map, Vector3(0, 0, 50), Vector3(55, 3, 10), true)
	assert_gt(ridge_path.size(), 1, "경사로로 능선에 오를 수 있다")
	if ridge_path.size() > 0:
		assert_gt(ridge_path[ridge_path.size() - 1].y, 2.5, "능선 위까지 닿는다")


func test_encounters_spawn_members() -> void:
	var total := 0
	for g in arena.encounters:
		total += g.alive_count()
	assert_eq(total, 4 + 2 + 1 + 2, "야외 무리 배치")
	var rabbits := 0
	for e in runner.get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e is KillerRabbit:
			rabbits += 1
			assert_true(e.hidden, "풀숲 무리는 매복 상태로 시작")
	assert_eq(rabbits, 6)


func test_facilities_are_registered() -> void:
	assert_eq(arena.supply_points.size(), 1)
	var terminals := arena.find_children("*", "TestTerminal", true, false)
	var racks := arena.find_children("*", "WeaponRack", true, false)
	assert_eq(terminals.size(), 1)
	assert_eq(racks.size(), 1)


func test_test_waves_spawn_and_clear() -> void:
	for kind in CombatArena.TEST_WAVES:
		arena.spawn_test_wave(kind)
	await wait_physics_frames(2)
	assert_eq(arena.active_test_count(), 4 + 1 + 2 + 5)
	arena.clear_test_spawns()
	await wait_physics_frames(2)
	assert_eq(arena.active_test_count(), 0)


func test_reset_rules() -> void:
	var pack: EncounterGroup = arena.get_node("Encounters/RabbitPack")
	var charger_group: EncounterGroup = arena.get_node("Encounters/Charger")
	var charger: Enemy = charger_group.members[0]
	var players := runner.get_tree().get_nodes_in_group(&"player")
	assert_eq(players.size(), 0)
	# 토끼 한 마리를 처치하고 돌격수만 교전 상태로 만든다
	var victim: Enemy = pack.members[0]
	victim.receive_hit(DamageInfo.create(999.0, DamageInfo.Kind.GUN), null)
	assert_eq(pack.alive_count(), 3)
	charger.state = Enemy.State.CHASE
	assert_true(charger_group.is_engaged())
	var n := arena.reset_engaged_encounters()
	await wait_physics_frames(2)
	assert_eq(n, 1, "교전 중인 무리만 되돌린다")
	assert_eq(pack.alive_count(), 3, "교전하지 않은 무리의 처치 기록은 유지")
	arena.reset_all_encounters()
	await wait_physics_frames(2)
	assert_eq(pack.alive_count(), 4, "휴식하면 모두 다시 나타난다")


func test_supply_point_respawn_faces_field() -> void:
	var sp: SupplyPoint = arena.supply_points[0]
	var xform := sp.respawn_transform()
	var forward := -xform.basis.z
	assert_lt(forward.z, -0.9, "부활하면 북쪽(전장)을 바라본다")
	assert_gt(xform.origin.z, sp.global_position.z, "거점 뒤편(남쪽)에서 부활")

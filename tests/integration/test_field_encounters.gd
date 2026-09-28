extends TestCase
## 퍼시 외곽권의 야외 무리: 배치, 내비게이션 구역, 먼 무리 멈추기, 처치 보상(재료·은화·경험치).

const GAME := preload("res://src/main/game.tscn")

var game: Game


func before_each() -> void:
	Settings.load_settings("user://test_encounters.cfg")
	game = GAME.instantiate()
	game.mode = Game.Mode.FIELD
	runner.add_child(game)
	await wait_physics_frames(4)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	runner.get_tree().paused = false
	await wait_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_encounters.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()


func _nearest_group(to: Vector3) -> EncounterGroup:
	var best: EncounterGroup = null
	for g in game.field.encounters_node.groups:
		if best == null or g.global_position.distance_to(to) < best.global_position.distance_to(to):
			best = g
	return best


func test_groups_placed_and_navigation_baked() -> void:
	var enc := game.field.encounters_node
	assert_eq(enc.groups.size(), FieldLayout.ENCOUNTERS.size(), "무리가 모두 배치된다")
	var areas := enc.nav_areas()
	for a in areas.size():
		for b in range(a + 1, areas.size()):
			assert_false(areas[a].intersects(areas[b]), "내비게이션 구역은 서로 겹치지 않는다")
	for g in enc.groups:
		var inside := false
		for r in areas:
			inside = inside or r.has_point(Vector2(g.global_position.x, g.global_position.z))
		assert_true(inside, "%s는 내비게이션 구역 안에 있다" % g.name)
	for i in 600:
		if enc.is_baked():
			break
		await wait_frames(1)
	assert_true(enc.is_baked(), "구역을 모두 굽는다")
	var g := enc.groups[0]
	var from := g.global_position
	var to := game.field.terrain.point_at(Vector2(from.x + 12.0, from.z + 6.0))
	var map := game.field.get_world_3d().navigation_map
	# 구운 구역은 다음 물리 프레임들에 걸쳐(백그라운드 작업이 밀려 있으면 몇 초 뒤에) 내비게이션 지도에 들어간다.
	var path := PackedVector3Array()
	for i in 600:
		var cp := NavigationServer3D.map_get_closest_point(map, from)
		if Vector2(cp.x, cp.z).distance_to(Vector2(from.x, from.z)) < 2.0:
			path = NavigationServer3D.map_get_path(map, from, to, true)
			break
		await wait_physics_frames(1)
	assert_false(path.is_empty(), "무리 둘레에서 길을 찾는다")
	if not path.is_empty():
		var end := path[path.size() - 1]
		assert_lt(Vector2(end.x, end.z).distance_to(Vector2(to.x, to.z)), 3.0, "목표 근처까지 간다")


func test_far_groups_pause() -> void:
	await wait_physics_frames(75)
	var p := game.player.global_position
	var far := _nearest_group(Vector3(150, 0, -118))
	var near := _nearest_group(p)
	assert_gt(far.global_position.distance_to(p), FieldEncounters.ACTIVE_DISTANCE)
	for e in far.members:
		assert_eq(e.process_mode, Node.PROCESS_MODE_DISABLED, "먼 무리는 멈춰 둔다")
	for e in near.members:
		assert_eq(e.process_mode, Node.PROCESS_MODE_INHERIT, "가까운 무리는 움직인다")


func test_killed_enemy_drops_silver_and_materials() -> void:
	var g := _nearest_group(game.player.global_position)
	var enemy: Enemy = g.members[0]
	var spot := enemy.global_position
	game.player.global_position = spot + Vector3(2.5, 0.3, 0.0)
	game.player.reset_physics_interpolation()
	await wait_physics_frames(2)
	var xp := GameState.progress.total_xp
	var info := DamageInfo.create(9999.0, DamageInfo.Kind.MELEE, game.player)
	enemy._hurtboxes[0].hit(info)
	await wait_physics_frames(3)
	assert_false(enemy.is_alive(), "쓰러뜨린다")
	var silver_drops := runner.get_tree().root.find_children("*", "Pickup", true, false).filter(
		func(n: Node) -> bool: return (n as Pickup).kind == Pickup.Kind.SILVER)
	assert_gt(silver_drops.size(), 0, "은화가 떨어진다")
	assert_gt(GameState.progress.total_xp, xp, "처치 경험치")
	# 가까이 있으면 끌려와 회수된다.
	game.player.global_position = spot + Vector3(0.5, 0.3, 0.0)
	game.player.reset_physics_interpolation()
	for i in 120:
		if GameState.silver > 0:
			break
		await wait_physics_frames(1)
	assert_gt(GameState.silver, 0, "은화를 줍는다")


func test_oneeye_sniper_waits_on_watchtower_top() -> void:
	var sniper: Goblin = null
	for g in game.field.encounters_node.groups:
		for e in g.members:
			if is_instance_valid(e) and e.data.id == &"oneeye_sniper":
				sniper = e
	assert_not_null(sniper, "외눈 저격수가 배치된다")
	if sniper == null:
		return
	await wait_physics_frames(20)
	var ground := game.field.terrain.height_at(sniper.global_position.x, sniper.global_position.z)
	assert_gt(sniper.global_position.y - ground, 3.0, "무너진 감시탑 위층에 서 있다")
	assert_gt(sniper.perch_radius, 0.0, "탑 위 자리를 지킨다")
	# 탑 아래 남쪽 30m에서 발견되면 가장자리로 가서 쏜다(탑을 내려오지 않는다).
	var p := game.player
	var below := game.field.terrain.point_at(FieldLayout.WATCHTOWER + Vector2(6, 30))
	p.global_position = below + Vector3.UP * 0.1
	p.reset_physics_interpolation()
	sniper.alert(p)
	var shot := false
	for i in 600:
		await wait_physics_frames(1)
		p.stats.hp = p.stats.max_hp
		if sniper.state == Enemy.State.ATTACK and sniper._attack and sniper._attack.id == &"aimed_shot":
			shot = true
	var ground2 := game.field.terrain.height_at(sniper.global_position.x, sniper.global_position.z)
	assert_true(shot, "탑 위에서 저격한다")
	assert_gt(sniper.global_position.y - ground2, 3.0, "싸우는 동안에도 탑 위에 남는다")

extends TestCase
## 필드의 보스 전장 늪턱 구렁: 가운데에 잠든 보스, 들어서면 깨어나 싸움이 시작되고(보스 체력바),
## 떠나거나 쓰러지면 처음으로 돌아간다. 쓰러뜨린 기록이 있으면 다시 나타나지 않는다.

const GAME := preload("res://src/main/game.tscn")

var game: Game


func before_each() -> void:
	Settings.load_settings("user://test_mire_arena.cfg")
	game = GAME.instantiate()
	game.mode = Game.Mode.FIELD
	runner.add_child(game)
	await wait_physics_frames(4)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	runner.get_tree().paused = false
	await wait_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_mire_arena.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()


func _put_player(at: Vector2) -> void:
	var p := game.player
	p.global_position = game.field.terrain.point_at(at) + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func test_arena_has_sleeping_boss_pillars_and_rest_point() -> void:
	var arena := game.field.mire_arena
	assert_not_null(arena)
	assert_true(arena.is_boss_alive(), "보스가 있다")
	assert_true(arena.boss.dormant, "진흙 속에 잠들어 있다")
	assert_eq(arena.pillars.size(), 4, "돌기둥 넷")
	var floor_h := game.field.terrain.height_at(FieldLayout.MAW_CENTER.x, FieldLayout.MAW_CENTER.y)
	assert_lt(floor_h, FieldLayout.WATER_LEVEL, "구렁 바닥에 물이 고여 있다")
	var sp := game.field.supply_point_by_name("Supply_maw")
	assert_not_null(sp, "보스전 직전 거점")
	var d := Vector2(sp.global_position.x, sp.global_position.z).distance_to(FieldLayout.MAW_CENTER)
	assert_gt(d, MireArena.FIGHT_RADIUS, "거점은 싸움터 밖에 있다")
	assert_eq(game.field.area_at(FieldLayout.MAW_CENTER), &"maw_hollow")


func test_entering_starts_fight_and_leaving_resets() -> void:
	var arena := game.field.mire_arena
	var started := [false]
	arena.fight_started.connect(func() -> void: started[0] = true)
	_put_player(FieldLayout.MAW_CENTER + Vector2(10, -8))
	for i in 30:
		await wait_physics_frames(1)
	assert_true(started[0], "구렁 안으로 들어서면 싸움이 시작된다")
	assert_false(arena.boss.dormant)
	assert_true(arena.shows_boss_bar(), "보스 체력바")
	await wait_frames(2)
	assert_true(game.hud._boss_bar.visible, "HUD에 보스 체력바가 보인다")
	arena.boss._apply_damage(arena.boss.data.max_hp * 0.3, null, Hurtbox.Zone.NORMAL)
	_put_player(FieldLayout.MAW_CENTER + Vector2(70, -30))
	for i in int((MireArena.LEAVE_TIME + 1.5) * 60.0):
		await wait_physics_frames(1)
		if not arena.fighting:
			break
	assert_false(arena.fighting, "멀리 떠나면 싸움이 처음으로 돌아간다")
	assert_true(arena.boss.dormant)
	assert_eq(arena.boss.hp, arena.boss.data.max_hp, "체력이 모두 돌아온다")


func test_player_death_resets_fight() -> void:
	var arena := game.field.mire_arena
	_put_player(FieldLayout.MAW_CENTER + Vector2(10, -8))
	for i in 30:
		await wait_physics_frames(1)
	assert_true(arena.fighting)
	game.player.stats.take_damage(99999.0)
	for i in 20:
		await wait_physics_frames(1)
	assert_false(arena.fighting, "쓰러지면 싸움이 처음으로 돌아간다")
	assert_true(arena.boss.dormant)


func test_defeated_boss_does_not_return() -> void:
	# 보스를 쓰러뜨린 저장을 불러온다.
	GameState.record_boss(&"mire_maw", "defeated")
	var doc := {"game": {"state": GameState.to_dict()}}
	game.queue_free()
	await wait_frames(2)
	game = GAME.instantiate()
	game.load_doc = doc
	runner.add_child(game)
	await wait_physics_frames(4)
	assert_false(game.field.mire_arena.is_boss_alive(), "쓰러뜨린 보스는 다시 나타나지 않는다")
	assert_not_null(game.field.supply_point_by_name("Supply_maw"), "거점은 남는다")

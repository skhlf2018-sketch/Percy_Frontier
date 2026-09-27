extends TestCase
## 퍼시 외곽권 필드: 지형과 충돌, 시작 지점, 지역 발견, 시간, 마을, 공명 장치 창.

const GAME := preload("res://src/main/game.tscn")

var game: Game


func before_each() -> void:
	Settings.load_settings("user://test_field.cfg")
	game = GAME.instantiate()
	game.mode = Game.Mode.FIELD
	runner.add_child(game)
	await wait_physics_frames(4)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	runner.get_tree().paused = false
	await wait_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_field.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()


func test_player_stands_on_terrain_at_start() -> void:
	var p := game.player
	await wait_physics_frames(60)
	var ground := game.field.terrain.height_at(p.global_position.x, p.global_position.z)
	assert_near(p.global_position.y, ground, 0.35, "시작 지점에서 지면 위에 서 있다")
	assert_true(p.is_on_floor(), "바닥에 닿아 있다")


func test_terrain_collision_matches_height_query() -> void:
	var space := game.field.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var worst := 0.0
	for i in 60:
		var x := rng.randf_range(-200.0, 200.0)
		var z := rng.randf_range(-200.0, 200.0)
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -50, z), CombatLayers.WORLD)
		q.exclude = []
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		# 나무·바위에 맞았으면 건너뛴다(지형만 비교).
		if not (hit.collider is StaticBody3D and hit.collider.name == "TerrainBody"):
			continue
		worst = maxf(worst, absf(hit.position.y - game.field.terrain.height_at(x, z)))
	assert_lt(worst, 0.12, "충돌 지형과 높이 계산이 어긋나지 않는다")


func test_starting_area_is_discovered_with_xp() -> void:
	await wait_physics_frames(45)
	assert_true(GameState.discovered_areas.has(&"drop_site"), "시작 지역이 발견된다")
	assert_gt(GameState.progress.total_xp, 0, "발견 경험치")


func test_walking_into_new_area_announces_it() -> void:
	var seen := []
	GameEvents.announcement.connect(func(title: String, _s: String, _k: int) -> void: seen.append(title))
	var p := game.player
	var town := game.field.terrain.point_at(FieldLayout.TOWN_CENTER + Vector2(-20, 4))
	p.global_position = town + Vector3.UP * 0.5
	p.reset_physics_interpolation()
	await wait_physics_frames(50)
	assert_true(GameState.discovered_areas.has(&"percy"))
	var found := false
	for t in seen:
		if String(t).contains("퍼시"):
			found = true
	assert_true(found, "퍼시 발견 알림")


func test_night_turns_on_town_lights() -> void:
	var f := game.field
	f.day_night.advance_to(12.0)
	await wait_frames(2)
	assert_false(f.day_night.is_night())
	assert_false(f.town.lantern_lights[0].visible, "낮에는 가로등이 꺼져 있다")
	f.day_night.advance_to(23.0)
	await wait_frames(2)
	assert_true(f.day_night.is_night())
	assert_true(f.town.lantern_lights[0].visible, "밤에는 가로등이 켜진다")
	assert_gt(f.town.window_material.emission_energy_multiplier, 1.0, "창문이 밝아진다")


func test_time_advances_and_wraps() -> void:
	var dn := game.field.day_night
	dn.advance_to(23.9)
	dn.hours_per_sec = 1.0
	await wait_seconds(0.3)
	assert_lt(dn.hour, 1.0, "자정을 넘기면 0시로 돌아간다")


func test_inn_rest_sets_checkpoint_and_heals() -> void:
	var p := game.player
	var inn := game.field.supply_point_by_name("Supply_inn")
	assert_not_null(inn)
	p.stats.take_damage(40.0)
	# 필드의 거점은 휴식 메뉴를 연다(쉬기·기다리기).
	game.field.rest_requested.emit(p, inn)
	await wait_frames(2)
	assert_true(game.menus.choice_menu.visible, "휴식 메뉴가 열린다")
	assert_true(tree().paused, "메뉴가 열려 있는 동안 멈춘다")
	game.menus.close_all()
	game.rest_at(p, inn)
	await wait_frames(2)
	assert_near(p.stats.hp, p.stats.max_hp, 0.01)
	assert_true(game.checkpoint.origin.distance_to(inn.respawn_transform().origin) < 0.1, "여관이 부활 지점이 된다")


func test_rest_and_wait_moves_clock() -> void:
	var camp := game.field.supply_point_by_name("Supply_camp")
	game.field.day_night.advance_to(10.0)
	game.rest_at(game.player, camp, 23.0)
	await wait_frames(2)
	assert_near(game.field.day_night.hour, 23.0, 0.05, "기다리면 고른 시각이 된다")
	assert_true(game.field.day_night.is_night())


func test_status_window_allocates_points() -> void:
	GameState.progress.unspent_points = 3
	var ev := InputEventAction.new()
	ev.action = &"status_window"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(3)
	var win := game.menus.status_window
	assert_true(win.visible, "Tab으로 공명 장치 창이 열린다")
	assert_true(runner.get_tree().paused, "창이 열리면 게임이 멈춘다")
	win._pending = [2, 0, 0, 0, 0, 0, 1]
	win._build_status()
	var confirm: Button = null
	for b in win.find_children("*", "Button", true, false):
		if b is Button and b.text == "확정":
			confirm = b
	assert_not_null(confirm)
	confirm.pressed.emit()
	assert_eq(GameState.progress.unspent_points, 0)
	assert_eq(GameState.progress.stat(PlayerProgress.Stat.VIT), PlayerProgress.BASE_STAT + 2)
	await wait_frames(1)
	assert_near(game.player.stats.max_hp, GameState.progress.max_hp(), 0.01, "플레이어 최대 HP에 반영된다")
	game.menus.close_all()
	await wait_frames(1)
	assert_false(runner.get_tree().paused)


func test_status_window_tabs_build_without_errors() -> void:
	game.menus.open_status(StatusWindow.TAB_GEAR)
	await wait_frames(2)
	game.menus.status_window._tabs.current_tab = StatusWindow.TAB_SKILLS
	await wait_frames(2)
	game.menus.status_window._tabs.current_tab = StatusWindow.TAB_BESTIARY
	await wait_frames(2)
	game.menus.close_all()
	assert_true(true)

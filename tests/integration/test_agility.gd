extends TestCase
## 원작식 기동과 근접 기술: 공중 도약, 벽 차기, 미끄러지기, 간발의 회피와 반격, 돌진 베기, 낙하 베기, 쌍검 회전 베기.

const DUMMY := preload("res://src/enemies/training_dummy.tscn")
const RABBIT := preload("res://src/enemies/killer_rabbit.tscn")

var world: TestWorld
var techniques: Array[String] = []


func before_each() -> void:
	GameState.reset_session()
	Settings.load_settings("user://test_agility_settings.cfg")
	world = TestWorld.create(runner)
	techniques.clear()


func after_each() -> void:
	TimeFx.reset()
	GameState.reset_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_agility_settings.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _melee_player(pos: Vector3, twin := false) -> Player:
	if twin:
		GameState.set_melee_weapon(&"twin_moon")
	var p := world.spawn_player(pos)
	p.weapons.technique_used.connect(func(n: String) -> void: techniques.append(n))
	await wait_physics_frames(3)
	p.weapons.select_slot(WeaponManager.Slot.MELEE)
	await wait_seconds(0.5)
	return p


func test_air_step_once_per_jump() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(5)
	_press(&"jump")
	await wait_physics_frames(12)
	assert_false(p.is_on_floor(), "점프했다")
	var stamina := p.stats.stamina
	var vy := p.velocity.y
	_press(&"jump")
	await wait_physics_frames(2)
	assert_gt(p.velocity.y, vy + 2.0, "공중 도약으로 다시 떠오른다")
	assert_near(p.stats.stamina, stamina - Player.AIR_STEP_COST, 1.0)
	var vy2 := p.velocity.y
	_press(&"jump")
	await wait_physics_frames(2)
	assert_lt(p.velocity.y, vy2, "공중 도약은 한 번뿐이다")
	await wait_seconds(1.5)
	assert_true(p.is_on_floor())


func test_wall_kick_pushes_away_from_wall() -> void:
	world.add_box(Vector3(0, 3, -1.2), Vector3(6, 6, 0.4))
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(5)
	_press(&"jump")
	await wait_physics_frames(4)
	# 벽 쪽으로 몸을 날린다.
	for i in 12:
		p.velocity.z = -6.0
		await wait_physics_frames(1)
	assert_gt(p._wall_contact, 0.0, "벽에 닿았다")
	_press(&"jump")
	await wait_physics_frames(2)
	assert_gt(p.velocity.z, 3.0, "벽 반대쪽(+Z)으로 튕겨 나간다")
	assert_gt(p.velocity.y, 3.0, "위로도 튀어 오른다")


func test_slide_from_sprint() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(5)
	p.sprinting = true
	p.velocity = Vector3(0, 0, -8.0)
	assert_true(p.try_slide())
	await wait_physics_frames(3)
	assert_true(p.is_sliding())
	assert_gt(Vector2(p.velocity.x, p.velocity.z).length(), Player.WALK_SPEED + 2.0, "걷기보다 빠르게 미끄러진다")
	assert_true(p.crouching, "몸을 낮춘다")
	await wait_seconds(Player.SLIDE_TIME + 0.2)
	assert_false(p.is_sliding())


func test_perfect_evade_slows_time_and_opens_counter() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -3), PI)
	await wait_physics_frames(3)
	assert_true(p.try_dodge())
	var res_before := p.stats.resonance
	var result := p.receive_enemy_attack(DamageInfo.create(10.0, DamageInfo.Kind.ENEMY_MELEE, rabbit))
	assert_true(result.evaded)
	assert_true(result.get("perfect", false), "회피 직후에 맞으면 간발의 회피")
	assert_lt(Engine.time_scale, 0.5, "잠깐 느려진다")
	assert_gt(p.stats.resonance, res_before, "공명을 얻는다")
	assert_true(p.has_counter(), "반격 기회가 열린다")
	await wait_seconds(Player.PERFECT_SLOW_TIME + 0.2)
	assert_near(Engine.time_scale, 1.0, 0.001, "원래 속도로 돌아온다")


func test_late_evade_is_not_perfect() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -3), PI)
	await wait_physics_frames(3)
	assert_true(p.try_dodge())
	await wait_seconds(Player.PERFECT_DODGE_WINDOW + 0.03)
	var result := p.receive_enemy_attack(DamageInfo.create(10.0, DamageInfo.Kind.ENEMY_MELEE, rabbit))
	assert_true(result.evaded, "아직 무적이다")
	assert_false(result.get("perfect", false))
	assert_false(p.has_counter())


func test_counter_strike_hits_harder() -> void:
	var p := await _melee_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -2.0), PI)
	await wait_physics_frames(3)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 0.9)
	p.open_counter()
	var before := dummy.hp
	p.weapons.press_trigger()
	await wait_physics_frames(2)
	p.weapons.release_trigger()
	await wait_seconds(0.4)
	var dealt := before - dummy.hp
	assert_true(techniques.has("반격"), "반격이 나간다")
	assert_gt(dealt, p.weapons.melee.light_damage * 1.3, "반격은 평소보다 세다")
	assert_false(p.has_counter(), "반격 기회는 한 번 쓴다")


func test_dash_strike_after_dodge() -> void:
	var p := await _melee_player(Vector3(0, 0, 3.0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -2.5), PI)
	await wait_physics_frames(3)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 0.9)
	var before := dummy.hp
	p.try_dodge()
	p.weapons.press_trigger()
	await wait_physics_frames(2)
	p.weapons.release_trigger()
	await wait_seconds(0.6)
	assert_true(techniques.has("돌진 베기"), "회피 중 공격은 돌진 베기")
	assert_lt(dummy.hp, before, "파고들어 벤다")


func test_plunge_strike_from_height() -> void:
	world.add_box(Vector3(0, 3.0, 4.0), Vector3(3, 6, 3))
	var p := await _melee_player(Vector3(0, 6.2, 4.0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -1.0), PI)
	await wait_physics_frames(3)
	# 받침대 끝에서 앞으로 뛰어내린다.
	p.global_position = Vector3(0, 6.5, 1.2)
	p.velocity = Vector3(0, 0, -2.0)
	await wait_physics_frames(6)
	assert_false(p.is_on_floor())
	var before := dummy.hp
	p.weapons.press_trigger()
	await wait_physics_frames(2)
	p.weapons.release_trigger()
	await wait_seconds(1.0)
	assert_true(techniques.has("낙하 베기"))
	assert_true(p.is_on_floor())
	assert_lt(dummy.hp, before, "내려찍으며 주변을 벤다")


func test_twin_blades_spin_hits_front_and_back() -> void:
	var p := await _melee_player(Vector3(0, 0, 0), true)
	assert_eq(p.weapons.melee.id, &"twin_moon")
	assert_true(p.weapons.melee.dual)
	var front := world.spawn(DUMMY, Vector3(0, 0, -1.8), PI)
	var back := world.spawn(DUMMY, Vector3(0, 0, 1.8), 0.0)
	await wait_physics_frames(3)
	TestWorld.aim_at(p, front.global_position + Vector3.UP * 0.9)
	var f0 := front.hp
	var b0 := back.hp
	p.weapons.simulate_hold(true)
	await wait_seconds(0.6)
	p.weapons.simulate_hold(false)
	await wait_seconds(0.4)
	assert_lt(front.hp, f0, "앞의 적")
	assert_lt(back.hp, b0, "뒤의 적도 회전 베기에 맞는다")


func test_twin_blades_alternate_hands() -> void:
	var p := await _melee_player(Vector3(0, 0, 0), true)
	var view: Dictionary = p.weapons._views[&"twin_moon"]
	assert_not_null(view.get("left"))
	assert_not_null(view.get("right"))
	var r0: Transform3D = view.right.transform
	var l0: Transform3D = view.left.transform
	p.weapons.press_trigger()
	await wait_physics_frames(2)
	p.weapons.release_trigger()
	await wait_physics_frames(4)
	var moved_r: bool = not view.right.transform.is_equal_approx(r0)
	var moved_l: bool = not view.left.transform.is_equal_approx(l0)
	assert_true(moved_r or moved_l, "한 손이 벤다")

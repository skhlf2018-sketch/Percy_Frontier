extends TestCase


func test_xp_curve_grows() -> void:
	assert_gt(PlayerProgress.xp_to_next(2), PlayerProgress.xp_to_next(1))
	assert_gt(PlayerProgress.xp_to_next(10), PlayerProgress.xp_to_next(9))


func test_level_up_carries_over_xp_and_grants_points() -> void:
	var p := PlayerProgress.new()
	var levels := []
	p.leveled_up.connect(func(l: int, _pts: int) -> void: levels.append(l))
	var need := PlayerProgress.xp_to_next(1)
	var gained := p.add_xp(need + 5)
	assert_eq(gained, 1)
	assert_eq(p.level, 2)
	assert_eq(p.xp, 5, "남은 경험치는 다음 레벨로 넘어간다")
	assert_eq(p.unspent_points, PlayerProgress.POINTS_PER_LEVEL)
	assert_eq(levels, [2])


func test_many_levels_at_once() -> void:
	var p := PlayerProgress.new()
	var total := 0
	for l in range(1, 5):
		total += PlayerProgress.xp_to_next(l)
	assert_eq(p.add_xp(total), 4)
	assert_eq(p.level, 5)
	assert_eq(p.unspent_points, 4 * PlayerProgress.POINTS_PER_LEVEL)


func test_level_raises_hp_and_stamina() -> void:
	var p := PlayerProgress.new()
	var hp1 := p.max_hp()
	var st1 := p.max_stamina()
	p.add_xp(PlayerProgress.xp_to_next(1))
	assert_near(p.max_hp(), hp1 + PlayerProgress.HP_PER_LEVEL)
	assert_near(p.max_stamina(), st1 + PlayerProgress.STAMINA_PER_LEVEL)


func test_allocation_spends_points_and_applies_effects() -> void:
	var p := PlayerProgress.new()
	p.unspent_points = 5
	assert_true(p.allocate(PlayerProgress.Stat.VIT, 2))
	assert_eq(p.unspent_points, 3)
	assert_near(p.max_hp(), PlayerProgress.BASE_HP + 8.0)
	assert_false(p.allocate(PlayerProgress.Stat.VIT, 4), "남은 포인트보다 많이 쓸 수 없다")
	assert_true(p.apply_allocation([0, 0, 0, 1, 2, 0, 0]))
	assert_eq(p.unspent_points, 0)
	assert_gt(p.move_speed_mult(), 1.0)
	assert_lt(p.recoil_mult(), 1.0)
	assert_false(p.apply_allocation([1, 0, 0, 0, 0, 0, 0]))


func test_reset_refunds_points_but_keeps_origin_bonus() -> void:
	var p := PlayerProgress.new()
	p.set_origin(&"blade")
	var str_base := p.stat(PlayerProgress.Stat.STR)
	assert_eq(str_base, PlayerProgress.BASE_STAT + 2)
	p.unspent_points = 3
	p.allocate(PlayerProgress.Stat.STR, 3)
	assert_eq(p.reset_allocation(), 3)
	assert_eq(p.unspent_points, 3)
	assert_eq(p.stat(PlayerProgress.Stat.STR), str_base)


func test_effects_are_modest() -> void:
	# 기획서 §10.1: 공격력은 레벨·능력치만으로 크게 늘지 않는다.
	var p := PlayerProgress.new()
	p.unspent_points = 30
	p.allocate(PlayerProgress.Stat.STR, 30)
	assert_lt(p.melee_damage_mult(), 1.5)
	p.unspent_points = 30
	p.allocate(PlayerProgress.Stat.AGI, 30)
	assert_le(p.move_speed_mult(), 1.15)


func test_save_round_trip() -> void:
	var p := PlayerProgress.new()
	p.character_name = "시험"
	p.set_origin(&"resonant")
	p.add_xp(PlayerProgress.xp_to_next(1) + PlayerProgress.xp_to_next(2) + 3)
	p.allocate(PlayerProgress.Stat.RES, 2)
	var q := PlayerProgress.new()
	q.from_dict(p.to_dict())
	assert_eq(q.character_name, "시험")
	assert_eq(q.origin, &"resonant")
	assert_eq(q.level, 3)
	assert_eq(q.xp, 3)
	assert_eq(q.unspent_points, p.unspent_points)
	assert_eq(q.stat(PlayerProgress.Stat.RES), p.stat(PlayerProgress.Stat.RES))


func test_kill_grants_xp_through_game_state() -> void:
	GameState.reset_session()
	var before := GameState.progress.total_xp
	GameState.grant_xp(14, "시험")
	assert_eq(GameState.progress.total_xp, before + 14)
	assert_true(GameState.discover_area(&"test_area", "시험 지역"))
	assert_false(GameState.discover_area(&"test_area", "시험 지역"), "두 번째 발견은 보상이 없다")
	GameState.reset_session()

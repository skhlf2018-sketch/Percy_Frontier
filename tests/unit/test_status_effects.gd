extends TestCase

const T := StatusEffects.Type


func test_buildup_triggers_at_threshold() -> void:
	var s := StatusEffects.new()
	var fired: Array[int] = []
	s.triggered.connect(func(t: int) -> void: fired.append(t))
	assert_false(s.add_buildup(T.BURN, 60.0))
	assert_true(s.add_buildup(T.BURN, 40.0))
	assert_eq(fired, [T.BURN] as Array[int])
	assert_true(s.is_active(T.BURN))
	assert_near(s.get_buildup(T.BURN), 0.0)


func test_resistance_scales_buildup() -> void:
	var s := StatusEffects.new()
	s.resistance[T.CHILL] = 0.5
	s.add_buildup(T.CHILL, 100.0)
	assert_near(s.get_buildup(T.CHILL), 50.0)
	assert_false(s.is_frozen())


func test_burn_deals_damage_then_ends() -> void:
	var s := StatusEffects.new()
	var ended: Array[int] = []
	s.ended.connect(func(t: int) -> void: ended.append(t))
	s.add_buildup(T.BURN, 100.0)
	var total := 0.0
	for i in 400:
		total += s.tick(1.0 / 60.0, false)
	assert_near(total, StatusEffects.BURN_DPS * StatusEffects.BURN_DURATION, 0.2)
	assert_false(s.is_active(T.BURN))
	assert_eq(ended, [T.BURN] as Array[int])


func test_chill_slows_then_freezes() -> void:
	var s := StatusEffects.new()
	s.add_buildup(T.CHILL, 55.0)
	assert_true(s.is_chilled())
	assert_near(s.move_multiplier(), 1.0 - StatusEffects.CHILL_SLOW)
	s.add_buildup(T.CHILL, 50.0)
	assert_true(s.is_frozen())
	assert_near(s.move_multiplier(), 0.0)


func test_freeze_tolerance_halves_next_buildup() -> void:
	var s := StatusEffects.new()
	s.add_buildup(T.CHILL, 100.0)
	for i in 200:
		s.tick(1.0 / 60.0, false)
	assert_false(s.is_frozen(), "빙결은 끝나야 한다")
	s.add_buildup(T.CHILL, 100.0)
	assert_near(s.get_buildup(T.CHILL), 50.0, 0.001, "직후에는 절반만 쌓인다")


func test_boss_rules_slow_instead_of_freeze() -> void:
	var s := StatusEffects.new()
	s.boss_rules = true
	s.add_buildup(T.CHILL, 100.0)
	assert_false(s.is_frozen())
	assert_gt(s.move_multiplier(), 0.0)
	assert_near(s.get_remaining(T.CHILL), StatusEffects.FREEZE_DURATION * 0.5)


func test_frozen_target_takes_bonus_melee_damage() -> void:
	var s := StatusEffects.new()
	s.add_buildup(T.CHILL, 100.0)
	var melee := DamageInfo.create(10.0, DamageInfo.Kind.MELEE)
	var gun := DamageInfo.create(10.0, DamageInfo.Kind.GUN)
	assert_near(s.damage_taken_multiplier(melee), StatusEffects.FROZEN_SHATTER_MULT)
	assert_near(s.damage_taken_multiplier(gun), 1.0)


func test_shock_increases_armor_damage() -> void:
	var s := StatusEffects.new()
	assert_near(s.armor_damage_multiplier(), 1.0)
	s.add_buildup(T.SHOCK, 100.0)
	assert_near(s.armor_damage_multiplier(), StatusEffects.SHOCK_ARMOR_MULT)


func test_bleed_only_hurts_when_moving_or_acting() -> void:
	var s := StatusEffects.new()
	s.add_buildup(T.BLEED, 100.0)
	assert_near(s.tick(0.5, false), 0.0)
	assert_near(s.tick(0.5, true), StatusEffects.BLEED_MOVE_DPS * 0.5)
	assert_near(s.on_action(), StatusEffects.BLEED_ACTION_DAMAGE)


func test_immunity_blocks_buildup() -> void:
	var s := StatusEffects.new()
	s.immunity_time = 2.0
	assert_false(s.add_buildup(T.BURN, 200.0))
	assert_near(s.get_buildup(T.BURN), 0.0)


func test_buildup_decays_after_delay() -> void:
	var s := StatusEffects.new()
	s.add_buildup(T.BURN, 40.0)
	s.tick(1.0, false)
	assert_near(s.get_buildup(T.BURN), 40.0, 0.001, "지연 시간 동안은 줄지 않는다")
	s.tick(1.0, false)
	assert_lt(s.get_buildup(T.BURN), 40.0)


func test_clear_all_emits_ended() -> void:
	var s := StatusEffects.new()
	var ended: Array[int] = []
	s.ended.connect(func(t: int) -> void: ended.append(t))
	s.add_buildup(T.BLEED, 100.0)
	s.add_buildup(T.BURN, 30.0)
	s.clear_all()
	assert_eq(ended, [T.BLEED] as Array[int])
	assert_false(s.has_any())


func test_apply_buildup_returns_triggered() -> void:
	var s := StatusEffects.new()
	var fired := s.apply_buildup({T.BURN: 100.0, T.SHOCK: 10.0})
	assert_eq(fired, [T.BURN] as Array[int])


func test_active_status_ignores_more_buildup() -> void:
	var s := StatusEffects.new()
	s.add_buildup(T.BURN, 100.0)
	var remaining := s.get_remaining(T.BURN)
	s.tick(1.0, false)
	s.add_buildup(T.BURN, 100.0)
	assert_near(s.get_remaining(T.BURN), remaining - 1.0, 0.001, "발동 중에는 연장되지 않는다")

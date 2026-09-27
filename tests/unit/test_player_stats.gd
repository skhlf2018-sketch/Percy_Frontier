extends TestCase


func test_shield_absorbs_before_hp() -> void:
	var s := PlayerStats.new()
	s.add_shield(30.0, 5.0)
	var lost := s.take_damage(50.0)
	assert_near(lost, 20.0)
	assert_near(s.hp, 80.0)
	assert_near(s.shield, 0.0)


func test_shield_expires() -> void:
	var s := PlayerStats.new()
	s.add_shield(30.0, 1.0)
	s.tick(1.1)
	assert_false(s.has_shield())
	assert_near(s.shield, 0.0)


func test_died_emits_once() -> void:
	var s := PlayerStats.new()
	var count := [0]
	s.died.connect(func() -> void: count[0] += 1)
	s.take_damage(150.0)
	s.take_damage(10.0)
	assert_true(s.is_dead())
	assert_eq(count[0], 1)


func test_no_heal_when_dead_and_heal_clamps() -> void:
	var s := PlayerStats.new()
	s.take_damage(30.0)
	assert_near(s.heal(100.0), 30.0)
	s.take_damage(200.0)
	assert_near(s.heal(50.0), 0.0)


func test_stamina_use_and_regen_delay() -> void:
	var s := PlayerStats.new()
	assert_true(s.use_stamina(40.0))
	assert_near(s.stamina, 60.0)
	s.tick(0.5)
	assert_near(s.stamina, 60.0, 0.001, "회복 지연 중")
	s.tick(1.0)
	assert_gt(s.stamina, 60.0)


func test_exhaustion_blocks_until_recovered() -> void:
	var s := PlayerStats.new()
	s.drain_stamina(200.0)
	assert_true(s.exhausted)
	assert_false(s.use_stamina(1.0))
	s.tick(s.stamina_regen_delay + 0.01)
	for i in 120:
		s.tick(1.0 / 60.0)
	assert_false(s.exhausted, "30% 이상 회복하면 탈진이 풀린다")


func test_resonance_clamps_and_spends() -> void:
	var s := PlayerStats.new()
	s.add_resonance(250.0)
	assert_near(s.resonance, 100.0)
	assert_true(s.spend_resonance(35.0))
	assert_near(s.resonance, 65.0)
	assert_false(s.spend_resonance(70.0))
	assert_near(s.resonance, 65.0)


func test_restore_full_clears_combat_resources() -> void:
	var s := PlayerStats.new()
	s.take_damage(40.0)
	s.add_resonance(50.0)
	s.drain_stamina(200.0)
	s.restore_full()
	assert_near(s.hp, s.max_hp)
	assert_near(s.stamina, s.max_stamina)
	assert_near(s.resonance, 0.0)
	assert_false(s.exhausted)

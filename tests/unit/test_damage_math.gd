extends TestCase


func test_weak_point_ignores_defense() -> void:
	var r := DamageMath.resolve_zone(10.0, Hurtbox.Zone.WEAK_POINT, 2.0, 0.0, 0.2, 1.0, 0.5)
	assert_near(r.damage, 20.0)
	assert_near(r.armor_damage, 0.0)


func test_normal_zone_applies_defense() -> void:
	var r := DamageMath.resolve_zone(10.0, Hurtbox.Zone.NORMAL, 1.0, 0.0, 0.2, 1.0, 0.25)
	assert_near(r.damage, 7.5)


func test_intact_armor_passes_fraction_and_takes_armor_damage() -> void:
	var r := DamageMath.resolve_zone(10.0, Hurtbox.Zone.ARMOR, 1.0, 50.0, 0.2, 2.0, 0.0)
	assert_near(r.damage, 2.0, 0.001, "장갑이 남아 있으면 20%만 본체로")
	assert_near(r.armor_damage, 20.0, 0.001, "근접처럼 장갑 배율 2.0")


func test_broken_armor_uses_zone_multiplier() -> void:
	var r := DamageMath.resolve_zone(10.0, Hurtbox.Zone.ARMOR, 1.5, 0.0, 0.2, 2.0, 0.0)
	assert_near(r.damage, 15.0)
	assert_near(r.armor_damage, 0.0)


func test_defense_is_clamped() -> void:
	var r := DamageMath.resolve_zone(10.0, Hurtbox.Zone.NORMAL, 1.0, 0.0, 0.2, 1.0, 5.0)
	assert_near(r.damage, 1.0, 0.001, "방어력은 최대 90%")


func test_falloff() -> void:
	assert_near(DamageMath.falloff(5.0, 10.0, 30.0, 0.5), 1.0)
	assert_near(DamageMath.falloff(20.0, 10.0, 30.0, 0.5), 0.75)
	assert_near(DamageMath.falloff(40.0, 10.0, 30.0, 0.5), 0.5)


func test_resonance_rewards_weak_points_and_breaks() -> void:
	var normal := HitResult.new()
	normal.kind = DamageInfo.Kind.GUN
	var weak := HitResult.new()
	weak.kind = DamageInfo.Kind.GUN
	weak.zone = Hurtbox.Zone.WEAK_POINT
	assert_gt(DamageMath.resonance_for_hit(weak), DamageMath.resonance_for_hit(normal))
	var broke := HitResult.new()
	broke.kind = DamageInfo.Kind.MELEE
	broke.armor_broken = true
	assert_near(DamageMath.resonance_for_hit(broke), 18.0)
	var pellet := HitResult.new()
	pellet.kind = DamageInfo.Kind.GUN
	pellet.zone = Hurtbox.Zone.WEAK_POINT
	pellet.resonance_mult = 1.0 / 9.0
	assert_near(DamageMath.resonance_for_hit(pellet), 3.0 / 9.0)


func test_skill_hits_do_not_generate_resonance() -> void:
	var r := HitResult.new()
	r.kind = DamageInfo.Kind.SKILL
	r.zone = Hurtbox.Zone.WEAK_POINT
	assert_near(DamageMath.resonance_for_hit(r), 0.0, 0.001, "스킬로 공명을 되돌려 받는 순환을 막는다")

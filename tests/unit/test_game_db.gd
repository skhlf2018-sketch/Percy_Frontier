extends TestCase
## 데이터 무결성: id 중복, 참조 대상 존재, 기획 규칙 위반 여부를 검사한다.


func _assert_unique_ids(list: Array, label: String) -> void:
	var seen := {}
	for item in list:
		assert_ne(item.id, &"", "%s id 비어 있음" % label)
		assert_false(seen.has(item.id), "%s id 중복: %s" % [label, item.id])
		seen[item.id] = true


func test_ids_are_unique() -> void:
	_assert_unique_ids(GameDB.WEAPONS, "총기")
	_assert_unique_ids(GameDB.MELEE, "근접")
	_assert_unique_ids(GameDB.SKILLS, "스킬")
	_assert_unique_ids(GameDB.ENEMIES, "적")
	_assert_unique_ids(GameDB.CONSUMABLES, "소모품")


func test_lookup_by_id() -> void:
	assert_not_null(GameDB.weapon(&"rifle_bfa3"))
	assert_not_null(GameDB.melee(&"karambit_hook"))
	assert_not_null(GameDB.skill(&"frost_pulse"))
	assert_not_null(GameDB.enemy(&"spore_spitter"))
	assert_not_null(GameDB.consumable(&"field_suture"))
	assert_null(GameDB.weapon(&"missing"))


func test_analysis_skills_exist_and_point_back() -> void:
	for data in GameDB.analyzable_enemies():
		var skill := GameDB.skill(data.analysis_skill)
		assert_not_null(skill, "%s의 분석 스킬" % data.id)
		if skill:
			assert_eq(skill.source_enemy, data.id, "%s 출처 몬스터" % skill.id)


func test_every_skill_is_obtainable() -> void:
	# 핵심 스킬을 확률 드롭에만 의존시키지 않는다(기획서 §10.3): 모든 스킬은 기본 기록이거나 분석으로 확정 해금된다.
	for skill: SkillData in GameDB.SKILLS:
		if skill.source_enemy == &"":
			assert_eq(skill.id, GameState.STARTER_SKILL, "기본 기록 스킬은 시작 스킬")
		else:
			var enemy := GameDB.enemy(skill.source_enemy)
			assert_not_null(enemy, "%s 출처" % skill.id)
			if enemy:
				assert_eq(enemy.analysis_skill, skill.id)


func test_slots_have_weapons() -> void:
	assert_gt(GameDB.weapons_for_slot(WeaponData.Slot.PRIMARY).size(), 1)
	assert_gt(GameDB.weapons_for_slot(WeaponData.Slot.SECONDARY).size(), 0)
	assert_gt(GameDB.all_melee().size(), 1)


func test_weapon_sounds_exist() -> void:
	for w: WeaponData in GameDB.WEAPONS:
		assert_true(Sfx.has_sound(w.sound), "%s 발사음 %s" % [w.id, w.sound])


func test_attack_windups_are_readable() -> void:
	# 강한 공격은 충분한 전조를 가진다(기획서 §8.7).
	for e: EnemyData in GameDB.ENEMIES:
		for a in e.attacks:
			assert_ge(a.windup, 0.4, "%s/%s 전조" % [e.id, a.id])
			if not a.parryable:
				assert_ge(a.windup, 0.8, "%s/%s 패링 불가 공격은 더 긴 전조" % [e.id, a.id])


func test_default_loadout_exists() -> void:
	assert_not_null(GameDB.weapon(GameState.primary_weapon))
	assert_not_null(GameDB.weapon(GameState.secondary_weapon))
	assert_not_null(GameDB.melee(GameState.melee_weapon))

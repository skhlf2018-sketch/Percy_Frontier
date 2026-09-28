extends TestCase
## 무기 한 자루 단위(희귀도·특성·강화), 칸 제한과 창고, 저장과 예전 저장 옮기기.


func before_each() -> void:
	GameState.reset_session()


func after_each() -> void:
	GameState.reset_session()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_perk_count_grows_with_rarity() -> void:
	var expected := {
		ItemRarity.Tier.STANDARD: 0, ItemRarity.Tier.IMPROVED: 1, ItemRarity.Tier.RARE: 2,
		ItemRarity.Tier.EPIC: 3, ItemRarity.Tier.LEGENDARY: 3,
	}
	for tier: int in expected:
		for s in 20:
			var it := WeaponItem.roll(&"bolt_rifle", tier, _rng(s * 31 + tier))
			assert_eq(it.perks.size(), int(expected[tier]), "%s 특성 수" % ItemRarity.tier_name(tier))
			var seen := {}
			for p in it.perks:
				assert_false(seen.has(p), "같은 특성이 두 번 붙지 않는다")
				seen[p] = true


func test_perks_fit_the_weapon_kind() -> void:
	for s in 40:
		for p in WeaponItem.roll(&"goblin_cleaver", ItemRarity.Tier.EPIC, _rng(s)).perks:
			assert_true(WeaponPerks.fits(p, false, false), "근접 무기에 총기 특성(%s)이 붙지 않는다" % p)
		for p in WeaponItem.roll(&"energy_re2", ItemRarity.Tier.EPIC, _rng(s)).perks:
			assert_true(WeaponPerks.fits(p, true, false), "과열식 총에 탄창 특성(%s)이 붙지 않는다" % p)


func test_legendary_gets_signature_and_name() -> void:
	var it := WeaponItem.roll(&"chief_greatblade", ItemRarity.Tier.LEGENDARY, _rng(7))
	assert_true(it.has_perk(&"butcher"), "전설은 고유 특성을 가진다")
	assert_eq(it.display_name(), "도살자의 대도")
	assert_eq(it.rarity_name(), "전설")


func test_upgrade_and_keen_multiply_damage() -> void:
	var it := WeaponItem.create(&"rifle_bfa3")
	assert_near(it.damage_mult(), 1.0)
	it.upgrade = 2
	assert_near(it.damage_mult(), 1.16)
	it.perks = [&"keen"] as Array[StringName]
	assert_near(it.damage_mult(), 1.16 * 1.1)
	assert_eq(it.display_name(), GameDB.weapon(&"rifle_bfa3").display_name + " +2")


func test_extended_mag_only_for_magazine_guns() -> void:
	var rifle := WeaponItem.create(&"rifle_bfa3", ItemRarity.Tier.IMPROVED, [&"extended_mag"] as Array[StringName])
	assert_eq(rifle.mag_capacity(), int(round(GameDB.weapon(&"rifle_bfa3").magazine_size * 1.3)))
	var plain := WeaponItem.create(&"rifle_bfa3")
	assert_eq(plain.mag_capacity(), GameDB.weapon(&"rifle_bfa3").magazine_size)


func test_rarer_items_sell_for_more() -> void:
	var a := WeaponItem.create(&"pipe_shotgun", ItemRarity.Tier.STANDARD)
	var b := WeaponItem.create(&"pipe_shotgun", ItemRarity.Tier.RARE)
	var c := WeaponItem.create(&"pipe_shotgun", ItemRarity.Tier.LEGENDARY)
	assert_lt(a.sell_value(), b.sell_value())
	assert_lt(b.sell_value(), c.sell_value())


func test_slots_follow_weapon_kind() -> void:
	assert_eq(WeaponItem.create(&"bolt_rifle").slot(), WeaponItem.Slot.PRIMARY)
	assert_eq(WeaponItem.create(&"pistol_bf9").slot(), WeaponItem.Slot.SECONDARY)
	assert_eq(WeaponItem.create(&"hand_axe").slot(), WeaponItem.Slot.MELEE)


func test_equip_returns_previous_item_of_same_slot() -> void:
	var before := GameState.equipped_item(WeaponItem.Slot.MELEE)
	var cleaver := WeaponItem.create(&"goblin_cleaver", ItemRarity.Tier.RARE)
	var old := GameState.equip_item(cleaver)
	assert_true(old == before, "같은 칸에 들던 무기를 돌려준다")
	assert_eq(GameState.melee_weapon, &"goblin_cleaver")
	assert_eq(GameState.primary_weapon, &"rifle_bfa3", "다른 칸은 그대로")


func test_warehouse_swaps_and_limits() -> void:
	var shotgun := WeaponItem.create(&"shotgun_logger")
	assert_true(GameState.store_item(shotgun))
	var rifle := GameState.equipped_item(WeaponItem.Slot.PRIMARY)
	assert_true(GameState.take_from_warehouse(0))
	assert_true(GameState.equipped_item(WeaponItem.Slot.PRIMARY) == shotgun)
	assert_true(GameState.warehouse[0] == rifle, "들던 무기가 그 자리에 들어간다")
	while not GameState.warehouse_full():
		GameState.store_item(WeaponItem.create(&"pistol_bf9"))
	assert_false(GameState.store_item(WeaponItem.create(&"pistol_bf9")), "가득 차면 더 맡기지 못한다")
	assert_eq(GameState.warehouse.size(), GameState.WAREHOUSE_SIZE)


func test_save_round_trip_keeps_items() -> void:
	var epic := WeaponItem.create(&"bolt_rifle", ItemRarity.Tier.EPIC,
		[&"steady", &"serrated", &"last_rounds"] as Array[StringName])
	epic.upgrade = 2
	GameState.equip_item(epic)
	GameState.store_item(WeaponItem.create(&"hand_axe", ItemRarity.Tier.IMPROVED, [&"balanced"] as Array[StringName]))
	var doc := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset_session()
	GameState.from_dict(doc)
	var it := GameState.equipped_item(WeaponItem.Slot.PRIMARY)
	assert_eq(it.base_id, &"bolt_rifle")
	assert_eq(it.rarity, ItemRarity.Tier.EPIC)
	assert_eq(it.upgrade, 2)
	assert_eq(it.perks, [&"steady", &"serrated", &"last_rounds"] as Array[StringName])
	assert_eq(GameState.warehouse.size(), 1)
	assert_eq(GameState.warehouse[0].base_id, &"hand_axe")
	assert_true(GameState.warehouse[0].has_perk(&"balanced"))


func test_old_save_format_is_migrated() -> void:
	var doc := GameState.to_dict()
	doc.erase("equipped")
	doc.erase("warehouse")
	doc["primary"] = "shotgun_logger"
	doc["secondary"] = "pistol_bf9"
	doc["melee"] = "karambit_hook"
	doc["upgrades"] = {"shotgun_logger": 2, "sword_survey": 1}
	doc["owned_weapons"] = ["rifle_bfa3", "shotgun_logger", "pistol_bf9", "sword_survey", "karambit_hook"]
	GameState.reset_session()
	GameState.from_dict(doc)
	assert_eq(GameState.primary_weapon, &"shotgun_logger")
	assert_eq(GameState.equipped_item(WeaponItem.Slot.PRIMARY).upgrade, 2, "강화 단계를 옮긴다")
	assert_eq(GameState.melee_weapon, &"karambit_hook")
	var bases: Array[StringName] = []
	for it in GameState.warehouse:
		bases.append(it.base_id)
	assert_true(bases.has(&"rifle_bfa3") and bases.has(&"sword_survey"), "들지 않은 무기는 창고로 간다")
	assert_eq(bases.size(), 2)
	for it in GameState.warehouse:
		if it.base_id == &"sword_survey":
			assert_eq(it.upgrade, 1)


func test_unknown_weapon_in_save_is_dropped() -> void:
	assert_null(WeaponItem.from_dict({"base": "laser_banana"}))
	var it := WeaponItem.from_dict({"base": "rifle_bfa3", "perks": ["keen", "made_up"], "upgrade": 9})
	assert_eq(it.perks, [&"keen"] as Array[StringName], "모르는 특성은 버린다")
	assert_eq(it.upgrade, GameState.MAX_UPGRADE)

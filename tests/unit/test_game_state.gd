extends TestCase


func before_each() -> void:
	GameState.reset_session()


func after_each() -> void:
	GameState.reset_session()


func test_session_starts_with_starter_skill() -> void:
	assert_eq(GameState.skill_slots.size(), GameState.SKILL_SLOT_COUNT)
	assert_eq(GameState.skill_slots[0], GameState.STARTER_SKILL)
	assert_eq(GameState.skill_slots[1], &"")
	assert_true(GameState.is_skill_unlocked(&"frost_pulse"))


func test_unlock_fills_next_empty_slot() -> void:
	assert_eq(GameState.unlock_skill(&"fire_spore"), 1)
	assert_eq(GameState.unlock_skill(&"ambush_leap"), 2)
	assert_eq(GameState.unlock_skill(&"fire_spore"), 1, "이미 해금한 스킬은 같은 슬롯")
	assert_eq(GameState.skill_slots, [&"frost_pulse", &"fire_spore", &"ambush_leap", &""] as Array[StringName])


func test_unknown_skill_is_rejected() -> void:
	expect_error()
	assert_eq(GameState.unlock_skill(&"nonexistent"), -1)


func test_bestiary_unlock_equips_skill_and_notifies() -> void:
	var notices: Array[String] = []
	var cb := func(text: String, _kind: int) -> void: notices.append(text)
	GameEvents.notice.connect(cb)
	GameState.bestiary.complete(GameDB.enemy(&"rock_charger"))
	GameEvents.notice.disconnect(cb)
	assert_true(GameState.is_skill_unlocked(&"carapace_guard"))
	assert_eq(GameState.skill_slots[1], &"carapace_guard")
	var found := false
	for n in notices:
		if n.contains("갑각 방벽"):
			found = true
	assert_true(found, "해금 알림에 스킬 이름이 들어간다")


func test_complete_all_analysis_fills_every_slot() -> void:
	GameState.complete_all_analysis()
	for slot in GameState.skill_slots:
		assert_ne(slot, &"")


func test_weapon_selection_validates_ids() -> void:
	GameState.set_primary_weapon(&"shotgun_logger")
	assert_eq(GameState.primary_weapon, &"shotgun_logger")
	GameState.set_primary_weapon(&"not_a_weapon")
	assert_eq(GameState.primary_weapon, &"shotgun_logger")
	GameState.set_melee_weapon(&"karambit_hook")
	assert_eq(GameState.melee_weapon, &"karambit_hook")

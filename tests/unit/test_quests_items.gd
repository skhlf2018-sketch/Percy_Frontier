extends TestCase
## 의뢰 기록(QuestLog), 재료 드롭 표(ItemDB), 보관함과 지도 기록의 저장.


func after_each() -> void:
	GameState.reset_session()


func test_item_step_counts_items_already_owned() -> void:
	GameState.add_item(&"stone_scale", 5)
	var q := GameState.quests
	q.start(&"main_signal")
	q.notify(&"area", &"percy")
	assert_true(q.try_talk_step(&"main_signal", &"clerk"))
	assert_eq(q.step_of(&"main_signal"), 3, "이미 가진 재료는 받자마자 인정한다(§17.2)")


func test_talk_step_needs_items_to_consume() -> void:
	var q := GameState.quests
	q.start(&"herb_basket")
	GameState.add_item(&"herb_basket")
	assert_eq(q.step_of(&"herb_basket"), 1)
	GameState.remove_item(&"herb_basket")
	assert_false(q.try_talk_step(&"herb_basket", &"innkeeper"), "건넬 물건이 없으면 넘어가지 않는다")
	assert_false(q.try_talk_step(&"herb_basket", &"clerk"), "다른 주민과는 넘어가지 않는다")
	GameState.add_item(&"herb_basket")
	assert_true(q.try_talk_step(&"herb_basket", &"innkeeper"))
	assert_true(q.is_done(&"herb_basket"))


func test_wrong_kill_target_does_not_count() -> void:
	var q := GameState.quests
	q.start(&"rabbit_trouble")
	q.notify(&"kill", &"rock_charger")
	assert_eq(q.count_of(&"rabbit_trouble"), 0)
	q.notify(&"kill", &"killer_rabbit")
	assert_eq(q.count_of(&"rabbit_trouble"), 1)


func test_clue_step_accepts_any_clue() -> void:
	var q := GameState.quests
	q.start(&"night_silence")
	q.notify(&"clue", &"broken_trees")
	q.notify(&"clue", &"giant_tracks")
	assert_eq(q.step_of(&"night_silence"), 1, "단서 두 개면 다음 단계")


func test_completion_grants_rewards_once() -> void:
	var q := GameState.quests
	q.start(&"rabbit_trouble")
	for i in 6:
		q.notify(&"kill", &"killer_rabbit")
	assert_true(q.try_talk_step(&"rabbit_trouble", &"clerk"))
	assert_eq(GameState.silver, 80)
	assert_false(q.start(&"rabbit_trouble"), "끝난 의뢰는 다시 받지 않는다")
	assert_false(q.try_talk_step(&"rabbit_trouble", &"clerk"))
	assert_eq(GameState.silver, 80, "보상은 한 번만")


func test_quest_log_round_trip() -> void:
	var q := GameState.quests
	q.start(&"rabbit_trouble")
	q.notify(&"kill", &"killer_rabbit", 2)
	q.start(&"herb_basket")
	q.tracked = &"rabbit_trouble"
	GameState.add_item(&"rabbit_fur", 4)
	GameState.add_silver(33)
	GameState.reveal_map(Vector2(10, 10), 30.0)
	var d := GameState.to_dict()
	var json := JSON.stringify(d)
	GameState.reset_session()
	var parsed: Dictionary = JSON.parse_string(json)
	GameState.from_dict(parsed)
	q = GameState.quests
	assert_true(q.is_active(&"rabbit_trouble"))
	assert_eq(q.count_of(&"rabbit_trouble"), 2)
	assert_eq(q.tracked, &"rabbit_trouble")
	assert_eq(GameState.item_count(&"rabbit_fur"), 4)
	assert_eq(GameState.silver, 33)
	assert_true(GameState.is_map_revealed(Vector2(10, 10)), "지도 기록이 저장된다")
	assert_false(GameState.is_map_revealed(Vector2(200, -200)))


func test_charger_always_drops_stone_scales() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 20:
		var drops := ItemDB.roll_drops(&"rock_charger", 1.0, rng)
		var scales := 0
		for d in drops:
			if d[0] == &"stone_scale":
				scales += int(d[1])
		assert_true(scales >= 2 and scales <= 3, "돌격수는 돌비늘 조각을 2~3개 남긴다")
	assert_eq(ItemDB.roll_drops(&"training_dummy", 1.0, rng).size(), 0, "표에 없는 적은 재료가 없다")


func test_reveal_map_marks_nearby_cells_only() -> void:
	assert_eq(GameState.map_explored_ratio(), 0.0)
	assert_true(GameState.reveal_map(Vector2(-182, 28), 44.0))
	assert_false(GameState.reveal_map(Vector2(-182, 28), 44.0), "이미 드러난 곳은 새로 드러나지 않는다")
	assert_true(GameState.is_map_revealed(Vector2(-182, 28)))
	assert_false(GameState.is_map_revealed(Vector2(-182, 100)))
	assert_gt(GameState.map_explored_ratio(), 0.0)

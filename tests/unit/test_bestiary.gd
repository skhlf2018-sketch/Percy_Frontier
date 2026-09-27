extends TestCase

const E := Bestiary.Event


func _rabbit() -> EnemyData:
	return GameDB.enemy(&"killer_rabbit")


func test_observe_counts_once() -> void:
	var b := Bestiary.new()
	var first := b.record(_rabbit(), E.OBSERVE)
	var second := b.record(_rabbit(), E.OBSERVE)
	assert_near(first, _rabbit().analysis_observe)
	assert_near(second, 0.0)
	assert_true(b.is_discovered(&"killer_rabbit"))


func test_repeated_kills_have_diminishing_returns() -> void:
	var b := Bestiary.new()
	var gains: Array[float] = []
	for i in 12:
		gains.append(b.record(_rabbit(), E.KILL))
	assert_near(gains[0], _rabbit().analysis_kill)
	assert_lt(gains[3], gains[0])
	var floor_value := _rabbit().analysis_kill * Bestiary.REPEAT_FLOOR
	assert_ge(gains[10], floor_value - 0.001, "감소에는 하한이 있다")


func test_varied_actions_beat_repeated_kills() -> void:
	var repeat := Bestiary.new()
	for i in 4:
		repeat.record(_rabbit(), E.KILL)
	var varied := Bestiary.new()
	varied.record(_rabbit(), E.KILL)
	varied.record(_rabbit(), E.WEAK_POINT_KILL)
	varied.record(_rabbit(), E.PARRY)
	varied.record(_rabbit(), E.EVADE)
	assert_gt(varied.analysis_of(&"killer_rabbit"), repeat.analysis_of(&"killer_rabbit"),
		"같은 몬스터 반복 사냥만이 최선이 되지 않는다")


func test_unlock_is_guaranteed_at_max() -> void:
	var b := Bestiary.new()
	var unlocked: Array = []
	b.skill_unlocked.connect(func(skill: StringName, enemy: StringName, core: bool) -> void:
		unlocked.append([skill, enemy, core]))
	var guard := 0
	while not b.get_entry(&"killer_rabbit") or not b.get_entry(&"killer_rabbit").skill_unlocked:
		b.record(_rabbit(), E.KILL)
		guard += 1
		if guard > 200:
			break
	assert_lt(guard, 200, "분석도 누적만으로 반드시 해금된다")
	assert_eq(unlocked.size(), 1)
	assert_eq(unlocked[0][0], &"ambush_leap")
	assert_false(unlocked[0][2])
	assert_near(b.analysis_of(&"killer_rabbit"), Bestiary.MAX_ANALYSIS)
	assert_near(b.record(_rabbit(), E.KILL), 0.0, 0.001, "해금 후에는 더 오르지 않는다")


func test_core_drop_unlocks_immediately() -> void:
	var b := Bestiary.new()
	var data: EnemyData = _rabbit().duplicate()
	data.core_drop_chance = 1.0
	var unlocked: Array = []
	b.skill_unlocked.connect(func(skill: StringName, _e: StringName, core: bool) -> void:
		unlocked.append([skill, core]))
	assert_true(b.roll_core_drop(data))
	assert_eq(unlocked, [[&"ambush_leap", true]])
	assert_false(b.roll_core_drop(data), "이미 해금했으면 다시 떨어지지 않는다")


func test_core_drop_can_fail() -> void:
	var b := Bestiary.new()
	var data: EnemyData = _rabbit().duplicate()
	data.core_drop_chance = 0.0
	assert_false(b.roll_core_drop(data))


func test_non_analyzable_enemy_gives_no_analysis() -> void:
	var b := Bestiary.new()
	var dummy := GameDB.enemy(&"training_dummy")
	assert_near(b.record(dummy, E.KILL), 0.0)


func test_complete_unlocks() -> void:
	var b := Bestiary.new()
	var unlocked: Array = []
	b.skill_unlocked.connect(func(skill: StringName, _e: StringName, _c: bool) -> void: unlocked.append(skill))
	b.complete(GameDB.enemy(&"spore_spitter"))
	assert_eq(unlocked, [&"fire_spore"])

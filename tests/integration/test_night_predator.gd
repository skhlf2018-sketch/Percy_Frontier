extends TestCase
## 유니크 사건 「밤의 포식자」: 단서, 출현 조건(밤·그늘 숲 깊은 곳·단서 둘), 전조와 출현, 생존·사망·도주 결과,
## 각인 효과, 사냥꾼 의뢰와의 연결.

const GAME := preload("res://src/main/game.tscn")
const RABBIT := preload("res://src/enemies/killer_rabbit.tscn")

var game: Game
var ev: NightPredatorEvent


func before_each() -> void:
	Settings.load_settings("user://test_predator.cfg")
	game = GAME.instantiate()
	game.mode = Game.Mode.FIELD
	runner.add_child(game)
	await wait_physics_frames(4)
	ev = game.field.predator_event
	game.field.day_night.paused = true


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	runner.get_tree().paused = false
	await wait_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_predator.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()
	TimeFx.reset()


func _put_player(p2: Vector2) -> void:
	var p := game.player
	p.global_position = game.field.terrain.point_at(p2) + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _prepare_night_deep(clues: bool = true) -> void:
	game.field.day_night.advance_to(23.0)
	if clues:
		GameState.add_clue(&"claw_marks")
		GameState.add_clue(&"explorer_journal")
	_put_player(FieldLayout.SHADE_CENTER + Vector2(6, 4))


## 전조를 건너뛰고 바로 출현시킨다.
func _start_encounter() -> void:
	_prepare_night_deep()
	for i in 30:
		if ev.state == NightPredatorEvent.State.OMEN:
			break
		await wait_physics_frames(1)
	ev._timer = 0.02
	for i in 30:
		if ev.state == NightPredatorEvent.State.ENCOUNTER:
			break
		await wait_physics_frames(1)


func _wait_state(s: int, frames: int) -> bool:
	for i in frames:
		if ev.state == s:
			return true
		await wait_physics_frames(1)
	return ev.state == s


func test_clue_spots_record_clues() -> void:
	assert_eq(game.field.clue_spots.size(), 3, "단서 자리가 셋 있다")
	for spot in game.field.clue_spots:
		var want: Vector2 = FieldWorld.CLUE_PLACES[spot.clue_id]
		var at := Vector2(spot.global_position.x, spot.global_position.z)
		assert_lt(at.distance_to(want), 13.0, "%s는 정한 곳 가까이에 있다" % spot.clue_id)
		assert_near(spot.global_position.y, game.field.terrain.height_at(at.x, at.y), 0.2, "지면 위")
		spot.interact(game.player)
		assert_true(GameState.clues.has(spot.clue_id), "조사하면 단서가 남는다")
	assert_eq(GameState.clue_count(&"night_predator"), 3)


func test_no_encounter_without_all_conditions() -> void:
	# 낮: 단서가 있어도 나타나지 않는다.
	GameState.add_clue(&"claw_marks")
	GameState.add_clue(&"explorer_journal")
	game.field.day_night.advance_to(13.0)
	_put_player(FieldLayout.SHADE_CENTER)
	await wait_physics_frames(20)
	assert_eq(ev.state, NightPredatorEvent.State.IDLE, "낮에는 나타나지 않는다")
	# 밤이어도 숲 깊은 곳이 아니면 나타나지 않는다.
	game.field.day_night.advance_to(23.0)
	_put_player(FieldLayout.CAMP + Vector2(0, 10))
	await wait_physics_frames(20)
	assert_eq(ev.state, NightPredatorEvent.State.IDLE, "숲 밖에서는 나타나지 않는다")
	_put_player(FieldLayout.SHADE_CENTER)
	await wait_physics_frames(10)
	assert_eq(ev.state, NightPredatorEvent.State.OMEN, "세 조건이 모이면 전조가 시작된다")


func test_glimpse_without_clues_gives_existence_clue() -> void:
	_prepare_night_deep(false)
	assert_true(await _wait_state(NightPredatorEvent.State.GLIMPSE, 30), "단서 없이 밤의 숲에 들어가면 흘끗 본다")
	assert_true(await _wait_state(NightPredatorEvent.State.IDLE, 600), "잠시 뒤 사라진다")
	assert_true(GameState.clues.has(&"night_glimpse"), "「어둠 속의 푸른 눈」 단서")
	assert_false(GameState.unique_record(&"night_predator").sighted, "흘끗 본 것은 조우가 아니다")


func test_omen_then_encounter_with_hidden_name() -> void:
	_prepare_night_deep()
	assert_true(await _wait_state(NightPredatorEvent.State.OMEN, 30))
	await wait_physics_frames(120)
	assert_gt(game.field.day_night.eerie, 0.3, "전조: 빛이 사그라든다")
	assert_true(await _wait_state(NightPredatorEvent.State.ENCOUNTER, 420), "전조 뒤 반드시 나타난다")
	var pred := ev.predator
	assert_not_null(pred)
	assert_true(pred.display_label().contains("???"), "정체를 모를 때는 이름을 숨긴다")
	assert_true(GameState.unique_record(&"night_predator").sighted, "최초 발견 기록")
	var d := pred.global_position.distance_to(game.player.global_position)
	assert_true(d > 12.0 and d < 30.0, "조금 떨어진 곳에서 나타난다 (%.1fm)" % d)
	await wait_frames(2)
	assert_true(game.hud._unique_panel.visible, "유니크 조우 표시")
	await wait_physics_frames(20)
	assert_true(game.player.is_in_combat(), "사냥당하는 동안은 전투 중이다")


func test_surviving_grants_mark_title_and_quest_progress() -> void:
	GameState.quests.start(&"night_silence")
	await _start_encounter()
	assert_eq(ev.state, NightPredatorEvent.State.ENCOUNTER)
	assert_eq(GameState.quests.step_of(&"night_silence"), 1, "단서 둘로 첫 단계가 끝나 있다")
	var xp := GameState.progress.total_xp
	ev.predator.interest = NightPredator.MAX_INTEREST - 0.01
	assert_true(await _wait_state(NightPredatorEvent.State.AFTERMATH, 400), "흥미가 차면 물러난다")
	assert_eq(ev.last_outcome, NightPredatorEvent.Outcome.SURVIVED)
	assert_true(GameState.has_mark(&"predator_mark"), "각인")
	assert_true(GameState.titles.has(&"night_survivor"), "칭호")
	assert_true(GameState.unique_record(&"night_predator").survived, "최초 생존 기록")
	assert_gt(GameState.progress.total_xp, xp + NightPredatorEvent.FIRST_SURVIVAL_XP - 1, "경험치")
	assert_eq(GameState.quests.step_of(&"night_silence"), 2, "사냥꾼에게 보고하는 단계")
	assert_true(await _wait_state(NightPredatorEvent.State.IDLE, 400))
	await wait_physics_frames(20)
	assert_eq(ev.state, NightPredatorEvent.State.IDLE, "같은 밤에는 다시 나타나지 않는다")
	game.services.talk(game.field.npcs[&"hunter"])
	assert_true(GameState.quests.is_done(&"night_silence"), "사냥꾼 의뢰 완료")


func test_cannot_be_killed_and_retreats_when_wounded() -> void:
	await _start_encounter()
	var pred := ev.predator
	await wait_physics_frames(3)
	var body: Hurtbox = pred.get_node("BodyHurtbox")
	var info := DamageInfo.create(99999.0, DamageInfo.Kind.MELEE, game.player)
	body.hit(info)
	assert_true(pred.is_alive(), "쓰러뜨릴 수 없다")
	assert_gt(pred.health_ratio(), NightPredator.HP_FLOOR_RATIO - 0.01)
	assert_eq(pred.phase, NightPredator.Phase.RETREAT, "깊이 다치면 물러난다")
	assert_true(await _wait_state(NightPredatorEvent.State.AFTERMATH, 400))
	assert_eq(ev.last_outcome, NightPredatorEvent.Outcome.SURVIVED)


func test_dying_fails_and_can_retry() -> void:
	await _start_encounter()
	game.player.stats.take_damage(9999.0)
	assert_true(await _wait_state(NightPredatorEvent.State.AFTERMATH, 300), "쓰러지면 사건이 끝난다")
	assert_eq(ev.last_outcome, NightPredatorEvent.Outcome.DIED)
	assert_false(GameState.has_mark(&"predator_mark"), "각인은 없다")
	assert_true(GameState.unique_record(&"night_predator").sighted, "그래도 최초 발견은 남는다")
	assert_false(ev._spent_tonight, "같은 밤에 다시 도전할 수 있다")


func test_running_away_ends_without_reward() -> void:
	await _start_encounter()
	_put_player(FieldLayout.SHADE_CENTER + Vector2(170, 20))
	assert_true(await _wait_state(NightPredatorEvent.State.AFTERMATH, 300))
	assert_eq(ev.last_outcome, NightPredatorEvent.Outcome.ESCAPED)
	assert_false(GameState.has_mark(&"predator_mark"))


func test_dawn_ends_hunt_as_survival() -> void:
	await _start_encounter()
	game.field.day_night.advance_to(6.0)
	assert_true(await _wait_state(NightPredatorEvent.State.AFTERMATH, 400), "새벽이 오면 물러난다")
	assert_eq(ev.last_outcome, NightPredatorEvent.Outcome.SURVIVED)


func test_parry_and_evade_raise_interest() -> void:
	await _start_encounter()
	var pred := ev.predator
	var before := pred.interest
	pred.on_parried(game.player)
	assert_gt(pred.interest, before + NightPredator.INTEREST_PARRY - 0.5, "패링하면 흥미가 오른다")
	before = pred.interest
	GameEvents.perfect_evaded.emit(pred)
	assert_gt(pred.interest, before + NightPredator.INTEREST_PERFECT - 0.5, "간발의 회피도")


func test_predator_attacks_are_telegraphed() -> void:
	await _start_encounter()
	var pred := ev.predator
	pred._start_phase(NightPredator.Phase.ASSAULT)
	pred.global_position = game.player.global_position + Vector3(0, 0, -3.0)
	pred.reset_physics_interpolation()
	var seen := false
	for i in 240:
		if not pred.telegraph_info().is_empty():
			seen = true
			break
		await wait_physics_frames(1)
	assert_true(seen, "공격 전에는 전조가 있다")


func test_mark_makes_weak_monsters_flee() -> void:
	game.field.day_night.advance_to(12.0)
	var spot := FieldLayout.MEADOW_CENTER + Vector2(-30, 40)
	_put_player(spot)
	var rabbit: KillerRabbit = RABBIT.instantiate()
	rabbit.ambush = false
	game.field.add_child(rabbit)
	rabbit.global_position = game.field.terrain.point_at(spot + Vector2(0, -8)) + Vector3.UP * 0.2
	rabbit.look_at(game.player.global_position, Vector3.UP)
	GameState.grant_mark(&"predator_mark")
	assert_true(rabbit.fears_mark(), "약한 몬스터는 각인을 두려워한다")
	for i in 60:
		if rabbit.state == Enemy.State.FLEE:
			break
		await wait_physics_frames(1)
	assert_eq(rabbit.state, Enemy.State.FLEE, "덤비지 않고 달아난다")
	# 공격받으면 맞서 싸운다.
	var info := DamageInfo.create(1.0, DamageInfo.Kind.GUN, game.player)
	rabbit._hurtboxes[0].hit(info)
	assert_true(rabbit.is_engaged(), "공격받으면 맞선다")
	rabbit.queue_free()


func test_mark_changes_detection_and_night_vision() -> void:
	var charger := GameDB.enemy(&"rock_charger")
	assert_gt(charger.level, GameState.progress.level)
	GameState.grant_mark(&"predator_mark")
	await wait_frames(2)
	assert_near(game.field.day_night.night_vision, 1.0, 0.01, "밤눈이 밝아진다")

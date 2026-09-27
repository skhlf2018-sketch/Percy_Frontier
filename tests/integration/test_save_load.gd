extends TestCase
## 캐릭터 생성·도입부·저장·불러오기(기획서 §3.2, §20).

const GAME := preload("res://src/main/game.tscn")
const TEST_DIR := "user://test_saves"

var game: Game
var _prev_dir := ""


func before_each() -> void:
	Settings.load_settings("user://test_save.cfg")
	_prev_dir = SaveSystem.directory
	SaveSystem.directory = TEST_DIR
	for slot in SaveSystem.all_slots():
		SaveSystem.delete(slot)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	runner.get_tree().paused = false
	await wait_frames(2)
	for slot in SaveSystem.all_slots():
		SaveSystem.delete(slot)
	SaveSystem.directory = _prev_dir
	Game.next_new_game = {}
	Game.next_load = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()


func _start(config := {}, doc := {}) -> void:
	game = GAME.instantiate()
	game.mode = Game.Mode.FIELD
	game.new_game_config = config
	game.load_doc = doc
	runner.add_child(game)
	await wait_physics_frames(4)


func test_save_file_round_trip_and_backup() -> void:
	assert_eq(SaveSystem.write("1", {"state": {"x": 1}}, {"name": "가"}), OK)
	assert_eq(SaveSystem.write("1", {"state": {"x": 2}}, {"name": "나"}), OK)
	var doc := SaveSystem.read("1")
	assert_eq(int(doc.game.state.x), 2)
	assert_eq(int(doc.version), SaveSystem.VERSION)
	# 본 파일이 깨지면 백업(직전 저장)을 읽는다.
	var f := FileAccess.open(SaveSystem.path_for("1"), FileAccess.WRITE)
	f.store_string("{ 깨진 파일")
	f.close()
	doc = SaveSystem.read("1")
	assert_eq(int(doc.game.state.x), 1, "백업에서 되살린다")
	assert_eq(SaveSystem.latest_slot(), "1")


func test_new_character_plays_intro_and_blocks_input() -> void:
	await _start({"name": "하람", "origin": &"blade", "appearance": {"hair_color": 3}})
	assert_eq(GameState.progress.character_name, "하람")
	assert_eq(GameState.progress.origin, &"blade")
	assert_eq(int(GameState.appearance.hair_color), 3)
	assert_true(game.is_intro_playing(), "도입부가 나온다")
	assert_false(game.player.input_enabled, "도입부 중에는 조작하지 않는다")
	assert_ne(game.save_block_reason(), "", "도입부 중에는 저장하지 않는다")
	game.intro.skip()
	await wait_seconds(IntroSequence.FADE_TIME + 0.3)
	assert_false(game.is_intro_playing())
	assert_true(game.player.input_enabled)


func test_save_and_load_restores_progress_and_place() -> void:
	await _start({"name": "서린", "origin": &"marksman", "appearance": {}})
	game.intro.skip()
	await wait_seconds(IntroSequence.FADE_TIME + 0.3)
	GameState.grant_xp(PlayerProgress.xp_to_next(1) + 7, "시험")
	GameState.progress.allocate(PlayerProgress.Stat.DEX, 2)
	GameState.complete_all_analysis()
	var target := game.field.terrain.point_at(FieldLayout.CAMP + Vector2(5, 5))
	game.player.global_position = target + Vector3.UP * 0.2
	game.player.reset_physics_interpolation()
	game.field.day_night.advance_to(21.5)
	game.player.consumable_counts[&"field_suture"] = 1
	game.player.ammo.counts[&"rifle"] = 42
	await wait_physics_frames(10)
	var camp := game.field.supply_point_by_name("Supply_camp")
	game.rest_at(game.player, camp)
	await wait_frames(2)
	assert_true(SaveSystem.exists(SaveSystem.AUTO), "휴식하면 자동 저장된다")
	game.player.consumable_counts[&"field_suture"] = 1
	game.player.ammo.counts[&"rifle"] = 42
	assert_true(game.save_to("2"), "수동 저장")
	var saved_pos := game.player.global_position
	var doc := SaveSystem.read("2")
	game.queue_free()
	await wait_frames(2)
	GameState.reset_session()
	await _start({}, doc)
	await wait_physics_frames(20)
	assert_eq(GameState.progress.character_name, "서린")
	assert_eq(GameState.progress.level, 2)
	assert_eq(GameState.progress.stat(PlayerProgress.Stat.DEX), PlayerProgress.BASE_STAT + 2 + 2)
	assert_true(GameState.is_skill_unlocked(&"ambush_leap"), "해금한 스킬이 남는다")
	assert_near(game.player.global_position.distance_to(saved_pos), 0.0, 0.6, "저장한 곳에서 다시 시작한다")
	assert_near(game.field.day_night.hour, 21.5, 0.2, "시각도 이어진다")
	assert_eq(int(game.player.consumable_counts[&"field_suture"]), 1)
	assert_eq(game.player.ammo.get_count(&"rifle"), 42)
	assert_eq(String(game.checkpoint_point.name), "Supply_camp", "마지막 거점이 부활 지점이다")
	assert_false(game.is_intro_playing(), "불러오면 도입부가 없다")


func test_cannot_save_in_combat_or_training() -> void:
	await _start()
	game.player.mark_combat()
	assert_eq(game.save_block_reason(), "전투 중에는 저장할 수 없습니다.")
	assert_false(game.save_to("1"))
	game.queue_free()
	await wait_frames(2)
	game = GAME.instantiate()
	game.mode = Game.Mode.TRAINING
	runner.add_child(game)
	await wait_physics_frames(3)
	assert_ne(game.save_block_reason(), "")


func test_pause_menu_shows_save_state() -> void:
	await _start()
	game.open_pause()
	await wait_frames(2)
	assert_true(game.menus.pause_menu._save_button.visible)
	assert_false(game.menus.pause_menu._save_button.disabled)
	game.menus.pause_menu.save_requested.emit()
	await wait_frames(2)
	assert_true(game.menus.save_menu.visible)
	game.menus.save_menu.save_requested.emit("3")
	await wait_frames(1)
	assert_true(SaveSystem.exists("3"))
	game.menus.close_all()


func test_character_creation_builds_config() -> void:
	var cc := CharacterCreation.new()
	runner.add_child(cc)
	await wait_frames(2)
	cc._name_edit.text = "  리온 "
	cc._step("hair_style", HumanoidModel.HAIR_STYLES.size(), 1)
	cc.origin = &"survivor"
	var cfg := cc.config()
	assert_eq(cfg.name, "리온")
	assert_eq(cfg.origin, &"survivor")
	assert_eq(int(cfg.appearance.hair_style), 1)
	cc._name_edit.text = "   "
	cc._refresh()
	assert_true(cc._start_button.disabled, "이름이 없으면 시작할 수 없다")
	cc.queue_free()

extends TestCase
## 게임 루트 흐름: 시험장·플레이어·HUD·메뉴 연결, 사망과 부활, 휴식, 시설 메뉴, 일시정지, 설정.

const GAME := preload("res://src/main/game.tscn")

var game: Game


func before_each() -> void:
	Settings.load_settings("user://test_game_flow.cfg")
	game = GAME.instantiate()
	runner.add_child(game)
	await wait_physics_frames(6)


func after_each() -> void:
	runner.get_tree().paused = false
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_game_flow.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()


func _choice_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for b in game.menus.choice_menu.find_children("*", "Button", true, false):
		out.append(b)
	return out


func _press(text_part: String) -> bool:
	for b in _choice_buttons():
		if b.text.contains(text_part) and not b.disabled:
			b.pressed.emit()
			return true
	return false


func test_game_starts_in_camp() -> void:
	assert_not_null(game.player)
	assert_not_null(game.hud)
	assert_true(game.player.alive)
	assert_gt(game.player.global_position.z, 40.0, "보급 기지에서 시작")
	assert_near(game.player.yaw, 0.0, 0.01, "북쪽(전장)을 바라본다")
	assert_eq(game.player.weapons.primary.id, &"rifle_bfa3")


func test_death_respawns_at_checkpoint_and_resets_engaged() -> void:
	var p := game.player
	var charger_group: EncounterGroup = game.arena.get_node("Encounters/Charger")
	var charger: Enemy = charger_group.members[0]
	var old_id := charger.get_instance_id()
	charger.alert(p)
	game.arena.spawn_test_wave(&"rabbits")
	await wait_physics_frames(2)
	p.global_position = Vector3(0, 0, 10)
	p.stats.take_damage(999.0)
	assert_false(p.alive)
	await wait_seconds(Game.RESPAWN_DELAY + 0.2)
	assert_true(p.alive, "잠시 뒤 부활")
	assert_lt(p.global_position.distance_to(game.checkpoint.origin), 1.0, "마지막 거점에서 부활")
	assert_eq(game.arena.active_test_count(), 0, "부른 적 정리")
	var new_charger: Enemy = charger_group.members[0]
	assert_ne(new_charger.get_instance_id(), old_id, "교전하던 무리는 새로 배치")
	assert_eq(new_charger.state, Enemy.State.IDLE)


func test_rest_is_blocked_in_combat_and_restores_outside() -> void:
	var p := game.player
	var point: SupplyPoint = game.arena.supply_points[0]
	p.mark_combat()
	assert_ne(point.get_block_reason(p), "", "전투 중에는 휴식할 수 없다")
	await wait_seconds(Player.COMBAT_LINGER + 0.2)
	assert_eq(point.get_block_reason(p), "")
	p.stats.take_damage(50.0)
	p.ammo.counts[&"rifle"] = 0
	point.interact(p)
	await wait_physics_frames(2)
	assert_near(p.stats.hp, p.stats.max_hp)
	assert_eq(p.ammo.get_count(&"rifle"), AmmoInventory.TYPES[&"rifle"].start)


func test_player_can_target_supply_point() -> void:
	var p := game.player
	var point: SupplyPoint = game.arena.supply_points[0]
	TestWorld.aim_at(p, point.global_position + Vector3.UP * 1.2)
	await wait_physics_frames(3)
	assert_null(p.interaction_target, "상호작용 거리(3m) 밖에서는 대상이 아니다")
	p.global_position = point.global_position + Vector3(0, 0, 2.2)
	TestWorld.aim_at(p, point.global_position + Vector3.UP * 1.2)
	await wait_physics_frames(3)
	assert_eq(p.interaction_target, point, "가까이에서 시선이 거점을 향하면 상호작용 대상")


func test_weapon_rack_menu_swaps_primary() -> void:
	game._open_weapon_rack(game.player)
	assert_true(game.menus.choice_menu.visible)
	assert_true(runner.get_tree().paused, "메뉴가 열리면 게임이 멈춘다")
	assert_true(_press("벌목꾼"), "산탄총 항목")
	await wait_frames(2)
	assert_false(game.menus.is_open())
	assert_false(runner.get_tree().paused)
	assert_eq(GameState.primary_weapon, &"shotgun_logger")
	assert_eq(game.player.weapons.primary.id, &"shotgun_logger")


func test_rack_marks_equipped_item_disabled() -> void:
	game._open_weapon_rack(game.player)
	var found := false
	for b in _choice_buttons():
		if b.text.contains("BF-A3"):
			found = true
			assert_true(b.disabled, "장착 중인 무기는 고를 수 없다")
	assert_true(found)
	game.menus.close_all()


func test_terminal_spawns_and_clears() -> void:
	game._open_test_terminal(game.player)
	assert_true(_press("살인토끼 무리"))
	await wait_frames(2)
	assert_eq(game.arena.active_test_count(), 4)
	game._open_test_terminal(game.player)
	assert_true(_press("부른 적 모두 정리"))
	await wait_frames(2)
	assert_eq(game.arena.active_test_count(), 0)


func test_terminal_completes_analysis() -> void:
	game._open_test_terminal(game.player)
	assert_true(_press("모든 몬스터 분석 완료"))
	await wait_frames(2)
	for slot in GameState.skill_slots:
		assert_ne(slot, &"", "네 슬롯이 모두 찬다")
	game._open_test_terminal(game.player)
	var disabled := false
	for b in _choice_buttons():
		if b.text.contains("모든 몬스터 분석 완료"):
			disabled = b.disabled
	assert_true(disabled, "이미 끝났으면 누를 수 없다")
	game.menus.close_all()


func test_pause_menu_opens_and_resumes() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	assert_true(game.menus.pause_menu.visible, "Esc로 일시정지")
	assert_true(runner.get_tree().paused)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await wait_frames(1)
	Input.parse_input_event(ev)
	await wait_frames(2)
	Input.parse_input_event(up)
	await wait_frames(1)
	assert_false(game.menus.is_open(), "다시 Esc로 계속하기")
	assert_false(runner.get_tree().paused)


func test_settings_menu_rebinds_key_from_input() -> void:
	game.menus.open_pause()
	game.menus.pause_menu.settings_requested.emit()
	var menu := game.menus.settings_menu
	assert_true(menu.visible)
	menu._start_listening(&"reload")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_T
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	assert_eq(Settings.binding_text(&"reload"), "T")
	assert_eq(menu._listening, &"")
	menu.close()
	assert_true(game.menus.pause_menu.visible, "설정을 닫으면 일시정지 메뉴로 돌아간다")
	game.menus.close_all()


func test_hud_reflects_state() -> void:
	var hud := game.hud
	var p := game.player
	p.stats.take_damage(30.0)
	await wait_frames(2)
	assert_near(hud._hp.value, 0.7, 0.01)
	assert_eq(hud._ammo.text, "30")
	assert_true(hud._skill_slots[1].empty, "빈 스킬 슬롯은 비어 있음으로 표시")
	assert_false(hud._skill_slots[0].empty)
	GameEvents.notify("시험 알림", GameEvents.NoticeKind.INFO)
	await wait_frames(1)
	var found := false
	for l in hud._notices.get_children():
		if l is Label and l.text == "시험 알림":
			found = true
	assert_true(found)


func test_title_screen_loads() -> void:
	var title: Control = load("res://src/ui/menus/title_screen.tscn").instantiate()
	runner.add_child(title)
	await wait_frames(2)
	var buttons := title.find_children("*", "Button", true, false)
	assert_gt(buttons.size(), 3)

extends TestCase
## 퍼시 주민과 시설, 의뢰 흐름, 지도: 주민 배치, 메인·지역·인물 의뢰 진행, 잡화점과 공방, 공명 이동.

const GAME := preload("res://src/main/game.tscn")
const RABBIT := preload("res://src/enemies/killer_rabbit.tscn")

var game: Game


func before_each() -> void:
	Settings.load_settings("user://test_town.cfg")
	game = GAME.instantiate()
	game.mode = Game.Mode.FIELD
	runner.add_child(game)
	await wait_physics_frames(4)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	runner.get_tree().paused = false
	await wait_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_town.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()


func _npc(id: StringName) -> TownNpc:
	return game.field.npcs[id]


## 선택 메뉴에서 글자가 들어간 첫 버튼을 누른다. 눌렀으면 true.
func _press_choice(text_part: String) -> bool:
	for c in game.menus.choice_menu._list.get_children():
		if c is Button and not c.disabled and c.text.contains(text_part) and not c.is_queued_for_deletion():
			c.pressed.emit()
			return true
	return false


func test_npcs_stand_in_town_clear_of_walls() -> void:
	assert_eq(game.field.npcs.size(), TownNpc.NPCS.size(), "주민이 모두 배치된다")
	var space := game.field.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 1.5
	for id: StringName in game.field.npcs:
		var npc := _npc(id)
		var p2 := Vector2(npc.global_position.x, npc.global_position.z)
		assert_lt(p2.distance_to(FieldLayout.TOWN_CENTER), PercyTown.PALISADE_RADIUS - 1.0, "%s는 목책 안에 선다" % id)
		assert_near(npc.global_position.y, FieldLayout.TOWN_HEIGHT, 0.2, "%s는 광장 높이에 선다" % id)
		# 주민 자신의 몸체를 빼고는 벽·소품과 겹치지 않는다.
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis.IDENTITY, npc.global_position + Vector3.UP * 0.95)
		q.collision_mask = CombatLayers.WORLD
		var own: Array[RID] = []
		for body in npc.find_children("*", "StaticBody3D", true, false):
			own.append((body as StaticBody3D).get_rid())
		q.exclude = own
		var hits := space.intersect_shape(q, 4)
		var blockers: Array[String] = []
		for h in hits:
			if h.collider.name != "TerrainBody":
				blockers.append(String(h.collider.name))
		assert_true(blockers.is_empty(), "%s 자리가 막혀 있지 않다: %s" % [id, blockers])


func test_talking_to_npc_opens_dialogue() -> void:
	var p := game.player
	var clerk := _npc(&"clerk")
	var front := clerk.global_transform * Vector3(0, 0, 2.2)
	p.global_position = front + Vector3.UP * 0.1
	p.yaw = atan2(front.x - clerk.global_position.x, front.z - clerk.global_position.z)
	p.pitch = -0.25
	p.reset_physics_interpolation()
	await wait_physics_frames(6)
	assert_eq(p.interaction_target, clerk, "주민을 바라보면 대화 대상이 된다")
	p.try_interact()
	await wait_frames(2)
	assert_true(game.menus.choice_menu.visible, "대화 창이 열린다")
	assert_true(game.menus.choice_menu._title_label.text.contains("카일"))


func test_main_quest_flow_fixes_tower() -> void:
	var q := GameState.quests
	assert_true(q.is_active(&"main_signal"), "필드에 들어오면 메인 의뢰가 시작된다")
	assert_eq(q.tracked, &"main_signal")
	game.field.area_entered.emit(&"percy", "퍼시")
	assert_eq(q.step_of(&"main_signal"), 1, "퍼시에 도착하면 다음 단계")
	game.services.talk(_npc(&"clerk"))
	assert_eq(q.step_of(&"main_signal"), 2, "카일과 이야기하면 재료 단계")
	game.menus.close_all()
	GameState.add_item(&"stone_scale", 2)
	assert_eq(q.count_of(&"main_signal"), 2, "가진 돌비늘을 센다")
	GameState.add_item(&"stone_scale", 2)
	assert_eq(q.step_of(&"main_signal"), 3, "세 개를 모으면 대장장이 단계")
	var silver := GameState.silver
	var xp := GameState.progress.total_xp
	game.services.talk(_npc(&"smith"))
	assert_true(q.is_done(&"main_signal"), "대장장이에게 건네면 완료")
	assert_eq(GameState.item_count(&"stone_scale"), 1, "세 개를 건넨다")
	assert_eq(GameState.silver, silver + 120, "은화 보상")
	assert_gt(GameState.progress.total_xp, xp, "경험치 보상")
	assert_true(game.field.town.tower_fixed, "통신탑이 고쳐진다")


func test_kill_quest_counts_rabbits() -> void:
	var q := GameState.quests
	game.field.area_entered.emit(&"percy", "퍼시")
	game.services.talk(_npc(&"clerk"))
	assert_true(_press_choice("길목의 토끼 소동"), "카일이 토끼 의뢰를 준다")
	assert_true(q.is_active(&"rabbit_trouble"))
	game.menus.close_all()
	var rabbit: Enemy = RABBIT.instantiate()
	for i in 6:
		GameEvents.enemy_killed.emit(rabbit)
	rabbit.free()
	assert_eq(q.step_of(&"rabbit_trouble"), 1, "여섯 마리를 잡으면 보고 단계")
	var silver := GameState.silver
	game.services.talk(_npc(&"clerk"))
	assert_true(q.is_done(&"rabbit_trouble"))
	assert_eq(GameState.silver, silver + 80)


func test_herb_basket_quest() -> void:
	var q := GameState.quests
	var basket: QuestItemSpot = game.field.quest_items[0]
	assert_false(basket.visible, "의뢰를 받기 전에는 바구니가 없다")
	game.services.talk(_npc(&"innkeeper"))
	assert_true(_press_choice("잃어버린 약초 바구니"))
	game.menus.close_all()
	await wait_frames(1)
	assert_true(basket.visible, "의뢰를 받으면 연못가에 바구니가 나타난다")
	var shore := Vector2(basket.global_position.x, basket.global_position.z)
	assert_lt(shore.distance_to(FieldLayout.POND_CENTER), FieldLayout.POND_RADIUS + 12.0, "연못가에 있다")
	assert_gt(basket.global_position.y, FieldLayout.WATER_LEVEL + 0.2, "물 밖 뭍에 있다")
	basket.interact(game.player)
	await wait_frames(1)
	assert_false(basket.visible, "주우면 사라진다")
	assert_eq(q.step_of(&"herb_basket"), 1)
	game.player.consumable_counts[&"field_suture"] = 0
	game.services.talk(_npc(&"innkeeper"))
	assert_true(q.is_done(&"herb_basket"))
	assert_eq(GameState.item_count(&"herb_basket"), 0, "바구니를 돌려준다")
	assert_eq(int(game.player.consumable_counts[&"field_suture"]), 2, "보상으로 봉합제를 받는다")


func test_shop_buy_and_sell() -> void:
	var p := game.player
	GameState.add_silver(100)
	p.consumable_counts[&"field_suture"] = 0
	game.services.open_shop(_npc(&"merchant"))
	assert_true(_press_choice("응급 봉합제") or _press_choice(GameDB.consumable(&"field_suture").display_name))
	assert_eq(GameState.silver, 65, "봉합제 값 35")
	assert_eq(int(p.consumable_counts[&"field_suture"]), 1)
	GameState.add_item(&"rabbit_fur", 3)
	game.services.open_sell(_npc(&"merchant"))
	assert_true(_press_choice(ItemDB.name_of(&"rabbit_fur")))
	assert_eq(GameState.item_count(&"rabbit_fur"), 2, "하나 판다")
	assert_eq(GameState.silver, 65 + ItemDB.value_of(&"rabbit_fur"))
	assert_true(_press_choice("모두 판다"))
	assert_eq(GameState.item_count(&"rabbit_fur"), 0)


func test_workshop_buys_and_upgrades_weapons() -> void:
	GameState.add_silver(1000)
	GameState.add_item(&"stone_scale", 5)
	var owned := GameState.owned_weapons.size()
	game.services.open_buy_weapons(_npc(&"smith"))
	assert_true(_press_choice("벌목꾼"), "산탄총을 산다")
	assert_true(GameState.owns_weapon(&"shotgun_logger"))
	assert_eq(GameState.owned_weapons.size(), owned + 1)
	assert_eq(GameState.silver, 1000 - TownServices.WEAPON_PRICES[&"shotgun_logger"])
	var before := GameState.silver
	assert_true(game.services.apply_upgrade(&"rifle_bfa3"), "재료가 있으면 강화한다")
	assert_eq(GameState.upgrade_level(&"rifle_bfa3"), 1)
	assert_eq(GameState.silver, before - TownServices.UPGRADE_SILVER[0])
	assert_eq(GameState.item_count(&"stone_scale"), 3)
	assert_near(GameState.upgrade_mult(&"rifle_bfa3"), 1.08, 0.001)
	GameState.remove_item(&"stone_scale", 3)
	assert_false(game.services.apply_upgrade(&"rifle_bfa3"), "재료가 없으면 강화하지 못한다")


func test_travel_after_tower_fixed() -> void:
	var inn := game.field.supply_point_by_name("Supply_inn")
	var camp := game.field.supply_point_by_name("Supply_camp")
	assert_true(game.travel_targets(inn).is_empty(), "통신탑을 고치기 전에는 공명 이동이 없다")
	GameState.quests.from_dict({"quests": {"main_signal": {"state": QuestLog.State.DONE, "step": 4, "count": 0}}})
	GameState.discovered_areas.append(&"camp")
	var targets := game.travel_targets(inn)
	assert_true(targets.has(camp), "발견한 거점으로 이동할 수 있다")
	game.travel_to(game.player, camp)
	await wait_physics_frames(3)
	assert_lt(game.player.global_position.distance_to(camp.respawn_transform().origin), 1.5, "거점으로 이동한다")
	assert_true(game.checkpoint_point == camp, "도착한 거점에서 쉰다")


func test_map_reveals_and_opens() -> void:
	await wait_physics_frames(40)
	var start := Vector2(game.player.global_position.x, game.player.global_position.z)
	assert_true(GameState.is_map_revealed(start), "서 있는 곳은 지도에 드러난다")
	assert_false(GameState.is_map_revealed(FieldLayout.CAMP), "가 보지 않은 곳은 가려져 있다")
	var tex := game.field.map_texture()
	assert_eq(tex.get_width(), FieldTerrain.CELLS * 2)
	var ev := InputEventAction.new()
	ev.action = &"map"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(3)
	assert_true(game.menus.status_window.visible, "M으로 지도를 연다")
	assert_eq(game.menus.status_window._tabs.current_tab, StatusWindow.TAB_MAP)
	game.menus.status_window._tabs.current_tab = StatusWindow.TAB_QUESTS
	game.menus.status_window._tabs.current_tab = StatusWindow.TAB_ITEMS
	await wait_frames(2)
	game.menus.close_all()


func test_hud_tracks_main_quest() -> void:
	await wait_frames(3)
	assert_true(game.hud._tracker.visible, "추적 중인 의뢰를 보여 준다")
	assert_true(game.hud._tracker_title.text.contains("구조 신호"))
	var quest_marks := game.hud._compass.markers.filter(func(m: Dictionary) -> bool: return m.kind == &"quest")
	assert_eq(quest_marks.size(), 1, "나침반에 의뢰 방향이 있다")
	var bearing: float = quest_marks[0].bearing
	var to_town := CompassBar.bearing_deg(game.player.global_position, FieldLayout.TOWN_GATE)
	assert_lt(absf(wrapf(bearing - to_town, -180.0, 180.0)), 3.0, "퍼시 정문 쪽을 가리킨다")

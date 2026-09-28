class_name Game
extends Node
## 게임 진행 루트: 시험장·플레이어·HUD·메뉴를 묶고 일시정지, 사망과 부활, 시설 메뉴를 처리한다.

enum Mode { FIELD, TRAINING }

const ARENA_SCENE := preload("res://src/world/combat_arena.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const TITLE_SCENE_PATH := "res://src/ui/menus/title_screen.tscn"
const GAME_SCENE_PATH := "res://src/main/game.tscn"
const RESPAWN_DELAY := 2.5

## 다음에 시작할 공간(타이틀이 장면을 바꾸기 전에 정한다)
static var next_mode: int = Mode.FIELD
## 다음 게임을 새 캐릭터로 시작할 때의 설정(캐릭터 생성 화면이 정한다)
static var next_new_game: Dictionary = {}
## 다음 게임에서 불러올 저장 문서(SaveSystem.read 결과)
static var next_load: Dictionary = {}

## 이 게임의 공간. 트리에 넣기 전에 정하지 않으면 next_mode를 따른다.
var mode: int = -1
## 현재 공간(필드 또는 훈련장)
var world: GameWorld
## 훈련장일 때만 있다.
var arena: CombatArena
## 필드일 때만 있다.
var field: FieldWorld
var player: Player
var hud: Hud
var menus: MenuLayer
## 부활 위치(마지막으로 휴식한 거점)
var checkpoint := Transform3D()
## 부활 위치의 거점(저장용 이름을 얻는다)
var checkpoint_point: SupplyPoint
## 새 캐릭터 설정. 비어 있으면 next_new_game을 따른다.
var new_game_config: Dictionary = {}
## 불러올 저장 문서. 비어 있으면 next_load를 따른다.
var load_doc: Dictionary = {}
var intro: IntroSequence
## 퍼시 주민과 시설(필드일 때만)
var services: TownServices

var _autosave_pending: float = -1.0

var _respawn_timer: float = -1.0
## 사망 순간에 교전 중이던 야외 무리(부활할 때 처음 상태로 되돌린다)
var _engaged_at_death: Array[EncounterGroup] = []


func _ready() -> void:
	if mode < 0:
		mode = next_mode
	if new_game_config.is_empty() and load_doc.is_empty():
		new_game_config = next_new_game
		load_doc = next_load
	next_new_game = {}
	next_load = {}
	if not load_doc.is_empty():
		mode = Mode.FIELD
		GameState.from_dict(load_doc.get("game", {}).get("state", {}))
	elif not new_game_config.is_empty():
		mode = Mode.FIELD
		GameState.start_new_character(new_game_config)
	else:
		GameState.reset_session()
	if mode == Mode.TRAINING:
		arena = ARENA_SCENE.instantiate()
		world = arena
	else:
		field = FieldWorld.new()
		field.name = "Field"
		world = field
	add_child(world)
	player = PLAYER_SCENE.instantiate()
	var start := world.default_respawn()
	player.position = start.origin
	add_child(player)
	player.yaw = start.basis.get_euler().y
	player.reset_physics_interpolation()
	if mode == Mode.TRAINING:
		checkpoint_point = arena.supply_points[0] if not arena.supply_points.is_empty() else null
	else:
		checkpoint_point = field.supply_point_by_name("Supply_drop_site")
	checkpoint = checkpoint_point.respawn_transform() if checkpoint_point else start
	hud = Hud.new()
	add_child(hud)
	hud.bind(player)
	menus = MenuLayer.new()
	add_child(menus)
	menus.status_window.setup(player, field)
	menus.title_requested.connect(_go_to_title)
	menus.save_menu.save_requested.connect(_on_manual_save)
	menus.save_menu.load_requested.connect(_on_load_slot)
	player.died.connect(_on_player_died)
	if field:
		services = TownServices.new(self)
		hud.bind_field(field)
		field.area_entered.connect(func(area_id: StringName, area_name: String) -> void:
			var first := GameState.discover_area(area_id, area_name)
			GameState.quests.notify(&"area", area_id)
			if first:
				request_autosave())
		GameEvents.enemy_killed.connect(_on_enemy_killed)
		GameEvents.consumable_granted.connect(func(consumable_id: StringName, count: int) -> void:
			player.add_consumable(consumable_id, count))
		GameState.quests.completed.connect(_on_quest_completed)
		field.predator_event.ended.connect(func(outcome: int) -> void:
			if outcome == NightPredatorEvent.Outcome.SURVIVED:
				request_autosave())
	world.rest_requested.connect(_on_rest_requested)
	world.rack_requested.connect(_open_weapon_rack)
	world.terminal_requested.connect(_open_test_terminal)
	world.facility_requested.connect(_on_facility_requested)
	_capture_mouse()
	if not load_doc.is_empty():
		_apply_loaded(load_doc.get("game", {}))
		hud.notify("저장한 곳에서 이어서 시작합니다.", GameEvents.NoticeKind.INFO)
		_start_main_quest()
	elif not new_game_config.is_empty():
		_start_intro()
	elif field:
		_start_main_quest()
	if mode == Mode.TRAINING:
		hud.notify("훈련장에 들어왔습니다. %s: 메뉴 · 조작 안내는 메뉴에서 볼 수 있습니다." % "Esc",
			GameEvents.NoticeKind.INFO)


# --- 도입부 ---

func _start_intro() -> void:
	intro = IntroSequence.new()
	intro.lines = IntroSequence.lines_for(GameState.progress.character_name, GameState.progress.origin_name())
	player.input_enabled = false
	intro.finished.connect(func() -> void:
		player.input_enabled = true
		intro = null
		_start_main_quest())
	add_child(intro)


## 메인 의뢰 「구조 신호」를 시작한다(새 게임은 도입부가 끝난 뒤, 불러온 게임은 아직 없을 때).
## 구조 신호를 끝낸 저장이면 다음 메인 의뢰 「늪의 구렁」을 잇는다.
func _start_main_quest() -> void:
	if field == null:
		return
	var q := GameState.quests
	if q.state_of(&"main_signal") == QuestLog.State.INACTIVE:
		q.start(&"main_signal")
	elif q.is_done(&"main_signal") and q.state_of(&"mire_maw_hunt") == QuestLog.State.INACTIVE:
		q.start(&"mire_maw_hunt")


func is_intro_playing() -> bool:
	return intro != null and is_instance_valid(intro)


func _exit_tree() -> void:
	# 슬로 모션 도중 장면을 떠나도 게임 속도가 원래대로 돌아오게 한다.
	TimeFx.reset()


func _capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not menus.is_open() and not is_intro_playing():
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if not menus.is_open() and player.alive and not is_intro_playing():
		for pair in [[&"status_window", StatusWindow.TAB_STATUS], [&"map", StatusWindow.TAB_MAP],
				[&"journal", StatusWindow.TAB_QUESTS]]:
			if event.is_action_pressed(pair[0]):
				get_viewport().set_input_as_handled()
				menus.open_status(pair[1])
				return
	# 창 밖을 눌렀다가 돌아오면 클릭으로 마우스를 다시 잡는다(이 클릭은 사격으로 쓰지 않는다).
	if event is InputEventMouseButton and event.pressed and not menus.is_open() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		get_viewport().set_input_as_handled()
		_capture_mouse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and menus \
			and not menus.is_open() and DisplayServer.get_name() != "headless" and not is_intro_playing():
		open_pause()


func open_pause() -> void:
	var reason := save_block_reason()
	menus.pause_menu.set_save_state(field != null, reason == "", reason)
	menus.open_pause()


func _process(delta: float) -> void:
	world.track_player(player)
	if not get_tree().paused:
		GameState.play_time += delta
	if _autosave_pending >= 0.0:
		_autosave_pending -= delta
		if _autosave_pending < 0.0:
			if save_block_reason() == "":
				save_to(SaveSystem.AUTO)
			else:
				_autosave_pending = 3.0
	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer < 0.0:
			_respawn()


# --- 사망·부활(기획서 §19.1) ---

func _on_player_died() -> void:
	# 적은 플레이어가 쓰러지면 곧 대상을 잃으므로, 교전 무리는 사망 순간에 기억해 둔다.
	_engaged_at_death = world.engaged_encounters()
	_respawn_timer = RESPAWN_DELAY


func _respawn() -> void:
	var reset := 0
	if not _engaged_at_death.is_empty():
		reset = world.reset_engaged_encounters(_engaged_at_death)
	_engaged_at_death.clear()
	var had_tests := world.active_test_count() > 0
	world.clear_test_spawns()
	player.respawn_at(checkpoint)
	if field:
		field.predator_event.on_player_respawned()
	var parts: Array[String] = ["거점에서 다시 시작합니다."]
	if reset > 0:
		parts.append("교전하던 야외 무리가 처음 상태로 돌아갔습니다.")
	if had_tests:
		parts.append("시험 단말기로 부른 적을 정리했습니다.")
	hud.notify(" ".join(parts), GameEvents.NoticeKind.INFO)


# --- 시설 ---

## 거점과 상호작용: 필드에서는 휴식 메뉴(기다리기·공명 이동)를 열고, 훈련장에서는 바로 쉰다.
func _on_rest_requested(p: Player, point: SupplyPoint) -> void:
	if field:
		open_rest_menu(p, point)
	else:
		rest_at(p, point)


func _point_title(point: SupplyPoint) -> String:
	if point.name == "Supply_inn":
		return "여관 「첫 등불」"
	return point.label_text if point.label_text != "" else "보급 거점"


## 휴식 메뉴(기획서 §13.4: 안전 거점에서 기다리기). 여관 주인과 이야기할 때도 연다.
func open_rest_menu(p: Player, point: SupplyPoint) -> void:
	var reason := point.get_block_reason(p)
	if reason != "":
		hud.notify(reason, GameEvents.NoticeKind.WARNING)
		return
	var entries: Array = [{
		"text": "휴식한다",
		"detail": "HP·스태미나 회복, 탄약·소모품 보급. 이 거점이 부활 지점이 되고 자동 저장합니다. 야외 무리가 다시 나타납니다.",
		"action": func() -> void: rest_at(p, point),
	}]
	entries.append({"header": true, "text": "쉬면서 기다리기"})
	for w in TownServices.WAIT_TIMES:
		var hour: float = w[1]
		entries.append({
			"text": "%s까지 기다린다" % w[0],
			"detail": "시간에 따라 나타나는 몬스터와 단서가 다릅니다. 밤에는 숲이 더 위험해집니다.",
			"action": func() -> void: rest_at(p, point, hour),
		})
	var targets := travel_targets(point)
	if not targets.is_empty():
		entries.append({"header": true, "text": "공명 이동 (통신탑 복구)"})
		for sp: SupplyPoint in targets:
			var dest := sp
			entries.append({
				"text": "%s(으)로 이동" % _point_title(dest),
				"detail": "복구한 통신탑의 신호를 타고 발견한 거점으로 이동합니다. 도착한 거점에서 휴식합니다.",
				"action": func() -> void: travel_to(p, dest),
			})
	var clock := field.day_night.clock_text() if field else ""
	menus.open_choice(_point_title(point), "안전한 거점입니다. 지금 시각 %s." % clock, entries)


## 공명 이동으로 갈 수 있는 거점: 통신탑을 고친 뒤, 발견한 지역에 있는 다른 거점
func travel_targets(from: SupplyPoint) -> Array[SupplyPoint]:
	var out: Array[SupplyPoint] = []
	if field == null or not GameState.quests.is_done(&"main_signal"):
		return out
	for sp in field.supply_points:
		if sp == from:
			continue
		var area := field.area_at(Vector2(sp.global_position.x, sp.global_position.z))
		if GameState.discovered_areas.has(area):
			out.append(sp)
	return out


func travel_to(p: Player, point: SupplyPoint) -> void:
	var t := point.respawn_transform()
	p.global_position = t.origin + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO
	p.yaw = t.basis.get_euler().y
	p.reset_physics_interpolation()
	field.track_player(p)
	field.grass.fill_now()
	rest_at(p, point)


## 휴식: 회복·보급, 야외 무리 재배치, 부활 지점 갱신, 자동 저장. wait_hour를 주면 그 시각까지 기다린다.
func rest_at(p: Player, point: SupplyPoint, wait_hour: float = -1.0) -> void:
	p.rest()
	world.reset_all_encounters()
	checkpoint = point.respawn_transform()
	checkpoint_point = point
	var waited := ""
	if field and wait_hour >= 0.0:
		field.day_night.advance_to(wait_hour)
		waited = " %s까지 기다렸습니다." % field.day_night.clock_text()
	if field:
		save_to(SaveSystem.AUTO)
	Sfx.play_ui(&"respawn")
	hud.notify("휴식했습니다.%s HP·스태미나 회복, 탄약·소모품 보급. 이 거점에서 다시 시작하며, 야외 무리가 다시 나타났습니다." % waited,
		GameEvents.NoticeKind.INFO)


func _on_facility_requested(_p: Player, node: Interactable) -> void:
	if node is TownNpc and services:
		services.talk(node)


func _on_enemy_killed(enemy: Node) -> void:
	if enemy is Enemy and (enemy as Enemy).data:
		GameState.quests.notify(&"kill", (enemy as Enemy).data.id)


func _on_quest_completed(quest_id: StringName) -> void:
	if quest_id == &"main_signal" and field:
		field.town.fix_tower()
		GameEvents.announce("통신탑 복구", "공명 이동 해금 · 거점에서 발견한 다른 거점으로 이동할 수 있습니다",
			GameEvents.AnnounceKind.SYSTEM)
		GameState.quests.start(&"mire_maw_hunt")
	request_autosave()


func _open_weapon_rack(_p: Player) -> void:
	var entries: Array = [{"header": true, "text": "주무기"}]
	for w in GameDB.weapons_for_slot(WeaponData.Slot.PRIMARY):
		var equipped := GameState.primary_weapon == w.id
		var id := w.id
		entries.append({
			"text": "%s  ·  %s%s" % [w.display_name, w.class_label(), "  (장착 중)" if equipped else ""],
			"detail": "%s\n제조: %s · 희귀도: %s" % [w.description, w.manufacturer, ItemRarity.tier_name(w.rarity)],
			"enabled": not equipped,
			"action": func() -> void:
				GameState.set_primary_weapon(id)
				player.weapons.select_slot(WeaponManager.Slot.PRIMARY)
				hud.notify("주무기: %s" % GameDB.weapon(id).display_name, GameEvents.NoticeKind.INFO),
		})
	entries.append({"header": true, "text": "근접 무기"})
	for m in GameDB.all_melee():
		var equipped := GameState.melee_weapon == m.id
		var id := m.id
		entries.append({
			"text": "%s%s" % [m.display_name, "  (장착 중)" if equipped else ""],
			"detail": "%s\n제조: %s · 희귀도: %s" % [m.description, m.manufacturer, ItemRarity.tier_name(m.rarity)],
			"enabled": not equipped,
			"action": func() -> void:
				GameState.set_melee_weapon(id)
				hud.notify("근접 무기: %s" % GameDB.melee(id).display_name, GameEvents.NoticeKind.INFO),
		})
	menus.open_choice("무기 거치대", "주무기와 근접 무기를 바꿉니다. 보조 총기(%s)는 고정입니다. 총기별 탄창 상태는 유지됩니다." %
		player.weapons.secondary.display_name, entries)


func _open_test_terminal(_p: Player) -> void:
	var entries: Array = [{"header": true, "text": "중앙 광장에 적 부르기"}]
	for kind in CombatArena.TEST_WAVES:
		var k: StringName = kind
		entries.append({
			"text": CombatArena.TEST_WAVES[k],
			"detail": "중앙 광장(기지 북쪽)에 부릅니다. 생성 직후 잠시 동안은 공격하지 않습니다.",
			"action": func() -> void:
				var n := arena.spawn_test_wave(k)
				hud.notify("중앙 광장에 %d마리를 불렀습니다." % n, GameEvents.NoticeKind.INFO),
		})
	var active := arena.active_test_count()
	entries.append({"header": true, "text": "정리"})
	entries.append({
		"text": "부른 적 모두 정리 (%d마리)" % active,
		"detail": "시험 단말기로 부른 적만 없앱니다." if active > 0 else "지금 부른 적이 없습니다.",
		"enabled": active > 0,
		"action": func() -> void:
			arena.clear_test_spawns()
			hud.notify("부른 적을 정리했습니다.", GameEvents.NoticeKind.INFO),
	})
	entries.append({
		"text": "야외 무리 다시 배치",
		"detail": "풀숲·들판·능선의 무리를 처음 상태로 다시 배치합니다(휴식과 같은 효과, 회복 없음).",
		"action": func() -> void:
			arena.reset_all_encounters()
			hud.notify("야외 무리를 다시 배치했습니다.", GameEvents.NoticeKind.INFO),
	})
	var all_done := true
	for data in GameDB.analyzable_enemies():
		if not GameState.is_skill_unlocked(data.analysis_skill):
			all_done = false
	entries.append({"header": true, "text": "시험 전용"})
	entries.append({
		"text": "모든 몬스터 분석 완료",
		"detail": "모든 스킬이 해금되어 있습니다." if all_done else \
			"시험장 전용 기능입니다. 분석 대상 몬스터의 분석도를 100%로 만들고 스킬을 해금·장착합니다. 정식 게임에는 없습니다.",
		"enabled": not all_done,
		"action": func() -> void: GameState.complete_all_analysis(),
	})
	menus.open_choice("시험 단말기", "전투 시험장 전용 기능입니다.", entries)


func _go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


# --- 저장·불러오기(기획서 §20) ---

## 저장할 수 없으면 이유, 가능하면 빈 문자열
func save_block_reason() -> String:
	if field == null:
		return "훈련장에서는 저장하지 않습니다."
	if not player.alive:
		return "쓰러진 동안에는 저장할 수 없습니다."
	if player.is_in_combat():
		return "전투 중에는 저장할 수 없습니다."
	if is_intro_playing():
		return "도입부가 끝난 뒤 저장할 수 있습니다."
	return ""


## 잠시 뒤 자동 저장한다(전투 중이면 끝날 때까지 미룬다).
func request_autosave() -> void:
	if field != null:
		_autosave_pending = 1.5


func save_summary() -> Dictionary:
	var area: String = FieldWorld.AREAS.get(field.current_area(), "퍼시 외곽권") if field else ""
	return {
		"name": GameState.progress.character_name, "level": GameState.progress.level, "area": area,
		"clock": field.day_night.clock_text() if field else "", "play_time": int(GameState.play_time),
	}


func collect_save() -> Dictionary:
	var p := player
	var cons := {}
	for id in p.consumable_counts:
		cons[String(id)] = int(p.consumable_counts[id])
	var ammo := {}
	for t in p.ammo.counts:
		ammo[String(t)] = int(p.ammo.counts[t])
	var mags := {}
	for d: WeaponData in [p.weapons.primary, p.weapons.secondary]:
		if d:
			mags[String(d.id)] = p.weapons.gun_state_for(d.id).mag
	return {
		"mode": "field",
		"state": GameState.to_dict(),
		"player": {
			"pos": [p.global_position.x, p.global_position.y, p.global_position.z],
			"yaw": p.yaw, "hp": p.stats.hp, "stamina": p.stats.stamina,
			"consumables": cons, "ammo": ammo, "mags": mags,
		},
		"checkpoint": String(checkpoint_point.name) if checkpoint_point else "",
		"time": field.day_night.hour if field else 12.0,
	}


func save_to(slot: String) -> bool:
	_autosave_pending = -1.0
	if save_block_reason() != "":
		return false
	hud.show_saving()
	var err := SaveSystem.write(slot, collect_save(), save_summary())
	hud.show_saved(err == OK)
	return err == OK


func _apply_loaded(game_data: Dictionary) -> void:
	var pd: Dictionary = game_data.get("player", {})
	var pos: Array = pd.get("pos", [])
	if pos.size() == 3:
		player.global_position = Vector3(float(pos[0]), float(pos[1]) + 0.1, float(pos[2]))
	player.yaw = float(pd.get("yaw", player.yaw))
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.stats.hp = clampf(float(pd.get("hp", player.stats.max_hp)), 1.0, player.stats.max_hp)
	player.stats.stamina = clampf(float(pd.get("stamina", player.stats.max_stamina)), 0.0, player.stats.max_stamina)
	var cons: Dictionary = pd.get("consumables", {})
	for id in cons:
		var sid := StringName(id)
		if player.consumable_counts.has(sid):
			player.consumable_counts[sid] = maxi(int(cons[id]), 0)
	var ammo: Dictionary = pd.get("ammo", {})
	for t in ammo:
		var st := StringName(t)
		if AmmoInventory.TYPES.has(st):
			player.ammo.counts[st] = clampi(int(ammo[t]), 0, player.ammo.get_max(st))
	var mags: Dictionary = pd.get("mags", {})
	for id in mags:
		var gs := player.weapons.gun_state_for(StringName(id))
		if gs:
			gs.mag = clampi(int(mags[id]), 0, gs.capacity)
	var sp := field.supply_point_by_name(String(game_data.get("checkpoint", "")))
	if sp:
		checkpoint_point = sp
		checkpoint = sp.respawn_transform()
	field.day_night.advance_to(float(game_data.get("time", 9.0)))
	player.stats.changed.emit()
	player.consumables_changed.emit()
	player.weapons.ammo_changed.emit()


func _on_manual_save(slot: String) -> void:
	if save_to(slot):
		menus.save_menu.show_message("%s에 저장했습니다." % SaveSystem.slot_label(slot))
	else:
		menus.save_menu.show_message(save_block_reason() if save_block_reason() != "" else "저장하지 못했습니다.")


func _on_load_slot(slot: String) -> void:
	var doc := SaveSystem.read(slot)
	if doc.is_empty():
		menus.save_menu.show_message("불러올 수 없는 저장 파일입니다.")
		return
	next_load = doc
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

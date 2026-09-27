class_name Game
extends Node
## 게임 진행 루트: 시험장·플레이어·HUD·메뉴를 묶고 일시정지, 사망과 부활, 시설 메뉴를 처리한다.

enum Mode { FIELD, TRAINING }

const ARENA_SCENE := preload("res://src/world/combat_arena.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const TITLE_SCENE_PATH := "res://src/ui/menus/title_screen.tscn"
const RESPAWN_DELAY := 2.5

## 다음에 시작할 공간(타이틀이 장면을 바꾸기 전에 정한다)
static var next_mode: int = Mode.FIELD

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

var _respawn_timer: float = -1.0
## 사망 순간에 교전 중이던 야외 무리(부활할 때 처음 상태로 되돌린다)
var _engaged_at_death: Array[EncounterGroup] = []


func _ready() -> void:
	if mode < 0:
		mode = next_mode
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
		checkpoint = arena.supply_points[0].respawn_transform() if not arena.supply_points.is_empty() else start
	else:
		var first := field.supply_point_by_name("Supply_drop_site")
		checkpoint = first.respawn_transform() if first else start
	hud = Hud.new()
	add_child(hud)
	hud.bind(player)
	menus = MenuLayer.new()
	add_child(menus)
	menus.status_window.setup(player)
	menus.title_requested.connect(_go_to_title)
	player.died.connect(_on_player_died)
	if field:
		field.area_entered.connect(func(area_id: StringName, area_name: String) -> void:
			GameState.discover_area(area_id, area_name))
	world.rest_requested.connect(_on_rest_requested)
	world.rack_requested.connect(_open_weapon_rack)
	world.terminal_requested.connect(_open_test_terminal)
	_capture_mouse()
	if mode == Mode.TRAINING:
		hud.notify("훈련장에 들어왔습니다. %s: 메뉴 · 조작 안내는 메뉴에서 볼 수 있습니다." % "Esc",
			GameEvents.NoticeKind.INFO)


func _capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not menus.is_open():
		get_viewport().set_input_as_handled()
		menus.open_pause()
		return
	if event.is_action_pressed(&"status_window") and not menus.is_open() and player.alive:
		get_viewport().set_input_as_handled()
		menus.open_status()
		return
	# 창 밖을 눌렀다가 돌아오면 클릭으로 마우스를 다시 잡는다(이 클릭은 사격으로 쓰지 않는다).
	if event is InputEventMouseButton and event.pressed and not menus.is_open() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		get_viewport().set_input_as_handled()
		_capture_mouse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and menus \
			and not menus.is_open() and DisplayServer.get_name() != "headless":
		menus.open_pause()


func _process(delta: float) -> void:
	world.track_player(player)
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
	var parts: Array[String] = ["거점에서 다시 시작합니다."]
	if reset > 0:
		parts.append("교전하던 야외 무리가 처음 상태로 돌아갔습니다.")
	if had_tests:
		parts.append("시험 단말기로 부른 적을 정리했습니다.")
	hud.notify(" ".join(parts), GameEvents.NoticeKind.INFO)


# --- 시설 ---

func _on_rest_requested(p: Player, point: SupplyPoint) -> void:
	p.rest()
	world.reset_all_encounters()
	checkpoint = point.respawn_transform()
	Sfx.play_ui(&"respawn")
	hud.notify("휴식했습니다. HP·스태미나 회복, 탄약·소모품 보급. 이 거점에서 다시 시작하며, 야외 무리가 다시 나타났습니다.",
		GameEvents.NoticeKind.INFO)


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

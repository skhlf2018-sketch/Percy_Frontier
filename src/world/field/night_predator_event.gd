class_name NightPredatorEvent
extends Node3D
## 유니크 사건 「밤의 포식자」(기획서 §15.1~15.2).
## 출현 조건(세 가지 조합): 밤 + 그늘 숲 깊은 곳 + 단서 두 개 이상.
## 조건을 채우면 낮은 확률에 기대지 않고 몇 초의 전조 뒤 반드시 나타난다.
## 전조: 풀벌레 소리가 멎고, 달빛이 사그라들고, 안개가 짙어진다(DayNight.eerie).
## 단서가 모자라면 푸른 눈만 잠깐 보이고 사라진다(존재 단서 「어둠 속의 푸른 눈」).
## 결과: 살아남으면 각인·칭호·경험치와 탐사 기록(최초 생존), 쓰러지면 다음에 다시 도전할 수 있다.

signal state_changed(state: int)
signal ended(outcome: int)

enum State { IDLE, GLIMPSE, OMEN, ENCOUNTER, AFTERMATH }
enum Outcome { SURVIVED, DIED, ESCAPED }

const UNIQUE_ID := &"night_predator"
## 그늘 숲 깊은 곳(출현 조건)
const DEEP_RADIUS := 55.0
## 흘끗 보기 조건(그늘 숲 안)
const GLIMPSE_RADIUS := 95.0
## 전투 중 이보다 멀리 달아나면 포식자가 쫓기를 그만둔다.
const ESCAPE_RADIUS := 150.0
const OMEN_TIME := 6.5
const GLIMPSE_TIME := 7.0
const AFTERMATH_TIME := 5.0
const SPAWN_DISTANCE := 24.0
const FIRST_SURVIVAL_XP := 300

var field: FieldWorld
var player: Player
var state: int = State.IDLE
var predator: NightPredator
var last_outcome: int = -1

var _timer: float = 0.0
var _eerie_target: float = 0.0
## 이번 밤에 이미 만났다(다시 낮이 되어야 다음 사건이 열린다)
var _spent_tonight: bool = false
var _howl_done: bool = false
var _eyes: Node3D
var _eye_materials: Array[StandardMaterial3D] = []


func setup(f: FieldWorld) -> void:
	field = f
	name = "NightPredatorEvent"


func is_active() -> bool:
	return state == State.OMEN or state == State.ENCOUNTER


## 사건이 열릴 조건을 모두 채웠는지(지금 위치 기준)
func conditions_met(at: Vector3) -> bool:
	return field.day_night.is_night() and not _spent_tonight and _deep(at) \
		and GameState.clue_count(UNIQUE_ID) >= int(UniqueDB.UNIQUES[UNIQUE_ID].clues_needed)


func _distance_to_center(at: Vector3) -> float:
	return Vector2(at.x, at.z).distance_to(FieldLayout.SHADE_CENTER)


func _deep(at: Vector3) -> bool:
	return _distance_to_center(at) <= DEEP_RADIUS


func _process(delta: float) -> void:
	if field == null:
		return
	var dn := field.day_night
	dn.eerie = move_toward(dn.eerie, _eerie_target, delta * (0.35 if _eerie_target > dn.eerie else 0.25))
	if player == null or not is_instance_valid(player):
		return
	if not dn.is_night() and state == State.IDLE:
		_spent_tonight = false
	var pos := player.global_position
	match state:
		State.IDLE:
			if not player.alive or not dn.is_night():
				return
			if conditions_met(pos):
				_start_omen()
			elif not _spent_tonight and _distance_to_center(pos) <= GLIMPSE_RADIUS \
					and not GameState.clues.has(&"night_glimpse") and not GameState.unique_record(UNIQUE_ID).sighted \
					and field.layout.shade_factor(Vector2(pos.x, pos.z)) > 0.6:
				_start_glimpse()
		State.GLIMPSE:
			_process_glimpse(delta)
		State.OMEN:
			_process_omen(delta)
		State.ENCOUNTER:
			_process_encounter()
		State.AFTERMATH:
			_timer -= delta
			if _timer <= 0.0:
				_set_state(State.IDLE)


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)


# --- 흘끗 보기(존재 단서) ---

func _start_glimpse() -> void:
	_set_state(State.GLIMPSE)
	_timer = GLIMPSE_TIME
	_eerie_target = 0.55
	_howl_done = false


func _process_glimpse(delta: float) -> void:
	_timer -= delta
	var t := GLIMPSE_TIME - _timer
	if t >= 2.0 and _eyes == null:
		_spawn_eyes()
	if _eyes:
		var a := clampf(minf(t - 2.0, _timer - 1.0), 0.0, 1.0)
		for m in _eye_materials:
			m.emission_energy_multiplier = 8.0 * a
		_eyes.visible = a > 0.02
	if t >= 3.0 and not _howl_done:
		_howl_done = true
		if _eyes:
			Sfx.play_at(&"predator_growl", _eyes.global_position, 2.0)
	if _timer <= 0.0:
		if _eyes:
			_eyes.queue_free()
			_eyes = null
			_eye_materials.clear()
		_eerie_target = 0.0
		GameState.add_clue(&"night_glimpse")
		_set_state(State.IDLE)


## 바라보는 방향 30~40m 앞 나무 사이에 푸른 눈 두 개
func _spawn_eyes() -> void:
	var look := -Basis(Vector3.UP, player.yaw).z
	var eye_pos := player.get_eye_position()
	var space := get_world_3d().direct_space_state
	var p := Vector3.ZERO
	# 나무 사이로 보이는 자리를 고른다(가려지면 다른 자리).
	for i in 10:
		var yaw := atan2(look.x, look.z) + randf_range(-0.45, 0.45)
		var d := randf_range(20.0, 30.0) * (1.0 - i * 0.05)
		p = player.global_position + Vector3(sin(yaw), 0.0, cos(yaw)) * d
		p.y = field.terrain.height_at(p.x, p.z) + 1.9
		var q := PhysicsRayQueryParameters3D.create(eye_pos, p, CombatLayers.WORLD)
		if space.intersect_ray(q).is_empty():
			break
	_eyes = Node3D.new()
	_eyes.name = "GlimpseEyes"
	add_child(_eyes)
	_eyes.global_position = p
	_eyes.look_at(player.get_eye_position(), Vector3.UP, true)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.18
		eye.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.3, 0.4)
		m.emission_enabled = true
		m.emission = NightPredator.EYE_COLOR
		m.emission_energy_multiplier = 0.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye.material_override = m
		eye.position = Vector3(side * 0.2, 0.0, 0.0)
		_eyes.add_child(eye)
		_eye_materials.append(m)
	var glow := OmniLight3D.new()
	glow.light_color = NightPredator.EYE_COLOR
	glow.light_energy = 1.2
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0, 0.4)
	_eyes.add_child(glow)


# --- 전조와 출현 ---

func _start_omen() -> void:
	_set_state(State.OMEN)
	_timer = OMEN_TIME
	_eerie_target = 1.0
	_howl_done = false
	var rec := GameState.unique_record(UNIQUE_ID)
	var who := UniqueDB.unique_name(UNIQUE_ID, rec.survived)
	GameEvents.announce("공명 장치 경고 · 미확인 반응", "주변 생체 반응이 한꺼번에 사라졌다 — %s이(가) 다가온다" % who,
		GameEvents.AnnounceKind.UNIQUE)


func _process_omen(delta: float) -> void:
	_timer -= delta
	if not player.alive or _distance_to_center(player.global_position) > DEEP_RADIUS + 30.0:
		# 전조 도중 숲을 벗어나면 일어나지 않는다(다음에 다시 온다).
		_eerie_target = 0.0
		_set_state(State.IDLE)
		return
	if _timer <= OMEN_TIME * 0.5 and not _howl_done:
		_howl_done = true
		var look := -Basis(Vector3.UP, player.yaw).z
		Sfx.play_at(&"predator_howl", player.global_position - look * 35.0 + Vector3.UP * 3.0, 6.0)
	if _timer <= 0.0:
		_spawn_predator()


func _spawn_predator() -> void:
	predator = NightPredator.new()
	predator.revealed = GameState.unique_record(UNIQUE_ID).survived
	add_child(predator)
	predator.global_position = predator.reappear_point(player)
	predator.reset_physics_interpolation()
	var to := player.global_position - predator.global_position
	predator.rotation.y = atan2(-to.x, -to.z)
	predator.home_position = predator.global_position
	predator.retreated.connect(_on_retreated)
	predator.begin_hunt(player)
	_set_state(State.ENCOUNTER)
	GameState.record_unique(UNIQUE_ID, "encounters")
	if GameState.record_unique(UNIQUE_ID, "sighted"):
		GameEvents.announce("탐사 기록 · 최초 발견", "미확인 유니크 개체와 조우 — 살아남아라", GameEvents.AnnounceKind.UNIQUE)


# --- 전투 ---

func _process_encounter() -> void:
	if predator == null or not is_instance_valid(predator):
		_finish(Outcome.ESCAPED)
		return
	if not player.alive:
		predator.retreat(NightPredator.RetreatReason.PLAYER_DOWN)
		return
	if not field.day_night.is_night():
		predator.retreat(NightPredator.RetreatReason.DAWN)
	elif _distance_to_center(player.global_position) > ESCAPE_RADIUS:
		predator.retreat(NightPredator.RetreatReason.LEFT_AREA)


func _on_retreated(reason: int) -> void:
	match reason:
		NightPredator.RetreatReason.PLAYER_DOWN:
			_finish(Outcome.DIED)
		NightPredator.RetreatReason.LEFT_AREA:
			_finish(Outcome.ESCAPED)
		_:
			_finish(Outcome.SURVIVED)


func _finish(outcome: int) -> void:
	last_outcome = outcome
	if predator and is_instance_valid(predator):
		predator.queue_free()
	predator = null
	_eerie_target = 0.0
	_timer = AFTERMATH_TIME
	_set_state(State.AFTERMATH)
	match outcome:
		Outcome.SURVIVED:
			_spent_tonight = true
			_grant_survival()
		Outcome.ESCAPED:
			_spent_tonight = true
			GameEvents.announce("공명 장치 · 반응 소실", "포식자가 어둠 속으로 물러났다. 달아난 사냥감은 쫓지 않는 모양이다.",
				GameEvents.AnnounceKind.UNIQUE)
		Outcome.DIED:
			GameEvents.notify("그것은 쓰러진 사냥감에게 흥미를 잃고 사라졌다. 밤이 끝나기 전에 다시 찾아갈 수 있다.",
				GameEvents.NoticeKind.WARNING)
	ended.emit(outcome)


func _grant_survival() -> void:
	var first := GameState.record_unique(UNIQUE_ID, "survived")
	GameState.quests.notify(&"unique", UNIQUE_ID)
	if not first:
		GameEvents.announce("유니크 시나리오 · 밤을 넘겼다", "밤의 포식자가 다시 물러났다", GameEvents.AnnounceKind.UNIQUE)
		return
	GameState.grant_mark(&"predator_mark")
	GameState.grant_title(&"night_survivor")
	GameEvents.announce("유니크 시나리오 달성 · 밤을 넘긴 자",
		"%s을(를) 새겼다 — 탐사 기록: 최초 생존 · 칭호 「%s」" % [UniqueDB.mark_name(&"predator_mark"), UniqueDB.title_name(&"night_survivor")],
		GameEvents.AnnounceKind.UNIQUE)
	for e in UniqueDB.MARKS[&"predator_mark"].effects:
		GameEvents.notify("각인 효과: " + String(e), GameEvents.NoticeKind.UNLOCK)
	GameState.grant_xp(FIRST_SURVIVAL_XP, "유니크 생존")


## 사망해 부활하면 사건을 정리한다(Game이 부른다).
func on_player_respawned() -> void:
	if state == State.OMEN or state == State.GLIMPSE:
		_eerie_target = 0.0
		_set_state(State.IDLE)

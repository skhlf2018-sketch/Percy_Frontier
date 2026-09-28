class_name Enemy
extends CharacterBody3D
## 적 공통 동작(기획서 §8.7, §14.4, §14.5).
## - 시각과 청각을 구분해 감지한다. 소리는 위치만 알려 주며, 무리형만 경고 울음으로 위치를 공유한다.
## - 공격은 전조(windup) → 판정(active) → 회복(recovery). 전조는 모양·색·소리로 패링 가능 여부를 알린다.
## - 생성 직후와 벽 너머에서는 공격하지 않는다.
## - 경직 저항이 있어 무한 경직이 불가능하다.
## - 거점에서 너무 멀어지면 순간이동하지 않고 걸어서 돌아간다.
## 종별 행동은 하위 클래스가 가상 함수를 덮어써서 정한다.

signal died(enemy: Enemy)
signal state_changed(state: int)

enum State { IDLE, INVESTIGATE, ALERT, CHASE, ATTACK, STAGGER, STUNNED, RETURN, FLEE, DEAD }
enum AttackPhase { NONE, WINDUP, ACTIVE, RECOVERY }

const GRAVITY := 20.0
const SPAWN_GRACE := 1.5
const PERCEPTION_INTERVAL := 0.15
const LOSE_TARGET_TIME := 4.0
const INVESTIGATE_WAIT := 3.0
const ALERT_DELAY := 0.4
const PACK_CALL_DELAY := 0.35
const STAGGER_RESIST_GROWTH := 1.5
const STAGGER_RESIST_MAX := 4.0
const STAGGER_RESIST_RESET := 8.0
const POISE_REGEN_DELAY := 2.0
const RETURN_HEAL_PER_SEC := 0.3
const NAV_REPATH_INTERVAL := 0.2
const CORPSE_TIME := 3.0
const OBSERVE_RANGE := 35.0
## 밤의 포식자의 각인: 약한 야생 몬스터가 이 거리 안에서 달아난다.
const MARK_FLEE_DISTANCE := 14.0
## 각인: 강한 몬스터의 감지 거리 배율
const MARK_SIGHT_MULT := 1.3

const TELEGRAPH_PARRY_COLOR := Color(1.0, 0.82, 0.2)
const TELEGRAPH_HEAVY_COLOR := Color(1.0, 0.18, 0.12)

@export var data: EnemyData
## 매복: 플레이어가 가까이 오거나 소리가 나기 전까지 숨어 있다.
@export var ambush: bool = false
## 눈 높이(시야 판정 기준)
@export var eye_height: float = 1.0
## 날아다니는 적(중력 대신 땅 위 높이를 유지한다)
var flying: bool = false
var fly_height: float = 2.6
var _ground_y: float = 0.0
var _ground_timer: float = 0.0

var hp: float = 0.0
var state: int = State.IDLE
var status := StatusEffects.new()
var target: Player = null
var home_position := Vector3.ZERO
var home_yaw: float = 0.0
var last_known_position := Vector3.ZERO
## 0..1. 1이 되면 플레이어를 발견한다.
var awareness: float = 0.0
var poise: float = 0.0
## 생성한 야외 무리(EncounterGroup). 없을 수 있다.
var encounter: Node = null

var _state_time: float = 0.0
var _perception_timer: float = 0.0
var _lost_sight_time: float = 0.0
var _spawn_grace: float = SPAWN_GRACE
var _stagger_mult: float = 1.0
var _stagger_mult_timer: float = 0.0
var _poise_regen_delay: float = 0.0
var _state_timer: float = 0.0
var _investigate_point := Vector3.ZERO
var _cooldowns: Dictionary = {}
var _attack: EnemyAttackData = null
var _attack_phase: int = AttackPhase.NONE
var _attack_timer: float = 0.0
var _attack_hit_done: bool = false
var _attack_dir := Vector3.FORWARD
var _nav: NavigationAgent3D
var _repath_timer: float = 0.0
var _hurtboxes: Array[Hurtbox] = []
var _visual: Node3D
var _geometry: Array[GeometryInstance3D] = []
var _hit_flash: float = 0.0
var _last_damaged_time: float = -100.0
var _clock: float = 0.0
var _observed: bool = false
var _pack_call_pending: float = -1.0
var _knockback := Vector3.ZERO
var _corpse_timer: float = 0.0
var _last_hit_zone: int = Hurtbox.Zone.NORMAL
var _sees_target: bool = false
## 각인 때문에 달아나는 중(공격받으면 맞서 싸운다)
var _mark_fleeing: bool = false
## 절차적 모델과 동작(EnemyBody가 갖춘다). 예전 장면 모델이면 null.
var _rig: CreatureRig = null
var _anim: CreatureAnimator = null
var _fur: MeshInstance3D = null
var _prev_yaw: float = 0.0
## 총격 전조: 조준점과 붉은 조준선
var _aim_point := Vector3.ZERO
var _aim_locked: bool = false
var _laser: MeshInstance3D = null
var _path_ok: bool = false
## 동작 LOD: 멀거나 화면 밖이면 몇 프레임에 한 번만 뼈를 움직인다.
var _anim_skip: int = 0
var _anim_accum: float = 0.0
var _on_screen: bool = true

static var _overlay_cache: Dictionary = {}


func _ready() -> void:
	add_to_group(Hearing.ENEMY_GROUP)
	collision_layer = CombatLayers.ENEMY
	collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY
	hp = data.max_hp
	poise = data.poise
	status.resistance = data.status_resistance()
	status.boss_rules = data.boss_status_rules
	home_position = global_position
	home_yaw = global_rotation.y
	_prev_yaw = global_rotation.y
	_perception_timer = randf() * PERCEPTION_INTERVAL
	if data.model_id != &"" and _rig == null:
		EnemyBody.build(self)
	_visual = get_node_or_null(^"Visual")
	if _visual:
		_collect_geometry(_visual)
	for hb in find_children("*", "Hurtbox", true, false):
		_hurtboxes.append(hb)
		hb.armor_broken.connect(_on_hurtbox_armor_broken)
	_nav = NavigationAgent3D.new()
	_nav.path_desired_distance = 0.7
	_nav.target_desired_distance = 0.9
	_nav.avoidance_enabled = false
	add_child(_nav)
	_on_ready()


func _collect_geometry(node: Node) -> void:
	for child in node.get_children():
		if _rig and child == _rig.fur:
			# 털 껍질은 덧칠 재질 대신 개체별 셰이더 값으로 물든다.
			_fur = child
		elif child is GeometryInstance3D:
			_geometry.append(child)
		_collect_geometry(child)


## EnemyBody가 모델과 동작기를 넘겨준다.
func set_body(rig: CreatureRig, anim: CreatureAnimator) -> void:
	_rig = rig
	_anim = anim


func rig() -> CreatureRig:
	return _rig


func animator() -> CreatureAnimator:
	return _anim


## 하위 클래스 초기화 지점
func _on_ready() -> void:
	pass


# --- 공개 조회 ---

func is_alive() -> bool:
	return state != State.DEAD


func is_engaged() -> bool:
	return state in [State.ALERT, State.CHASE, State.ATTACK, State.STAGGER, State.STUNNED]


## 머리 위에 표시할 이름(레벨과 위협 등급 포함). 유니크처럼 정체를 숨기는 적은 덮어쓴다.
func display_label() -> String:
	var label := "%s  Lv %d" % [data.display_name, data.level]
	if data.threat_tier != EnemyData.ThreatTier.NORMAL:
		label += " · " + data.tier_label()
	return label


func health_ratio() -> float:
	return clampf(hp / data.max_hp, 0.0, 1.0)


func recently_damaged(window: float = 4.0) -> bool:
	return _clock - _last_damaged_time < window


## HUD 표시 위치(머리 위)
func marker_position() -> Vector3:
	return global_position + Vector3.UP * (eye_height + 0.55)


## 머리 위 체력바를 보일지(보스는 화면 아래 보스 체력바를 쓴다)
func shows_overhead_health() -> bool:
	return true


## 공격 전조 정보. 전조 중이 아니면 빈 사전.
func telegraph_info() -> Dictionary:
	if _attack == null or _attack_phase != AttackPhase.WINDUP:
		return {}
	var total := _attack.windup * _telegraph_mult()
	return {
		"parryable": _attack.parryable,
		"progress": clampf(1.0 - _attack_timer / maxf(total, 0.01), 0.0, 1.0),
		"name": _attack.display_name,
	}


func _telegraph_mult() -> float:
	return float(Settings.difficulty_params().telegraph_mult)


# --- 물리 프레임 ---

func _physics_process(delta: float) -> void:
	_clock += delta
	if state == State.DEAD:
		_process_dead(delta)
		return
	_state_time += delta
	_spawn_grace = maxf(0.0, _spawn_grace - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	_tick_poise(delta)
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	var dot := status.tick(delta, moving)
	if dot > 0.0:
		_apply_damage(dot, null, Hurtbox.Zone.NORMAL)
		if state == State.DEAD:
			return
	if _pack_call_pending >= 0.0:
		_pack_call_pending -= delta
		if _pack_call_pending < 0.0:
			_call_pack()
	_perception_timer -= delta
	if _perception_timer <= 0.0:
		_perception_timer = PERCEPTION_INTERVAL
		_perceive()
	if status.is_frozen():
		if _attack:
			_end_attack(false)
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		_process_state(delta)
	if flying:
		_fly(delta)
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	if _knockback.length_squared() > 0.01:
		velocity += _knockback
		_knockback = _knockback.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	move_and_slide()
	_check_charge_crash()
	_after_move(delta)
	_update_overlay()
	_update_laser()


func _after_move(_delta: float) -> void:
	pass


## 나는 적: 땅 위 목표 높이로 오르내린다.
func _fly(delta: float) -> void:
	_ground_timer -= delta
	if _ground_timer <= 0.0:
		_ground_timer = 0.25
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 30.0,
			CombatLayers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		_ground_y = hit.position.y if not hit.is_empty() else global_position.y - fly_height
	var want := _fly_target_y()
	velocity.y = clampf((want - global_position.y) * 3.0, -7.0, 7.0)


func _fly_target_y() -> float:
	return _ground_y + fly_height


## EnemyBody가 모델을 입힌 뒤 부른다(종별 부품: 장갑판, 포자 주머니 등).
func _on_body_built(_rig_node: CreatureRig) -> void:
	pass


## 돌진(벽 충돌 기절이 있는 공격) 중 벽에 부딪히면 스스로 기절한다.
func _check_charge_crash() -> void:
	if state != State.ATTACK or _attack == null or _attack.kind != EnemyAttackData.Kind.CHARGE:
		return
	if _attack_phase != AttackPhase.ACTIVE or _attack.wall_stun <= 0.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Enemy or other is Player:
			continue
		if col.get_normal().dot(_attack_dir) < -0.6 and _attack.move_speed >= 6.0:
			_crash(_attack.wall_stun)
			return


func _crash(stun_time: float) -> void:
	Sfx.play_at(&"wall_crash", global_position + Vector3.UP * eye_height)
	CombatFx.impact(self, global_position - global_basis.z * 0.6 + Vector3.UP * eye_height * 0.7, Color(0.85, 0.8, 0.7), 0.4, 0.3)
	var p := _find_player()
	if p and p.global_position.distance_to(global_position) < 12.0:
		p.camera_rig.add_trauma(clampf(data.mass_kg / 1000.0, 0.08, 0.35))
	Hearing.emit(get_tree(), global_position, 16.0, self, Hearing.Kind.IMPACT)
	_end_attack(true)
	if stun_time > 0.0:
		_state_timer = stun_time
		_set_state(State.STUNNED)


func _process(delta: float) -> void:
	if _anim == null or state == State.DEAD:
		return
	# 멀거나 화면 밖이면 뼈 갱신을 줄인다(쌓인 시간만큼 한 번에 움직인다).
	_anim_accum += delta
	_anim_skip -= 1
	if _anim_skip > 0:
		return
	var cam := get_viewport().get_camera_3d()
	var dist := cam.global_position.distance_to(global_position) if cam else 0.0
	var every := 1
	if not _on_screen:
		every = 8
	elif dist > 70.0:
		every = 4
	elif dist > 35.0:
		every = 2
	_anim_skip = every
	_animate(_anim_accum)
	_anim_accum = 0.0


## 절차적 동작: 이동 속도, 대상을 향한 고개, 행동 자세를 넘긴다.
func _animate(delta: float) -> void:
	var hv := Vector2(velocity.x, velocity.z)
	_anim.speed = hv.length() * (1.0 if not status.is_frozen() else 0.0)
	var yaw := global_rotation.y
	_anim.turn_rate = angle_difference(_prev_yaw, yaw) / maxf(delta, 0.001)
	_prev_yaw = yaw
	var look_yaw := 0.0
	var look_pitch := 0.0
	if target and is_instance_valid(target) and state != State.RETURN:
		var local := to_local(target.get_eye_position())
		look_yaw = clampf(atan2(-local.x, -local.z), -1.1, 1.1)
		look_pitch = clampf(atan2(local.y - eye_height, Vector2(local.x, local.z).length()), -0.6, 0.6)
	_anim.look_yaw = lerp_angle(_anim.look_yaw, look_yaw, 1.0 - exp(-6.0 * delta))
	_anim.look_pitch = lerpf(_anim.look_pitch, look_pitch, 1.0 - exp(-6.0 * delta))
	_anim.action = _anim_action()
	_anim.action_weight = 1.0
	_anim.update(delta)


## 지금 상태에 맞는 동작 자세. 종별 스크립트가 덮어쓴다.
func _anim_action() -> StringName:
	match state:
		State.STAGGER:
			return &"stagger"
		State.STUNNED:
			return &"stun"
		State.ATTACK:
			if _attack == null:
				return &""
			match _attack_phase:
				AttackPhase.WINDUP:
					match _attack.kind:
						EnemyAttackData.Kind.PROJECTILE:
							return &"throw_windup"
						EnemyAttackData.Kind.SHOT:
							return &"aim"
						EnemyAttackData.Kind.SPECIAL:
							return &"cast"
					return &"windup"
				AttackPhase.ACTIVE, AttackPhase.RECOVERY:
					match _attack.kind:
						EnemyAttackData.Kind.LUNGE, EnemyAttackData.Kind.CHARGE:
							return &"lunge"
						EnemyAttackData.Kind.PROJECTILE:
							return &"throw"
						EnemyAttackData.Kind.SHOT:
							return &"aim"
						EnemyAttackData.Kind.SPECIAL:
							return &"cast"
					return &"strike"
	return &""


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	if state == State.ATTACK and new_state != State.ATTACK:
		_release_token()
	state = new_state
	_state_time = 0.0
	state_changed.emit(new_state)


func _process_state(delta: float) -> void:
	match state:
		State.IDLE:
			_process_idle(delta)
		State.INVESTIGATE:
			_process_investigate(delta)
		State.ALERT:
			_stop(delta)
			if target:
				_face_toward(target.global_position, delta)
			if _state_time >= ALERT_DELAY:
				_set_state(State.CHASE)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.STAGGER, State.STUNNED:
			_stop(delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.CHASE if target else State.RETURN)
		State.RETURN:
			_process_return(delta)
		State.FLEE:
			_process_flee(delta)


# --- 상태별 처리(하위 클래스에서 덮어쓸 수 있다) ---

func _process_idle(delta: float) -> void:
	_stop(delta)


func _process_investigate(delta: float) -> void:
	if global_position.distance_to(_investigate_point) > 1.5 and _state_time < 12.0:
		_move_toward(_investigate_point, data.walk_speed, delta)
		return
	_stop(delta)
	_state_timer -= delta
	rotate_y(delta * 0.8)
	if _state_timer <= 0.0:
		_set_state(State.RETURN)


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if _try_start_attack():
		return
	_move_toward(last_known_position, data.run_speed, delta)
	if _sees_target:
		_face_toward(target.global_position, delta)


func _process_return(delta: float) -> void:
	hp = minf(data.max_hp, hp + data.max_hp * RETURN_HEAL_PER_SEC * delta)
	if global_position.distance_to(home_position) > 1.2:
		_move_toward(home_position, data.run_speed * 0.8, delta)
		return
	_stop(delta)
	hp = data.max_hp
	poise = data.poise
	status.clear_all()
	awareness = 0.0
	_set_state(State.IDLE)


func _process_flee(delta: float) -> void:
	if target == null or _state_time > 3.5:
		_mark_fleeing = false
		_set_state(State.RETURN)
		return
	var away := global_position - target.global_position
	away.y = 0.0
	_move_toward(global_position + away.normalized() * 6.0, data.run_speed, delta)


# --- 감지 ---

func _find_player() -> Player:
	if target and is_instance_valid(target):
		return target
	var players := get_tree().get_nodes_in_group(&"player")
	return players[0] if players.size() > 0 else null


func can_see(p: Player) -> bool:
	if p == null or not p.alive or data.sight_range <= 0.0:
		return false
	var eye := global_position + Vector3.UP * eye_height
	var point := p.get_chest_position()
	var to := point - eye
	var dist := to.length()
	var sight := data.sight_range * (0.6 if p.crouching else 1.0) * _mark_sight_mult()
	if dist > sight:
		return false
	if dist > data.proximity_sense:
		var fwd := -global_basis.z
		fwd.y = 0.0
		var flat := Vector3(to.x, 0.0, to.z)
		if fwd.length_squared() > 0.0001 and flat.length_squared() > 0.0001:
			if rad_to_deg(fwd.angle_to(flat)) > data.sight_fov_deg * 0.5:
				return false
	return CombatQuery.has_line_of_sight(get_world_3d(), eye, point)


func _perceive() -> void:
	var p := _find_player()
	if p == null:
		return
	if not p.alive:
		if target:
			_lose_target()
		return
	_sees_target = can_see(p)
	_check_observed(p)
	match state:
		State.IDLE, State.INVESTIGATE, State.RETURN:
			if _sees_target and fears_mark():
				# 밤의 포식자의 각인: 약한 야생 몬스터는 먼저 덤비지 않고 달아난다.
				if global_position.distance_to(p.global_position) < MARK_FLEE_DISTANCE:
					target = p
					_mark_fleeing = true
					_set_state(State.FLEE)
				return
			if _sees_target:
				var dist := global_position.distance_to(p.global_position)
				var rate := lerpf(3.5, 0.7, clampf(dist / maxf(data.sight_range, 1.0), 0.0, 1.0))
				if p.crouching:
					rate *= 0.5
				awareness += rate * PERCEPTION_INTERVAL
				if awareness >= 1.0 or dist <= data.proximity_sense:
					alert(p)
			else:
				awareness = maxf(0.0, awareness - 0.25 * PERCEPTION_INTERVAL)
		State.ALERT, State.CHASE, State.ATTACK, State.STAGGER, State.STUNNED:
			if _sees_target:
				last_known_position = p.global_position
				_lost_sight_time = 0.0
				p.mark_combat()
			else:
				_lost_sight_time += PERCEPTION_INTERVAL
				if _lost_sight_time > LOSE_TARGET_TIME and state == State.CHASE:
					_investigate(last_known_position)
					target = null
			if _beyond_leash(p):
				_lose_target()


## 플레이어의 각인을 두려워하는 약한 야생 몬스터인지(일반·강화 등급, 레벨이 플레이어+3 이하)
func fears_mark() -> bool:
	return GameState.has_mark(&"predator_mark") and data.threat_tier <= EnemyData.ThreatTier.ENHANCED \
		and data.level <= GameState.progress.level + 3


## 각인을 알아보는 강한 몬스터는 더 멀리서 알아챈다.
func _mark_sight_mult() -> float:
	if GameState.has_mark(&"predator_mark") and data.level > GameState.progress.level \
			and data.threat_tier != EnemyData.ThreatTier.UNIQUE:
		return MARK_SIGHT_MULT
	return 1.0


func _beyond_leash(p: Player) -> bool:
	return global_position.distance_to(home_position) > data.leash_radius \
		and p.global_position.distance_to(home_position) > data.leash_radius


## 플레이어가 이 적을 충분히 보았으면 도감에 관찰로 기록한다.
func _check_observed(p: Player) -> void:
	if _observed or not data.in_catalog:
		return
	var eye := p.get_eye_position()
	var center := global_position + Vector3.UP * eye_height * 0.6
	if eye.distance_to(center) > OBSERVE_RANGE:
		return
	var look := -p.look_basis().z
	if look.dot((center - eye).normalized()) < cos(deg_to_rad(35.0)):
		return
	if not CombatQuery.has_line_of_sight(get_world_3d(), eye, center):
		return
	_observed = true
	GameState.bestiary.record(data, Bestiary.Event.OBSERVE)


func hear_noise(position: Vector3, radius: float, _source: Node, kind: int) -> void:
	if state == State.DEAD or data.sight_range <= 0.0:
		return
	var dist := global_position.distance_to(position)
	var reach := radius * data.hearing_mult
	if dist > reach:
		return
	var eye := global_position + Vector3.UP * eye_height
	if dist > reach * 0.5 and not CombatQuery.has_line_of_sight(get_world_3d(), eye, position + Vector3.UP * 0.5):
		return
	match state:
		State.IDLE, State.RETURN, State.INVESTIGATE:
			if kind == Hearing.Kind.GUNSHOT or kind == Hearing.Kind.EXPLOSION:
				awareness = maxf(awareness, 0.5)
			_investigate(position)
		State.CHASE:
			if not _sees_target:
				last_known_position = position


func _investigate(point: Vector3) -> void:
	_investigate_point = point
	_state_timer = INVESTIGATE_WAIT
	_on_disturbed()
	_set_state(State.INVESTIGATE)


## 매복 등에서 깨어날 때(하위 클래스)
func _on_disturbed() -> void:
	pass


## 플레이어를 발견했다. 무리형은 잠시 뒤 경고 울음으로 주변 무리를 부른다.
func alert(p: Player) -> void:
	if state == State.DEAD or p == null:
		return
	var was_engaged := is_engaged()
	target = p
	last_known_position = p.global_position
	awareness = 1.0
	_lost_sight_time = 0.0
	p.mark_combat()
	_on_disturbed()
	if not was_engaged:
		_set_state(State.ALERT)
		if data.pack_alert_radius > 0.0:
			_pack_call_pending = PACK_CALL_DELAY
		_on_alerted()
	if encounter and encounter.has_method("notify_engaged"):
		encounter.notify_engaged()


func _on_alerted() -> void:
	pass


func _call_pack() -> void:
	if target == null or state == State.DEAD:
		return
	Sfx.play_at(&"rabbit_squeal", global_position + Vector3.UP * 0.5)
	for e in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e == self or not (e is Enemy) or not e.is_alive():
			continue
		if e.data.id != data.id:
			continue
		if e.global_position.distance_to(global_position) <= data.pack_alert_radius:
			e.alert(target)


func _lose_target() -> void:
	_release_token()
	if _attack:
		_end_attack(false)
	target = null
	_sees_target = false
	_set_state(State.RETURN)


# --- 이동 ---

func _move_toward(point: Vector3, speed: float, delta: float) -> void:
	var dir := _nav_direction(point, delta)
	var desired := dir * speed * status.move_multiplier()
	desired += _separation() * speed * 0.5
	var accel := 18.0 if is_on_floor() else 4.0
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(desired.x, 0.0, desired.z), accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if dir.length_squared() > 0.001:
		_face_direction(dir, delta)


func _nav_direction(point: Vector3, delta: float) -> Vector3:
	_repath_timer -= delta
	if _repath_timer <= 0.0 or _nav.target_position.distance_to(point) > 2.0:
		_repath_timer = NAV_REPATH_INTERVAL
		_nav.target_position = point
	var next := point
	if NavigationServer3D.map_get_iteration_id(_nav.get_navigation_map()) > 0 and not _nav.is_navigation_finished():
		var candidate := _nav.get_next_path_position()
		# 이 자리의 내비게이션 구역이 아직 지도에 들어오지 않았으면(굽는 중) 길이 엉뚱한 구역에서 시작한다.
		# 그때는 목표로 곧장 간다. 길 전체를 꺼내 보는 일은 길을 새로 찾을 때만 한다.
		if _repath_timer == NAV_REPATH_INTERVAL:
			var path := _nav.get_current_navigation_path()
			_path_ok = not path.is_empty() and Vector2(path[0].x - global_position.x, path[0].z - global_position.z).length() < 3.0
		if _path_ok:
			next = candidate
	var dir := next - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0025:
		dir = point - global_position
		dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.ZERO


## 같은 무리끼리 겹치지 않도록 밀어낸다(야외 무리는 같은 무리 안에서만 본다).
func _separation() -> Vector3:
	var push := Vector3.ZERO
	var others: Array = encounter.members if encounter and "members" in encounter else get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP)
	for e in others:
		if e == self or not is_instance_valid(e) or not (e is Node3D):
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0.0
		var dist := d.length()
		if dist > 0.01 and dist < 1.6:
			push += d / dist * (1.6 - dist) / 1.6
	return push


func _stop(delta: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 30.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z


func _face_direction(dir: Vector3, delta: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	var desired := atan2(-flat.x, -flat.z)
	var max_step := deg_to_rad(data.turn_speed_deg) * delta * status.move_multiplier()
	rotation.y = rotate_toward(rotation.y, desired, max_step)


func _face_toward(point: Vector3, delta: float) -> void:
	_face_direction(point - global_position, delta)


func facing_angle_to(point: Vector3) -> float:
	var fwd := -global_basis.z
	fwd.y = 0.0
	var to := point - global_position
	to.y = 0.0
	if fwd.length_squared() < 0.0001 or to.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(fwd.angle_to(to))


# --- 공격 ---

## 사거리·쿨다운·시야·공격권을 확인해 공격을 시작한다.
func _try_start_attack() -> bool:
	if target == null or _spawn_grace > 0.0 or not _sees_target:
		return false
	var dist := global_position.distance_to(target.global_position)
	var options: Array[EnemyAttackData] = []
	var total := 0.0
	for a in data.attacks:
		if _cooldowns.has(a.id) or dist < a.min_range or dist > a.max_range:
			continue
		if not _attack_allowed(a):
			continue
		options.append(a)
		total += a.weight
	if options.is_empty():
		return false
	var pick := randf() * total
	var chosen: EnemyAttackData = options[0]
	for a in options:
		pick -= a.weight
		if pick <= 0.0:
			chosen = a
			break
	if not target.request_attack_token(self, chosen.token_group):
		return false
	_start_attack(chosen)
	return true


## 하위 클래스가 공격별 추가 조건(정면을 보고 있는지 등)을 건다.
func _attack_allowed(_attack_data: EnemyAttackData) -> bool:
	return true


func _start_attack(a: EnemyAttackData) -> void:
	_attack = a
	_attack_phase = AttackPhase.WINDUP
	_attack_timer = a.windup * _telegraph_mult()
	_attack_hit_done = false
	_attack_dir = _flat_dir_to(target.global_position)
	_aim_locked = false
	_aim_point = target.get_chest_position()
	_set_state(State.ATTACK)
	var sound := &"tele_parry" if a.parryable else &"tele_heavy"
	Sfx.play_at(sound, global_position + Vector3.UP * eye_height, 2.0)
	var bleed := status.on_action()
	if bleed > 0.0:
		_apply_damage(bleed, null, Hurtbox.Zone.NORMAL)
	_on_attack_windup(a)


func _flat_dir_to(point: Vector3) -> Vector3:
	var d := point - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else -global_basis.z


func _on_attack_windup(_a: EnemyAttackData) -> void:
	pass


func _on_attack_active(_a: EnemyAttackData) -> void:
	pass


func _process_attack(delta: float) -> void:
	if _attack == null:
		_set_state(State.CHASE)
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_stop(delta)
			if target:
				# 돌진·뛰어들기 방향은 전조가 끝나는 순간 고정된다.
				if not _aim_locked:
					_attack_dir = _flat_dir_to(target.global_position)
				_face_direction(_attack_dir, delta)
				# 총격: 발사 직전까지 조준을 따라가다 고정한다(고정된 선에서 비키면 피한다).
				if _attack.kind == EnemyAttackData.Kind.SHOT and not _aim_locked:
					_aim_point = target.get_chest_position()
					if _attack_timer <= _attack.aim_lock * _telegraph_mult():
						_aim_locked = true
						_on_aim_locked(_attack)
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_phase = AttackPhase.ACTIVE
				_attack_timer = _attack.active_time
				if _attack.kind != EnemyAttackData.Kind.PROJECTILE and _attack.kind != EnemyAttackData.Kind.SHOT:
					_attack_dir = -global_basis.z
				_attack_dir.y = 0.0
				_attack_dir = _attack_dir.normalized()
				_on_attack_active(_attack)
				match _attack.kind:
					EnemyAttackData.Kind.STRIKE:
						_try_hit_target(_attack)
					EnemyAttackData.Kind.PROJECTILE:
						_fire_projectile(_attack)
					EnemyAttackData.Kind.SHOT:
						_fire_shot(_attack)
		AttackPhase.ACTIVE:
			match _attack.kind:
				EnemyAttackData.Kind.LUNGE, EnemyAttackData.Kind.CHARGE:
					velocity.x = _attack_dir.x * _attack.move_speed * status.move_multiplier()
					velocity.z = _attack_dir.z * _attack.move_speed * status.move_multiplier()
					if not _attack_hit_done:
						_try_hit_target(_attack)
				_:
					_stop(delta)
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_phase = AttackPhase.RECOVERY
				_attack_timer = _attack.recovery
				# 뛰어들기는 착지하며 곧 멈춘다(판정이 끝난 뒤 미끄러져 플레이어를 지나치지 않게).
				if _attack.kind == EnemyAttackData.Kind.LUNGE:
					velocity.x *= 0.25
					velocity.z *= 0.25
		AttackPhase.RECOVERY:
			_stop(delta)
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_end_attack(true)


func _end_attack(completed: bool) -> void:
	if _attack and completed:
		_cooldowns[_attack.id] = _attack.cooldown * float(Settings.difficulty_params().attack_cooldown_mult)
	elif _attack:
		_cooldowns[_attack.id] = _attack.cooldown * 0.5
	_attack = null
	_attack_phase = AttackPhase.NONE
	_aim_locked = false
	_release_token()
	if state == State.ATTACK:
		_set_state(State.CHASE if target else State.RETURN)


func _release_token() -> void:
	if target and is_instance_valid(target):
		target.release_attack_token(self)


## 판정 범위 안에 있고 벽에 가리지 않았으면 플레이어를 맞힌다(기획서 §8.7: 벽 너머 공격 금지).
func _try_hit_target(a: EnemyAttackData) -> bool:
	if target == null or not target.alive or _attack_hit_done:
		return false
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() > a.reach + Player.RADIUS:
		return false
	if to.length_squared() > 0.0001 and rad_to_deg(_attack_dir.angle_to(to)) > a.hit_angle_deg * 0.5:
		return false
	var eye := global_position + Vector3.UP * eye_height
	if not CombatQuery.has_line_of_sight(get_world_3d(), eye, target.get_chest_position()):
		return false
	_attack_hit_done = true
	var info := DamageInfo.create(a.damage, DamageInfo.Kind.ENEMY_MELEE, self)
	info.parryable = a.parryable
	info.status_buildup = a.status_buildup()
	info.knockback = a.knockback
	info.direction = _attack_dir
	info.hit_position = global_position
	target.receive_enemy_attack(info)
	return true


## 곡사 투사체. 비행 시간 동안의 이동을 일부만 예측해 공정하게 피할 수 있게 한다.
func _fire_projectile(a: EnemyAttackData) -> void:
	if target == null:
		return
	var origin := global_position + Vector3.UP * (eye_height + 0.3)
	var aim_point := target.global_position + Vector3.UP * 0.9
	var flight := origin.distance_to(aim_point) / maxf(a.projectile_speed, 1.0)
	aim_point += Vector3(target.velocity.x, 0.0, target.velocity.z) * flight * 0.5
	var vel := ballistic_velocity(origin, aim_point, a.projectile_speed, a.projectile_gravity)
	var color := _projectile_color()
	var p := Projectile.create(color, 0.16 * _projectile_size(), 1.0)
	p.collision_mask = CombatLayers.ENEMY_ATTACK_MASK
	p.collide_with_areas = false
	p.gravity = a.projectile_gravity
	p.life = 5.0
	# 발사한 적이 먼저 죽어도 폭발이 일어나도록 self를 잡지 않는 람다와 약한 참조를 쓴다.
	var attack := a
	var attacker_ref: WeakRef = weakref(self)
	var sound := _projectile_blast_sound()
	p.on_hit = func(hit: Dictionary) -> void: Enemy.projectile_blast(p, attack, hit.position, attacker_ref, color, sound)
	p.on_expire = func() -> void: Enemy.projectile_blast(p, attack, p.global_position, attacker_ref, color, sound)
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	p.launch(parent, origin, vel)


## 투사체 색·크기·터지는 소리(종별로 바꾼다: 진흙 덩이 등)
func _projectile_color() -> Color:
	return Color(1.0, 0.5, 0.15)


func _projectile_size() -> float:
	return 1.0


func _projectile_blast_sound() -> StringName:
	return &"sac_burst"


## 투사체 폭발: 범위 안의 플레이어에게 방어·패링할 수 없는 피해(회피 무적으로 피할 수 있다).
static func projectile_blast(ctx: Node3D, a: EnemyAttackData, position: Vector3, attacker_ref: WeakRef,
		color := Color(1.0, 0.5, 0.15), sound := &"sac_burst") -> void:
	CombatFx.explosion(ctx, position, a.projectile_blast_radius, color)
	Sfx.play_at(sound, position)
	if ctx == null or not ctx.is_inside_tree():
		return
	var players := ctx.get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return
	var p: Player = players[0]
	if not p.alive:
		return
	var center := position + Vector3.UP * 0.3
	if p.get_chest_position().distance_to(center) > a.projectile_blast_radius + 0.4:
		return
	if not CombatQuery.has_line_of_sight(p.get_world_3d(), center, p.get_chest_position()):
		return
	var info := DamageInfo.create(a.damage, DamageInfo.Kind.ENEMY_PROJECTILE, attacker_ref.get_ref())
	info.parryable = false
	info.status_buildup = a.status_buildup()
	info.knockback = a.knockback
	info.direction = (p.global_position - position).normalized()
	info.hit_position = position
	p.receive_area_damage(info)


## 총구 위치(총격·조준선의 시작점). 무기를 든 종은 손의 무기 끝을 쓴다.
func muzzle_position() -> Vector3:
	return global_position + Vector3.UP * eye_height - global_basis.z * 0.35


func _on_aim_locked(_a: EnemyAttackData) -> void:
	Sfx.play_at(&"tele_heavy", muzzle_position(), -4.0, 1.6)


## 총격: 고정된 조준선을 따라 즉시 맞힌다. 선이 플레이어 몸에서 0.5m 안을 지나면 명중.
func _fire_shot(a: EnemyAttackData) -> void:
	var from := muzzle_position()
	var dir := (_aim_point - from)
	dir = dir.normalized() if dir.length_squared() > 0.0001 else -global_basis.z
	var to := from + dir * a.max_range * 1.15
	var q := PhysicsRayQueryParameters3D.create(from, to, CombatLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = to if hit.is_empty() else hit.position
	CombatFx.tracer(self, from, end, Color(1.0, 0.72, 0.4), 0.025, 0.09)
	CombatFx.impact(self, from, Color(1.0, 0.8, 0.5), 0.12, 0.05)
	Sfx.play_at(_shot_sound(), from)
	Hearing.emit(get_tree(), from, 60.0, self, Hearing.Kind.GUNSHOT)
	if target == null or not target.alive:
		return
	var chest := target.get_chest_position()
	var closest := Geometry3D.get_closest_point_to_segment(chest, from, end)
	if closest.distance_to(chest) > 0.5:
		return
	var info := DamageInfo.create(a.damage, DamageInfo.Kind.ENEMY_PROJECTILE, self)
	info.parryable = false
	info.knockback = a.knockback
	info.direction = dir
	info.hit_position = closest
	info.status_buildup = a.status_buildup()
	target.receive_enemy_attack(info)


func _shot_sound() -> StringName:
	return &"shot_rifle"


## 총격 전조의 붉은 조준선(전조 중에만 보인다)
func _update_laser() -> void:
	var show := state == State.ATTACK and _attack != null and _attack.kind == EnemyAttackData.Kind.SHOT \
		and _attack_phase == AttackPhase.WINDUP
	if not show:
		if _laser:
			_laser.visible = false
		return
	if _laser == null:
		_laser = MeshInstance3D.new()
		_laser.name = "AimLaser"
		_laser.top_level = true
		var bm := BoxMesh.new()
		bm.size = Vector3(0.018, 0.018, 1.0)
		_laser.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.12, 0.08, 0.85)
		_laser.material_override = m
		_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_laser)
	var from := muzzle_position()
	var dir := _aim_point - from
	if dir.length_squared() < 0.0001:
		_laser.visible = false
		return
	var length := minf(dir.length() + 1.5, _attack.max_range * 1.15)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * length, CombatLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		length = from.distance_to(hit.position)
	_laser.visible = true
	var mid := from + dir.normalized() * length * 0.5
	_laser.global_transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK), mid)
	_laser.scale = Vector3(1.0 if not _aim_locked else 1.8, 1.0 if not _aim_locked else 1.8, length)


## 목표 지점에 닿는 발사 속도(낮은 궤도). 사거리를 넘으면 45도로 던진다.
static func ballistic_velocity(from: Vector3, to: Vector3, speed: float, gravity: float) -> Vector3:
	var delta := to - from
	var flat := Vector3(delta.x, 0.0, delta.z)
	var d := flat.length()
	if d < 0.01 or gravity <= 0.0:
		return delta.normalized() * speed
	var h := delta.y
	var v2 := speed * speed
	var disc := v2 * v2 - gravity * (gravity * d * d + 2.0 * h * v2)
	var angle := PI / 4.0
	if disc >= 0.0:
		angle = atan((v2 - sqrt(disc)) / (gravity * d))
	var dir := flat / d
	return dir * cos(angle) * speed + Vector3.UP * sin(angle) * speed


## 플레이어가 패링에 성공했다.
func on_parried(_by: Node) -> void:
	if state == State.DEAD:
		return
	if _attack:
		_end_attack(false)
	stagger(data.stagger_duration * 1.3, true)


# --- 피격 ---

## 피해를 받는다. hurtbox가 null이면(범위 공격) 일반 부위로 처리한다.
func receive_hit(info: DamageInfo, hurtbox: Hurtbox) -> HitResult:
	if state == State.DEAD:
		return null
	var result := HitResult.new()
	result.target = self
	result.kind = info.kind
	result.position = info.hit_position
	result.resonance_mult = info.resonance_mult
	var zone: int = Hurtbox.Zone.NORMAL
	var mult := 1.0
	var armor_left := 0.0
	var armor_pass := 0.2
	if hurtbox and not info.ignore_zones:
		zone = hurtbox.effective_zone()
		mult = hurtbox.effective_multiplier()
		armor_pass = hurtbox.armor_pass_through
		if hurtbox.is_armor_intact():
			armor_left = hurtbox.armor_current
	var calc := DamageMath.resolve_zone(info.amount, zone, mult, armor_left, armor_pass,
		info.armor_damage_mult * status.armor_damage_multiplier(), data.defense)
	var damage: float = calc.damage * status.damage_taken_multiplier(info)
	if info.bonus_vs_staggered > 0.0 and state in [State.STAGGER, State.STUNNED]:
		damage *= 1.0 + info.bonus_vs_staggered
	var stagger_amount := info.stagger * (1.5 if zone == Hurtbox.Zone.WEAK_POINT else 1.0)
	if hurtbox and calc.armor_damage > 0.0:
		result.hit_armor = true
		result.armor_damage = calc.armor_damage
		if hurtbox.apply_armor_damage(calc.armor_damage):
			result.armor_broken = true
			stagger_amount += data.poise * 2.0
	result.zone = zone
	result.damage = damage
	_last_hit_zone = zone
	_on_hit_zone(hurtbox, zone, info)
	for t in status.apply_buildup(info.status_buildup):
		result.triggered_statuses.append(t)
		_on_status_triggered(t)
	_last_damaged_time = _clock
	_hit_flash = 0.07
	if info.is_from_player() and info.attacker is Player:
		_on_damaged_by(info.attacker)
	_apply_damage(damage, info, zone)
	if state == State.DEAD:
		result.killed = true
		return result
	result.staggered = _apply_poise(stagger_amount)
	if info.knockback > 0.0 and data.mass_kg < 150.0:
		var push := info.direction
		push.y = 0.0
		_knockback += push.normalized() * info.knockback * clampf(60.0 / data.mass_kg, 0.2, 1.5)
	return result


## 하위 클래스: 특정 부위 명중 반응(포자 주머니 등)
func _on_hit_zone(_hurtbox: Hurtbox, _zone: int, _info: DamageInfo) -> void:
	pass


func _on_damaged_by(p: Player) -> void:
	if state == State.RETURN or state == State.IDLE or state == State.INVESTIGATE \
			or (state == State.FLEE and _mark_fleeing):
		_mark_fleeing = false
		alert(p)
	elif target == null:
		alert(p)
	last_known_position = p.global_position


func _apply_damage(amount: float, info: DamageInfo, zone: int) -> void:
	if amount <= 0.0 or state == State.DEAD:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		_die(info, zone)


func _tick_poise(delta: float) -> void:
	_stagger_mult_timer = maxf(0.0, _stagger_mult_timer - delta)
	if _stagger_mult_timer <= 0.0:
		_stagger_mult = 1.0
	_poise_regen_delay = maxf(0.0, _poise_regen_delay - delta)
	if _poise_regen_delay <= 0.0 and poise < data.poise:
		poise = minf(data.poise, poise + data.poise * 0.5 * delta)


func _apply_poise(amount: float) -> bool:
	if amount <= 0.0 or state in [State.STAGGER, State.STUNNED, State.DEAD]:
		return false
	poise -= amount / _stagger_mult
	_poise_regen_delay = POISE_REGEN_DELAY
	if poise <= 0.0:
		stagger(data.stagger_duration, false)
		return true
	return false


## 경직. 짧은 시간 안에 반복되면 경직 저항이 커진다(기획서 §8.4).
func stagger(duration: float, forced: bool) -> void:
	if state == State.DEAD:
		return
	if _attack:
		_end_attack(false)
	_state_timer = duration
	poise = data.poise
	if not forced:
		_stagger_mult = minf(STAGGER_RESIST_MAX, _stagger_mult * STAGGER_RESIST_GROWTH)
		_stagger_mult_timer = STAGGER_RESIST_RESET
	_set_state(State.STAGGER)


func _on_status_triggered(type: int) -> void:
	var at := global_position + Vector3.UP * eye_height
	match type:
		StatusEffects.Type.BURN:
			Sfx.play_at(&"ignite", at)
		StatusEffects.Type.CHILL:
			Sfx.play_at(&"freeze", at)
			if _attack:
				_end_attack(false)
		StatusEffects.Type.SHOCK:
			Sfx.play_at(&"shock", at)
			_apply_damage(StatusEffects.SHOCK_BURST, null, Hurtbox.Zone.NORMAL)
			if state != State.DEAD:
				if _attack:
					_end_attack(false)
				_state_timer = 0.6
				_set_state(State.STUNNED)
				_chain_shock()
		StatusEffects.Type.BLEED:
			Sfx.play_at(&"bleed", at)


## 감전은 가까운 적에게 옮는다(기획서 §8.6).
func _chain_shock() -> void:
	var count := 0
	for e in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e == self or not (e is Enemy) or not e.is_alive():
			continue
		if e.global_position.distance_to(global_position) > 5.0:
			continue
		e.status.add_buildup(StatusEffects.Type.SHOCK, 50.0)
		CombatFx.tracer(self, global_position + Vector3.UP * eye_height, e.global_position + Vector3.UP * e.eye_height,
			Color(0.5, 0.9, 1.0), 0.03, 0.12)
		count += 1
		if count >= 2:
			break


func _on_hurtbox_armor_broken(hb: Hurtbox) -> void:
	Sfx.play_at(&"armor_break", hb.global_position)
	CombatFx.impact(self, hb.global_position, Color(1.0, 0.9, 0.7), 0.35, 0.3)
	GameState.bestiary.record(data, Bestiary.Event.PART_BREAK)
	_on_armor_broken(hb)


func _on_armor_broken(_hb: Hurtbox) -> void:
	pass


# --- 사망 ---

func _die(info: DamageInfo, zone: int) -> void:
	if state == State.DEAD:
		return
	_release_token()
	_attack = null
	_attack_phase = AttackPhase.NONE
	_set_state(State.DEAD)
	collision_layer = 0
	collision_mask = CombatLayers.WORLD
	velocity = Vector3.ZERO
	for hb in _hurtboxes:
		hb.set_enabled(false)
	status.clear_all()
	_corpse_timer = CORPSE_TIME
	var by_player := info != null and info.is_from_player()
	if by_player or (target != null):
		_reward(info, zone)
	Sfx.play_at(&"kill", global_position + Vector3.UP * eye_height, -2.0)
	died.emit(self)
	GameEvents.enemy_killed.emit(self)
	_on_died()


func _on_died() -> void:
	pass


## 처치 보상: 도감 기록, 처치 공명, 스킬 핵 판정, 탄약·회복품 드롭.
func _reward(info: DamageInfo, zone: int) -> void:
	var p := _find_player()
	var weak_kill := info != null and zone == Hurtbox.Zone.WEAK_POINT \
		and (info.kind == DamageInfo.Kind.GUN or info.kind == DamageInfo.Kind.MELEE)
	GameState.bestiary.record(data, Bestiary.Event.WEAK_POINT_KILL if weak_kill else Bestiary.Event.KILL)
	var progress := GameState.progress
	GameState.bestiary.roll_core_drop(data, progress.core_chance_bonus())
	if p:
		p.stats.add_resonance(data.resonance_on_kill * progress.resonance_gain_mult())
	if data.xp_reward > 0:
		GameState.grant_xp(data.xp_reward, data.display_name)
	var drop_origin := global_position + Vector3.UP * 0.4
	var luck := progress.drop_chance_mult()
	if randf() < data.ammo_drop_chance * luck:
		Pickup.spawn_ammo(self, drop_origin)
	if randf() < data.heal_drop_chance * luck:
		Pickup.spawn_consumable(self, drop_origin + Vector3(0.4, 0.0, 0.0), &"field_suture")
	# 재료와 은화(기획서 §11.1: 일반 몬스터는 탄약·회복 재료·몬스터 재료 중심)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for drop in ItemDB.roll_drops(data.id, luck, rng):
		Pickup.spawn_material(self, drop_origin + Vector3(rng.randf_range(-0.4, 0.4), 0.1, rng.randf_range(-0.4, 0.4)), drop[0], drop[1])
	Pickup.spawn_silver(self, drop_origin + Vector3(-0.3, 0.1, 0.2), ItemDB.roll_silver(data.id, rng))


func _process_dead(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		move_and_slide()
	if _visual:
		_visual.rotation.z = lerpf(_visual.rotation.z, PI * 0.5, 1.0 - exp(-6.0 * delta))
		if _corpse_timer < 1.0:
			_visual.scale = Vector3.ONE * maxf(_corpse_timer, 0.05)
	_corpse_timer -= delta
	if _corpse_timer <= 0.0:
		queue_free()


# --- 시각 피드백 ---

## 전조·피격·상태이상을 표면 위 덧칠 재질로 표시한다.
func _update_overlay() -> void:
	var color := Color(0, 0, 0, 0)
	var info := telegraph_info()
	if not info.is_empty():
		var c: Color = TELEGRAPH_PARRY_COLOR if info.parryable else TELEGRAPH_HEAVY_COLOR
		var pulse := 0.35 + 0.35 * sin(_clock * 30.0)
		color = Color(c, pulse + 0.2)
	elif _hit_flash > 0.0:
		color = Color(1, 1, 1, 0.55)
	elif status.is_frozen():
		color = Color(0.55, 0.85, 1.0, 0.55)
	elif status.is_active(StatusEffects.Type.BURN):
		color = Color(1.0, 0.45, 0.1, 0.25 + 0.15 * sin(_clock * 18.0))
	elif status.is_active(StatusEffects.Type.SHOCK):
		color = Color(0.5, 0.9, 1.0, 0.3 + 0.2 * sin(_clock * 40.0))
	elif status.is_chilled():
		color = Color(0.55, 0.85, 1.0, 0.25)
	var mat: Material = null
	if color.a > 0.01:
		mat = _overlay_material(color)
	for g in _geometry:
		if is_instance_valid(g):
			g.material_overlay = mat
	if _fur and is_instance_valid(_fur):
		_fur.set_instance_shader_parameter(&"overlay_tint", color if color.a > 0.01 else Color(0, 0, 0, 0))


static func _overlay_material(color: Color) -> StandardMaterial3D:
	var key := "%d_%d_%d_%d" % [int(color.r * 20), int(color.g * 20), int(color.b * 20), int(color.a * 20)]
	if _overlay_cache.has(key):
		return _overlay_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_overlay_cache[key] = m
	return m

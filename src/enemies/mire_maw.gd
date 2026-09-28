class_name MireMaw
extends Enemy
## 늪턱 구렁(퍼시 외곽권 보스, 기획서 §16.1 "뱀과 악어의 특징을 가진 하이브리드 포식자").
## 핵심 질문(§16.2): 지형 활용. 뛰어들어 물기와 몸 굴리기 돌진이 돌기둥이나 구렁 벽에 부딪히면 한참 정신을 잃고,
## 그동안 목 아래 붉은 턱살(큰 약점)이 드러난다. 포효할 때, 경직됐을 때, 진흙에서 솟구친 뒤 박혀 있을 때도 드러난다.
## - 1단계: 턱 내리꽂기(정면·패링 가능), 뛰어들어 물기(돌진), 꼬리 휩쓸기(옆이나 뒤에 있을 때만, 머리 쪽으로 붙으면 피한다)
## - 2단계(HP 65% 미만): 포효 뒤 진흙 뱉기(둔화)와 잠수(땅속으로 다가와 발밑에서 솟구친다)가 더해진다.
## - 3단계(HP 30% 미만): 포효 뒤 몸 굴리기 돌진이 더해지고 모든 전조가 짧아진다.
## 총(드러난 턱살과 눈 저격), 근접(기절한 틈의 강공격, 등 골판 부수기), 스킬(냉기 둔화, 감전 기절) 모두 통한다.
## 싸움터 밖으로 나간 상대는 쫓지 않는다. 대신 진흙 속에 숨어 상처를 아물린다(밖에서 쏘기만 하는 공략 방지).

signal phase_changed(phase: int)
signal awakened

const PHASE2_RATIO := 0.65
const PHASE3_RATIO := 0.30
const PHASE3_WINDUP_MULT := 0.85
## 잠수: 땅속 이동 속도, 솟구치기 전 표시 시간, 솟구친 뒤 박혀 있는 시간
const BURROW_SPEED := 9.0
const BURST_TELEGRAPH := 1.0
const BURST_RADIUS := 3.5
const STUCK_TIME := 2.5
## 꼬리 휩쓸기: 앞쪽 이 각도 안(머리 쪽)은 맞지 않는다.
const TAIL_SAFE_FRONT_DEG := 50.0
## 싸움터 밖에 숨어 있는 동안 초당 회복(최대 HP 비율). 상대가 이만큼 밖에 머물러야 숨는다.
const HIDE_REGEN := 0.02
const HIDE_DELAY := 2.5
const MUD_COLOR := Color(0.36, 0.3, 0.2)
const HEAD_CAPSULE_RADIUS := 0.55

var phase: int = 1
## 잠든 채 진흙 속에 잠겨 있다(싸움터가 깨운다).
var dormant: bool = true
## 싸움터: 가운데와 보스가 움직이는 바닥 반경, 상대가 이 안에 있으면 싸운다(fight_radius).
var arena_center := Vector3.ZERO
var arena_radius: float = 17.0
var fight_radius: float = 26.0
## 돌기둥 자리(솟구칠 자리가 기둥과 겹치지 않게 한다)
var obstacles: Array[Vector3] = []
var obstacle_radius: float = 1.6

var _throat: Hurtbox = null
var _pending_roar: bool = false
var _underground: bool = false
var _hiding: bool = false
var _stuck: bool = false
var _burst_point := Vector3.ZERO
var _burst_locked: bool = false
var _burrow_y: float = 0.0
var _burst_ring: MeshInstance3D = null
var _sink: float = 1.0
var _sweep_side: float = 1.0
var _bubbles: CPUParticles3D = null
var _dead_time: float = 0.0
var _crash_told: bool = false
var _arena_set: bool = false
## 상대가 싸움터 밖에 머문 시간(잠깐 벗어난 것으로는 숨지 않는다)
var _outside_time: float = 0.0
## 드러난 턱살의 붉은 빛(약점이 드러났음을 멀리서도 알 수 있게)
var _throat_glow: MeshInstance3D = null
var _glow_mat: StandardMaterial3D = null


func _on_ready() -> void:
	for hb in find_children("ThroatHurtbox", "Hurtbox", true, false):
		_throat = hb
	if not _arena_set:
		arena_center = global_position
	_bubbles = _make_bubbles()
	add_child(_bubbles)
	if dormant:
		_enter_dormant()


## 싸움터를 정한다(MireArena가 부른다).
func set_arena(center: Vector3, floor_radius: float, fight_r: float, pillars: Array[Vector3], pillar_r: float) -> void:
	_arena_set = true
	arena_center = center
	arena_radius = floor_radius
	fight_radius = fight_r
	obstacles = pillars
	obstacle_radius = pillar_r


func _on_body_built(rig_node: CreatureRig) -> void:
	# 몸통 충돌체는 어깨에 있으므로, 앞으로 뻗은 목과 머리에도 충돌체를 붙인다(돌기둥에 머리가 박히도록).
	var cs := CollisionShape3D.new()
	cs.name = "HeadCollision"
	var cap := CapsuleShape3D.new()
	cap.radius = HEAD_CAPSULE_RADIUS
	cap.height = 3.6
	cs.shape = cap
	cs.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.9, -3.0))
	add_child(cs)
	# 드러난 턱살의 맥박치는 붉은 빛
	_throat_glow = MeshInstance3D.new()
	_throat_glow.name = "ThroatGlow"
	var sm := SphereMesh.new()
	sm.radius = 0.46
	sm.height = 0.56
	sm.radial_segments = 16
	sm.rings = 8
	_throat_glow.mesh = sm
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.albedo_color = Color(1.0, 0.25, 0.12, 0.0)
	_glow_mat.no_depth_test = false
	_throat_glow.material_override = _glow_mat
	_throat_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_throat_glow.visible = false
	rig_node.attach_socket(&"throat", _throat_glow)
	var light := OmniLight3D.new()
	light.name = "ThroatLight"
	light.light_color = Color(1.0, 0.3, 0.15)
	light.omni_range = 3.5
	light.light_energy = 1.6
	light.shadow_enabled = false
	_throat_glow.add_child(light)


# --- 공개 조회 ---

func shows_overhead_health() -> bool:
	return false


func marker_position() -> Vector3:
	if _rig:
		return _rig.bone_global_position(&"head") + Vector3.UP * 1.3
	return super.marker_position()


func is_hidden() -> bool:
	return dormant or _underground or _hiding


func throat_exposed() -> bool:
	return _throat != null and _throat.is_enabled()


## 포효는 공격이 아니므로 전조 표시를 하지 않는다.
func telegraph_info() -> Dictionary:
	if _attack and _attack.id == &"roar":
		return {}
	return super.telegraph_info()


## 싸움터가 깨운다: 진흙을 뚫고 솟아올라 포효한다.
func awaken(p: Player) -> void:
	if not dormant or state == State.DEAD:
		return
	dormant = false
	_set_solid(true)
	_splash(global_position, 4.0)
	Sfx.play_at(&"mud_burst", global_position + Vector3.UP, 3.0)
	_pending_roar = true
	awakened.emit()
	if p:
		alert(p)


## 싸움을 처음으로 되돌린다(상대가 싸움터를 떠났거나 쓰러졌을 때, 휴식했을 때).
func reset_fight() -> void:
	if state == State.DEAD:
		return
	if _attack:
		_end_attack(false)
	_cooldowns.clear()
	_hide_burst_ring()
	_underground = false
	_hiding = false
	_stuck = false
	flying = false
	velocity = Vector3.ZERO
	global_position = home_position
	rotation.y = home_yaw
	reset_physics_interpolation()
	hp = data.max_hp
	poise = data.poise
	status.clear_all()
	for hb in _hurtboxes:
		hb.restore_armor()
	target = null
	awareness = 0.0
	_pending_roar = false
	if phase != 1:
		phase = 1
		phase_changed.emit(phase)
	dormant = true
	_enter_dormant()
	_set_state(State.IDLE)


func _enter_dormant() -> void:
	_sink = 1.0
	_set_solid(false)


## 몸이 드러나 있는지: 피격 부위와 충돌을 켜고 끈다(목 아래 턱살은 따로 드러난다).
func _set_solid(on: bool) -> void:
	collision_layer = CombatLayers.ENEMY if on else 0
	collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY if on else CombatLayers.WORLD
	for hb in _hurtboxes:
		if hb == _throat:
			continue
		hb.set_enabled(on)
	if _throat and not on:
		_throat.set_enabled(false)


# --- 감지: 싸움이 시작되면 늪의 울림으로 상대를 늘 안다 ---

func _perceive() -> void:
	if dormant:
		return
	super._perceive()
	var p := _find_player()
	if p and p.alive and target == p:
		last_known_position = p.global_position
		_lost_sight_time = 0.0


func hear_noise(position: Vector3, radius: float, source: Node, kind: int) -> void:
	if dormant:
		return
	super.hear_noise(position, radius, source, kind)


func _lose_target() -> void:
	# 싸움터가 되돌리기 전에는 제자리로 돌아가 회복하지 않는다.
	if _attack:
		_end_attack(false)
	_release_token()
	target = null
	_sees_target = false
	_set_state(State.IDLE)


func _investigate(_point: Vector3) -> void:
	pass


# --- 상태 ---

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		return
	var exposed := not is_hidden() and (state == State.STUNNED or state == State.STAGGER \
		or (state == State.ATTACK and _attack != null and _attack.id == &"roar"))
	if _throat and _throat.is_enabled() != exposed:
		_throat.set_enabled(exposed)
	if _throat_glow:
		_throat_glow.visible = exposed
		if exposed:
			_glow_mat.albedo_color.a = 0.28 + 0.2 * sin(_clock * 9.0)
	if state != State.STUNNED:
		_stuck = false
	if _bubbles:
		_bubbles.emitting = is_hidden() and _sink > 0.6


func _process_idle(delta: float) -> void:
	_stop(delta)


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_stop(delta)
		return
	var outside := _outside_fight(target.global_position)
	_outside_time = _outside_time + delta if outside else 0.0
	if _hiding:
		_stop(delta)
		hp = minf(data.max_hp, hp + data.max_hp * HIDE_REGEN * delta)
		if not outside:
			_emerge_from_hiding()
		return
	if _outside_time > HIDE_DELAY:
		_start_hiding()
		return
	if _pending_roar:
		_pending_roar = false
		_force_attack(&"roar")
		return
	if _try_start_attack():
		return
	var goal := _clamp_to_floor(target.global_position, 2.0)
	var dist := _flat_distance(target.global_position)
	if dist < 3.4:
		_stop(delta)
		_face_toward(target.global_position, delta)
	elif global_position.distance_to(goal) > 1.5:
		_move_toward(goal, data.run_speed if dist > 10.0 else data.walk_speed, delta)
	else:
		_stop(delta)
		_face_toward(target.global_position, delta)


func _start_hiding() -> void:
	_hiding = true
	_set_solid(false)
	Sfx.play_at(&"mud_dive", global_position + Vector3.UP, 1.0)
	_splash(global_position, 3.0)


func _emerge_from_hiding() -> void:
	_hiding = false
	_set_solid(true)
	Sfx.play_at(&"mud_burst", global_position + Vector3.UP, 1.0)
	_splash(global_position, 3.5)


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _outside_fight(point: Vector3) -> bool:
	return Vector2(point.x - arena_center.x, point.z - arena_center.z).length() > fight_radius


## 바닥 안쪽(가장자리에서 margin만큼 들어온 곳)으로 자리를 당긴다.
func _clamp_to_floor(point: Vector3, margin: float) -> Vector3:
	var off := Vector2(point.x - arena_center.x, point.z - arena_center.z)
	var r := maxf(arena_radius - margin, 1.0)
	if off.length() > r:
		off = off.normalized() * r
	return Vector3(arena_center.x + off.x, point.y, arena_center.z + off.y)


# --- 단계 ---

func _apply_damage(amount: float, info: DamageInfo, zone: int) -> void:
	super._apply_damage(amount, info, zone)
	if state == State.DEAD:
		return
	var r := health_ratio()
	var want := 3 if r < PHASE3_RATIO else (2 if r < PHASE2_RATIO else 1)
	if want > phase:
		phase = want
		_pending_roar = true
		phase_changed.emit(phase)


func receive_hit(info: DamageInfo, hurtbox: Hurtbox) -> HitResult:
	# 진흙 속에 있으면 맞지 않는다(범위 피해 포함). 잠든 채 맞으면 깨어난다.
	if is_hidden():
		if dormant and info.is_from_player() and info.attacker is Player:
			awaken(info.attacker)
		return null
	return super.receive_hit(info, hurtbox)


# --- 공격 ---

func _attack_allowed(a: EnemyAttackData) -> bool:
	if target == null:
		return false
	var ang := facing_angle_to(target.global_position)
	match a.id:
		&"roar":
			return false
		&"jaw_snap":
			return ang <= 45.0
		&"lunge_bite":
			return ang <= 30.0
		&"tail_sweep":
			return ang >= 70.0
		&"mud_spit":
			return phase >= 2 and ang <= 60.0
		&"submerge":
			return phase >= 2
		&"death_roll":
			return phase >= 3 and ang <= 30.0
	return true


func _force_attack(id: StringName) -> void:
	for a in data.attacks:
		if a.id == id:
			_start_attack(a)
			return


func _start_attack(a: EnemyAttackData) -> void:
	super._start_attack(a)
	if phase >= 3 and a.id != &"roar":
		_attack_timer *= PHASE3_WINDUP_MULT
	if a.id == &"tail_sweep" and target:
		# 꼬리를 반대쪽으로 감았다가 상대 쪽으로 휘두른다.
		var local := to_local(target.global_position)
		_sweep_side = 1.0 if local.x >= 0.0 else -1.0


func _on_attack_windup(a: EnemyAttackData) -> void:
	var at := global_position + Vector3.UP * eye_height
	match a.id:
		&"lunge_bite", &"death_roll":
			Sfx.play_at(&"charger_roar", at, 2.0, 0.6)
		&"submerge":
			Sfx.play_at(&"mud_dive", at, 2.0)
		&"mud_spit":
			Sfx.play_at(&"spit_charge", at, 2.0, 0.6)
		&"roar":
			Sfx.play_at(&"predator_growl", at, 2.0, 0.7)


func _on_attack_active(a: EnemyAttackData) -> void:
	match a.id:
		&"roar":
			_roar()
		&"submerge":
			_dive()
		&"mud_spit":
			Sfx.play_at(&"mud_spit", global_position + Vector3.UP * eye_height)


func _roar() -> void:
	Sfx.play_at(&"maw_roar", global_position + Vector3.UP * eye_height, 4.0)
	var p := _find_player()
	if p and p.global_position.distance_to(global_position) < 40.0:
		p.camera_rig.add_trauma(0.35)
	Hearing.emit(get_tree(), global_position, 40.0, self, Hearing.Kind.IMPACT)
	match phase:
		2:
			GameEvents.notify("%s이(가) 진흙을 끓어오르게 한다 — 진흙 속으로 숨고, 진흙을 뱉는다" % data.display_name,
				GameEvents.NoticeKind.WARNING)
		3:
			GameEvents.notify("%s이(가) 미쳐 날뛴다 — 몸을 굴리며 돌진한다" % data.display_name, GameEvents.NoticeKind.WARNING)


## 꼬리 휩쓸기: 둘레를 모두 쓸지만 머리 쪽 앞은 비워 둔다(머리 쪽으로 붙으면 피한다). 맞으면 바깥으로 밀려난다.
## 나머지 공격은 기본 판정.
func _try_hit_target(a: EnemyAttackData) -> bool:
	if a.id != &"tail_sweep":
		return super._try_hit_target(a)
	if target == null or not target.alive or _attack_hit_done:
		return false
	if facing_angle_to(target.global_position) < TAIL_SAFE_FRONT_DEG:
		return false
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() > a.reach + Player.RADIUS:
		return false
	if not CombatQuery.has_line_of_sight(get_world_3d(), global_position + Vector3.UP * 0.6, target.get_chest_position()):
		return false
	_attack_hit_done = true
	var info := DamageInfo.create(a.damage, DamageInfo.Kind.ENEMY_MELEE, self)
	info.parryable = a.parryable
	info.status_buildup = a.status_buildup()
	info.knockback = a.knockback
	info.direction = to.normalized() if to.length_squared() > 0.0001 else global_basis.z
	info.hit_position = global_position
	target.receive_enemy_attack(info)
	return true


func _projectile_color() -> Color:
	return MUD_COLOR


func _projectile_size() -> float:
	return 2.2


func _projectile_blast_sound() -> StringName:
	return &"mud_spit"


func _process_attack(delta: float) -> void:
	if _attack and _attack.id == &"submerge" and _attack_phase == AttackPhase.ACTIVE:
		_process_burrow(delta)
		return
	super._process_attack(delta)


# --- 잠수: 땅속으로 다가와 발밑에서 솟구친다 ---

func _dive() -> void:
	_underground = true
	_burst_locked = false
	_burrow_y = global_position.y
	_set_solid(false)
	collision_mask = 0
	flying = true
	_splash(global_position, 3.0)


func _fly_target_y() -> float:
	return _burrow_y if _underground else super._fly_target_y()


func _process_burrow(delta: float) -> void:
	_attack_timer -= delta
	if not _burst_locked and _attack_timer <= BURST_TELEGRAPH:
		_burst_locked = true
		var aim := target.global_position if target and target.alive else global_position
		_burst_point = _safe_burst_point(aim)
		_show_burst_ring(_burst_point)
	var goal := _burst_point if _burst_locked else _clamp_to_floor(target.global_position if target else global_position, 2.5)
	var to := goal - global_position
	to.y = 0.0
	var dist := to.length()
	var speed := BURROW_SPEED
	if _burst_locked:
		speed = maxf(BURROW_SPEED, dist / maxf(_attack_timer, 0.05))
	if dist > 0.05:
		var v := to / dist * minf(speed, dist / maxf(delta, 0.001))
		velocity.x = v.x
		velocity.z = v.z
		_face_direction(to, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if _attack_timer <= 0.0:
		_burst()


## 솟구칠 자리: 싸움터 바닥 안, 돌기둥과 겹치지 않는 곳
func _safe_burst_point(aim: Vector3) -> Vector3:
	var p := _clamp_to_floor(aim, 2.5)
	for o in obstacles:
		var d := Vector2(p.x - o.x, p.z - o.z)
		var min_d := obstacle_radius + 2.2
		if d.length() < min_d:
			var n := d.normalized() if d.length_squared() > 0.0001 else Vector2(1, 0)
			p = Vector3(o.x + n.x * min_d, p.y, o.z + n.y * min_d)
	return p


func _burst() -> void:
	var a := _attack
	_hide_burst_ring()
	global_position = Vector3(_burst_point.x, _burrow_y, _burst_point.z)
	velocity = Vector3.ZERO
	_underground = false
	flying = false
	_set_solid(true)
	_sink = 0.2
	if target:
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			rotation.y = atan2(-to.x, -to.z)
	reset_physics_interpolation()
	_splash(_burst_point, BURST_RADIUS)
	Sfx.play_at(&"mud_burst", _burst_point + Vector3.UP, 4.0)
	CombatFx.ring(self, _burst_point + Vector3.UP * 0.1, BURST_RADIUS, Color(0.7, 0.55, 0.35), 0.45)
	var p := _find_player()
	if p and p.alive:
		if p.global_position.distance_to(_burst_point) < 16.0:
			p.camera_rig.add_trauma(0.4)
		var flat := Vector2(p.global_position.x - _burst_point.x, p.global_position.z - _burst_point.z)
		if flat.length() <= BURST_RADIUS + Player.RADIUS and absf(p.global_position.y - _burst_point.y) < 3.0:
			var info := DamageInfo.create(a.damage if a else 34.0, DamageInfo.Kind.ENEMY_MELEE, self)
			info.parryable = false
			info.knockback = a.knockback if a else 10.0
			info.direction = Vector3(flat.x, 0.0, flat.y).normalized() if flat.length_squared() > 0.0001 else -global_basis.z
			info.hit_position = _burst_point
			p.receive_area_damage(info)
	Hearing.emit(get_tree(), _burst_point, 30.0, self, Hearing.Kind.IMPACT)
	_end_attack(true)
	# 솟구친 뒤 진흙에 박혀 잠시 움직이지 못한다(목 아래가 드러난다).
	_stuck = true
	_state_timer = STUCK_TIME
	_set_state(State.STUNNED)


func _show_burst_ring(at: Vector3) -> void:
	_hide_burst_ring()
	var mi := MeshInstance3D.new()
	mi.name = "BurstWarning"
	var mesh := TorusMesh.new()
	mesh.inner_radius = BURST_RADIUS - 0.25
	mesh.outer_radius = BURST_RADIUS
	mesh.rings = 48
	mesh.ring_segments = 4
	mi.mesh = mesh
	mi.material_override = CombatFx.glow_material(TELEGRAPH_HEAVY_COLOR, 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	var ground := at
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 4.0, CombatLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		ground = hit.position
	# 물에 잠긴 바닥이면 수면 위에 보이게 띄운다.
	mi.global_position = Vector3(at.x, maxf(ground.y, FieldLayout.WATER_LEVEL) + 0.08, at.z)
	mi.scale = Vector3(0.3, 1.0, 0.3)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, BURST_TELEGRAPH * 0.6).set_ease(Tween.EASE_OUT)
	_burst_ring = mi
	_splash(at, 1.5)


func _hide_burst_ring() -> void:
	if _burst_ring and is_instance_valid(_burst_ring):
		_burst_ring.queue_free()
	_burst_ring = null


# --- 부딪혀 기절 ---

func _crash(stun_time: float) -> void:
	super._crash(stun_time)
	_splash(global_position - global_basis.z * 3.0, 2.0)
	var p := _find_player()
	if p and p.global_position.distance_to(global_position) < 20.0:
		p.camera_rig.add_trauma(0.3)
	if not _crash_told:
		_crash_told = true
		GameEvents.notify("%s이(가) 부딪혀 정신을 잃었다 — 목 아래 붉은 턱살을 노려라" % data.display_name,
			GameEvents.NoticeKind.INFO)


# --- 동작 ---

func _animate(delta: float) -> void:
	var want := 1.0 if is_hidden() else 0.0
	if state == State.ATTACK and _attack and _attack.id == &"submerge" and _attack_phase == AttackPhase.WINDUP:
		var total := _attack.windup * _telegraph_mult()
		want = clampf(1.0 - _attack_timer / maxf(total, 0.01), 0.0, 1.0)
	var rate := 1.3 if want > _sink else 0.9
	_sink = move_toward(_sink, want, delta * rate)
	_anim.sink = _sink
	_anim.sweep_side = _sweep_side
	super._animate(delta)


func _anim_action() -> StringName:
	if is_hidden():
		return &""
	match state:
		State.STUNNED:
			return &"stuck" if _stuck else &"stun"
		State.STAGGER:
			return &"stagger"
		State.ATTACK:
			if _attack == null:
				return &""
			match _attack.id:
				&"roar":
					return &"roar"
				&"tail_sweep":
					return &"sweep"
				&"death_roll":
					return &"roll" if _attack_phase == AttackPhase.ACTIVE else &"windup"
				&"submerge":
					return &""
	return super._anim_action()


func _process(delta: float) -> void:
	# 꼬리 휩쓸기: 전조 동안은 반대쪽으로 감는다.
	if state == State.ATTACK and _attack and _attack.id == &"tail_sweep" and _anim:
		_anim.sweep_side = -_sweep_side if _attack_phase == AttackPhase.WINDUP else _sweep_side
	super._process(delta)


# --- 쓰러짐: 배를 드러내고 뒤집힌 채 늪에 가라앉는다 ---

func _die(info: DamageInfo, zone: int) -> void:
	_hide_burst_ring()
	flying = false
	_underground = false
	_hiding = false
	super._die(info, zone)
	if _bubbles:
		_bubbles.emitting = false
	if _throat_glow:
		_throat_glow.visible = false
	# 동작 갱신이 멈추므로 마지막 자세를 한 번 잡아 둔다(진흙 속에서 죽었어도 몸이 드러나게).
	if _anim:
		_sink = 0.0
		_anim.sink = 0.0
		_anim.action = &"stun"
		_anim.action_weight = 1.0
		for i in 12:
			_anim.update(0.05)


func _process_dead(delta: float) -> void:
	_dead_time += delta
	if not is_on_floor() and _dead_time < 3.0:
		velocity.y -= GRAVITY * delta
		move_and_slide()
	if _visual:
		var roll := lerpf(0.0, 2.5, smoothstep(0.0, 1.6, _dead_time))
		var pivot := Vector3(0, 0.85, 0)
		var sink_y := maxf(_dead_time - 12.0, 0.0) * 0.3
		_visual.transform = Transform3D(Basis(Vector3.BACK, roll), Vector3.ZERO).translated_local(-pivot) \
			.translated(pivot + Vector3.DOWN * sink_y)
	if _dead_time > 20.0:
		queue_free()


# --- 효과 ---

## 진흙이 튀는 효과(솟구치기, 잠수, 부딪힘)
func _splash(at: Vector3, radius: float) -> void:
	if not is_inside_tree():
		return
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.emitting = false
	ps.amount = int(clampf(radius * 10.0, 12.0, 48.0))
	ps.lifetime = 1.1
	ps.explosiveness = 0.9
	ps.direction = Vector3.UP
	ps.spread = 38.0
	ps.gravity = Vector3(0, -14.0, 0)
	ps.initial_velocity_min = 3.0 + radius
	ps.initial_velocity_max = 5.0 + radius * 1.6
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = radius * 0.5
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.6
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.26
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MUD_COLOR.darkened(0.15)
	mat.roughness = 0.35
	sm.material = mat
	ps.mesh = sm
	ps.top_level = true
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(ps)
	ps.global_position = Vector3(at.x, maxf(at.y, FieldLayout.WATER_LEVEL - 0.3), at.z)
	ps.emitting = true
	var tw := ps.create_tween()
	tw.tween_interval(ps.lifetime + 0.3)
	tw.tween_callback(ps.queue_free)


## 진흙 속에 잠겨 있을 때 수면으로 올라오는 거품
func _make_bubbles() -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.name = "Bubbles"
	ps.amount = 18
	ps.lifetime = 1.4
	ps.emitting = false
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(1.4, 0.05, 3.0)
	ps.direction = Vector3.UP
	ps.spread = 10.0
	ps.gravity = Vector3(0, 0.6, 0)
	ps.initial_velocity_min = 0.1
	ps.initial_velocity_max = 0.3
	ps.scale_amount_min = 0.4
	ps.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.14
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.74, 0.6, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	sm.material = mat
	ps.mesh = sm
	ps.position = Vector3(0, 0.45, -0.8)
	return ps

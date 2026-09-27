class_name NightPredator
extends Enemy
## 유니크 「밤의 포식자」(기획서 §15, 발견 방향: 빛이 사라지는 구간과 야행성 생태 흔적).
## 밤의 그늘 숲 깊은 곳에서만 나타나며, 사냥감을 곧장 죽이기보다 시험하듯 쫓는다.
## - 잠행: 사냥감 둘레를 돌며 간을 본다(공격하지 않는다).
## - 습격: 발톱 휘두르기(패링 가능), 그림자 도약·꼬리 쓸기(패링 불가, 긴 전조).
## - 사라짐: 안개 속으로 녹아들었다가 다른 방향에서 다시 나타난다(그동안은 맞지 않는다).
## - 흥미: 시간이 지날수록, 그리고 패링·회피·약점 명중을 해낼수록 오른다. 가득 차면 물러난다.
## 이 개발 빌드에서는 쓰러뜨릴 수 없다. 체력이 절반 아래로 떨어져도 물러난다.

signal retreated(reason: int)

enum Phase { STALK, ASSAULT, VANISH, RETREAT }
enum RetreatReason { INTEREST, WOUNDED, DAWN, LEFT_AREA, PLAYER_DOWN }

const DATA := preload("res://data/enemies/night_predator.tres")
const SHADER := preload("res://assets/shaders/shadow_beast.gdshader")

const STALK_TIME := Vector2(3.5, 5.0)
const ASSAULT_TIME := Vector2(7.5, 10.0)
const VANISH_TIME := 2.8
const VANISH_MOVE_AT := 0.9
const STALK_RADIUS := 14.0
const REAPPEAR_DISTANCE := Vector2(17.0, 22.0)
const RETREAT_TIME := 3.2
## 체력이 이 비율 아래로 내려가면 물러난다. 이보다 더 깎이지 않는다(이 빌드에서는 처치 불가).
const RETREAT_HP_RATIO := 0.5
const HP_FLOOR_RATIO := 0.45
const MAX_INTEREST := 100.0
const INTEREST_PER_SEC := 1.25
const INTEREST_PARRY := 12.0
const INTEREST_PERFECT := 10.0
const INTEREST_EVADE := 3.0
const INTEREST_WEAK_HIT := 2.5

const BODY_COLOR := Color(0.07, 0.075, 0.1)
const BONE_COLOR := Color(0.86, 0.84, 0.78)
const SPINE_COLOR := Color(0.2, 0.22, 0.3)
const EYE_COLOR := Color(0.35, 0.85, 1.0)

var phase: int = Phase.STALK
var interest: float = 0.0
## 정체가 드러났는지(한 번 살아남으면 이름이 보인다)
var revealed: bool = false
var retreat_reason: int = -1

var _phase_timer: float = 0.0
var _orbit_dir: float = 1.0
var _fade: float = 1.0
var _fade_target: float = 1.0
var _vanish_moved: bool = false
var _materials: Array[ShaderMaterial] = []
var _legs: Array[Node3D] = []
var _head: Node3D
## 전조 색은 머리(가면·눈)에만 진하게 칠한다(몸이 커서 온몸을 칠하면 화면을 가린다).
var _head_geometry: Array[GeometryInstance3D] = []
var _tail: Node3D
var _eye_light: OmniLight3D
var _mist: CPUParticles3D
var _gait: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	data = DATA
	eye_height = 1.9
	name = "NightPredator"
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.75
	capsule.height = 2.3
	cs.shape = capsule
	cs.position = Vector3(0, 1.15, 0)
	add_child(cs)
	# 앞으로 길게 나온 가슴과 머리도 막는다(머리가 카메라를 파고들지 않게).
	var chest := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	chest.shape = sphere
	chest.position = Vector3(0, 1.75, 1.55)
	add_child(chest)
	_build_visual()
	_add_hurtbox("HeadHurtbox", Hurtbox.Zone.WEAK_POINT, 1.6, "가면 아래 눈", Vector3(0, 2.15, 1.85), SphereShape3D.new(), 0.5)
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(1.5, 1.3, 3.0)
	_add_hurtbox("BodyHurtbox", Hurtbox.Zone.NORMAL, 1.0, "몸통", Vector3(0, 1.5, 0.1), body_shape, 0.0)


func _on_ready() -> void:
	_rng.randomize()
	_orbit_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	GameEvents.perfect_evaded.connect(_on_perfect_evaded)
	GameEvents.attack_evaded.connect(_on_evaded)


## 사냥을 시작한다(유니크 사건이 부른다).
func begin_hunt(p: Player) -> void:
	target = p
	last_known_position = p.global_position
	awareness = 1.0
	_set_state(State.CHASE)
	_start_phase(Phase.STALK)
	Sfx.play_at(&"predator_growl", global_position + Vector3.UP * eye_height, 4.0)


func display_label() -> String:
	if not revealed:
		return "%s  Lv ??  · %s" % [UniqueDB.unique_name(data.id, false), data.tier_label()]
	return super.display_label()


func is_vanished() -> bool:
	return phase == Phase.VANISH or _fade < 0.5


func interest_ratio() -> float:
	return clampf(interest / MAX_INTEREST, 0.0, 1.0)


# --- 흐름 ---

func _start_phase(p: int) -> void:
	phase = p
	match p:
		Phase.STALK:
			_phase_timer = _rng.randf_range(STALK_TIME.x, STALK_TIME.y)
			_orbit_dir = -_orbit_dir
		Phase.ASSAULT:
			_phase_timer = _rng.randf_range(ASSAULT_TIME.x, ASSAULT_TIME.y)
			Sfx.play_at(&"predator_growl", global_position + Vector3.UP * eye_height, 3.0, 0.9)
		Phase.VANISH:
			_phase_timer = VANISH_TIME
			_vanish_moved = false
			_fade_target = 0.0
			_set_tangible(false)
			Sfx.play_at(&"predator_vanish", global_position + Vector3.UP * eye_height, 2.0)
		Phase.RETREAT:
			_phase_timer = RETREAT_TIME


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		return
	_fade = move_toward(_fade, _fade_target, delta * 1.8)
	_apply_fade()
	if phase != Phase.RETREAT and target and target.alive:
		_add_interest(INTEREST_PER_SEC * delta)


func _process_state(delta: float) -> void:
	match phase:
		Phase.VANISH:
			_process_vanish(delta)
		Phase.RETREAT:
			_process_retreat(delta)
		_:
			super._process_state(delta)


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		retreat(RetreatReason.PLAYER_DOWN)
		return
	_phase_timer -= delta
	if phase == Phase.STALK:
		# 둘레를 돌며 간을 본다.
		var to_me := global_position - target.global_position
		to_me.y = 0.0
		var angle := atan2(to_me.x, to_me.z) + _orbit_dir * 0.55
		var goal := target.global_position + Vector3(sin(angle), 0.0, cos(angle)) * STALK_RADIUS
		_move_toward(goal, data.walk_speed * 1.7, delta)
		_face_toward(target.global_position, delta)
		if _phase_timer <= 0.0:
			_start_phase(Phase.ASSAULT)
		return
	# 습격
	if _phase_timer <= 0.0:
		_start_phase(Phase.VANISH)
		return
	if _try_start_attack():
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < 6.0 and not _sees_target:
		# 가까운데 나무 따위에 가려 보이지 않으면 옆으로 돌아 시야를 확보한다.
		var to_me := global_position - target.global_position
		to_me.y = 0.0
		var angle := atan2(to_me.x, to_me.z) + _orbit_dir * 0.7
		var goal := target.global_position + Vector3(sin(angle), 0.0, cos(angle)) * 3.8
		_move_toward(goal, data.run_speed * 0.7, delta)
		_face_toward(target.global_position, delta)
	# 머리가 몸 앞으로 길게 나와 있으므로 조금 떨어진 곳에서 멈춰 휘두른다.
	elif dist < 4.0:
		_stop(delta)
		_face_toward(target.global_position, delta)
	else:
		_move_toward(target.global_position, data.run_speed, delta)


func _process_vanish(delta: float) -> void:
	_stop(delta)
	_phase_timer -= delta
	if not _vanish_moved and VANISH_TIME - _phase_timer >= VANISH_MOVE_AT:
		_vanish_moved = true
		if target and is_instance_valid(target):
			global_position = reappear_point(target)
			reset_physics_interpolation()
			_face_direction(target.global_position - global_position, 10.0)
	if _vanish_moved and _phase_timer <= VANISH_TIME * 0.35:
		_fade_target = 1.0
	if _phase_timer <= 0.0:
		_set_tangible(true)
		if state == State.CHASE or state == State.ATTACK:
			_start_phase(Phase.STALK)
		else:
			_set_state(State.CHASE)
			_start_phase(Phase.STALK)


func _process_retreat(delta: float) -> void:
	_stop(delta)
	if target and is_instance_valid(target):
		_face_toward(target.global_position, delta)
	_phase_timer -= delta
	if _phase_timer <= RETREAT_TIME * 0.4 and _fade_target > 0.0:
		_fade_target = 0.0
		_set_tangible(false)
		Sfx.play_at(&"predator_vanish", global_position + Vector3.UP * eye_height, 3.0, 0.8)
	if _phase_timer <= 0.0 and retreat_reason >= 0:
		var reason := retreat_reason
		retreat_reason = -2
		retreated.emit(reason)


## 물러난다(흥미가 차거나, 깊이 다치거나, 새벽이 오거나, 사냥감이 멀리 달아났을 때).
func retreat(reason: int) -> void:
	if phase == Phase.RETREAT:
		return
	if _attack:
		_end_attack(false)
	_release_token()
	retreat_reason = reason
	_start_phase(Phase.RETREAT)
	if state != State.CHASE:
		_set_state(State.CHASE)
	if reason == RetreatReason.PLAYER_DOWN or reason == RetreatReason.LEFT_AREA:
		# 곧장 어둠 속으로 사라진다.
		_phase_timer = RETREAT_TIME * 0.4
	else:
		Sfx.play_at(&"predator_howl", global_position + Vector3.UP * eye_height, 6.0)


## 다시 나타날 자리: 사냥감에게서 17~22m, 가능하면 시야 밖, 물과 가파른 곳과 나무를 피한다.
func reappear_point(p: Player) -> Vector3:
	var field := get_parent()
	while field != null and not (field is FieldWorld):
		field = field.get_parent()
	# 플레이어 몸체는 돌지 않으므로 시선 방향은 yaw로 구한다.
	var look := -Basis(Vector3.UP, p.yaw).z
	var base_angle := atan2(look.x, look.z) + PI
	var best := p.global_position + Vector3(sin(base_angle), 0.0, cos(base_angle)) * REAPPEAR_DISTANCE.x
	for i in 12:
		var a := base_angle + _rng.randf_range(-1.4, 1.4)
		var d := _rng.randf_range(REAPPEAR_DISTANCE.x, REAPPEAR_DISTANCE.y)
		var c := p.global_position + Vector3(sin(a), 0.0, cos(a)) * d
		if field:
			var f: FieldWorld = field
			if f.terrain.is_underwater(c.x, c.z) or f.terrain.normal_at(c.x, c.z).y < 0.82:
				continue
			c.y = f.terrain.height_at(c.x, c.z)
		if not _space_clear(c):
			continue
		return c + Vector3.UP * 0.1
	return best + Vector3.UP * 0.5


func _space_clear(at: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.0
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.3)
	q.collision_mask = CombatLayers.WORLD
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _add_interest(amount: float) -> void:
	if phase == Phase.RETREAT:
		return
	interest = minf(MAX_INTEREST, interest + amount)
	if interest >= MAX_INTEREST:
		retreat(RetreatReason.INTEREST)


# --- 감지·피격(사냥 중에는 사냥감을 놓치지 않는다) ---

func _perceive() -> void:
	var p := _find_player()
	if p == null:
		return
	_sees_target = can_see(p) and not is_vanished()
	if p.alive and phase != Phase.RETREAT:
		target = p
		last_known_position = p.global_position
		p.mark_combat()


func _apply_damage(amount: float, info: DamageInfo, zone: int) -> void:
	if amount <= 0.0 or state == State.DEAD:
		return
	hp = maxf(hp - amount, data.max_hp * HP_FLOOR_RATIO)
	if hp <= data.max_hp * RETREAT_HP_RATIO:
		retreat(RetreatReason.WOUNDED)


func _on_hit_zone(_hurtbox: Hurtbox, zone: int, info: DamageInfo) -> void:
	if zone == Hurtbox.Zone.WEAK_POINT and info.is_from_player():
		_add_interest(INTEREST_WEAK_HIT)


func on_parried(by: Node) -> void:
	super.on_parried(by)
	_add_interest(INTEREST_PARRY)


func _on_perfect_evaded(enemy: Node) -> void:
	if enemy == self:
		_add_interest(INTEREST_PERFECT)


func _on_evaded(enemy: Node) -> void:
	if enemy == self:
		_add_interest(INTEREST_EVADE)


func _attack_allowed(a: EnemyAttackData) -> bool:
	if phase != Phase.ASSAULT or target == null:
		return false
	var limit := 40.0 if a.kind == EnemyAttackData.Kind.LUNGE else 70.0
	return facing_angle_to(target.global_position) <= limit


func _on_attack_windup(a: EnemyAttackData) -> void:
	if a.kind == EnemyAttackData.Kind.LUNGE:
		Sfx.play_at(&"predator_growl", global_position + Vector3.UP * eye_height, 3.0, 1.2)


func _update_overlay() -> void:
	var info := telegraph_info()
	var head := Color(0, 0, 0, 0)
	var body := Color(0, 0, 0, 0)
	if not info.is_empty():
		var c: Color = TELEGRAPH_PARRY_COLOR if info.parryable else TELEGRAPH_HEAVY_COLOR
		var pulse := 0.5 + 0.5 * sin(_clock * 30.0)
		head = Color(c, 0.5 + 0.4 * pulse)
		body = Color(c, 0.02 + 0.03 * pulse)
	elif _hit_flash > 0.0:
		head = Color(1, 1, 1, 0.45)
		body = Color(1, 1, 1, 0.22)
	var head_mat: Material = _overlay_material(head) if head.a > 0.01 else null
	var body_mat: Material = _overlay_material(body) if body.a > 0.01 else null
	for g in _geometry:
		if is_instance_valid(g):
			g.material_overlay = head_mat if _head_geometry.has(g) else body_mat


func _set_tangible(on: bool) -> void:
	for hb in _hurtboxes:
		hb.set_enabled(on)
	collision_layer = CombatLayers.ENEMY if on else 0


func _apply_fade() -> void:
	for m in _materials:
		m.set_shader_parameter(&"fade", _fade)
	if _eye_light:
		_eye_light.light_energy = 1.4 * _fade
	if _mist:
		_mist.emitting = _fade > 0.2


# --- 모습 ---

## 흐려질 때 정렬 문제 없이 사라지도록 점무늬로 구멍을 내는 재질(shadow_beast 셰이더)
func _material(color: Color, emission: float = 0.0, vertex_color: bool = true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"use_vertex_color", vertex_color)
	m.set_shader_parameter(&"albedo", color)
	if emission > 0.0:
		m.set_shader_parameter(&"emission_color", color)
		m.set_shader_parameter(&"emission_energy", emission)
	_materials.append(m)
	return m


func _mesh(b: MeshKit.Builder, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body_mat := _material(Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var dark := Color(BODY_COLOR, 0.0)
	# 몸통: 앞가슴이 두텁고 허리가 가는 긴 몸
	var b := MeshKit.Builder.new()
	b.blob(Vector3(0, 1.55, 0.05), 0.95, dark, 0.0, rng, 0.12, Vector3(0.72, 0.6, 1.35), -2.0, 0.05, 0.3)
	b.blob(Vector3(0, 1.62, 0.85), 0.72, dark, 0.0, rng, 0.14, Vector3(0.9, 0.95, 0.85), -2.0, 0.05, 0.3)
	b.blob(Vector3(0, 1.45, -0.85), 0.6, dark, 0.0, rng, 0.12, Vector3(0.95, 0.9, 0.95), -2.0, 0.05, 0.3)
	# 목
	b.frustum(Vector3(0, 1.75, 1.2), Vector3(0, 2.05, 1.65), 0.38, 0.27, 7, dark)
	# 등을 따라 솟은 가시(뿔 같은 실루엣)
	var spine := Color(SPINE_COLOR, 0.0)
	var sb := MeshKit.Builder.new()
	for i in 7:
		var t := float(i) / 6.0
		var z := lerpf(1.05, -1.0, t)
		var y := 2.02 - absf(t - 0.35) * 0.35
		var h := lerpf(0.75, 0.3, absf(t - 0.25) * 1.4)
		sb.frustum(Vector3(0, y, z), Vector3(0, y + h, z - 0.35), 0.1, 0.0, 5, spine)
	_mesh(b, body_mat, _visual)
	# 가시와 가면은 어둠 속에서도 윤곽이 보이도록 희미하게 빛난다(공정하게 알아볼 수 있게).
	_mesh(sb, _material(Color(0.3, 0.55, 0.8), 0.9, true), _visual)
	# 꼬리
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.55, -1.25)
	_visual.add_child(_tail)
	var tb := MeshKit.Builder.new()
	tb.frustum(Vector3.ZERO, Vector3(0, -0.3, -0.8), 0.2, 0.13, 6, dark)
	tb.frustum(Vector3(0, -0.3, -0.8), Vector3(0, -0.45, -1.6), 0.13, 0.03, 6, dark)
	_mesh(tb, body_mat, _tail)
	# 다리 넷: 어깨·엉덩이에서 흔든다.
	for spec in [[-0.45, 1.5, 0.95], [0.45, 1.5, 0.95], [-0.45, 1.42, -0.85], [0.45, 1.42, -0.85]]:
		var pivot := Node3D.new()
		pivot.position = Vector3(spec[0], spec[1], spec[2])
		_visual.add_child(pivot)
		var lb := MeshKit.Builder.new()
		var top: float = spec[1]
		lb.frustum(Vector3(0, -top * 0.5, 0.12), Vector3(0, 0.05, 0), 0.13, 0.21, 6, dark)
		lb.frustum(Vector3(0, -top + 0.08, -0.04), Vector3(0, -top * 0.5, 0.12), 0.09, 0.13, 6, dark)
		lb.box(Vector3(0, -top + 0.06, 0.1), Vector3(0.26, 0.12, 0.36), BODY_COLOR)
		_mesh(lb, body_mat, pivot)
		_legs.append(pivot)
	# 머리: 검은 두개골에 뼈처럼 흰 가면, 뒤로 휜 뿔, 푸른 눈
	_head = Node3D.new()
	_head.position = Vector3(0, 2.12, 1.78)
	_visual.add_child(_head)
	var hb := MeshKit.Builder.new()
	hb.blob(Vector3(0, 0, -0.05), 0.38, dark, 0.0, rng, 0.1, Vector3(0.8, 0.75, 1.1), -2.0, 0.04, 0.2)
	_mesh(hb, body_mat, _head)
	var mb := MeshKit.Builder.new()
	var bone := Color(BONE_COLOR, 0.0)
	mb.blob(Vector3(0, 0.03, 0.22), 0.33, bone, 0.0, rng, 0.08, Vector3(0.85, 0.8, 0.75), -2.0, 0.04, 0.15)
	mb.frustum(Vector3(0, -0.02, 0.4), Vector3(0, -0.1, 0.82), 0.19, 0.08, 6, bone)
	for side in [-1.0, 1.0]:
		var root := Vector3(side * 0.18, 0.28, 0.02)
		var mid := Vector3(side * 0.38, 0.62, -0.32)
		var tip := Vector3(side * 0.3, 0.92, -0.78)
		mb.frustum(root, mid, 0.07, 0.05, 5, bone)
		mb.frustum(mid, tip, 0.05, 0.0, 5, bone)
	_mesh(mb, _material(BONE_COLOR * 0.5, 0.35, true), _head)
	var eye_mat := _material(EYE_COLOR, 5.0, false)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.07
		sm.radial_segments = 8
		sm.rings = 4
		eye.mesh = sm
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.14, 0.09, 0.44)
		_head.add_child(eye)
	for c in _head.get_children():
		if c is GeometryInstance3D:
			_head_geometry.append(c)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = EYE_COLOR
	_eye_light.light_energy = 1.4
	_eye_light.omni_range = 5.0
	_eye_light.position = Vector3(0, 0.1, 0.6)
	_head.add_child(_eye_light)
	# 발치에 깔리는 검은 안개(겹침 효과가 번쩍이지 않게 Visual 바깥에 둔다)
	_mist = CPUParticles3D.new()
	_mist.amount = 28
	_mist.lifetime = 1.8
	_mist.local_coords = false
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_mist.emission_box_extents = Vector3(0.9, 0.3, 1.6)
	_mist.position = Vector3(0, 0.4, 0)
	_mist.gravity = Vector3(0, 0.35, 0)
	_mist.initial_velocity_min = 0.1
	_mist.initial_velocity_max = 0.4
	_mist.scale_amount_min = 0.5
	_mist.scale_amount_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(0.02, 0.03, 0.05, 0.0), Color(0.02, 0.03, 0.05, 0.55), Color(0.02, 0.03, 0.05, 0.0)])
	_mist.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var mist_mat := StandardMaterial3D.new()
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.vertex_color_use_as_albedo = true
	mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mist_mat
	_mist.mesh = quad
	add_child(_mist)


func _add_hurtbox(node_name: String, zone: int, mult: float, part: String, pos: Vector3, shape: Shape3D,
		radius: float) -> void:
	var hb := Hurtbox.new()
	hb.name = node_name
	hb.zone = zone
	hb.damage_multiplier = mult
	hb.part_name = part
	hb.position = pos
	if shape is SphereShape3D and radius > 0.0:
		(shape as SphereShape3D).radius = radius
	var cs := CollisionShape3D.new()
	cs.shape = shape
	hb.add_child(cs)
	add_child(hb)


func _process(delta: float) -> void:
	if _visual == null or state == State.DEAD:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	_gait += delta * (2.0 + speed * 1.1)
	var swing := clampf(speed / 7.0, 0.0, 1.0) * 0.65
	# 앞다리와 뒷다리가 엇갈리는 달리기
	var offsets := [0.0, PI, PI * 0.5, PI * 1.5]
	for i in _legs.size():
		_legs[i].rotation.x = sin(_gait + offsets[i]) * swing
	var crouch := 0.0
	var lean := 0.0
	if _attack_phase == AttackPhase.WINDUP:
		crouch = -0.18
		lean = 0.12
	elif _attack_phase == AttackPhase.ACTIVE and _attack and _attack.kind == EnemyAttackData.Kind.LUNGE:
		lean = -0.15
	_visual.position.y = lerpf(_visual.position.y, crouch + absf(sin(_gait * 2.0)) * 0.04 * swing, 1.0 - exp(-10.0 * delta))
	_visual.rotation.x = lerpf(_visual.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	_tail.rotation.y = sin(_clock * 1.7) * 0.35
	_tail.rotation.x = -0.1 + sin(_clock * 1.1) * 0.08
	# 사냥감 쪽으로 고개를 돌린다.
	if _head and target and is_instance_valid(target):
		var local := to_local(target.get_eye_position())
		var yaw := clampf(atan2(local.x, local.z), -0.8, 0.8)
		var pitch := clampf(-atan2(local.y - 2.1, Vector2(local.x, local.z).length()), -0.5, 0.4)
		_head.rotation.y = lerp_angle(_head.rotation.y, yaw, 1.0 - exp(-6.0 * delta))
		_head.rotation.x = lerp_angle(_head.rotation.x, pitch, 1.0 - exp(-6.0 * delta))

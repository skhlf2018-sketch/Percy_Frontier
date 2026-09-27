class_name Player
extends CharacterBody3D
## 1인칭 플레이어(기획서 §7 조작, §8.2 자원, §19.1 사망).
## 이동·시야·회피·앉기·난간 넘기, 자원과 상태이상, 소모품, 적 공격 수신, 사망과 부활을 맡는다.
## 무기는 WeaponManager, 몬스터 스킬은 SkillCaster가 담당한다.

signal interaction_changed(target: Interactable)
signal consumables_changed
signal died
signal respawned

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const STAND_EYE := 1.62
const CROUCH_EYE := 0.98
const RADIUS := 0.35

const WALK_SPEED := 5.2
const SPRINT_SPEED := 8.2
const CROUCH_SPEED := 2.6
const GROUND_ACCEL := 48.0
const AIR_ACCEL := 10.0
const GRAVITY := 19.0
const JUMP_VELOCITY := 6.3
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const SPRINT_DRAIN := 11.0

const DODGE_DISTANCE := 5.5
const DODGE_TIME := 0.24
const DODGE_IFRAMES := 0.22
const DODGE_COST := 22.0
const DODGE_COOLDOWN := 0.35

const MANTLE_MIN_HEIGHT := 0.45
const MANTLE_MAX_HEIGHT := 1.4
const MANTLE_TIME := 0.32

const INTERACT_RANGE := 3.0
const MAX_PITCH := deg_to_rad(86.0)
## 원거리 적의 동시 공격 수(근접 동시 공격 수는 난이도를 따른다)
const MAX_RANGED_ATTACKERS := 2
## 이 시간 동안 교전 신호가 없으면 전투가 끝난 것으로 본다
const COMBAT_LINGER := 5.0

@onready var head: Node3D = $Head
@onready var camera_rig: CameraRig = $Head/CameraRig
@onready var camera: Camera3D = $Head/CameraRig/Camera3D
@onready var weapons: WeaponManager = $Head/CameraRig/Camera3D/WeaponManager
@onready var skills: SkillCaster = $SkillCaster
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var stats := PlayerStats.new()
var status := StatusEffects.new()
var ammo := AmmoInventory.new()
var consumables: Array[ConsumableData] = []
var consumable_counts: Dictionary = {}

var yaw: float = 0.0
var pitch: float = 0.0
var alive: bool = true
## 메뉴가 열려 있거나 연출 중이면 false
var input_enabled: bool = true
var crouching: bool = false
var sprinting: bool = false
var interaction_target: Interactable = null

var _eye_height: float = STAND_EYE
var _crouch_toggled: bool = false
var _sprint_toggled: bool = false
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _stride: float = 0.0

var _forced_velocity := Vector3.ZERO
var _forced_time: float = 0.0
var _iframes: float = 0.0
var _dodge_cooldown: float = 0.0
var _knockback_immune: float = 0.0
var _move_lock: float = 0.0

var _mantling: bool = false
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t: float = 0.0

var _recoil_pool := Vector2.ZERO
var _recoil_recovery: float = 7.0

var _heals: Array[Dictionary] = []
var _consumable_busy: float = 0.0
var _last_combat: float = -100.0
var _clock: float = 0.0
var _tokens: Dictionary = {
	EnemyAttackData.TokenGroup.MELEE: [],
	EnemyAttackData.TokenGroup.RANGED: [],
}
var _capsule: CapsuleShape3D


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = CombatLayers.PLAYER
	collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY
	head.top_level = true
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_capsule = collision_shape.shape.duplicate()
	collision_shape.shape = _capsule
	_set_collision_height(STAND_HEIGHT)
	camera.make_current()
	stats.died.connect(_on_died)
	for id in [&"field_suture", &"purge_ampoule"]:
		var c := GameDB.consumable(id)
		consumables.append(c)
		consumable_counts[id] = c.start_count
	weapons.setup(self)
	skills.setup(self)
	yaw = global_rotation.y
	_update_head()


# --- 입력 ---

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not alive:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_look(event.screen_relative)
		return
	if event.is_action_pressed(&"jump"):
		_jump_buffer = JUMP_BUFFER
	elif event.is_action_pressed(&"dodge"):
		try_dodge()
	elif event.is_action_pressed(&"crouch"):
		if Settings.get_value(&"crouch_toggle"):
			_crouch_toggled = not _crouch_toggled
	elif event.is_action_pressed(&"sprint"):
		if Settings.get_value(&"sprint_toggle"):
			_sprint_toggled = not _sprint_toggled
			if _sprint_toggled:
				_crouch_toggled = false
	elif event.is_action_pressed(&"interact"):
		try_interact()
	elif event.is_action_pressed(&"consumable_1"):
		use_consumable(0)
	elif event.is_action_pressed(&"consumable_2"):
		use_consumable(1)


func _look(relative: Vector2) -> void:
	var s := Settings.look_rad_per_pixel(weapons.is_aiming())
	var invert := -1.0 if Settings.get_value(&"invert_y") else 1.0
	yaw = wrapf(yaw - relative.x * s, -PI, PI)
	pitch = clampf(pitch - relative.y * s * invert, -MAX_PITCH, MAX_PITCH)
	weapons.add_sway(relative)


## 반동(도). 일부는 시간이 지나며 원래 조준점으로 돌아온다.
func add_recoil(pitch_deg: float, yaw_deg: float, return_ratio: float, recovery: float) -> void:
	var p := deg_to_rad(pitch_deg)
	var y := deg_to_rad(yaw_deg)
	pitch = clampf(pitch + p, -MAX_PITCH, MAX_PITCH)
	yaw += y
	_recoil_pool += Vector2(p, y) * return_ratio
	_recoil_recovery = recovery


# --- 상태 조회 ---

func can_act() -> bool:
	return alive and input_enabled and not _mantling and not status.is_frozen()


func is_invulnerable() -> bool:
	return _iframes > 0.0


func is_busy_with_consumable() -> bool:
	return _consumable_busy > 0.0


func move_ratio() -> float:
	return clampf(Vector2(velocity.x, velocity.z).length() / SPRINT_SPEED, 0.0, 1.0)


func look_basis() -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)


## 사격·근접 판정의 기준. 렌더링용 카메라(보간)와 달리 현재 물리 위치를 쓴다.
func get_aim_transform() -> Transform3D:
	return Transform3D(look_basis(), global_position + Vector3.UP * _eye_height)


func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * _eye_height


func get_chest_position() -> Vector3:
	return global_position + Vector3.UP * (_eye_height * 0.72)


func is_in_combat() -> bool:
	return _clock - _last_combat < COMBAT_LINGER


func mark_combat() -> void:
	_last_combat = _clock


# --- 물리 프레임 ---

func _physics_process(delta: float) -> void:
	_clock += delta
	if not alive:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	stats.tick(delta)
	_tick_timers(delta)
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var dot := status.tick(delta, horizontal_speed > 0.5 and is_on_floor())
	if dot > 0.0:
		_take_raw_damage(dot)
	_tick_heals(delta)
	if not alive:
		return
	if _mantling:
		_process_mantle(delta)
		return
	_update_crouch(delta)
	var input_dir := Vector2.ZERO
	if can_act():
		input_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_update_sprint(input_dir, delta)
	_apply_movement(input_dir, delta)
	_apply_jump()
	var pre_velocity_y := velocity.y
	move_and_slide()
	_after_move(pre_velocity_y, delta)
	_update_interaction()
	_update_recoil_return(delta)
	_prune_tokens()


func _tick_timers(delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_knockback_immune = maxf(0.0, _knockback_immune - delta)
	_move_lock = maxf(0.0, _move_lock - delta)
	_consumable_busy = maxf(0.0, _consumable_busy - delta)
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)


func _update_crouch(delta: float) -> void:
	var want: bool
	if Settings.get_value(&"crouch_toggle"):
		want = _crouch_toggled
	else:
		want = can_act() and Input.is_action_pressed(&"crouch")
	if sprinting:
		want = false
	if want and not crouching:
		crouching = true
		_set_collision_height(CROUCH_HEIGHT)
	elif not want and crouching and _can_stand():
		crouching = false
		_crouch_toggled = false
		_set_collision_height(STAND_HEIGHT)
	var target_eye := CROUCH_EYE if crouching else STAND_EYE
	_eye_height = lerpf(_eye_height, target_eye, 1.0 - exp(-14.0 * delta))


func _set_collision_height(h: float) -> void:
	_capsule.radius = RADIUS
	_capsule.height = h
	collision_shape.position = Vector3(0, h * 0.5, 0)


func _can_stand() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS - 0.03
	shape.height = STAND_HEIGHT - 0.08
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * (STAND_HEIGHT * 0.5 + 0.05))
	q.collision_mask = CombatLayers.WORLD
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _update_sprint(input_dir: Vector2, delta: float) -> void:
	var want: bool
	if Settings.get_value(&"sprint_toggle"):
		want = _sprint_toggled
		if input_dir.length() < 0.1:
			_sprint_toggled = false
	else:
		want = Input.is_action_pressed(&"sprint")
	var allowed := can_act() and input_dir.y < -0.3 and not stats.exhausted \
		and not weapons.blocks_sprint() and not is_busy_with_consumable()
	if want and allowed and crouching and not _can_stand():
		allowed = false
	sprinting = want and allowed
	if sprinting:
		stats.drain_stamina(SPRINT_DRAIN * delta)
		if stats.exhausted:
			sprinting = false
			_sprint_toggled = false


## 사격 등으로 달리기를 멈춘다.
func cancel_sprint() -> void:
	sprinting = false
	_sprint_toggled = false


func _target_speed() -> float:
	var speed := WALK_SPEED
	if sprinting:
		speed = SPRINT_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	speed *= weapons.move_speed_multiplier()
	if is_busy_with_consumable():
		speed *= 0.6
	return speed * status.move_multiplier()


func _apply_movement(input_dir: Vector2, delta: float) -> void:
	if _forced_time > 0.0:
		_forced_time -= delta
		velocity.x = _forced_velocity.x
		velocity.z = _forced_velocity.z
		if _forced_velocity.y != 0.0:
			velocity.y = _forced_velocity.y
		if not is_on_floor():
			velocity.y -= GRAVITY * delta * 0.5
		return
	var wish := Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	var target := wish * _target_speed()
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	if _move_lock > 0.0:
		target = Vector3.ZERO
		accel = 6.0
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _apply_jump() -> void:
	if _jump_buffer <= 0.0 or not can_act():
		return
	if try_mantle():
		_jump_buffer = 0.0
		return
	if _coyote > 0.0 and not is_busy_with_consumable():
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		if crouching and _can_stand():
			crouching = false
			_crouch_toggled = false
			_set_collision_height(STAND_HEIGHT)


func _after_move(pre_velocity_y: float, delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -pre_velocity_y)
	elif not _was_on_floor:
		if _fall_speed > 4.0:
			camera_rig.land(_fall_speed)
			Sfx.play(&"land", -6.0)
			Hearing.emit(get_tree(), global_position, clampf(_fall_speed, 4.0, 12.0), self, Hearing.Kind.FOOTSTEP)
		_fall_speed = 0.0
	_was_on_floor = on_floor
	var hspeed := Vector2(velocity.x, velocity.z).length()
	camera_rig.bob_active = on_floor and _forced_time <= 0.0
	camera_rig.bob_speed = clampf(hspeed / SPRINT_SPEED, 0.0, 1.0)
	if on_floor and hspeed > 0.5:
		_stride += hspeed * delta
		var stride_len := 2.2 if sprinting else 1.7
		if _stride >= stride_len:
			_stride = 0.0
			if not crouching:
				Sfx.play(&"footstep", -12.0 if not sprinting else -8.0)
				var radius := 11.0 if sprinting else 4.0
				Hearing.emit(get_tree(), global_position, radius, self, Hearing.Kind.FOOTSTEP)


func _update_recoil_return(delta: float) -> void:
	if _recoil_pool.length_squared() < 1e-8:
		return
	var give := _recoil_pool * (1.0 - exp(-_recoil_recovery * delta))
	pitch = clampf(pitch - give.x, -MAX_PITCH, MAX_PITCH)
	yaw -= give.y
	_recoil_pool -= give


# --- 회피·강제 이동 ---

func try_dodge() -> bool:
	if not can_act() or _dodge_cooldown > 0.0 or _forced_time > 0.0 or is_busy_with_consumable():
		return false
	if not stats.use_stamina(DODGE_COST):
		return false
	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var dir := Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	if dir.length_squared() < 0.01:
		dir = Basis(Vector3.UP, yaw) * Vector3.BACK
	dir = dir.normalized()
	start_forced_motion(dir * (DODGE_DISTANCE / DODGE_TIME), DODGE_TIME, DODGE_IFRAMES)
	_dodge_cooldown = DODGE_COOLDOWN + DODGE_TIME
	cancel_sprint()
	apply_action_bleed()
	Sfx.play(&"dodge", -4.0)
	return true


## 회피·도약 스킬처럼 정해진 속도로 움직인다. 무적 시간을 함께 줄 수 있다.
func start_forced_motion(vel: Vector3, time: float, iframes: float) -> void:
	_forced_velocity = vel
	_forced_time = time
	_iframes = maxf(_iframes, iframes)


func is_in_forced_motion() -> bool:
	return _forced_time > 0.0


func apply_knockback(vel: Vector3) -> void:
	if _knockback_immune > 0.0 or vel.length_squared() < 0.01:
		return
	velocity += Vector3(vel.x, maxf(vel.y, 0.0), vel.z)
	_move_lock = 0.2


func set_knockback_immunity(time: float) -> void:
	_knockback_immune = maxf(_knockback_immune, time)


# --- 난간 넘기(기획서 §7: Space 점프·낮은 장애물 넘기) ---

func try_mantle() -> bool:
	var space := get_world_3d().direct_space_state
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var chest := global_position + Vector3.UP * 0.75
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		chest, chest + fwd * 0.75, CombatLayers.WORLD, [get_rid()]))
	if wall.is_empty():
		return false
	var probe_top := Vector3(wall.position.x, global_position.y + MANTLE_MAX_HEIGHT + 0.25, wall.position.z) + fwd * 0.3
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		probe_top, probe_top + Vector3.DOWN * (MANTLE_MAX_HEIGHT + 0.25 - MANTLE_MIN_HEIGHT + 0.05),
		CombatLayers.WORLD, [get_rid()]))
	if down.is_empty() or down.normal.dot(Vector3.UP) < 0.7:
		return false
	var ledge_height: float = down.position.y - global_position.y
	if ledge_height < MANTLE_MIN_HEIGHT or ledge_height > MANTLE_MAX_HEIGHT:
		return false
	var target: Vector3 = down.position + Vector3.UP * 0.02
	if not _has_room_at(target):
		return false
	_mantling = true
	_mantle_from = global_position
	_mantle_to = target
	_mantle_t = 0.0
	velocity = Vector3.ZERO
	cancel_sprint()
	Sfx.play(&"land", -8.0)
	return true


func _has_room_at(feet: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS - 0.03
	shape.height = CROUCH_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), feet + Vector3.UP * (CROUCH_HEIGHT * 0.5 + 0.05))
	q.collision_mask = CombatLayers.WORLD
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _process_mantle(delta: float) -> void:
	_mantle_t = minf(1.0, _mantle_t + delta / MANTLE_TIME)
	# 먼저 위로, 이어서 앞으로 이동하는 곡선
	var up_t := smoothstep(0.0, 0.6, _mantle_t)
	var fwd_t := smoothstep(0.35, 1.0, _mantle_t)
	var p := _mantle_from
	p.y = lerpf(_mantle_from.y, _mantle_to.y, up_t)
	p.x = lerpf(_mantle_from.x, _mantle_to.x, fwd_t)
	p.z = lerpf(_mantle_from.z, _mantle_to.z, fwd_t)
	global_position = p
	if _mantle_t >= 1.0:
		_mantling = false
		velocity = Vector3.ZERO
		_was_on_floor = true
		if not _can_stand():
			crouching = true
			_set_collision_height(CROUCH_HEIGHT)


# --- 상호작용 ---

func _update_interaction() -> void:
	var target: Interactable = null
	if can_act():
		var aim := get_aim_transform()
		var q := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin - aim.basis.z * INTERACT_RANGE,
			CombatLayers.WORLD | CombatLayers.INTERACTABLE, [get_rid()])
		q.collide_with_areas = true
		# 상호작용 영역 안에 서 있어도 인식하도록
		q.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider is Interactable:
			target = hit.collider
	if target != interaction_target:
		interaction_target = target
		interaction_changed.emit(target)


func try_interact() -> void:
	if interaction_target == null or not is_instance_valid(interaction_target) or not can_act():
		return
	var reason := interaction_target.get_block_reason(self)
	if reason != "":
		GameEvents.notify(reason, GameEvents.NoticeKind.WARNING)
		return
	interaction_target.interact(self)


# --- 소모품(기획서 §9.1: 빠른 슬롯 2개) ---

func consumable_count(index: int) -> int:
	if index < 0 or index >= consumables.size():
		return 0
	return consumable_counts.get(consumables[index].id, 0)


func use_consumable(index: int) -> bool:
	if index < 0 or index >= consumables.size() or not can_act() or is_busy_with_consumable():
		return false
	var c := consumables[index]
	if consumable_counts.get(c.id, 0) <= 0:
		GameEvents.notify("%s이(가) 없습니다." % c.display_name, GameEvents.NoticeKind.WARNING)
		return false
	match c.effect:
		ConsumableData.Effect.HEAL:
			if stats.hp >= stats.max_hp:
				GameEvents.notify("HP가 이미 가득 찼습니다.", GameEvents.NoticeKind.WARNING)
				return false
			_heals.append({"rate": c.amount / maxf(c.duration, 0.01), "left": c.duration})
		ConsumableData.Effect.CLEANSE:
			if not status.has_any():
				GameEvents.notify("해제할 상태이상이 없습니다.", GameEvents.NoticeKind.WARNING)
				return false
			status.clear_all()
			status.immunity_time = c.duration
	consumable_counts[c.id] -= 1
	_consumable_busy = c.use_time
	weapons.on_consumable_used(c.use_time)
	Sfx.play(&"consume")
	consumables_changed.emit()
	return true


func add_consumable(id: StringName, amount: int) -> int:
	var c := GameDB.consumable(id)
	if c == null:
		return 0
	var before: int = consumable_counts.get(id, 0)
	consumable_counts[id] = mini(c.max_carry, before + amount)
	var added: int = consumable_counts[id] - before
	if added > 0:
		consumables_changed.emit()
	return added


func _tick_heals(delta: float) -> void:
	if _heals.is_empty():
		return
	var total := 0.0
	for h in _heals:
		var dt := minf(delta, h.left)
		total += h.rate * dt
		h.left -= dt
	_heals = _heals.filter(func(h: Dictionary) -> bool: return h.left > 0.0)
	stats.heal(total * status.heal_multiplier())


func is_healing() -> bool:
	return not _heals.is_empty()


# --- 피격 ---

## 적의 공격을 받는다. 결과: { "evaded", "parried", "blocked", "damage" }
func receive_enemy_attack(info: DamageInfo) -> Dictionary:
	var result := {"evaded": false, "parried": false, "blocked": false, "damage": 0.0}
	if not alive:
		return result
	mark_combat()
	var attacker := info.attacker
	var source_pos := info.hit_position
	if attacker is Node3D and is_instance_valid(attacker):
		source_pos = attacker.global_position
	if is_invulnerable():
		result.evaded = true
		_record_on_attacker(attacker, Bestiary.Event.EVADE)
		GameEvents.attack_evaded.emit(attacker)
		return result
	var guard := weapons.try_block(info, source_pos)
	if guard.get("parried", false):
		result.parried = true
		stats.add_resonance(20.0)
		_record_on_attacker(attacker, Bestiary.Event.PARRY)
		if attacker and attacker.has_method("on_parried"):
			attacker.on_parried(self)
		Sfx.play(&"parry")
		camera_rig.add_trauma(0.25)
		GameEvents.parry_succeeded.emit(attacker)
		return result
	var amount := info.amount * float(Settings.difficulty_params().damage_taken)
	var buildup := info.status_buildup
	if guard.get("blocked", false):
		result.blocked = true
		var blocked_amount: float = amount * float(guard.reduction)
		amount -= blocked_amount
		stats.drain_stamina(blocked_amount * float(guard.stamina_per_damage))
		if stats.stamina <= 0.0:
			weapons.guard_break()
		Sfx.play(&"block")
		var halved := {}
		for t in buildup:
			halved[t] = buildup[t] * 0.5
		buildup = halved
	var lost := stats.take_damage(amount)
	result.damage = lost
	for t in status.apply_buildup(buildup):
		_on_player_status_triggered(t)
	if info.knockback > 0.0 and not result.blocked:
		var push := info.direction
		push.y = 0.0
		apply_knockback(push.normalized() * info.knockback + Vector3.UP * info.knockback * 0.15)
	if not result.blocked:
		Sfx.play(&"player_hurt", -2.0)
	var right := look_basis().x
	var to_source := (source_pos - global_position).normalized()
	camera_rig.flinch(clampf(amount / 15.0, 0.3, 1.5), right.dot(to_source))
	camera_rig.add_trauma(clampf(amount / 40.0, 0.1, 0.5))
	GameEvents.player_damaged.emit(lost, source_pos, result.blocked)
	return result


## 폭발처럼 방어·패링할 수 없는 범위 피해
func receive_area_damage(info: DamageInfo) -> void:
	if not alive:
		return
	mark_combat()
	if is_invulnerable():
		if info.attacker:
			_record_on_attacker(info.attacker, Bestiary.Event.EVADE)
		GameEvents.attack_evaded.emit(info.attacker)
		return
	var amount := info.amount * float(Settings.difficulty_params().damage_taken)
	var lost := stats.take_damage(amount)
	for t in status.apply_buildup(info.status_buildup):
		_on_player_status_triggered(t)
	if info.knockback > 0.0:
		apply_knockback(info.direction.normalized() * info.knockback)
	Sfx.play(&"player_hurt", -2.0)
	camera_rig.add_trauma(clampf(amount / 35.0, 0.15, 0.6))
	GameEvents.player_damaged.emit(lost, info.hit_position, false)


func _take_raw_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	stats.take_damage(amount)


## 공격·회피·스킬 같은 행동을 할 때 출혈 추가 피해를 받는다(기획서 §8.6).
func apply_action_bleed() -> void:
	_take_raw_damage(status.on_action())


func _on_player_status_triggered(type: int) -> void:
	match type:
		StatusEffects.Type.BURN:
			Sfx.play(&"ignite", -4.0)
		StatusEffects.Type.CHILL:
			Sfx.play(&"freeze", -4.0)
		StatusEffects.Type.SHOCK:
			Sfx.play(&"shock", -4.0)
			_take_raw_damage(StatusEffects.SHOCK_BURST)
		StatusEffects.Type.BLEED:
			Sfx.play(&"bleed", -4.0)
	GameEvents.notify("%s 상태가 되었습니다." % StatusEffects.type_name(type), GameEvents.NoticeKind.WARNING)


func _record_on_attacker(attacker: Node, event: Bestiary.Event) -> void:
	if attacker != null and is_instance_valid(attacker) and "data" in attacker:
		var data: EnemyData = attacker.data
		if data:
			GameState.bestiary.record(data, event)


# --- 공격권(동시에 공격하는 적 수 제한, 기획서 §21.1) ---

func request_attack_token(enemy: Node, group: int) -> bool:
	if group == EnemyAttackData.TokenGroup.NONE:
		return true
	var list: Array = _tokens[group]
	if list.has(enemy):
		return true
	var cap := MAX_RANGED_ATTACKERS
	if group == EnemyAttackData.TokenGroup.MELEE:
		cap = int(Settings.difficulty_params().max_attackers)
	if list.size() >= cap:
		return false
	list.append(enemy)
	return true


func release_attack_token(enemy: Node) -> void:
	for group in _tokens:
		_tokens[group].erase(enemy)


func _prune_tokens() -> void:
	for group in _tokens:
		var list: Array = _tokens[group]
		for i in range(list.size() - 1, -1, -1):
			var e = list[i]
			if not is_instance_valid(e) or (e.has_method("is_alive") and not e.is_alive()):
				list.remove_at(i)


# --- 사망·부활·휴식(기획서 §19) ---

func _on_died() -> void:
	alive = false
	_heals.clear()
	status.clear_all()
	weapons.on_owner_died()
	for group in _tokens:
		_tokens[group].clear()
	Sfx.play(&"death")
	died.emit()
	GameEvents.player_died.emit()


## 거점에서 부활한다. 레벨·장비·스킬·발견 기록은 유지하고, 사용한 소모품은 되돌리지 않는다.
## 진행 불능을 막기 위해 최소 비상 탄약과 기본 회복 수단은 보장한다.
func respawn_at(xform: Transform3D) -> void:
	global_transform = Transform3D(Basis(), xform.origin)
	yaw = xform.basis.get_euler().y
	pitch = 0.0
	velocity = Vector3.ZERO
	_forced_time = 0.0
	_mantling = false
	_recoil_pool = Vector2.ZERO
	crouching = false
	_crouch_toggled = false
	_set_collision_height(STAND_HEIGHT)
	_eye_height = STAND_EYE
	reset_physics_interpolation()
	stats.restore_full()
	status.clear_all()
	var supply := float(Settings.difficulty_params().supply_mult)
	ammo.ensure_emergency(supply)
	if consumable_counts.get(&"field_suture", 0) < 1:
		consumable_counts[&"field_suture"] = 1
		consumables_changed.emit()
	weapons.on_respawn()
	skills.reset_cooldowns()
	alive = true
	_update_head()
	Sfx.play(&"respawn")
	respawned.emit()
	GameEvents.player_respawned.emit()


## 거점 휴식: HP·스태미나 회복, 상태이상 해제, 시험장 보급.
func rest() -> void:
	stats.restore_full()
	status.clear_all()
	_heals.clear()
	var supply := float(Settings.difficulty_params().supply_mult)
	ammo.refill_to_start(supply)
	for c in consumables:
		if consumable_counts.get(c.id, 0) < c.start_count:
			consumable_counts[c.id] = c.start_count
	consumables_changed.emit()
	weapons.on_rest()
	skills.reset_cooldowns()


# --- 렌더링 프레임 ---

func _process(delta: float) -> void:
	if not alive:
		# 쓰러지면 시점이 바닥 쪽으로 내려간다.
		_eye_height = lerpf(_eye_height, 0.45, 1.0 - exp(-4.0 * delta))
	_update_head()
	var target_fov := Settings.vertical_fov_from_horizontal(float(Settings.get_value(&"fov")))
	target_fov *= weapons.fov_multiplier()
	camera.fov = target_fov


## 보간된 몸 위치에 머리를 둔다. 시야 회전은 보간하지 않아 마우스 입력이 바로 반영된다.
func _update_head() -> void:
	var origin := get_global_transform_interpolated().origin
	head.global_transform = Transform3D(look_basis(), origin + Vector3.UP * _eye_height)

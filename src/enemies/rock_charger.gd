class_name RockCharger
extends Enemy
## 바위등 돌격수(정예). 핵심 질문: "전면 장갑을 깰 것인가, 느린 회전을 이용해 등 뒤 약점을 노릴 것인가".
## - 몸을 돌리는 속도가 느려 옆과 뒤가 드러난다.
## - 돌진(패링 불가, 긴 전조와 포효)은 벽에 부딪히면 스스로 기절한다. 지형을 이용하는 공략.
## - 전면 장갑이 깨지면 분노해 빨라지지만 드러난 핵이 약점이 된다(기획서 §8.3: 파괴하면 행동이 달라진다).

const ENRAGE_SPEED_MULT := 1.25
const ENRAGE_WINDUP_MULT := 0.75
const CRASH_MIN_SPEED := 6.0

var enraged: bool = false
var _step_phase: float = 0.0


func _attack_allowed(a: EnemyAttackData) -> bool:
	if target == null:
		return false
	var limit := 35.0 if a.kind == EnemyAttackData.Kind.CHARGE else 55.0
	return facing_angle_to(target.global_position) <= limit


func _start_attack(a: EnemyAttackData) -> void:
	super._start_attack(a)
	if enraged:
		_attack_timer *= ENRAGE_WINDUP_MULT
	if a.kind == EnemyAttackData.Kind.CHARGE:
		Sfx.play_at(&"charger_roar", global_position + Vector3.UP * eye_height, 1.0)


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if _try_start_attack():
		return
	var speed := data.run_speed * (ENRAGE_SPEED_MULT if enraged else 1.0)
	var dist := global_position.distance_to(target.global_position)
	if dist < 3.0:
		_stop(delta)
		_face_toward(target.global_position, delta)
	else:
		_move_toward(last_known_position, speed, delta)


## 돌진 중 벽에 부딪히면 기절한다.
func _after_move(_delta: float) -> void:
	if state != State.ATTACK or _attack == null or _attack.kind != EnemyAttackData.Kind.CHARGE:
		return
	if _attack_phase != AttackPhase.ACTIVE:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Enemy or other is Player:
			continue
		if col.get_normal().dot(_attack_dir) < -0.6 and _attack.move_speed >= CRASH_MIN_SPEED:
			_crash(_attack.wall_stun)
			return


func _crash(stun_time: float) -> void:
	Sfx.play_at(&"wall_crash", global_position + Vector3.UP)
	CombatFx.impact(self, global_position - global_basis.z * 1.6 + Vector3.UP, Color(0.85, 0.8, 0.7), 0.5, 0.35)
	var p := _find_player()
	if p and p.global_position.distance_to(global_position) < 15.0:
		p.camera_rig.add_trauma(0.35)
	Hearing.emit(get_tree(), global_position, 20.0, self, Hearing.Kind.IMPACT)
	_end_attack(true)
	if stun_time > 0.0:
		_state_timer = stun_time
		_set_state(State.STUNNED)


func _on_armor_broken(_hb: Hurtbox) -> void:
	if enraged:
		return
	enraged = true
	Sfx.play_at(&"charger_roar", global_position + Vector3.UP * eye_height, 3.0, 1.2)
	GameEvents.notify("%s의 전면 장갑이 부서졌다 — 분노 상태" % data.display_name, GameEvents.NoticeKind.INFO)


func _process(delta: float) -> void:
	if _visual == null or state == State.DEAD:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	_step_phase += delta * speed * 1.2
	var lean := 0.0
	var y := absf(sin(_step_phase)) * 0.05 * clampf(speed / 4.0, 0.0, 1.0)
	if _attack_phase == AttackPhase.WINDUP:
		lean = 0.18
		y += sin(_clock * 40.0) * 0.015
	elif _attack_phase == AttackPhase.ACTIVE and _attack and _attack.kind == EnemyAttackData.Kind.CHARGE:
		lean = 0.12
	elif state == State.STUNNED:
		lean = -0.1
		_visual.rotation.z = sin(_clock * 6.0) * 0.06
	if state != State.STUNNED:
		_visual.rotation.z = lerpf(_visual.rotation.z, 0.0, 1.0 - exp(-8.0 * delta))
	_visual.rotation.x = lerpf(_visual.rotation.x, -lean, 1.0 - exp(-10.0 * delta))
	_visual.position.y = y

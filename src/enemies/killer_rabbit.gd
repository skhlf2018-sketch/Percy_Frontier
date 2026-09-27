class_name KillerRabbit
extends Enemy
## 살인토끼(기획서 §14.6): 작은 실루엣과 빠른 이동, 집단 매복.
## - 풀숲에 숨어 있다가 가까이 오면 튀어나온다. 숨어 있는 동안 바스락거리는 소리가 단서가 된다.
## - 공격권을 기다리는 동안 플레이어 주위를 돌며 포위한다.
## - 혼자 남은 채 크게 다치면 달아난다.
## 위험성은 신체 훼손 대신 빠른 습격과 소리로 표현한다.

const RUSTLE_RANGE := 16.0
const AMBUSH_TRIGGER := 6.0
const CIRCLE_RADIUS := 4.5
const CIRCLE_ENGAGE := 7.5
const FLEE_HEALTH := 0.3
const REHIDE_DELAY := 3.0

var hidden: bool = false
var _rustle_timer: float = 0.0
var _circle_sign: float = 1.0
var _fled: bool = false
var _hop_phase: float = 0.0



func _on_ready() -> void:
	hidden = ambush
	_circle_sign = 1.0 if randf() < 0.5 else -1.0
	_rustle_timer = randf_range(1.0, 3.0)


## 숨어 있는 동안은 멀리서 보고 반응하지 않는다. 가까이 오거나(_process_idle) 소리가 나거나 공격받을 때만 깨어난다.
func _perceive() -> void:
	if hidden and state == State.IDLE:
		return
	super._perceive()


func _process_idle(delta: float) -> void:
	_stop(delta)
	if not hidden:
		# 매복 무리는 거점에 돌아와 잠시 있으면 다시 숨는다.
		if ambush and _state_time > REHIDE_DELAY:
			hidden = true
		return
	var p := _find_player()
	if p == null or not p.alive:
		return
	var dist := global_position.distance_to(p.global_position)
	if dist < RUSTLE_RANGE:
		_rustle_timer -= delta
		if _rustle_timer <= 0.0:
			_rustle_timer = randf_range(2.5, 4.5)
			Sfx.play_at(&"rustle", global_position + Vector3.UP * 0.3, -2.0)
	if dist < AMBUSH_TRIGGER and CombatQuery.has_line_of_sight(get_world_3d(),
			global_position + Vector3.UP * eye_height, p.get_chest_position()):
		alert(p)


func _on_disturbed() -> void:
	hidden = false


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if not _fled and health_ratio() < FLEE_HEALTH and _nearby_pack_count() == 0:
		_fled = true
		_set_state(State.FLEE)
		return
	if _try_start_attack():
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < CIRCLE_ENGAGE and _sees_target:
		var to_me := global_position - target.global_position
		to_me.y = 0.0
		var angle := atan2(to_me.x, to_me.z) + _circle_sign * 0.8
		var goal := target.global_position + Vector3(sin(angle), 0.0, cos(angle)) * CIRCLE_RADIUS
		_move_toward(goal, data.run_speed * 0.75, delta)
		_face_toward(target.global_position, delta)
	else:
		_move_toward(last_known_position, data.run_speed, delta)


func _nearby_pack_count() -> int:
	var count := 0
	for e in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e != self and e is KillerRabbit and e.is_alive() and e.global_position.distance_to(global_position) < 12.0:
			count += 1
	return count


func _process(delta: float) -> void:
	if _visual == null or state == State.DEAD:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.5 and is_on_floor():
		_hop_phase += delta * (4.0 + speed * 1.6)
	var hop := absf(sin(_hop_phase)) * 0.14 * clampf(speed / 3.0, 0.0, 1.0)
	var target_scale := Vector3.ONE
	var y_offset := hop
	if hidden:
		target_scale = Vector3(1.0, 0.55, 1.0)
		y_offset = -0.12
	elif _attack_phase == AttackPhase.WINDUP:
		target_scale = Vector3(1.1, 0.78, 1.15)
	elif _attack_phase == AttackPhase.ACTIVE:
		target_scale = Vector3(0.9, 0.9, 1.35)
	_visual.position.y = y_offset
	_visual.scale = _visual.scale.lerp(target_scale, 1.0 - exp(-14.0 * delta))

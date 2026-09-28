class_name CaveBat
extends Enemy
## 동굴 박쥐: 날아다니며 플레이어 둘레를 돌다가 내리꽂혀 문다. 덮칠 때는 가슴 높이까지 내려온다.

const ORBIT_RADIUS := 5.0

var _orbit_sign: float = 1.0


func _on_ready() -> void:
	flying = true
	fly_height = randf_range(2.2, 3.4)
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0


## 공중에서는 길찾기 없이 곧장 난다.
func _nav_direction(point: Vector3, _delta: float) -> Vector3:
	var d := point - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO


func _fly_target_y() -> float:
	if state == State.ATTACK and target and _attack_phase != AttackPhase.NONE:
		return target.get_chest_position().y - 0.2
	return super._fly_target_y()


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if _try_start_attack():
		return
	var to_me := global_position - target.global_position
	to_me.y = 0.0
	var ang := atan2(to_me.x, to_me.z) + _orbit_sign * 0.9
	var goal := target.global_position + Vector3(sin(ang), 0.0, cos(ang)) * ORBIT_RADIUS
	_move_toward(goal, data.run_speed * 0.8, delta)
	_face_toward(target.global_position, delta)


func _process_dead(delta: float) -> void:
	flying = false
	super._process_dead(delta)

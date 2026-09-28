class_name ThornBoar
extends Enemy
## 가시등 멧돼지: 들이받고 지나쳐 멀리 돌아선 뒤 다시 들이받는다(치고 빠지기).
## 등은 가시로 덮여 탄이 박히고(장갑), 배가 약점이다. 들이받기를 옆으로 흘리면 나무에 박혀 기절한다.

const RUN_OFF := 10.0

var _run_off_to := Vector3.INF


func _end_attack(completed: bool) -> void:
	var was := _attack
	super._end_attack(completed)
	if was and was.kind == EnemyAttackData.Kind.CHARGE and completed and state != State.STUNNED and target:
		# 지나친 방향으로 더 달려가 거리를 벌린 뒤 돌아선다.
		var dir := _attack_dir if _attack_dir.length_squared() > 0.01 else -global_basis.z
		_run_off_to = global_position + dir * RUN_OFF


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if _run_off_to != Vector3.INF:
		if global_position.distance_to(_run_off_to) < 1.5 or _state_time > 3.0:
			_run_off_to = Vector3.INF
		else:
			_move_toward(_run_off_to, data.run_speed, delta)
			return
	super._process_chase(delta)


func _start_attack(a: EnemyAttackData) -> void:
	super._start_attack(a)
	if a.kind == EnemyAttackData.Kind.CHARGE:
		Sfx.play_at(&"wolf_growl", global_position + Vector3.UP * eye_height, 0.0, 0.6)


func _attack_allowed(a: EnemyAttackData) -> bool:
	if a.kind == EnemyAttackData.Kind.CHARGE and target:
		return facing_angle_to(target.global_position) <= 30.0
	return true

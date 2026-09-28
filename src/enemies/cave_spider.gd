class_name CaveSpider
extends Enemy
## 동굴 거미: 거리를 두고 거미줄을 쏘아 발을 묶은 뒤(냉기 누적 = 굼뜸), 뛰어올라 문다.

var _webbed_at: float = -100.0


func _on_attack_active(a: EnemyAttackData) -> void:
	if a.id == &"web_shot":
		_webbed_at = _clock


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if _try_start_attack():
		return
	var dist := global_position.distance_to(target.global_position)
	# 거미줄을 쏜 지 얼마 안 되었으면 달려들고, 아니면 거리를 두며 옆으로 돈다.
	if _clock - _webbed_at < 4.0 or dist > 16.0 or not _sees_target:
		_move_toward(last_known_position, data.run_speed, delta)
	elif dist < 5.0:
		var away := global_position - target.global_position
		away.y = 0.0
		_move_toward(global_position + away.normalized() * 4.0, data.run_speed, delta)
		_face_toward(target.global_position, delta)
	else:
		var to := target.global_position - global_position
		to.y = 0.0
		_move_toward(global_position + to.normalized().cross(Vector3.UP) * 3.0, data.walk_speed * 1.5, delta)
		_face_toward(target.global_position, delta)

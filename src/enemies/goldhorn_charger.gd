class_name GoldhornCharger
extends RockCharger
## 황금뿔 돌격수(희귀): 돌진이 벽에 막히지 않고 끝나면 곧바로 한 번 더 돌진한다(두 번째는 전조가 짧다).
## 가까이 붙으면 발구르기로 둘레를 모두 밀어낸다(막을 수 없다). 벽에 박히면 오래 정신을 잃는다.

var _double_ready: bool = false


func _start_attack(a: EnemyAttackData) -> void:
	super._start_attack(a)
	if a.id == &"stomp":
		Sfx.play_at(&"charger_roar", global_position + Vector3.UP * eye_height, 2.0, 0.8)


func _on_attack_active(a: EnemyAttackData) -> void:
	if a.id == &"stomp":
		CombatFx.explosion(self, global_position + Vector3.UP * 0.2, a.reach, Color(0.85, 0.75, 0.55, 0.5))
		Sfx.play_at(&"wall_crash", global_position, 3.0, 0.7)
		var p := _find_player()
		if p and p.global_position.distance_to(global_position) < 12.0:
			p.camera_rig.add_trauma(0.4)


func _attack_allowed(a: EnemyAttackData) -> bool:
	if a.id == &"stomp":
		return target != null and global_position.distance_to(target.global_position) < 4.2
	return super._attack_allowed(a)


func _crash(stun_time: float) -> void:
	_double_ready = false
	super._crash(stun_time)


func _end_attack(completed: bool) -> void:
	var was := _attack
	var crashed := state == State.STUNNED
	super._end_attack(completed)
	if was == null or was.id != &"gold_charge" or not completed or crashed:
		_double_ready = false
		return
	if _double_ready:
		_double_ready = false
		return
	# 두 번째 돌진: 돌아서자마자 짧은 전조로
	if target and target.alive and target.request_attack_token(self, was.token_group):
		_double_ready = true
		_cooldowns.erase(was.id)
		_start_attack(was)
		_attack_timer = 0.55 * _telegraph_mult()

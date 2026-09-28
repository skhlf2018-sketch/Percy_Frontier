class_name SerialRabbit
extends KillerRabbit
## 연쇄살인범토끼(희귀): 밤이면 토끼 무리에 섞여 다닌다. 한 번 뛰어들면 세 번까지 이어 덮친다.
## 이어 뛰기 사이의 짧은 착지가 반격할 틈이다(착지 뒤 회복 시간이 짧게 있다).

const MAX_CHAIN := 3
const CHAIN_WINDUP := 0.35

var _chain: int = 0


func _on_ready() -> void:
	super._on_ready()
	ambush = false
	hidden = false


func _end_attack(completed: bool) -> void:
	var was: EnemyAttackData = _attack
	super._end_attack(completed)
	if was == null or was.id != &"chain_leap" or not completed:
		_chain = 0
		return
	_chain += 1
	if _chain >= MAX_CHAIN or target == null or not target.alive or not _sees_target:
		_chain = 0
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < was.min_range * 0.6 or dist > was.max_range * 1.3:
		_chain = 0
		return
	# 착지하자마자 다시 뛴다(전조가 짧다).
	_cooldowns.erase(was.id)
	if target.request_attack_token(self, was.token_group):
		_start_attack(was)
		_attack_timer = CHAIN_WINDUP * _telegraph_mult()
		Sfx.play_at(&"rabbit_squeal", global_position + Vector3.UP * eye_height, -6.0, 1.3)

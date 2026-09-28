class_name HornRabbit
extends KillerRabbit
## 뿔토끼(강화): 숨지 않고 둘씩 다니며, 뒷발을 구른 뒤 곧게 들이받는다.
## 들이받기는 막을 수 없지만(전조가 붉다) 옆으로 비키면 나무나 바위에 부딪혀 잠시 정신을 잃는다.


func _on_ready() -> void:
	super._on_ready()
	ambush = false
	hidden = false


func _start_attack(a: EnemyAttackData) -> void:
	super._start_attack(a)
	if a.kind == EnemyAttackData.Kind.CHARGE:
		Sfx.play_at(&"rabbit_squeal", global_position + Vector3.UP * eye_height, -3.0, 0.7)


## 들이받기는 정면이 맞을 때만(몸을 돌리는 동안이 틈이다)
func _attack_allowed(a: EnemyAttackData) -> bool:
	if target == null:
		return false
	if a.kind == EnemyAttackData.Kind.CHARGE:
		return facing_angle_to(target.global_position) <= 30.0
	return true

class_name Hearing
extends RefCounted
## 소리 감지 이벤트(기획서 §14.5: 적은 시각과 청각 감지를 구분한다).
## 소리는 위치만 알려 준다. 적은 소리가 난 곳을 조사하러 가며, 플레이어 위치를 즉시 알지 못한다.

enum Kind { FOOTSTEP, GUNSHOT, IMPACT, EXPLOSION, VOICE }

const ENEMY_GROUP := &"enemies"


static func emit(tree: SceneTree, position: Vector3, radius: float, source: Node, kind: Kind) -> void:
	if tree == null or radius <= 0.0:
		return
	for enemy in tree.get_nodes_in_group(ENEMY_GROUP):
		if enemy.has_method("hear_noise"):
			enemy.hear_noise(position, radius, source, kind)

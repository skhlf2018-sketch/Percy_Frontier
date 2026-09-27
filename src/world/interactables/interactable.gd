class_name Interactable
extends Area3D
## 상호작용 대상(기본 키 E). 플레이어 시선이 이 영역을 향하면 HUD에 안내 문구가 뜬다.
## 사용할 수 없는 상황이면 이유를 함께 보여 준다(기획서 §4.4: 잠긴 이유를 전달한다).

signal interacted(player: Node)

@export var prompt: String = "상호작용"


func _ready() -> void:
	collision_layer = CombatLayers.INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_prompt(_player: Node) -> String:
	return prompt


## 지금 사용할 수 없으면 이유를, 가능하면 빈 문자열을 돌려준다.
func get_block_reason(_player: Node) -> String:
	return ""


func interact(player: Node) -> void:
	interacted.emit(player)

@tool
class_name SupplyPoint
extends Interactable
## 안전 거점(보급 비콘). 휴식하면 HP·스태미나 회복, 상태이상 해제, 시험장 보급을 받고
## 이 거점이 부활 지점이 된다. 휴식하면 야외 무리가 다시 나타난다(기획서 §19.3).
## 전투 중에는 쓸 수 없다(기획서 §4.5).

## 부활 위치(거점 앞)
@export var respawn_offset := Vector3(0, 0, 2.0)
## false면 비콘 모형 없이 판정만 둔다(여관 문처럼 건물이 모양을 대신하는 곳).
@export var show_beacon: bool = true


func _build() -> void:
	if prompt == "상호작용":
		prompt = "휴식 · 보급"
	if label_text == "" and show_beacon:
		label_text = "보급 거점"
	if not show_beacon:
		_add_trigger_box(Vector3(2.4, 2.6, 1.6), Vector3(0, 1.3, 0))
		return
	_add_mesh(cylinder(0.8, 0.15), Vector3(0, 0.075, 0), Color(0.22, 0.25, 0.28))
	_add_mesh(cylinder(0.07, 2.2), Vector3(0, 1.1, 0), Color(0.45, 0.48, 0.5))
	_add_mesh(SphereMesh.new(), Vector3(0, 2.3, 0), Color(0.35, 0.9, 0.85), 3.0).scale = Vector3.ONE * 0.36
	_add_mesh(box(Vector3(0.8, 0.5, 0.5)), Vector3(0.75, 0.25, 0), Color(0.35, 0.42, 0.3))
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.95, 0.9)
	light.light_energy = 1.5
	light.omni_range = 7.0
	light.position = Vector3(0, 2.3, 0)
	_add_internal(light)
	_add_solid_box(Vector3(0.4, 2.2, 0.4), Vector3(0, 1.1, 0))
	_add_solid_box(Vector3(0.8, 0.5, 0.5), Vector3(0.75, 0.25, 0))
	_add_trigger_box(Vector3(2.0, 2.6, 2.0), Vector3(0, 1.3, 0))
	_add_label(label_text, 2.9)


func get_block_reason(player: Node) -> String:
	if player is Player and player.is_in_combat():
		return "전투 중에는 휴식할 수 없습니다."
	return ""


## 부활 위치와 방향. 거점 뒤편에서 거점과 같은 방향을 바라본다.
func respawn_transform() -> Transform3D:
	var pos := global_transform * respawn_offset
	return Transform3D(Basis(Vector3.UP, global_rotation.y), pos)

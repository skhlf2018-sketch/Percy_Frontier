@tool
class_name WeaponRack
extends Interactable
## 무기 거치대. 전투 시험장에서 주무기와 근접 무기를 바꿔 무기군별 차이를 비교한다(기획서 §26.1).


func _build() -> void:
	if prompt == "상호작용":
		prompt = "무기 교체"
	if label_text == "":
		label_text = "무기 거치대"
	var frame := Color(0.35, 0.3, 0.25)
	_add_mesh(box(Vector3(0.1, 1.6, 0.1)), Vector3(-0.9, 0.8, 0), frame)
	_add_mesh(box(Vector3(0.1, 1.6, 0.1)), Vector3(0.9, 0.8, 0), frame)
	_add_mesh(box(Vector3(1.9, 0.08, 0.14)), Vector3(0, 1.45, 0), frame)
	_add_mesh(box(Vector3(1.9, 0.08, 0.14)), Vector3(0, 0.55, 0), frame)
	var guns := [Color(0.27, 0.3, 0.27), Color(0.3, 0.22, 0.16), Color(0.82, 0.84, 0.86), Color(0.2, 0.22, 0.2)]
	for i in guns.size():
		var x := -0.6 + i * 0.4
		_add_mesh(box(Vector3(0.07, 0.95, 0.12)), Vector3(x, 1.0, 0.06), guns[i], 0.0, Vector3(0, 0, 8))
	_add_solid_box(Vector3(2.0, 1.6, 0.3), Vector3(0, 0.8, 0))
	_add_trigger_box(Vector3(2.2, 2.0, 1.2), Vector3(0, 1.0, 0))
	_add_label(label_text, 2.0)

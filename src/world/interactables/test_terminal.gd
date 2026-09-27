@tool
class_name TestTerminal
extends Interactable
## 시험 단말기. 전투 시험장 전용 기능(적 무리 소환·정리, 분석 완료 등)을 연다.


func _build() -> void:
	if prompt == "상호작용":
		prompt = "시험 단말기 사용"
	if label_text == "":
		label_text = "시험 단말기"
	_add_mesh(box(Vector3(0.9, 1.1, 0.5)), Vector3(0, 0.55, 0), Color(0.24, 0.27, 0.3))
	_add_mesh(box(Vector3(0.8, 0.5, 0.05)), Vector3(0, 1.25, -0.05), Color(0.25, 0.9, 0.75), 2.0, Vector3(-20, 0, 0))
	_add_mesh(box(Vector3(0.7, 0.05, 0.3)), Vector3(0, 1.12, -0.2), Color(0.16, 0.18, 0.2))
	_add_solid_box(Vector3(0.9, 1.4, 0.5), Vector3(0, 0.7, 0))
	_add_trigger_box(Vector3(1.4, 2.0, 1.4), Vector3(0, 1.0, 0))
	_add_label(label_text, 2.0)

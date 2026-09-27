class_name PauseMenu
extends MenuPanel
## 일시정지 메뉴.

signal resume_requested
signal settings_requested
signal controls_requested
signal title_requested
signal quit_requested
signal save_requested
signal load_requested

var _save_button: Button
var _load_button: Button
var _save_note: Label


func _init() -> void:
	super._init()
	panel.custom_minimum_size = Vector2(460, 0)
	set_title("일시정지")
	add_button(body, "계속하기", func() -> void: resume_requested.emit(), &"MenuButtonLarge")
	_save_button = add_button(body, "저장하기", func() -> void: save_requested.emit(), &"MenuButtonLarge")
	_load_button = add_button(body, "불러오기", func() -> void: load_requested.emit(), &"MenuButtonLarge")
	_save_note = Label.new()
	_save_note.theme_type_variation = &"MutedLabel"
	_save_note.visible = false
	body.add_child(_save_note)
	add_button(body, "설정", func() -> void: settings_requested.emit(), &"MenuButtonLarge")
	add_button(body, "조작 안내", func() -> void: controls_requested.emit(), &"MenuButtonLarge")
	add_button(body, "타이틀로", func() -> void: title_requested.emit(), &"MenuButtonLarge")
	add_button(body, "게임 종료", func() -> void: quit_requested.emit(), &"MenuButtonLarge")


func _handle_cancel() -> bool:
	resume_requested.emit()
	return true


## 저장 가능 여부. 저장할 수 없으면 이유를 보여 준다(기획서 §20.2: 전투 중이 아닐 때만 수동 저장).
## available이 false면 저장·불러오기 버튼을 숨긴다(훈련장).
func set_save_state(available: bool, allowed: bool, reason: String = "") -> void:
	_save_button.visible = available
	_load_button.visible = available
	_save_button.disabled = not allowed
	_save_note.visible = available and not allowed and reason != ""
	_save_note.text = reason

class_name PauseMenu
extends MenuPanel
## 일시정지 메뉴.

signal resume_requested
signal settings_requested
signal controls_requested
signal title_requested
signal quit_requested


func _init() -> void:
	super._init()
	panel.custom_minimum_size = Vector2(460, 0)
	set_title("일시정지")
	add_button(body, "계속하기", func() -> void: resume_requested.emit(), &"MenuButtonLarge")
	add_button(body, "설정", func() -> void: settings_requested.emit(), &"MenuButtonLarge")
	add_button(body, "조작 안내", func() -> void: controls_requested.emit(), &"MenuButtonLarge")
	add_button(body, "타이틀로", func() -> void: title_requested.emit(), &"MenuButtonLarge")
	add_button(body, "게임 종료", func() -> void: quit_requested.emit(), &"MenuButtonLarge")


func _handle_cancel() -> bool:
	resume_requested.emit()
	return true

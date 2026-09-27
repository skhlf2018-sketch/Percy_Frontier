class_name ChoiceMenu
extends MenuPanel
## 선택 메뉴(시험 단말기, 무기 거치대).
## 항목 형식: { "text", "detail", "enabled"(기본 true), "action": Callable, "keep_open"(기본 false), "header"(기본 false) }
## 사용할 수 없는 항목은 이유를 설명에 적는다.

var _subtitle: Label
var _list: VBoxContainer
var _detail: Label


func _init() -> void:
	super._init()
	panel.custom_minimum_size = Vector2(760, 0)
	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"MutedLabel"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_subtitle)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	body.add_child(_list)
	_detail = Label.new()
	_detail.theme_type_variation = &"MutedLabel"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 56)
	body.add_child(_detail)


func show_choices(title: String, subtitle: String, entries: Array) -> void:
	set_title(title)
	_subtitle.text = subtitle
	_detail.text = ""
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for entry in entries:
		if entry.get("header", false):
			var h := Label.new()
			h.text = entry.text
			h.add_theme_font_size_override("font_size", 20)
			h.add_theme_color_override("font_color", Color(0.5, 0.82, 0.72))
			_list.add_child(h)
			continue
		var b := Button.new()
		b.text = entry.text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not entry.get("enabled", true)
		b.focus_mode = Control.FOCUS_ALL
		var detail: String = entry.get("detail", "")
		b.mouse_entered.connect(func() -> void: _detail.text = detail)
		b.focus_entered.connect(func() -> void: _detail.text = detail)
		var action: Callable = entry.get("action", Callable())
		var keep_open: bool = entry.get("keep_open", false)
		b.pressed.connect(func() -> void:
			Sfx.play_ui(&"ui_confirm")
			if action.is_valid():
				action.call()
			if not keep_open:
				close())
		_list.add_child(b)
	add_button(_list, "닫기", close)
	open()

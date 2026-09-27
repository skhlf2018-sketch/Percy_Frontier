class_name SaveSlotsMenu
extends MenuPanel
## 저장·불러오기 칸 목록(기획서 §20.2). 자동 저장 칸은 불러오기만 할 수 있다.

signal save_requested(slot: String)
signal load_requested(slot: String)

enum Mode { SAVE, LOAD }

var mode: int = Mode.LOAD
var _list: VBoxContainer
var _message: Label


func _init() -> void:
	super._init()
	panel.custom_minimum_size = Vector2(1100, 0)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	body.add_child(_list)
	_message = Label.new()
	_message.theme_type_variation = &"MutedLabel"
	_message.custom_minimum_size = Vector2(0, 28)
	body.add_child(_message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(row)
	add_button(row, "닫기", close)


func open_mode(m: int, message: String = "") -> void:
	mode = m
	set_title("저장하기" if mode == Mode.SAVE else "불러오기")
	_message.text = message
	_refresh()
	open()


func show_message(text: String) -> void:
	_message.text = text
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for slot in SaveSystem.all_slots():
		var doc := SaveSystem.read(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_list.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title := Label.new()
		title.text = SaveSystem.slot_label(slot)
		title.add_theme_font_size_override("font_size", 22)
		info.add_child(title)
		var desc := Label.new()
		desc.theme_type_variation = &"MutedLabel"
		desc.text = SaveSystem.describe(doc)
		info.add_child(desc)
		var s := slot
		if mode == Mode.SAVE:
			var b := add_button(row, "여기에 저장", func() -> void: save_requested.emit(s))
			b.disabled = slot == SaveSystem.AUTO
			if slot == SaveSystem.AUTO:
				b.tooltip_text = "자동 저장 칸은 거점 휴식과 지역 발견 때 저절로 채워집니다."
		else:
			var b := add_button(row, "불러오기", func() -> void: load_requested.emit(s))
			b.disabled = doc.is_empty()
	_focus_first()

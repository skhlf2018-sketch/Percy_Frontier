class_name ChoiceMenu
extends MenuPanel
## 선택 메뉴(시험 단말기, 무기 거치대).
## 항목 형식: { "text", "detail", "enabled"(기본 true), "action": Callable, "keep_open"(기본 false), "header"(기본 false),
##   "color"(글자색, 무기 희귀도 등) }
## 항목이 많으면 목록이 스크롤된다.
## 사용할 수 없는 항목은 이유를 설명에 적는다.

const MAX_LIST_HEIGHT := 560.0
const ROW_HEIGHT := 46.0

var _subtitle: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _detail: Label
var _shown_title := ""
## 다시 그린 뒤 포커스를 줄 버튼 순서(-1이면 첫 버튼)
var _refocus_index := -1


func _init() -> void:
	super._init()
	panel.custom_minimum_size = Vector2(760, 0)
	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"MutedLabel"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_subtitle)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
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
		if entry.has("color"):
			var c: Color = entry.color
			b.add_theme_color_override("font_color", c)
			b.add_theme_color_override("font_hover_color", c.lightened(0.25))
			b.add_theme_color_override("font_focus_color", c.lightened(0.25))
			b.add_theme_color_override("font_pressed_color", c.lightened(0.35))
			b.add_theme_color_override("font_disabled_color", Color(c, 0.6))
		b.disabled = not entry.get("enabled", true)
		b.focus_mode = Control.FOCUS_ALL
		var detail: String = entry.get("detail", "")
		b.mouse_entered.connect(func() -> void: _detail.text = detail)
		b.focus_entered.connect(func() -> void: _detail.text = detail)
		var action: Callable = entry.get("action", Callable())
		var keep_open: bool = entry.get("keep_open", false)
		var index := _list.get_child_count()
		b.pressed.connect(func() -> void:
			_refocus_index = index
			Sfx.play_ui(&"ui_confirm")
			if action.is_valid():
				action.call()
			if not keep_open:
				close())
		_list.add_child(b)
	add_button(_list, "닫기", close)
	_scroll.custom_minimum_size = Vector2(0, minf(_list.get_child_count() * ROW_HEIGHT, MAX_LIST_HEIGHT))
	# 같은 메뉴를 다시 그리면(사고 나서 목록 갱신 등) 누른 자리를 유지한다.
	if not (visible and title == _shown_title):
		_scroll.scroll_vertical = 0
		_refocus_index = -1
	_shown_title = title
	open()


func _grab_first_focus() -> void:
	if _refocus_index < 0 or not visible or not is_inside_tree():
		super._grab_first_focus()
		return
	var target: Control = null
	var i := mini(_refocus_index, _list.get_child_count() - 1)
	while i >= 0 and target == null:
		var c := _list.get_child(i)
		if c is BaseButton and not (c as BaseButton).disabled and not c.is_queued_for_deletion():
			target = c
		i -= 1
	if target == null:
		super._grab_first_focus()
	else:
		target.grab_focus()

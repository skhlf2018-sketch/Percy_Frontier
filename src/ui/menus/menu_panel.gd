class_name MenuPanel
extends Control
## 메뉴 화면 공통 기반: 화면을 어둡게 덮고 가운데 패널을 띄운다. Esc로 닫는다.

signal closed

var panel: PanelContainer
var body: VBoxContainer
var _title_label: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeaderLabel"
	body.add_child(_title_label)


func set_title(text: String) -> void:
	_title_label.text = text


func open() -> void:
	visible = true
	_focus_first()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _focus_first() -> void:
	var first := _find_focusable(body)
	if first:
		first.grab_focus.call_deferred()


func _find_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is BaseButton and not child.disabled and child.visible:
			return child
		var inner := _find_focusable(child)
		if inner:
			return inner
	return null


## 하위 클래스가 Esc를 먼저 처리하고 싶으면 true를 돌려준다.
func _handle_cancel() -> bool:
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _handle_cancel():
			Sfx.play_ui(&"ui_click")
			close()


func add_button(parent: Node, text: String, callback: Callable, variation: StringName = &"") -> Button:
	var b := Button.new()
	b.text = text
	if variation != &"":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Sfx.play_ui(&"ui_click")
		callback.call())
	parent.add_child(b)
	return b

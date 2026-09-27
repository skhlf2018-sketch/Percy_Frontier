class_name MenuLayer
extends CanvasLayer
## 게임 중 메뉴 묶음(일시정지, 설정, 조작 안내, 선택 메뉴).
## 메뉴가 열려 있는 동안 게임을 멈추고 마우스 커서를 보이게 한다.

signal title_requested

var pause_menu := PauseMenu.new()
var settings_menu := SettingsMenu.new()
var controls_help := ControlsHelp.new()
var choice_menu := ChoiceMenu.new()
var status_window := StatusWindow.new()


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	for m: MenuPanel in [pause_menu, settings_menu, controls_help, choice_menu, status_window]:
		add_child(m)
		m.closed.connect(_on_menu_closed.bind(m))
	pause_menu.resume_requested.connect(close_all)
	pause_menu.settings_requested.connect(_open_sub.bind(settings_menu))
	pause_menu.controls_requested.connect(_open_sub.bind(controls_help))
	pause_menu.title_requested.connect(func() -> void:
		close_all()
		title_requested.emit())
	pause_menu.quit_requested.connect(func() -> void: get_tree().quit())


func is_open() -> bool:
	for m: MenuPanel in [pause_menu, settings_menu, controls_help, choice_menu, status_window]:
		if m.visible:
			return true
	return false


func open_pause() -> void:
	_set_paused(true)
	pause_menu.open()


func open_choice(title: String, subtitle: String, entries: Array) -> void:
	_set_paused(true)
	choice_menu.show_choices(title, subtitle, entries)


## 공명 장치 창(Tab)
func open_status(tab: int = StatusWindow.TAB_STATUS) -> void:
	_set_paused(true)
	status_window.open_tab(tab)


func close_all() -> void:
	for m: MenuPanel in [pause_menu, settings_menu, controls_help, choice_menu, status_window]:
		m.visible = false
	Settings.save_settings()
	_set_paused(false)


func _open_sub(menu: MenuPanel) -> void:
	pause_menu.visible = false
	menu.open()


func _on_menu_closed(menu: MenuPanel) -> void:
	if menu == settings_menu or menu == controls_help:
		pause_menu.open()
		return
	if not is_open():
		_set_paused(false)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

class_name SettingsMenu
extends MenuPanel
## 설정(기획서 §7 입력, §21.3 접근성, §24.1 성능 옵션). 바꾸는 즉시 적용된다.
## 여기 있는 모든 항목은 실제로 동작한다. 동작하지 않는 옵션은 넣지 않는다(기획서 §0).

const LABEL_WIDTH := 330.0

var _tabs: TabContainer
var _refreshers: Array[Callable] = []
var _rebind_buttons: Dictionary = {}
var _listening: StringName = &""
var _message: Label
var _difficulty_note: Label


func _init() -> void:
	super._init()
	panel.custom_minimum_size = Vector2(1040, 0)
	set_title("설정")
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(1000, 560)
	body.add_child(_tabs)
	_build_controls()
	_build_display()
	_build_gameplay()
	_build_audio()
	_build_graphics()
	_build_keys()
	_message = Label.new()
	_message.theme_type_variation = &"MutedLabel"
	_message.custom_minimum_size = Vector2(0, 28)
	body.add_child(_message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(row)
	add_button(row, "옵션 기본값으로", _reset_options)
	add_button(row, "닫기", close)
	Settings.bindings_changed.connect(_refresh_bindings)


func open() -> void:
	_refresh_all()
	_message.text = ""
	super.open()


func close() -> void:
	if visible:
		_stop_listening()
		Settings.save_settings()
	super.close()


func _handle_cancel() -> bool:
	if _listening != &"":
		_stop_listening()
		return true
	return false


# --- 탭 구성 ---

func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title)
	return v


func _build_controls() -> void:
	var t := _tab("조작")
	_slider(t, &"mouse_sensitivity", "마우스 감도", 0.1, 3.0, 0.05, func(v: float) -> String: return "%.2f" % v)
	_slider(t, &"ads_sensitivity", "정조준 감도 배율", 0.2, 1.5, 0.05, func(v: float) -> String: return "%.2f" % v)
	_toggle(t, &"invert_y", "Y축 반전")
	_choice(t, &"aim_toggle", "조준·방어 방식", ["누르고 있기", "눌러서 전환"], [false, true])
	_choice(t, &"crouch_toggle", "앉기 방식", ["누르고 있기", "눌러서 전환"], [false, true])
	_choice(t, &"sprint_toggle", "달리기 방식", ["누르고 있기", "눌러서 전환"], [false, true])


func _build_display() -> void:
	var t := _tab("화면")
	_slider(t, &"fov", "시야각 (16:9 기준 수평)", 70.0, 110.0, 1.0, func(v: float) -> String: return "%d°" % int(v))
	_slider(t, &"camera_shake", "화면 흔들림", 0.0, 1.0, 0.05, _percent)
	_slider(t, &"muzzle_flash", "총구 섬광", 0.0, 1.0, 0.05, _percent)
	_toggle(t, &"head_bob", "걷기 흔들림(헤드밥)")
	_toggle(t, &"damage_numbers", "피해 수치 표시")
	_toggle(t, &"telegraph_boost", "공격 전조 강화")
	_note(t, "공격 전조 강화: 적 머리 위 전조 표시를 크게 하고, 화면 밖에서 공격을 준비하는 적을 화면 가장자리에 화살표로 알립니다.")


func _build_gameplay() -> void:
	var t := _tab("게임플레이")
	_choice(t, &"difficulty", "난이도", Settings.DIFFICULTY_NAMES, [0, 1, 2])
	_difficulty_note = _note(t, "")
	_note(t, "난이도는 적 HP를 늘리지 않고 받는 피해, 전조 시간, 동시에 공격하는 적 수, 공격 빈도, 보급량을 조정합니다. 도전 난이도에서도 공격 전조는 사라지지 않습니다. 게임 중에도 바꿀 수 있습니다.")
	_refreshers.append(_update_difficulty_note)


func _build_audio() -> void:
	var t := _tab("소리")
	_slider(t, &"master_volume", "전체 음량", 0.0, 1.0, 0.05, _percent)
	_slider(t, &"sfx_volume", "효과음", 0.0, 1.0, 0.05, _percent)
	_slider(t, &"ui_volume", "인터페이스", 0.0, 1.0, 0.05, _percent)
	_note(t, "현재 효과음은 절차적으로 합성한 임시 소리입니다. 음악은 아직 없습니다.")


func _build_graphics() -> void:
	var t := _tab("그래픽")
	_choice(t, &"window_mode", "창 모드", Settings.WINDOW_MODE_NAMES, [0, 1, 2])
	_toggle(t, &"vsync", "수직 동기화")
	var fps_names: Array = []
	for f in Settings.MAX_FPS_OPTIONS:
		fps_names.append("무제한" if f == 0 else str(f))
	_choice(t, &"max_fps", "프레임 제한", fps_names, Settings.MAX_FPS_OPTIONS)
	_slider(t, &"render_scale", "3D 렌더 배율", 0.5, 1.0, 0.05, _percent)
	_note(t, "렌더 배율이 100% 미만이면 FSR 1.0 업스케일링을 씁니다(Forward+ 렌더러). 호환 렌더러에서는 단순 확대를 씁니다.")
	_choice(t, &"graphics_quality", "그래픽 품질", Settings.GRAPHICS_QUALITY_NAMES, [0, 1, 2, 3])
	_note(t, "낮음: 단순한 그림자와 안개. 보통: 화면 공간 차폐·반사광. 높음: 전역 조명(SDFGI), 볼륨 안개, 짐승 털 표현. "
		+ "최고: 더 멀고 선명한 그림자와 반사. 새로 나타나는 몬스터부터 털 표현이 바뀝니다.")


func _build_keys() -> void:
	var t := _tab("키 설정")
	_note(t, "버튼을 누른 뒤 새 키나 마우스 버튼을 누르세요. Esc는 취소입니다. 다른 기능에 쓰이던 입력이면 두 기능의 입력을 서로 바꿉니다.")
	for entry in Settings.REBINDABLE:
		var action: StringName = entry[0]
		var row := _row(t, entry[1])
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 0)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_start_listening.bind(action))
		row.add_child(b)
		_rebind_buttons[action] = b
	var reset_row := HBoxContainer.new()
	t.add_child(reset_row)
	add_button(reset_row, "기본 키로 되돌리기", func() -> void:
		Settings.restore_default_bindings()
		_message.text = "모든 키를 기본값으로 되돌렸습니다.")


# --- 행 도우미 ---

func _row(parent: Node, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(l)
	parent.add_child(row)
	return row


func _slider(parent: Node, key: StringName, text: String, min_v: float, max_v: float, step: float,
		fmt: Callable) -> void:
	var row := _row(parent, text)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(360, 24)
	s.focus_mode = Control.FOCUS_ALL
	row.add_child(s)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(value_label)
	var refresh := func() -> void:
		s.set_value_no_signal(float(Settings.get_value(key)))
		value_label.text = fmt.call(float(Settings.get_value(key)))
	s.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v, false)
		value_label.text = fmt.call(v))
	_refreshers.append(refresh)


func _toggle(parent: Node, key: StringName, text: String) -> void:
	var row := _row(parent, text)
	var c := CheckButton.new()
	c.focus_mode = Control.FOCUS_ALL
	row.add_child(c)
	var state := Label.new()
	row.add_child(state)
	var refresh := func() -> void:
		c.set_pressed_no_signal(bool(Settings.get_value(key)))
		state.text = "켬" if bool(Settings.get_value(key)) else "끔"
	c.toggled.connect(func(on: bool) -> void:
		Sfx.play_ui(&"ui_click")
		Settings.set_value(key, on)
		state.text = "켬" if on else "끔")
	_refreshers.append(refresh)


func _choice(parent: Node, key: StringName, text: String, names: Array, values: Array) -> void:
	var row := _row(parent, text)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(300, 0)
	o.focus_mode = Control.FOCUS_ALL
	for n in names:
		o.add_item(String(n))
	row.add_child(o)
	var refresh := func() -> void:
		var idx := values.find(Settings.get_value(key))
		o.select(maxi(idx, 0))
	o.item_selected.connect(func(idx: int) -> void:
		Sfx.play_ui(&"ui_click")
		Settings.set_value(key, values[idx])
		_update_difficulty_note())
	_refreshers.append(refresh)


func _note(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"MutedLabel"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	l.text = text
	parent.add_child(l)
	return l


static func _percent(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


func _update_difficulty_note() -> void:
	if _difficulty_note == null:
		return
	var p := Settings.difficulty_params()
	_difficulty_note.text = "받는 피해 %d%% · 공격 전조 %d%% · 동시에 공격하는 근접 적 %d · 공격 간격 %d%% · 보급량 %d%%" % [
		int(p.damage_taken * 100.0), int(p.telegraph_mult * 100.0), int(p.max_attackers),
		int(p.attack_cooldown_mult * 100.0), int(p.supply_mult * 100.0)]


func _refresh_all() -> void:
	for r in _refreshers:
		r.call()
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action in _rebind_buttons:
		if action == _listening:
			continue
		_rebind_buttons[action].text = Settings.binding_text(action)


func _reset_options() -> void:
	Settings.reset_options_to_default()
	_refresh_all()
	_message.text = "키 설정을 제외한 옵션을 기본값으로 되돌렸습니다."


# --- 키 재설정 ---

func _start_listening(action: StringName) -> void:
	_stop_listening()
	_listening = action
	_rebind_buttons[action].text = "키를 누르세요… (Esc 취소)"
	_message.text = "'%s'에 쓸 입력을 누르세요." % Settings.action_label(action)


func _stop_listening() -> void:
	if _listening == &"":
		return
	var action := _listening
	_listening = &""
	if _rebind_buttons.has(action):
		_rebind_buttons[action].text = Settings.binding_text(action)


func _input(event: InputEvent) -> void:
	if _listening == &"" or not visible:
		return
	var accepted := false
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			_stop_listening()
			_message.text = "키 변경을 취소했습니다."
			return
		accepted = true
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		accepted = true
	if not accepted:
		return
	var action := _listening
	var conflict := Settings.rebind(action, event)
	_listening = &""
	_refresh_bindings()
	Sfx.play_ui(&"ui_confirm")
	if conflict != &"":
		_message.text = "'%s' → %s. '%s'에 쓰이던 입력과 서로 바꿨습니다." % [
			Settings.action_label(action), Settings.binding_text(action), Settings.action_label(conflict)]
	else:
		_message.text = "'%s' → %s" % [Settings.action_label(action), Settings.binding_text(action)]

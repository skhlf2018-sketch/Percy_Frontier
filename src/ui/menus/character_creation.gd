class_name CharacterCreation
extends Control
## 캐릭터 생성(기획서 §3.2: 외형과 이름은 플레이어가 정한다). 공명 장치의 "사용자 등록" 화면으로 보여 준다.
## 이름, 외형, 시작 성향, 난이도를 고르고 탐사를 시작한다. 성향은 능력치에 작은 보너스만 준다.

signal back_requested
signal start_requested(config: Dictionary)

const ACCENT := Color(0.45, 0.88, 0.98)
const MUTED := Color(0.66, 0.74, 0.78)
const NAME_MAX := 12
const RANDOM_NAMES: Array[String] = ["하람", "도윤", "서린", "리온", "아인", "카이", "유나", "세오", "노아", "린", "이안", "소라"]

var appearance: Dictionary = HumanoidModel.default_appearance()
var origin: StringName = &"marksman"

var _model: HumanoidModel
var _pivot: Node3D
var _name_edit: LineEdit
var _option_labels: Dictionary = {}
var _origin_buttons: Dictionary = {}
var _origin_desc: Label
var _difficulty_buttons: Array[Button] = []
var _start_button: Button
var _dragging: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.03, 0.045)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(_build_preview())
	row.add_child(_build_form())
	_refresh()


# --- 미리보기 ---

func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_stretch_ratio = 1.1
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_preview_input)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	container.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.6, 0.7)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 0.85
	key.shadow_enabled = true
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 2.2, -1.5)
	rim.light_color = ACCENT
	rim.light_energy = 2.0
	rim.omni_range = 5.0
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 3.0)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 40.0
	vp.add_child(cam)
	# 원형 받침과 공명 고리
	var b := MeshKit.Builder.new()
	b.frustum(Vector3(0, -0.12, 0), Vector3(0, 0.0, 0), 0.9, 0.85, 24, Color(0.12, 0.16, 0.2))
	var base := MeshInstance3D.new()
	base.mesh = b.commit()
	base.material_override = MeshKit.solid_material()
	vp.add_child(base)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 0.9
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.albedo_color = ACCENT
	rm.emission_enabled = true
	rm.emission = ACCENT
	rm.emission_energy_multiplier = 3.0
	ring.material_override = rm
	ring.position.y = 0.01
	vp.add_child(ring)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	_model = HumanoidModel.new(appearance)
	_pivot.add_child(_model)
	_pivot.rotation.y = 0.35
	return container


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y += event.relative.x * 0.01


func _process(delta: float) -> void:
	if _pivot and not _dragging:
		_pivot.rotation.y += delta * 0.25


# --- 입력 양식 ---

func _build_form() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", StatusWindow.holo_style())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)
	_label(v, "공명 장치 · 사용자 등록", 34, ACCENT)
	_label(v, "경계 숲에 투입될 탐사자를 등록합니다. 외형과 이름은 언제든 기록에 남습니다.", 18, MUTED)

	_section(v, "이름")
	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NAME_MAX
	_name_edit.placeholder_text = "이름 (최대 %d자)" % NAME_MAX
	_name_edit.custom_minimum_size = Vector2(420, 0)
	_name_edit.text = RANDOM_NAMES[_rng.randi() % RANDOM_NAMES.size()]
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh())
	name_row.add_child(_name_edit)
	_button(name_row, "무작위", func() -> void:
		_name_edit.text = RANDOM_NAMES[_rng.randi() % RANDOM_NAMES.size()]
		_refresh())

	_section(v, "외형")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for opt in HumanoidModel.OPTIONS:
		var key: String = opt[0]
		var count: int = opt[2]
		_label(grid, opt[1], 20).custom_minimum_size = Vector2(130, 0)
		_button(grid, "◀", func() -> void: _step(key, count, -1)).custom_minimum_size = Vector2(52, 0)
		var value := _label(grid, "", 20)
		value.custom_minimum_size = Vector2(170, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_option_labels[key] = value
		_button(grid, "▶", func() -> void: _step(key, count, 1)).custom_minimum_size = Vector2(52, 0)
	_button(v, "외형 무작위", func() -> void:
		appearance = HumanoidModel.random_appearance(_rng)
		_model.set_appearance(appearance)
		_refresh())

	_section(v, "시작 성향")
	var origins := HBoxContainer.new()
	origins.add_theme_constant_override("separation", 8)
	v.add_child(origins)
	var group := ButtonGroup.new()
	for id: StringName in PlayerProgress.ORIGINS:
		var o: Dictionary = PlayerProgress.ORIGINS[id]
		var b := _button(origins, o.name, func() -> void:
			origin = id
			_refresh())
		b.toggle_mode = true
		b.button_group = group
		_origin_buttons[id] = b
	_origin_desc = _label(v, "", 18, MUTED)
	_origin_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_section(v, "난이도 (게임 중에도 바꿀 수 있습니다)")
	var diff := HBoxContainer.new()
	v.add_child(diff)
	var dgroup := ButtonGroup.new()
	for i in Settings.DIFFICULTY_NAMES.size():
		var idx := i
		var b := _button(diff, Settings.DIFFICULTY_NAMES[i], func() -> void:
			Settings.set_value(&"difficulty", idx)
			_refresh())
		b.toggle_mode = true
		b.button_group = dgroup
		_difficulty_buttons.append(b)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	v.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	_button(buttons, "뒤로", func() -> void: back_requested.emit())
	_start_button = _button(buttons, "탐사 시작", _start)
	_start_button.theme_type_variation = &"MenuButtonLarge"
	return panel


func _label(parent: Node, text: String, size_px: int = 20, color := Color(0.92, 0.95, 0.96)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _section(parent: Node, title: String) -> void:
	_label(parent, title, 22, ACCENT)
	var line := ColorRect.new()
	line.color = Color(ACCENT, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		Sfx.play_ui(&"ui_click")
		callback.call())
	parent.add_child(b)
	return b


func _step(key: String, count: int, dir: int) -> void:
	appearance[key] = posmod(int(appearance.get(key, 0)) + dir, count)
	_model.set_appearance(appearance)
	_refresh()


func _refresh() -> void:
	for key: String in _option_labels:
		(_option_labels[key] as Label).text = HumanoidModel.option_label(key, int(appearance.get(key, 0)))
	for id: StringName in _origin_buttons:
		(_origin_buttons[id] as Button).set_pressed_no_signal(id == origin)
	var o: Dictionary = PlayerProgress.ORIGINS[origin]
	var bonus: Array[String] = []
	for s: int in o.bonus:
		bonus.append("%s +%d" % [PlayerProgress.STAT_NAMES[s], o.bonus[s]])
	_origin_desc.text = "%s  (%s)" % [o.desc, ", ".join(bonus)]
	var d := int(Settings.get_value(&"difficulty"))
	for i in _difficulty_buttons.size():
		_difficulty_buttons[i].set_pressed_no_signal(i == d)
	if _start_button:
		_start_button.disabled = player_name().is_empty()


func player_name() -> String:
	return _name_edit.text.strip_edges() if _name_edit else ""


func config() -> Dictionary:
	return {"name": player_name(), "origin": origin, "appearance": appearance.duplicate()}


func _start() -> void:
	if player_name().is_empty():
		return
	Settings.save_settings()
	start_requested.emit(config())

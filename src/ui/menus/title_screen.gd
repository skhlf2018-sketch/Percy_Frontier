extends Control
## 타이틀 화면. 배경에 퍼시 외곽권을 띄워 천천히 둘러보고, 이 빌드가 무엇을 담고 있는지 정직하게 안내한다(기획서 §0).
## 이어하기(가장 최근 저장), 새로 시작(캐릭터 생성), 불러오기, 훈련장(전투 시험장), 설정, 조작 안내, 종료.

const GAME_SCENE_PATH := "res://src/main/game.tscn"

var _settings := SettingsMenu.new()
var _controls := ControlsHelp.new()
var _saves := SaveSlotsMenu.new()
var _creation: CharacterCreation
var _ui: Control
var _field: FieldWorld
var _camera: Camera3D
var _time: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var shade := TextureRect.new()
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 110)
	_ui.add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "PERCY FRONTIER"
	col.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"HeaderLabel"
	sub.text = "퍼시 외곽권 · 개발 빌드 v%s" % ProjectSettings.get_setting("application/config/version", "0")
	col.add_child(sub)
	var desc := Label.new()
	desc.theme_type_variation = &"MutedLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(900, 0)
	desc.text = "\n".join([
		"강하선이 추락한 경계 숲에서 홀로 깨어난 탐사자가 되어, 구조 신호를 따라 첫 정착지 퍼시를 찾아갑니다.",
		"임시 모델과 합성 효과음으로 만든 개발 빌드입니다. 무엇이 들어 있는지는 README.txt와 조작 안내를 보세요.",
	])
	col.add_child(desc)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	col.add_child(spacer)
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(440, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(buttons)
	var latest := SaveSystem.latest_slot()
	var first: Button
	if latest != "":
		first = _button(buttons, "이어하기", func() -> void: _load(latest))
		first.tooltip_text = SaveSystem.describe(SaveSystem.read(latest))
		var note := Label.new()
		note.theme_type_variation = &"MutedLabel"
		note.text = SaveSystem.describe(SaveSystem.read(latest))
		buttons.add_child(note)
	var new_game := _button(buttons, "새로 시작", _open_creation)
	if first == null:
		first = new_game
	var load_button := _button(buttons, "불러오기", func() -> void: _saves.open_mode(SaveSlotsMenu.Mode.LOAD))
	load_button.disabled = latest == ""
	_button(buttons, "훈련장 (전투 시험장)", _start_training)
	_button(buttons, "설정", func() -> void: _settings.open())
	_button(buttons, "조작 안내", func() -> void: _controls.open())
	_button(buttons, "종료", func() -> void: get_tree().quit())
	add_child(_settings)
	add_child(_controls)
	add_child(_saves)
	_saves.load_requested.connect(_load)
	first.grab_focus.call_deferred()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"MenuButtonLarge"
	b.pressed.connect(func() -> void:
		Sfx.play_ui(&"ui_click")
		callback.call())
	parent.add_child(b)
	return b


# --- 배경: 해 질 녘의 퍼시 외곽권 ---

func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if DisplayServer.get_name() == "headless":
		return
	bg.visible = false
	_field = FieldWorld.new()
	add_child(_field)
	_field.day_night.advance_to(17.9)
	_field.day_night.paused = true
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.far = 900.0
	add_child(_camera)
	_camera.make_current()
	_field.ambience.player = _camera
	_update_camera(0.0)


func _update_camera(t: float) -> void:
	if _camera == null:
		return
	# 감시탑 언덕 위를 천천히 돌며 퍼시 쪽을 바라본다.
	var center := Vector2(FieldLayout.WATCHTOWER.x + 10.0, FieldLayout.WATCHTOWER.y + 30.0)
	var a := 0.6 + t * 0.02
	var p := center + Vector2(cos(a), sin(a)) * 42.0
	var ground := _field.terrain.height_at(p.x, p.y)
	var eye := Vector3(p.x, ground + 16.0, p.y)
	var target := Vector3(FieldLayout.TOWN_CENTER.x, FieldLayout.TOWN_HEIGHT + 4.0, FieldLayout.TOWN_CENTER.y)
	_camera.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	_field.grass.focus = _camera


func _process(delta: float) -> void:
	_time += delta
	_update_camera(_time)


static func _shade_texture() -> GradientTexture2D:
	# 왼쪽을 어둡게 눌러 글자가 잘 보이게 한다.
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.02, 0.03, 0.9))
	g.set_color(1, Color(0.01, 0.02, 0.03, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.5)
	t.fill_to = Vector2(0.75, 0.5)
	t.width = 256
	t.height = 16
	return t


# --- 흐름 ---

func _open_creation() -> void:
	_ui.visible = false
	_creation = CharacterCreation.new()
	add_child(_creation)
	_creation.back_requested.connect(func() -> void:
		_creation.queue_free()
		_creation = null
		_ui.visible = true)
	_creation.start_requested.connect(func(config: Dictionary) -> void:
		Game.next_mode = Game.Mode.FIELD
		Game.next_new_game = config
		get_tree().change_scene_to_file(GAME_SCENE_PATH))


func _start_training() -> void:
	Game.next_mode = Game.Mode.TRAINING
	Game.next_new_game = {}
	Game.next_load = {}
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _load(slot: String) -> void:
	var doc := SaveSystem.read(slot)
	if doc.is_empty():
		return
	Game.next_load = doc
	Game.next_new_game = {}
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

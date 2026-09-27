extends Control
## 타이틀 화면. 이 빌드가 무엇을 담고 있는지 정직하게 안내한다(기획서 §0, §28).

const GAME_SCENE_PATH := "res://src/main/game.tscn"

var _settings := SettingsMenu.new()
var _controls := ControlsHelp.new()


func _ready() -> void:
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = _background()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 120)
	add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "PERCY FRONTIER"
	col.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"HeaderLabel"
	sub.text = "전투 시험 단계 · v%s" % ProjectSettings.get_setting("application/config/version", "0")
	col.add_child(sub)
	var desc := Label.new()
	desc.theme_type_variation = &"MutedLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(1000, 0)
	desc.text = "\n".join([
		"이 빌드는 기획서 §25.1의 첫 단계인 '전투 시험' 빌드입니다. 회색 상자 전장에서 조작감, 타격감, 전투 규칙을 검증합니다.",
		"",
		"포함: 1인칭 이동·회피·난간 넘기 / 총기 5종(권총·소총·산탄총·에너지·저격)과 근접 무기 2종 / 몬스터 스킬 4종과 분석도 해금 /",
		"살인토끼·바위등 돌격수·포자 사수와 훈련용 표적 / 부위 판정·장갑 파괴·상태이상·패링 / 사망과 거점 부활 / 설정·키 재설정",
		"",
		"아직 없음: 저장·불러오기, 인벤토리·지도·퀘스트 화면, 퍼시 마을과 이야기, 게임패드, 정식 그래픽·사운드",
	])
	col.add_child(desc)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	col.add_child(spacer)
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(420, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(buttons)
	var start := _button(buttons, "전투 시험장 입장", _start)
	_button(buttons, "설정", func() -> void: _settings.open())
	_button(buttons, "조작 안내", func() -> void: _controls.open())
	_button(buttons, "종료", func() -> void: get_tree().quit())
	add_child(_settings)
	add_child(_controls)
	start.grab_focus.call_deferred()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"MenuButtonLarge"
	b.pressed.connect(func() -> void:
		Sfx.play_ui(&"ui_click")
		callback.call())
	parent.add_child(b)
	return b


func _start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


static func _background() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.1, 0.16, 0.2))
	g.set_color(1, Color(0.02, 0.03, 0.05))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.25, 0.35)
	t.fill_to = Vector2(1.2, 1.1)
	t.width = 512
	t.height = 512
	return t

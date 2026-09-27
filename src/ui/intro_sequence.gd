class_name IntroSequence
extends CanvasLayer
## 새 게임 도입부(기획서 §3.2): 강하선이 추락한 뒤 공명 장치가 깨어나며 상황을 알려 준다.
## 검은 화면에 공명 장치의 기록이 한 줄씩 찍히고, 화면이 밝아지며 경계 숲이 보인다.
## 아무 키나 누르면 건너뛸 수 있다.

signal finished

const CHAR_TIME := 0.028
const LINE_PAUSE := 0.45
const FADE_TIME := 1.6

var lines: Array[String] = []

var _bg: ColorRect
var _box: VBoxContainer
var _labels: Array[Label] = []
var _line: int = 0
var _chars: float = 0.0
var _pause: float = 0.6
var _fading: float = -1.0
var _done: bool = false


static func lines_for(character_name: String, origin_name: String) -> Array[String]:
	return [
		"공명 장치 기동 … 자가 진단 완료",
		"사용자 확인: %s%s" % [character_name, " · " + origin_name if origin_name != "" else ""],
		"생체 동기화 … 100%",
		"경고: 강하선 추락. 귀환 신호 없음. 통신 두절.",
		"약한 구조 신호 수신 — 발신지: 동쪽, 정착지 「퍼시」 추정",
		"주변 관측: 프론티어 현상 — 경계 숲",
		"권고: 신호를 따라 동쪽으로 이동하십시오.",
	]


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 1)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 220)
	margin.add_theme_constant_override("margin_top", 260)
	add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	margin.add_child(_box)
	for i in lines.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", Color(1.0, 0.72, 0.4) if lines[i].begins_with("경고") else Color(0.55, 0.92, 1.0))
		l.visible_characters = 0
		l.text = "› " + lines[i]
		_box.add_child(l)
		_labels.append(l)
	var hint := Label.new()
	hint.text = "아무 키나 누르면 건너뜁니다"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-360, -60)
	add_child(hint)


func _input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		skip()


func skip() -> void:
	if _fading < 0.0:
		for l in _labels:
			l.visible_characters = -1
		_fading = 0.0


func _process(delta: float) -> void:
	if _done:
		return
	if _fading >= 0.0:
		_fading += delta
		var t := clampf(_fading / FADE_TIME, 0.0, 1.0)
		_bg.color.a = 1.0 - t
		_box.modulate.a = 1.0 - t
		if t >= 1.0:
			_finish()
		return
	if _pause > 0.0:
		_pause -= delta
		return
	if _line >= _labels.size():
		_pause = 0.0
		_fading = 0.0
		return
	var l := _labels[_line]
	_chars += delta / CHAR_TIME
	l.visible_characters = int(_chars)
	if l.visible_characters >= l.text.length():
		l.visible_characters = -1
		if l.visible_characters == -1 and _line % 2 == 0:
			Sfx.play_ui(&"ui_click", -12.0)
		_line += 1
		_chars = 0.0
		_pause = LINE_PAUSE * (2.0 if _line == _labels.size() else 1.0)


func _finish() -> void:
	_done = true
	finished.emit()
	queue_free()

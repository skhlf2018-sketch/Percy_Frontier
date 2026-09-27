class_name SystemBanner
extends Control
## 공명 장치 알림 띠: 레벨 업, 지역 발견, 스킬 습득, 유니크 시나리오처럼 기억에 남아야 할 순간을
## 화면 위쪽 가운데에 크게 띄운다. 여러 개가 겹치면 차례로 보여 준다.

const SHOW_TIME := 2.8
const OPEN_TIME := 0.2
const CLOSE_TIME := 0.45
const ACCENTS := {
	GameEvents.AnnounceKind.LEVEL_UP: Color(1.0, 0.84, 0.4),
	GameEvents.AnnounceKind.DISCOVERY: Color(0.55, 0.95, 0.85),
	GameEvents.AnnounceKind.SKILL: Color(0.6, 0.78, 1.0),
	GameEvents.AnnounceKind.QUEST: Color(0.92, 0.92, 0.85),
	GameEvents.AnnounceKind.UNIQUE: Color(0.85, 0.45, 1.0),
	GameEvents.AnnounceKind.SYSTEM: Color(0.55, 0.9, 0.98),
}
const HEADERS := {
	GameEvents.AnnounceKind.LEVEL_UP: "공명 장치 · 성장",
	GameEvents.AnnounceKind.DISCOVERY: "공명 장치 · 탐사 기록",
	GameEvents.AnnounceKind.SKILL: "공명 장치 · 스킬 기록",
	GameEvents.AnnounceKind.QUEST: "공명 장치 · 의뢰",
	GameEvents.AnnounceKind.UNIQUE: "공명 장치 · 경고 — 미측정 개체",
	GameEvents.AnnounceKind.SYSTEM: "공명 장치",
}
const SOUNDS := {
	GameEvents.AnnounceKind.LEVEL_UP: &"level_up",
	GameEvents.AnnounceKind.DISCOVERY: &"discover",
	GameEvents.AnnounceKind.SKILL: &"unlock",
	GameEvents.AnnounceKind.QUEST: &"notice",
	GameEvents.AnnounceKind.UNIQUE: &"unique_sting",
	GameEvents.AnnounceKind.SYSTEM: &"notice",
}

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _time: float = 0.0
var _header: Label
var _title: Label
var _subtitle: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header = _make_label(18, Color(0.7, 0.9, 0.95))
	_title = _make_label(40, Color(1, 1, 1))
	_subtitle = _make_label(20, Color(0.85, 0.9, 0.92))
	GameEvents.announcement.connect(push)
	visible = false


func _make_label(size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"HudLabel"
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func push(title: String, subtitle: String, kind: int) -> void:
	# 같은 알림이 연달아 쌓이지 않게 한다.
	for q in _queue:
		if q.title == title:
			return
	_queue.append({"title": title, "subtitle": subtitle, "kind": kind})


func is_showing() -> bool:
	return not _current.is_empty()


func _process(delta: float) -> void:
	if _current.is_empty():
		if _queue.is_empty():
			visible = false
			return
		_current = _queue.pop_front()
		_time = 0.0
		var kind: int = _current.kind
		_header.text = HEADERS.get(kind, "공명 장치")
		_title.text = _current.title
		_subtitle.text = _current.subtitle
		_subtitle.visible = _current.subtitle != ""
		Sfx.play_ui(SOUNDS.get(kind, &"notice"), -3.0)
		visible = true
	_time += delta
	var total := OPEN_TIME + SHOW_TIME + CLOSE_TIME
	if _time >= total:
		_current = {}
		return
	var open := clampf(_time / OPEN_TIME, 0.0, 1.0)
	var fade := 1.0 - clampf((_time - OPEN_TIME - SHOW_TIME) / CLOSE_TIME, 0.0, 1.0)
	modulate.a = fade
	_layout(open)
	queue_redraw()


func _layout(open: float) -> void:
	var w := size.x
	_header.position = Vector2(0, 8)
	_header.size = Vector2(w, 24)
	_title.position = Vector2(0, 34)
	_title.size = Vector2(w, 50)
	_subtitle.position = Vector2(0, 88)
	_subtitle.size = Vector2(w, 28)
	var text_alpha := clampf((open - 0.5) * 2.0, 0.0, 1.0)
	for l in [_header, _title, _subtitle]:
		l.modulate.a = text_alpha


func _draw() -> void:
	if _current.is_empty():
		return
	var kind: int = _current.kind
	var accent: Color = ACCENTS.get(kind, Color(0.55, 0.9, 0.98))
	var open := clampf(_time / OPEN_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - open, 3.0)
	var w := size.x * (0.35 + 0.65 * eased)
	var h := 124.0 if _subtitle.visible else 96.0
	var x0 := (size.x - w) * 0.5
	var bg := Color(0.02, 0.06, 0.09, 0.78)
	draw_rect(Rect2(x0, 0, w, h), bg)
	# 위아래 빛나는 선과 양 끝 표식
	draw_rect(Rect2(x0, 0, w, 2), accent)
	draw_rect(Rect2(x0, h - 2, w, 2), Color(accent, 0.7))
	draw_rect(Rect2(x0 - 1, -3, 18, 3), accent)
	draw_rect(Rect2(x0 + w - 17, -3, 18, 3), accent)
	draw_rect(Rect2(x0 - 1, h, 18, 3), Color(accent, 0.7))
	draw_rect(Rect2(x0 + w - 17, h, 18, 3), Color(accent, 0.7))
	# 흐르는 빛
	var sweep := fmod(_time * 0.6, 1.0)
	draw_rect(Rect2(x0 + w * sweep - 40, 0, 80, 2), Color(1, 1, 1, 0.5 * (1.0 - sweep)))

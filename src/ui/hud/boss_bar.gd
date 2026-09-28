class_name BossBar
extends Control
## 보스 체력바(화면 위 가운데, 기획서 §16·§22.1): 이름과 단계, 체력, 단계가 바뀌는 눈금, 방금 깎인 만큼 옅게 남는 자국,
## 약점이 드러났을 때의 알림. 보스와 싸우는 동안에만 보인다.

const FILL := Color(0.82, 0.2, 0.16)
const TRAIL := Color(1.0, 0.86, 0.7, 0.75)
const BACK := Color(0.05, 0.05, 0.06, 0.78)
const EDGE := Color(1.0, 1.0, 1.0, 0.18)
const HINT_COLOR := Color(1.0, 0.72, 0.3)
const BAR_HEIGHT := 14.0

var boss_name: String = ""
var ratio: float = 1.0
var phase: int = 1
## 단계가 바뀌는 체력 비율(눈금)
var marks: Array[float] = []
var hint: String = ""
var hint_hot: bool = false

var _trail: float = 1.0
var _trail_hold: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 매 프레임 상태를 넣는다.
func set_state(p_name: String, p_ratio: float, p_phase: int, p_marks: Array[float], p_hint: String, hot: bool) -> void:
	if p_name != boss_name:
		_trail = p_ratio
	boss_name = p_name
	if p_ratio < ratio:
		_trail_hold = 0.6
	elif p_ratio > _trail:
		_trail = p_ratio
	ratio = clampf(p_ratio, 0.0, 1.0)
	phase = p_phase
	marks = p_marks
	hint = p_hint
	hint_hot = hot
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	if _trail_hold > 0.0:
		_trail_hold -= delta
	elif _trail > ratio:
		_trail = maxf(ratio, _trail - delta * 0.35)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var w := size.x
	var title := "%s  ·  보스  ·  %d단계" % [boss_name, phase]
	draw_string_outline(font, Vector2(0, 24), title, HORIZONTAL_ALIGNMENT_CENTER, w, 24, 6, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, 24), title, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(1.0, 0.9, 0.82))
	var bar := Rect2(Vector2(0, 34), Vector2(w, BAR_HEIGHT))
	draw_rect(bar.grow(2.0), BACK)
	if _trail > ratio:
		draw_rect(Rect2(bar.position + Vector2(w * ratio, 0), Vector2(w * (_trail - ratio), BAR_HEIGHT)), TRAIL)
	draw_rect(Rect2(bar.position, Vector2(w * ratio, BAR_HEIGHT)), FILL)
	# 위쪽 반사광
	draw_rect(Rect2(bar.position, Vector2(w * ratio, BAR_HEIGHT * 0.35)), Color(1, 1, 1, 0.12))
	draw_rect(bar, EDGE, false, 1.0)
	for m in marks:
		var x := w * m
		draw_line(Vector2(x, bar.position.y - 4.0), Vector2(x, bar.end.y + 4.0), Color(1, 1, 1, 0.75), 2.0)
	if hint != "":
		var a := 0.75 + 0.25 * sin(_pulse * 9.0) if hint_hot else 0.8
		var col := Color(HINT_COLOR, a) if hint_hot else Color(0.8, 0.84, 0.86, a)
		draw_string_outline(font, Vector2(0, bar.end.y + 24.0), hint, HORIZONTAL_ALIGNMENT_CENTER, w, 18, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, bar.end.y + 24.0), hint, HORIZONTAL_ALIGNMENT_CENTER, w, 18, col)

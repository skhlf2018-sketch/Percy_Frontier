class_name NoticeFeed
extends VBoxContainer
## 알림 목록(분석도, 스킬 해금, 회수, 경고). 잠시 뒤 사라진다.

const LIFE := 4.5
const MAX_ITEMS := 6
const COLORS := {
	GameEvents.NoticeKind.INFO: Color(0.92, 0.95, 0.97),
	GameEvents.NoticeKind.ANALYSIS: Color(0.5, 0.88, 1.0),
	GameEvents.NoticeKind.UNLOCK: Color(1.0, 0.82, 0.35),
	GameEvents.NoticeKind.PICKUP: Color(0.62, 0.92, 0.55),
	GameEvents.NoticeKind.WARNING: Color(1.0, 0.6, 0.4),
}


func push(text: String, kind: int) -> void:
	# 같은 문구가 이어지면 새로 쌓지 않고 수명만 되살린다(연속 경고 도배 방지).
	for child in get_children():
		if child is Label and child.text == text:
			child.set_meta("t", 0.0)
			child.modulate.a = 1.0
			return
	var l := Label.new()
	l.theme_type_variation = &"HudLabel"
	l.add_theme_font_size_override("font_size", 20)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", COLORS.get(kind, Color.WHITE))
	l.set_meta("t", 0.0)
	add_child(l)
	while get_child_count() > MAX_ITEMS:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()
	match kind:
		GameEvents.NoticeKind.UNLOCK:
			Sfx.play_ui(&"unlock")
		GameEvents.NoticeKind.ANALYSIS:
			Sfx.play_ui(&"notice", -6.0)


func _process(delta: float) -> void:
	for child in get_children():
		var t: float = child.get_meta("t", 0.0) + delta
		child.set_meta("t", t)
		if t > LIFE - 0.6:
			child.modulate.a = clampf((LIFE - t) / 0.6, 0.0, 1.0)
		if t >= LIFE:
			child.queue_free()

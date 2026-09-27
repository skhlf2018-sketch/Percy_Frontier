class_name ControlsHelp
extends MenuPanel
## 조작 안내. 현재 키 설정을 그대로 읽어 보여 준다(설정에서 바꾸면 여기에도 반영된다).

var _grid: GridContainer


func _init() -> void:
	super._init()
	panel.custom_minimum_size = Vector2(980, 0)
	set_title("조작 안내")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 6)
	inner.add_child(_grid)
	var rules := Label.new()
	rules.theme_type_variation = &"MutedLabel"
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(900, 0)
	rules.text = "\n".join([
		"· 공격 전조: 노란 마름모(◇)와 짧은 두 음은 패링할 수 있는 공격, 빨간 삼각형(▲)과 낮은 울음은 패링할 수 없는 공격입니다.",
		"· 패링: 근접 무기를 들고 공격이 닿기 직전에 방어를 시작하세요. 성공하면 적이 경직되고 공명을 얻습니다.",
		"· 회피: 회피 직후 짧은 시간 동안 피해를 받지 않습니다. 패링할 수 없는 공격은 회피하세요.",
		"· 공명: 약점 명중, 장갑 파괴, 패링, 처치로 모이고 몬스터 스킬에 쓰입니다.",
		"· 분석도: 몬스터를 관찰·처치하고 약점·부위 파괴·패링·회피를 하면 오릅니다. 100%가 되면 그 몬스터의 스킬이 확정 해금됩니다.",
		"· 장갑은 근접 공격과 에너지 무기에 약합니다. 장갑을 부수면 적의 행동이 바뀝니다.",
	])
	inner.add_child(rules)
	add_button(body, "닫기", close)
	Settings.bindings_changed.connect(_refresh)


func open() -> void:
	_refresh()
	super.open()


func _refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for entry in Settings.REBINDABLE:
		var name_label := Label.new()
		name_label.text = entry[1]
		_grid.add_child(name_label)
		var key_label := Label.new()
		key_label.text = Settings.binding_text(entry[0])
		key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		_grid.add_child(key_label)
	var esc_name := Label.new()
	esc_name.text = "메뉴"
	_grid.add_child(esc_name)
	var esc_key := Label.new()
	esc_key.text = "Esc (고정)"
	esc_key.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_grid.add_child(esc_key)

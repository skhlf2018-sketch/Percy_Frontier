class_name StatusWindow
extends MenuPanel
## 공명 장치 창(기본 키 Tab): 사용자 정보·능력치 분배, 장비, 스킬 배치, 몬스터 도감.
## VRMMO식 상태창을 세계관 안의 탐사 장비(공명 장치) 화면으로 보여 준다.

const ACCENT := Color(0.45, 0.88, 0.98)
const MUTED := Color(0.66, 0.74, 0.78)
const TAB_STATUS := 0
const TAB_GEAR := 1
const TAB_SKILLS := 2
const TAB_BESTIARY := 3

var player: Player

var _tabs: TabContainer
var _pending: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var _status_box: VBoxContainer
var _gear_box: VBoxContainer
var _skills_box: VBoxContainer
var _bestiary_box: VBoxContainer
var _hint: Label


func _init() -> void:
	super._init()
	panel.custom_minimum_size = Vector2(1260, 0)
	panel.add_theme_stylebox_override("panel", holo_style())
	set_title("공명 장치 · 사용자 정보")
	_title_label.add_theme_color_override("font_color", ACCENT)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(1220, 640)
	body.add_child(_tabs)
	_status_box = _tab("상태")
	_gear_box = _tab("장비")
	_skills_box = _tab("스킬")
	_bestiary_box = _tab("도감")
	_tabs.tab_changed.connect(func(_t: int) -> void: _refresh())
	_hint = Label.new()
	_hint.theme_type_variation = &"MutedLabel"
	_hint.text = "Tab · Esc: 닫기"
	body.add_child(_hint)


static func holo_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.1, 0.94)
	sb.border_color = Color(0.45, 0.88, 0.98, 0.85)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.shadow_color = Color(0.3, 0.8, 1.0, 0.18)
	sb.shadow_size = 14
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 20
	return sb


func setup(p: Player) -> void:
	player = p


func open_tab(tab: int) -> void:
	_tabs.current_tab = clampi(tab, 0, _tabs.get_tab_count() - 1)
	open()


func open() -> void:
	_pending = [0, 0, 0, 0, 0, 0, 0]
	_refresh()
	super.open()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"status_window"):
		get_viewport().set_input_as_handled()
		Sfx.play_ui(&"ui_click")
		close()
		return
	super._unhandled_input(event)


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title)
	return v


func _refresh() -> void:
	match _tabs.current_tab:
		TAB_STATUS:
			_build_status()
		TAB_GEAR:
			_build_gear()
		TAB_SKILLS:
			_build_skills()
		TAB_BESTIARY:
			_build_bestiary()


static func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


## 글자 한 줄. 세로 목록(VBox)에 넣는 긴 설명만 줄바꿈한다(표 안에서 줄바꿈하면 글자가 한 자씩 세로로 선다).
func _text(parent: Node, text: String, size_px: int = 20, color := Color(0.92, 0.95, 0.96)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if parent is VBoxContainer:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _section(parent: Node, title: String) -> void:
	var l := _text(parent, title, 22, ACCENT)
	l.add_theme_constant_override("outline_size", 0)
	var line := ColorRect.new()
	line.color = Color(ACCENT, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)


# --- 상태·능력치 ---

func _pending_total() -> int:
	var n := 0
	for v in _pending:
		n += v
	return n


func _build_status() -> void:
	_clear(_status_box)
	var pr := GameState.progress
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	_status_box.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	_text(left, pr.character_name, 36)
	var origin_name := pr.origin_name()
	_text(left, "Lv %d%s" % [pr.level, "  ·  " + origin_name if origin_name != "" else ""], 22, MUTED)
	var need := PlayerProgress.xp_to_next(pr.level)
	var xp := ProgressBar.new()
	xp.custom_minimum_size = Vector2(0, 14)
	xp.show_percentage = false
	xp.max_value = need
	xp.value = pr.xp
	left.add_child(xp)
	_text(left, "경험치 %d / %d   (누적 %d)" % [pr.xp, need, pr.total_xp], 18, MUTED)
	_section(left, "자원")
	var derived := [
		["최대 HP", "%d" % int(pr.max_hp())],
		["최대 스태미나", "%d" % int(pr.max_stamina())],
		["최대 공명", "%d" % int(pr.max_resonance())],
		["이동 속도", "×%.3f" % pr.move_speed_mult()],
		["회피 거리", "×%.2f" % pr.dodge_distance_mult()],
		["반동", "×%.2f" % pr.recoil_mult()],
		["재장전 속도", "×%.2f" % pr.reload_speed_mult()],
		["근접 피해", "×%.3f" % pr.melee_damage_mult()],
		["스킬 위력", "×%.3f" % pr.skill_power_mult()],
		["드롭 확률", "×%.2f" % pr.drop_chance_mult()],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	left.add_child(grid)
	for d in derived:
		_text(grid, d[0], 18, MUTED)
		_text(grid, d[1], 18)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	var remaining := pr.unspent_points - _pending_total()
	_section(right, "능력치")
	_text(right, "남은 능력 포인트: %d" % remaining, 22, Color(1.0, 0.84, 0.4) if remaining > 0 else MUTED)
	var stats := GridContainer.new()
	stats.columns = 5
	stats.add_theme_constant_override("h_separation", 16)
	stats.add_theme_constant_override("v_separation", 6)
	right.add_child(stats)
	var desc := Label.new()
	desc.custom_minimum_size = Vector2(0, 56)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", MUTED)
	desc.text = "능력치에 마우스를 올리면 설명이 나옵니다. 레벨이 오를 때마다 포인트 %d개를 얻습니다." % PlayerProgress.POINTS_PER_LEVEL
	for i in PlayerProgress.STAT_COUNT:
		var name_l := _text(stats, "%s  %s" % [PlayerProgress.STAT_NAMES[i], PlayerProgress.STAT_KEYS[i]], 20)
		name_l.custom_minimum_size = Vector2(150, 0)
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		var idx := i
		name_l.mouse_entered.connect(func() -> void: desc.text = PlayerProgress.STAT_DESCRIPTIONS[idx])
		var value_text := "%d" % pr.stat(i)
		if _pending[i] > 0:
			value_text += "  (+%d)" % _pending[i]
		_text(stats, value_text, 20, Color(1.0, 0.84, 0.4) if _pending[i] > 0 else Color(1, 1, 1)).custom_minimum_size = Vector2(90, 0)
		var minus := add_button(stats, "−", func() -> void:
			_pending[idx] = maxi(_pending[idx] - 1, 0)
			_build_status())
		minus.disabled = _pending[i] <= 0
		minus.custom_minimum_size = Vector2(44, 0)
		var plus := add_button(stats, "+", func() -> void:
			if GameState.progress.unspent_points - _pending_total() > 0:
				_pending[idx] += 1
			_build_status())
		plus.disabled = remaining <= 0
		plus.custom_minimum_size = Vector2(44, 0)
		_text(stats, pr.stat_effect_text(i), 17, MUTED)
	right.add_child(desc)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(buttons)
	var undo := add_button(buttons, "되돌리기", func() -> void:
		_pending = [0, 0, 0, 0, 0, 0, 0]
		_build_status())
	undo.disabled = _pending_total() == 0
	var confirm := add_button(buttons, "확정", func() -> void:
		if GameState.progress.apply_allocation(_pending):
			Sfx.play_ui(&"ui_confirm")
		_pending = [0, 0, 0, 0, 0, 0, 0]
		_build_status())
	confirm.disabled = _pending_total() == 0


# --- 장비 ---

func _build_gear() -> void:
	_clear(_gear_box)
	if player == null:
		return
	var w := player.weapons
	_section(_gear_box, "총기")
	for d: WeaponData in [w.primary, w.secondary]:
		if d == null:
			continue
		var stats := "피해 %s · 분당 %d발 · %s" % [
			("%d×%d" % [int(d.damage), d.pellets]) if d.pellets > 1 else "%d" % int(d.damage),
			int(d.rounds_per_minute), "과열식" if d.uses_heat else "탄창 %d" % d.magazine_size]
		_text(_gear_box, "%s  ·  %s  ·  %s" % [d.display_name, d.class_label(), ItemRarity.tier_name(d.rarity)], 22)
		_text(_gear_box, stats, 18, MUTED)
		_text(_gear_box, d.description, 17, MUTED)
	_section(_gear_box, "근접 무기")
	var m := w.melee
	if m:
		_text(_gear_box, "%s  ·  %s" % [m.display_name, ItemRarity.tier_name(m.rarity)], 22)
		_text(_gear_box, "약공격 %d · 강공격 %d · 패링 %.2f초" % [int(m.light_damage), int(m.heavy_damage), m.parry_window], 18, MUTED)
		_text(_gear_box, m.description, 17, MUTED)
	_section(_gear_box, "소모품과 탄약")
	var items: Array[String] = []
	for c in player.consumables:
		items.append("%s %d" % [c.display_name, int(player.consumable_counts.get(c.id, 0))])
	_text(_gear_box, "  ·  ".join(items), 19)
	var ammo: Array[String] = []
	for t in AmmoInventory.TYPES:
		ammo.append("%s %d" % [AmmoInventory.type_name(t), player.ammo.get_count(t)])
	_text(_gear_box, "  ·  ".join(ammo), 19, MUTED)
	_text(_gear_box, "무기는 퍼시의 무기 공방과 거점의 무기 거치대에서 바꿀 수 있습니다.", 17, MUTED)


# --- 스킬 ---

func _build_skills() -> void:
	_clear(_skills_box)
	_section(_skills_box, "스킬 슬롯 (키 4 · 5 · 6 · 7)")
	var slots: Array[String] = []
	for i in GameState.SKILL_SLOT_COUNT:
		var sid: StringName = GameState.skill_slots[i]
		var sk := GameDB.skill(sid) if sid != &"" else null
		slots.append("%d: %s" % [i + 1, sk.display_name if sk else "비어 있음"])
	_text(_skills_box, "   ".join(slots), 20)
	_section(_skills_box, "습득한 몬스터 스킬")
	for sid in GameState.unlocked_skills:
		var sk := GameDB.skill(sid)
		if sk == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_skills_box.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var slot := GameState.skill_slots.find(sid)
		_text(info, "%s  ·  %s%s" % [sk.display_name, sk.role_label(), "  ·  슬롯 %d" % (slot + 1) if slot >= 0 else ""], 21)
		_text(info, "공명 %d · 재사용 %.1f초 — %s" % [int(sk.resonance_cost), sk.cooldown, sk.description], 17, MUTED)
		for i in GameState.SKILL_SLOT_COUNT:
			var idx := i
			var skill_id := sid
			var b := add_button(row, "%d" % (i + 1), func() -> void:
				GameState.assign_skill(skill_id, idx)
				_build_skills())
			b.custom_minimum_size = Vector2(48, 0)
			b.disabled = slot == i
			b.tooltip_text = "슬롯 %d에 넣기" % (i + 1)
	_text(_skills_box, "몬스터를 관찰·처치·약점 공격·패링·회피하면 분석도가 오르고, 100%가 되면 그 몬스터의 스킬을 얻습니다.", 17, MUTED)


# --- 도감 ---

func _build_bestiary() -> void:
	_clear(_bestiary_box)
	var hidden := 0
	for data: EnemyData in GameDB.ENEMIES:
		if not data.is_analyzable():
			continue
		if not GameState.bestiary.is_discovered(data.id):
			hidden += 1
			continue
		_section(_bestiary_box, "%s  ·  %s  ·  Lv %d" % [data.display_name, data.tier_label(), data.level])
		var analysis := GameState.bestiary.analysis_of(data.id)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 12)
		bar.show_percentage = false
		bar.max_value = Bestiary.MAX_ANALYSIS
		bar.value = analysis
		_bestiary_box.add_child(bar)
		var sk := GameDB.skill(data.analysis_skill)
		var unlocked := sk != null and GameState.is_skill_unlocked(sk.id)
		_text(_bestiary_box, "분석도 %d%%  ·  %s" % [int(analysis),
			("스킬 습득: " + sk.display_name) if unlocked else ("분석 완료 시 스킬: " + (sk.display_name if sk else "없음"))], 18,
			Color(0.7, 1.0, 0.8) if unlocked else MUTED)
		_text(_bestiary_box, "%s · %s" % [data.family, data.combat_role], 17, MUTED)
		_text(_bestiary_box, data.description, 17)
	if hidden > 0:
		_text(_bestiary_box, "아직 만나지 못한 기록 %d건" % hidden, 18, MUTED)

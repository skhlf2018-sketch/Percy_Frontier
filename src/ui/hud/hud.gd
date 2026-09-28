class_name Hud
extends CanvasLayer
## 전투 HUD(기획서 §22.1): HP·스태미나·공명, 현재 무기와 탄약, 장착 스킬과 재사용 상태, 상태이상,
## 필요할 때만 나타나는 약점·부위 피드백. 1920x1080 기준으로 배치하고 화면 비율에 맞춰 늘어난다.

const MUTED := Color(0.72, 0.78, 0.8)
const WARNING_COLOR := Color(1.0, 0.55, 0.4)

var player: Player

var _root: Control
var _hp: StatBar
var _stamina: StatBar
var _resonance: StatBar
var _status: StatusChips
var _weapon_name: Label
var _weapon_detail: Label
var _ammo: Label
var _reserve: Label
var _heat: StatBar
var _slot_labels: Array[Label] = []
var _skill_slots: Array[SkillSlot] = []
var _consumable_slots: Array[SkillSlot] = []
var _quick_label: Label
var _crosshair: Crosshair
var _hit_markers: HitMarkers
var _damage_indicator: DamageIndicator
var _enemy_overlay: EnemyOverlay
var _scope: ScopeOverlay
var _prompt: Label
var _center_flash: Label
var _notices: NoticeFeed
var _vignette: TextureRect
var _death_panel: Control
var _banner: SystemBanner
## 간발의 회피 때 화면이 잠깐 푸르게 번쩍인다.
var _tint: ColorRect
var _tint_amount: float = 0.0
var _save_label: Label
var _save_time: float = 0.0
var _level_label: Label
var _xp_bar: StatBar
## 필드 전용: 나침반, 지역·시각, 의뢰 추적
var _field: FieldWorld
var _compass: CompassBar
var _area_label: Label
var _tracker: VBoxContainer
var _tracker_title: Label
var _tracker_step: Label
var _tracker_dist: Label
var _silver_label: Label
## 바닥의 무기를 바라볼 때 지금 무기와 비교해 보여 주는 칸(기획서 §11.5)
var _compare: PanelContainer
var _compare_text: RichTextLabel
## 유니크 조우: 이름(정체를 모르면 ???)과 흥미 게이지
var _unique_panel: VBoxContainer
var _unique_name: Label
var _unique_hint: Label
var _unique_bar: StatBar
## 보스 체력바(보스와 싸우는 동안)
var _boss_bar: BossBar

var _hit_sound_cooldown: float = 0.0
var _damage_flash: float = 0.0
var _center_flash_time: float = 0.0


func _ready() -> void:
	layer = 5
	_build()


# --- 구성 ---

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vignette = TextureRect.new()
	_vignette.texture = _make_vignette()
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.modulate.a = 0.0
	_full(_vignette)

	_tint = ColorRect.new()
	_tint.color = Color(0.45, 0.95, 1.0, 0.0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(_tint)

	_enemy_overlay = EnemyOverlay.new()
	_full(_enemy_overlay)
	_scope = ScopeOverlay.new()
	_scope.visible = false
	_full(_scope)
	_damage_indicator = DamageIndicator.new()
	_full(_damage_indicator)
	_crosshair = Crosshair.new()
	_full(_crosshair)
	_hit_markers = HitMarkers.new()
	_full(_hit_markers)

	# 왼쪽 아래: 레벨과 이름, 상태이상, HP, 스태미나, 공명, 경험치
	_level_label = _label("", 22, &"HudLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_place(_level_label, Vector2(0, 1), Vector2(40, -206), Vector2(520, 32))
	_status = StatusChips.new()
	_place(_status, Vector2(0, 1), Vector2(40, -168), Vector2(520, 30))
	_hp = StatBar.new()
	_hp.label = "HP"
	_hp.fill_color = Color(0.86, 0.26, 0.24)
	_place(_hp, Vector2(0, 1), Vector2(40, -128), Vector2(440, 30))
	_stamina = StatBar.new()
	_stamina.label = "스태미나"
	_stamina.fill_color = Color(0.45, 0.8, 0.4)
	_place(_stamina, Vector2(0, 1), Vector2(40, -92), Vector2(440, 20))
	_resonance = StatBar.new()
	_resonance.label = "공명"
	_resonance.fill_color = Color(0.45, 0.62, 1.0)
	_place(_resonance, Vector2(0, 1), Vector2(40, -66), Vector2(440, 24))
	_xp_bar = StatBar.new()
	_xp_bar.label = "EXP"
	_xp_bar.fill_color = Color(0.95, 0.82, 0.4)
	_place(_xp_bar, Vector2(0, 1), Vector2(40, -36), Vector2(440, 14))

	# 오른쪽 아래: 무기
	_weapon_name = _label("", 26, &"HudLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_weapon_name, Vector2(1, 1), Vector2(-600, -206), Vector2(560, 34))
	_weapon_detail = _label("", 18, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_weapon_detail.add_theme_color_override("font_color", MUTED)
	_place(_weapon_detail, Vector2(1, 1), Vector2(-600, -174), Vector2(560, 26))
	_ammo = _label("", 56, &"HudLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_ammo, Vector2(1, 1), Vector2(-420, -150), Vector2(220, 64))
	_reserve = _label("", 22, &"HudLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_place(_reserve, Vector2(1, 1), Vector2(-192, -120), Vector2(170, 30))
	_heat = StatBar.new()
	_heat.label = "열"
	_heat.fill_color = Color(1.0, 0.55, 0.2)
	_heat.visible = false
	_place(_heat, Vector2(1, 1), Vector2(-420, -120), Vector2(380, 22))
	for i in 3:
		var l := _label("", 17, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
		_place(l, Vector2(1, 1), Vector2(-600, -82 + i * 22), Vector2(560, 22))
		_slot_labels.append(l)

	# 아래 가운데: 스킬 4칸 + 소모품 2칸
	var slot_size := Vector2(86, 86)
	var total_w := slot_size.x * 6 + 8 * 5 + 18
	var x0 := -total_w * 0.5
	for i in 4:
		var s := SkillSlot.new()
		_place(s, Vector2(0.5, 1), Vector2(x0 + i * (slot_size.x + 8), -118), slot_size)
		_skill_slots.append(s)
	for i in 2:
		var s := SkillSlot.new()
		_place(s, Vector2(0.5, 1), Vector2(x0 + 18 + (4 + i) * (slot_size.x + 8), -118), slot_size)
		_consumable_slots.append(s)
	_quick_label = _label("", 17, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_quick_label.add_theme_color_override("font_color", MUTED)
	_place(_quick_label, Vector2(0.5, 1), Vector2(-300, -146), Vector2(600, 24))

	# 가운데: 상호작용 안내, 순간 알림
	_prompt = _label("", 24, &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_place(_prompt, Vector2(0.5, 0.5), Vector2(-500, 90), Vector2(1000, 34))
	_center_flash = _label("", 30, &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_place(_center_flash, Vector2(0.5, 0.5), Vector2(-300, 40), Vector2(600, 40))

	# 위 가운데: 공명 장치 알림 띠
	_banner = SystemBanner.new()
	_place(_banner, Vector2(0.5, 0), Vector2(-430, 120), Vector2(860, 130))

	# 오른쪽 아래 구석: 저장 표시(기획서 §20.2: 저장 중임을 명확히 표시)
	_save_label = _label("", 18, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_save_label.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	_place(_save_label, Vector2(1, 1), Vector2(-420, -30), Vector2(400, 24))

	# 오른쪽 위: 알림
	_notices = NoticeFeed.new()
	_notices.alignment = BoxContainer.ALIGNMENT_BEGIN
	_place(_notices, Vector2(1, 0), Vector2(-760, 30), Vector2(730, 300))

	var mark := _label("Percy Frontier · 개발 빌드 v%s · ESC 메뉴 · Tab 공명 장치 · M 지도 · J 의뢰" % ProjectSettings.get_setting("application/config/version", "0"),
		15, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
	mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_place(mark, Vector2(0, 0), Vector2(20, 14), Vector2(760, 22))

	# 위 가운데: 나침반과 지역·시각(필드 전용)
	_compass = CompassBar.new()
	_compass.visible = false
	_place(_compass, Vector2(0.5, 0), Vector2(-380, 12), Vector2(760, 58))
	_area_label = _label("", 17, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_area_label.add_theme_color_override("font_color", MUTED)
	_area_label.visible = false
	_place(_area_label, Vector2(0.5, 0), Vector2(-380, 72), Vector2(760, 24))

	# 왼쪽 위: 추적 중인 의뢰(전투 중에는 옅어진다, 기획서 §22.1)
	_tracker = VBoxContainer.new()
	_tracker.add_theme_constant_override("separation", 2)
	_tracker.visible = false
	_place(_tracker, Vector2(0, 0), Vector2(40, 52), Vector2(520, 130))
	_tracker_title = _label("", 21, &"HudLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_tracker_title.add_theme_color_override("font_color", CompassBar.QUEST_COLOR)
	_tracker.add_child(_tracker_title)
	_tracker_step = _label("", 18, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_tracker_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker_step.custom_minimum_size = Vector2(520, 0)
	_tracker.add_child(_tracker_step)
	_tracker_dist = _label("", 16, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_tracker_dist.add_theme_color_override("font_color", MUTED)
	_tracker.add_child(_tracker_dist)

	# 아래 가운데 스킬 칸 위: 유니크 조우(이름과 흥미 게이지)
	_unique_panel = VBoxContainer.new()
	_unique_panel.add_theme_constant_override("separation", 3)
	_unique_panel.visible = false
	_place(_unique_panel, Vector2(0.5, 1), Vector2(-360, -250), Vector2(720, 96))
	_unique_name = _label("", 24, &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_unique_name.add_theme_color_override("font_color", Color(0.62, 0.9, 1.0))
	_unique_panel.add_child(_unique_name)
	_unique_bar = StatBar.new()
	_unique_bar.label = "포식자의 흥미"
	_unique_bar.fill_color = Color(0.35, 0.75, 1.0)
	_unique_bar.custom_minimum_size = Vector2(720, 16)
	_unique_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unique_panel.add_child(_unique_bar)
	_unique_hint = _label("살아남아라 — 패링과 간발의 회피로 흥미를 끌면 물러난다", 16, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_unique_hint.add_theme_color_override("font_color", MUTED)
	_unique_panel.add_child(_unique_hint)

	# 아래 가운데 스킬 칸 위: 보스 체력바(위쪽 알림 띠와 겹치지 않게)
	_boss_bar = BossBar.new()
	_boss_bar.visible = false
	_place(_boss_bar, Vector2(0.5, 1), Vector2(-430, -262), Vector2(860, 84))

	# 오른쪽 가운데: 무기 비교
	_compare = PanelContainer.new()
	_compare.add_theme_stylebox_override("panel", StatusWindow.holo_style())
	_compare.visible = false
	_place(_compare, Vector2(1, 0.5), Vector2(-620, -190), Vector2(580, 330))
	_compare_text = RichTextLabel.new()
	_compare_text.bbcode_enabled = true
	_compare_text.fit_content = true
	_compare_text.scroll_active = false
	_compare_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compare_text.add_theme_font_size_override("normal_font_size", 18)
	_compare_text.add_theme_font_size_override("bold_font_size", 21)
	_compare.add_child(_compare_text)

	# 왼쪽 아래 레벨 줄 위: 은화
	_silver_label = _label("", 17, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_silver_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_silver_label.visible = false
	_place(_silver_label, Vector2(0, 1), Vector2(40, -234), Vector2(520, 26))

	_death_panel = ColorRect.new()
	(_death_panel as ColorRect).color = Color(0.05, 0.0, 0.0, 0.6)
	_death_panel.visible = false
	_full(_death_panel)
	var title := _label("쓰러졌습니다", 64, &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -500
	title.offset_right = 500
	title.offset_top = -80
	title.offset_bottom = 0
	_death_panel.add_child(title)
	var sub := _label("마지막으로 휴식한 거점에서 다시 시작합니다. 레벨·장비·스킬·발견 기록은 유지됩니다.", 22,
		&"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.offset_left = -700
	sub.offset_right = 700
	sub.offset_top = 10
	sub.offset_bottom = 50
	_death_panel.add_child(sub)


func _full(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(ctrl)


## anchor 지점을 기준으로 pos 위치, size 크기에 둔다.
func _place(ctrl: Control, anchor: Vector2, pos: Vector2, size: Vector2) -> void:
	ctrl.anchor_left = anchor.x
	ctrl.anchor_right = anchor.x
	ctrl.anchor_top = anchor.y
	ctrl.anchor_bottom = anchor.y
	ctrl.offset_left = pos.x
	ctrl.offset_top = pos.y
	ctrl.offset_right = pos.x + size.x
	ctrl.offset_bottom = pos.y + size.y
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(ctrl)


func _label(text: String, font_size: int, variation: StringName, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _make_vignette() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.75, 0.0, 0.0, 0.85))
	g.add_point(0.55, Color(0.8, 0.0, 0.0, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)
	t.width = 256
	t.height = 256
	return t


# --- 연결 ---

func bind(p: Player) -> void:
	player = p
	_damage_indicator.player = p
	_enemy_overlay.player = p
	_enemy_overlay.camera = p.camera
	_status.status = p.status
	GameEvents.hit_confirmed.connect(_on_hit)
	GameEvents.player_damaged.connect(_on_player_damaged)
	GameEvents.notice.connect(_notices.push)
	GameEvents.parry_succeeded.connect(func(_e: Node) -> void: flash_center("패링!", Color(1.0, 0.9, 0.4)))
	GameEvents.attack_evaded.connect(func(_e: Node) -> void: flash_center("회피", Color(0.7, 0.9, 1.0)))
	GameEvents.perfect_evaded.connect(func(_e: Node) -> void:
		flash_center("간발의 회피! · 반격 기회", Color(0.55, 1.0, 0.95))
		_tint_amount = 1.0)
	p.weapons.technique_used.connect(func(technique_name: String) -> void:
		if technique_name == "반격":
			flash_center("반격!", Color(1.0, 0.85, 0.4))
		else:
			flash_center("기술 · " + technique_name, Color(0.6, 0.92, 1.0)))
	p.weapons.guard_broken.connect(func() -> void: flash_center("방어 붕괴", WARNING_COLOR))
	p.weapons.overheated.connect(func() -> void: flash_center("과열", Color(1.0, 0.6, 0.25)))
	p.skills.cast_failed.connect(func(_slot: int, reason: String) -> void:
		_notices.push(reason, GameEvents.NoticeKind.WARNING))
	p.skills.skill_cast.connect(func(slot: int, _skill: SkillData) -> void: _skill_slots[slot].flash())
	GameEvents.xp_gained.connect(func(amount: int, reason: String) -> void:
		_notices.push("경험치 +%d%s" % [amount, " · " + reason if reason != "" else ""], GameEvents.NoticeKind.INFO))
	p.died.connect(func() -> void: _death_panel.visible = true)
	p.respawned.connect(func() -> void: _death_panel.visible = false)


## 필드에서만 쓰는 표시(나침반, 지역·시각, 의뢰 추적, 은화)를 켠다.
func bind_field(f: FieldWorld) -> void:
	_field = f
	_compass.visible = true
	_area_label.visible = true
	_silver_label.visible = true


func notify(text: String, kind: int) -> void:
	_notices.push(text, kind)


func show_saving() -> void:
	_save_label.text = "● 저장 중… 게임을 끄지 마세요"
	_save_time = 2.0


func show_saved(ok: bool) -> void:
	_save_label.text = "● 저장 완료" if ok else "● 저장하지 못했습니다"
	_save_label.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0) if ok else WARNING_COLOR)
	_save_time = 2.2


func flash_center(text: String, color: Color) -> void:
	_center_flash.text = text
	_center_flash.add_theme_color_override("font_color", color)
	_center_flash_time = 0.7


func _on_hit(result: HitResult) -> void:
	_hit_markers.add(HitMarkers.type_for(result))
	_enemy_overlay.add_damage_number(result.position, result.damage, result.zone, result.hit_armor)
	if _hit_sound_cooldown > 0.0 or result.killed or result.armor_broken:
		return
	_hit_sound_cooldown = 0.045
	if result.hit_armor:
		Sfx.play(&"hit_armor", -3.0)
	elif result.is_weak_point():
		Sfx.play(&"hit_weak", -2.0)
	else:
		Sfx.play(&"hit_normal", -4.0)


func _on_player_damaged(amount: float, source_position: Vector3, blocked: bool) -> void:
	_damage_indicator.add(source_position, blocked)
	if not blocked and amount > 0.0:
		_damage_flash = clampf(amount / 30.0, 0.25, 0.8)


# --- 매 프레임 갱신 ---

func _process(delta: float) -> void:
	_hit_sound_cooldown = maxf(0.0, _hit_sound_cooldown - delta)
	if _tint_amount > 0.0:
		_tint_amount = maxf(0.0, _tint_amount - delta * 2.5)
		_tint.color.a = _tint_amount * 0.22
	if _save_time > 0.0:
		_save_time -= delta
		_save_label.modulate.a = clampf(_save_time / 0.5, 0.0, 1.0)
	if player == null or not is_instance_valid(player):
		return
	_update_vitals(delta)
	_update_weapon()
	_update_skills()
	_update_center(delta)
	if _field:
		_update_field(delta)


func _update_vitals(delta: float) -> void:
	var s := player.stats
	var hp_text := "%d / %d" % [ceili(s.hp), int(s.max_hp)]
	if s.shield > 0.0:
		hp_text = "보호막 %d · %s" % [ceili(s.shield), hp_text]
	if player.is_healing():
		hp_text = "회복 중 · " + hp_text
	_hp.set_state(s.hp / s.max_hp, hp_text, s.shield / s.max_hp)
	_stamina.label = "스태미나 · 탈진" if s.exhausted else "스태미나"
	_stamina.set_state(s.stamina / s.max_stamina, "%d" % int(s.stamina), 0.0, s.exhausted)
	_resonance.set_state(s.resonance / s.max_resonance, "%d / %d" % [int(s.resonance), int(s.max_resonance)])
	var pr := GameState.progress
	var need := PlayerProgress.xp_to_next(pr.level)
	_xp_bar.set_state(float(pr.xp) / float(need) if pr.level < PlayerProgress.MAX_LEVEL else 1.0,
		"%d / %d" % [pr.xp, need] if pr.level < PlayerProgress.MAX_LEVEL else "최고 레벨")
	var level_text := "Lv %d  %s" % [pr.level, pr.character_name]
	if pr.unspent_points > 0:
		level_text += "   · 능력 포인트 %d (Tab)" % pr.unspent_points
	_level_label.text = level_text
	_damage_flash = maxf(0.0, _damage_flash - delta * 1.6)
	var low := clampf((0.35 - s.hp / s.max_hp) / 0.35, 0.0, 1.0) if player.alive else 0.0
	_vignette.modulate.a = clampf(low * 0.55 + _damage_flash, 0.0, 1.0)


func _update_weapon() -> void:
	var w := player.weapons
	if w.primary == null:
		return
	var items: Array[WeaponItem] = [w.primary_item, w.secondary_item, w.melee_item]
	var fallback := [w.primary.display_name, w.secondary.display_name, w.melee.display_name]
	var keys := [&"weapon_1", &"weapon_2", &"weapon_3"]
	for i in 3:
		var current := i == w.current_slot
		var it := items[i]
		_slot_labels[i].text = "%s  %s%s" % [Settings.binding_text(keys[i]), it.display_name() if it else fallback[i],
			"  ◀" if current else ""]
		var c := it.color() if it else Color(1, 1, 1)
		_slot_labels[i].add_theme_color_override("font_color", Color(c.lightened(0.15), 0.95) if current else Color(c, 0.5))
	var cur_item := w.current_item()
	_weapon_name.add_theme_color_override("font_color", cur_item.color().lightened(0.2) if cur_item else Color(1, 1, 1))
	if w.is_melee_equipped():
		_weapon_name.text = w.melee_item.display_name() if w.melee_item else w.melee.display_name
		_weapon_detail.text = "근접 · 누르고 있으면 강공격 · %s 방어(시작 직후 패링)" % Settings.binding_text(&"aim")
		_ammo.text = ""
		_reserve.text = ""
		_heat.visible = false
		return
	var gun := w.current_gun()
	var data := gun.data
	_weapon_name.text = cur_item.display_name() if cur_item else data.display_name
	var mode := "자동" if data.fire_mode == WeaponData.FireMode.AUTO else "단발"
	_weapon_detail.text = "%s · %s · %s" % [data.class_label(), mode,
		cur_item.rarity_name() if cur_item else data.manufacturer]
	if data.uses_heat:
		_ammo.text = ""
		_reserve.text = ""
		_heat.visible = true
		_heat.label = "과열 — 냉각 중" if gun.overheated else "열"
		_heat.set_state(gun.heat, "%d%%" % int(gun.heat * 100.0), 0.0, gun.overheated)
		return
	_heat.visible = false
	var reserve := player.ammo.get_count(data.ammo_type)
	_ammo.text = str(gun.mag)
	var low := gun.mag <= int(gun.capacity * 0.25)
	_ammo.add_theme_color_override("font_color", WARNING_COLOR if low else Color(1, 1, 1))
	if gun.reloading:
		_reserve.text = "재장전 %d%%" % int(gun.reload_progress() * 100.0)
	elif gun.mag == 0 and reserve == 0:
		_reserve.text = "탄약 없음"
	else:
		_reserve.text = "/ %d %s" % [reserve, AmmoInventory.type_name(data.ammo_type)]


func _update_skills() -> void:
	var sc := player.skills
	for i in _skill_slots.size():
		var slot := _skill_slots[i]
		slot.key_text = Settings.binding_text(StringName("skill_%d" % (i + 1)))
		var skill := sc.skill_in_slot(i)
		slot.empty = skill == null
		if skill == null:
			continue
		var left := sc.cooldown_left(skill)
		slot.title = skill.short_name
		slot.sub_text = "공명 %d" % int(skill.resonance_cost)
		slot.accent = skill.color
		slot.available = left <= 0.0 and sc.can_afford(skill)
		slot.cooldown_ratio = sc.cooldown_ratio(skill)
		slot.cooldown_text = "%.1f" % left if left > 0.0 else ""
	var quick := sc.skill_in_slot(sc.last_slot) if sc.last_slot >= 0 else null
	_quick_label.text = "%s  마지막 스킬 다시 사용: %s" % [Settings.binding_text(&"skill_quick"),
		quick.display_name if quick else "없음"]
	for i in _consumable_slots.size():
		var slot := _consumable_slots[i]
		var c := player.consumables[i]
		var count := player.consumable_count(i)
		slot.key_text = Settings.binding_text(StringName("consumable_%d" % (i + 1)))
		slot.title = c.short_name
		slot.sub_text = "%d개" % count
		slot.accent = c.color
		slot.available = count > 0
		slot.empty = false


func _update_center(delta: float) -> void:
	var w := player.weapons
	var scoped := w.is_scoped()
	_scope.visible = scoped
	if not player.alive or scoped:
		_crosshair.mode = Crosshair.Mode.HIDDEN
	elif w.is_melee_equipped() or w.is_quick_meleeing():
		_crosshair.mode = Crosshair.Mode.MELEE
	else:
		_crosshair.mode = Crosshair.Mode.GUN
		var half_fov := deg_to_rad(player.camera.fov) * 0.5
		var spread := deg_to_rad(w.current_spread_deg())
		_crosshair.spread_px = tan(spread) / tan(half_fov) * _root.size.y * 0.5
	var target := player.interaction_target
	if target and is_instance_valid(target) and player.alive:
		var reason := target.get_block_reason(player)
		var text := "[%s] %s" % [Settings.binding_text(&"interact"), target.get_prompt(player)]
		if reason != "":
			text += " — " + reason
		_prompt.text = text
		_prompt.add_theme_color_override("font_color", WARNING_COLOR if reason != "" else Color(1, 1, 1))
		_prompt.visible = true
	else:
		_prompt.visible = false
	var pickup: WeaponPickup = null
	if target and is_instance_valid(target) and target is WeaponPickup:
		pickup = target as WeaponPickup
	if pickup and pickup.item and player.alive:
		_compare_text.text = compare_text(pickup.item, GameState.equipped_item(pickup.item.slot()))
		_compare.visible = true
	else:
		_compare.visible = false
	_center_flash_time = maxf(0.0, _center_flash_time - delta)
	_center_flash.modulate.a = clampf(_center_flash_time / 0.3, 0.0, 1.0)


func _update_field(delta: float) -> void:
	_compass.heading = fposmod(-rad_to_deg(player.yaw), 360.0)
	var markers: Array = []
	var q := GameState.quests
	var id := q.tracked
	var pos := player.global_position
	if id != &"" and q.is_active(id):
		var step := q.current_step(id)
		var hint := _field.quest_hint(step)
		_tracker.visible = true
		_tracker_title.text = "◆ %s · %s" % [QuestDB.title(id), QuestDB.get_quest(id).get("type", "")]
		_tracker_step.text = q.step_progress_text(id)
		if hint != Vector2.INF:
			var dist := Vector2(pos.x, pos.z).distance_to(hint)
			var bearing := CompassBar.bearing_deg(pos, hint)
			var radius := float(step.get("radius", 0.0 if step.get("type", &"") == &"talk" else 28.0))
			if dist <= maxf(radius, 6.0):
				_tracker_dist.text = "목표 지점 근처" if radius > 0.0 else "바로 앞"
			else:
				_tracker_dist.text = "%s쪽 %d m" % [CompassBar.direction_name(bearing), int(dist)]
			markers.append({"bearing": bearing, "color": CompassBar.QUEST_COLOR, "kind": &"quest",
				"text": "%d m" % int(dist)})
		else:
			_tracker_dist.text = ""
	else:
		_tracker.visible = false
	var game := get_parent() as Game
	if game and game.checkpoint_point:
		var cp := game.checkpoint_point.global_position
		var cp2 := Vector2(cp.x, cp.z)
		if cp2.distance_to(Vector2(pos.x, pos.z)) > 12.0:
			markers.append({"bearing": CompassBar.bearing_deg(pos, cp2), "color": CompassBar.ACCENT, "kind": &"home", "text": ""})
	_compass.markers = markers
	# 전투 중에는 의뢰 표시를 옅게(기획서 §22.1)
	var target_alpha := 0.3 if player.is_in_combat() else 1.0
	_tracker.modulate.a = move_toward(_tracker.modulate.a, target_alpha, delta * 2.0)
	var area_name: String = FieldWorld.AREAS.get(_field.current_area(), "")
	var dn := _field.day_night
	_area_label.text = "%s  ·  %s %s" % [area_name if area_name != "" else "퍼시 외곽권", dn.phase_name(), dn.clock_text()]
	_silver_label.text = "은화 %d" % GameState.silver
	var ev := _field.predator_event
	var pred := ev.predator if ev and ev.state == NightPredatorEvent.State.ENCOUNTER else null
	if pred and is_instance_valid(pred):
		_unique_panel.visible = true
		_unique_name.text = "%s  ·  유니크" % UniqueDB.unique_name(&"night_predator", pred.revealed)
		_unique_bar.set_state(pred.interest_ratio(), "%d%%" % int(pred.interest_ratio() * 100.0))
		_unique_hint.text = "물러나고 있다…" if pred.phase == NightPredator.Phase.RETREAT else \
			"살아남아라 — 패링과 간발의 회피로 흥미를 끌면 물러난다"
	else:
		_unique_panel.visible = false
	_update_boss_bar()


## 보스와 싸우는 동안 보스 체력바를 보인다. 약점이 드러나면 알린다.
func _update_boss_bar() -> void:
	var arena := _field.mire_arena
	if arena == null or not arena.shows_boss_bar():
		_boss_bar.visible = false
		return
	var boss := arena.boss
	var hint := ""
	var hot := false
	if boss.throat_exposed():
		hint = "목 아래 붉은 턱살이 드러났다 — 지금 노려라"
		hot = true
	elif boss.is_hidden():
		hint = "진흙 속에 숨었다 — 발밑의 붉은 고리를 피하라"
	_boss_bar.visible = true
	_boss_bar.set_state(boss.data.display_name, boss.health_ratio(), boss.phase,
		[MireMaw.PHASE2_RATIO, MireMaw.PHASE3_RATIO] as Array[float], hint, hot)


# --- 무기 비교 ---

static func _hex(c: Color) -> String:
	return c.to_html(false)


static func _item_block(it: WeaponItem, title: String) -> String:
	var out := "[color=#9fb6bf]%s[/color]\n[b][color=#%s]%s[/color][/b]  [color=#%s][%s · %s][/color]\n%s" % [
		title, _hex(it.color().lightened(0.15)), it.display_name(), _hex(it.color()), it.rarity_name(), it.class_label(),
		it.stat_line()]
	for line in it.perk_lines():
		out += "\n[color=#%s]· %s[/color]" % [_hex(it.color().lightened(0.3)), line]
	return out


static func _delta(label: String, new_v: float, cur_v: float, fmt: String = "%d", higher_better: bool = true) -> String:
	var d := new_v - cur_v
	if absf(d) < 0.001:
		return "%s =" % label
	var good := (d > 0.0) == higher_better
	var arrow := "▲" if d > 0.0 else "▼"
	var plus := "+" if d > 0.0 else ""
	return "[color=#%s]%s %s%s%s[/color]" % ["7ee08a" if good else "ff8a70", label, arrow, plus, fmt % d]


## 바닥의 무기(new_it)와 지금 든 무기(cur)를 비교한 글(BBCode)
static func compare_text(new_it: WeaponItem, cur: WeaponItem) -> String:
	var text := _item_block(new_it, "바닥의 무기")
	if cur == null:
		return text
	text += "\n\n" + _item_block(cur, "지금 든 무기")
	var parts: Array[String] = []
	var ng := new_it.gun_data()
	var cg := cur.gun_data()
	if ng and cg:
		parts.append(_delta("한 번 쏠 때 피해", ng.damage * ng.pellets * new_it.damage_mult(), cg.damage * cg.pellets * cur.damage_mult()))
		parts.append(_delta("분당 발사", ng.rounds_per_minute, cg.rounds_per_minute))
		if not ng.uses_heat and not cg.uses_heat:
			parts.append(_delta("탄창", new_it.mag_capacity(), cur.mag_capacity()))
	else:
		var nm := new_it.melee_data()
		var cm := cur.melee_data()
		if nm and cm:
			parts.append(_delta("약공격", nm.light_damage * new_it.damage_mult(), cm.light_damage * cur.damage_mult()))
			parts.append(_delta("강공격", nm.heavy_damage * new_it.damage_mult(), cm.heavy_damage * cur.damage_mult()))
			parts.append(_delta("사거리", nm.reach, cm.reach, "%.1fm"))
	text += "\n\n" + " · ".join(parts)
	text += "\n[color=#9fb6bf]주우면 지금 든 무기를 이 자리에 내려놓습니다.[/color]"
	return text

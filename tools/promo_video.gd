extends Node
## 홍보 영상(1편: 게임 시작 오프닝과 게임 소개) 연출. 실제 게임을 직접 움직이며 찍고 자막을 얹는다.
##   xvfb-run -a godot --path . --write-movie <폴더>/movie.avi --fixed-fps 30 \
##       res://tools/promo_video.tscn -- [--only=번호,번호] [--quality=0~3]
## 창 크기(=영상 크기)는 프로젝트 설정의 창 크기를 따르므로 찍을 때만 override.cfg로 바꾼다(tools/promo_render.sh).
## 장면 번호:
##   오프닝 0 타이틀·캐릭터 만들기·공명 장치 기동, 1 강하선에서 깨어나 걷기, 2 첫 전투(살인토끼)
##   소개 3 제목, 4 이어진 세계, 5 낮과 밤, 6 총격, 7 쌍월, 8 무기, 9 몬스터, 10 보스, 11 마을, 12 성장, 13 유니크
##   14 끝(다음 편 예고)
## 장면이 시작하는 프레임을 "PROMO_SCENE 번호 프레임"으로 남긴다(음악·편집이 맞춘다).

const GAME := preload("res://src/main/game.tscn")
const TITLE := preload("res://src/ui/menus/title_screen.tscn")
const FONT_BOLD := preload("res://assets/fonts/Pretendard-Bold.woff2")
const FONT_REGULAR := preload("res://assets/fonts/Pretendard-Regular.woff2")

var game: Game
var only: Array[int] = []
var quality := 2
var cam: Camera3D
var _spawned: Array[Enemy] = []
## 장면이 도는 동안 플레이어를 늘 살려 둔다(쓰러지면 연출이 끊긴다).
var _keep_alive := true

# 자막
var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _cap_root: Control
var _cap_title: Label
var _cap_sub: Label
var _card: ColorRect
var _card_title: Label
var _card_sub: Label
var _card_foot: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			for part in arg.substr(7).split(","):
				only.append(int(part))
		elif arg.begins_with("--quality="):
			quality = int(arg.substr(10))
	SaveSystem.directory = "user://tool_saves"
	Settings.load_settings("user://promo_settings.cfg")
	Settings.set_value(&"graphics_quality", quality, false)
	_build_overlay()
	cam = Camera3D.new()
	cam.name = "PromoCamera"
	cam.fov = 58.0
	cam.far = 900.0
	add_child(cam)
	await _run()
	print("PROMO_SCENE end %d" % Engine.get_process_frames())
	get_tree().quit()


func _process(_delta: float) -> void:
	if _keep_alive and game and is_instance_valid(game) and game.player and is_instance_valid(game.player):
		var st := game.player.stats
		st.hp = st.max_hp
		st.stamina = st.max_stamina


func _run() -> void:
	var scenes: Array[Callable] = [_s_opening, _s_wake, _s_first_fight,
		_s_title, _s_drop_site, _s_day_night, _s_gunfight, _s_twin_moon, _s_weapons,
		_s_monsters, _s_boss, _s_town, _s_growth, _s_unique, _s_end]
	for i in scenes.size():
		if not only.is_empty() and not only.has(i):
			continue
		if i > 0:
			await _ensure_game({})
		print("PROMO_SCENE %d %d" % [i, Engine.get_process_frames()])
		await scenes[i].call()
		_clear_spawned()


## 게임을 띄운다. config가 있으면 새 캐릭터로 시작한다(공명 장치 기동 도입부가 나온다).
func _ensure_game(config: Dictionary) -> void:
	if game and is_instance_valid(game):
		return
	game = GAME.instantiate()
	if config.is_empty():
		game.mode = Game.Mode.FIELD
	else:
		game.new_game_config = config
	add_child(game)
	await _wait(0.4)
	if config.is_empty():
		game.menus.close_all()
		game.hud.visible = false
	game.field.day_night.paused = true


# --- 오프닝 ---

func _s_opening() -> void:
	var title: Control = TITLE.instantiate()
	add_child(title)
	# 타이틀 화면에는 게임 이름이 이미 있으니 편 제목만 얹는다.
	await _wait(0.6)
	_caption("1편 · 프론티어에 떨어지다", "PERCY FRONTIER 플레이 — 새로 시작부터", 5.0)
	await _wait(5.0)
	title._open_creation()
	await _wait(0.4)
	var cr: CharacterCreation = title._creation
	_caption("캐릭터 만들기", "이름 · 외형 · 시작 성향 · 난이도 — 오늘의 탐사자는 「하람」", 7.4)
	cr._name_edit.text = ""
	for ch in "하람":
		cr._name_edit.text += ch
		await _wait(0.35)
	var steps := [["hair_style", HumanoidModel.HAIR_STYLES.size(), 1], ["hair_color", 0, 1], ["outfit", HumanoidModel.OUTFIT_COLORS.size(), 3],
		["accent", HumanoidModel.ACCENT_COLORS.size(), 2], ["gear", HumanoidModel.GEAR_NAMES.size(), 2]]
	for st: Array in steps:
		var count: int = st[1] if int(st[1]) > 0 else 6
		for k in int(st[2]):
			cr._step(st[0], count, 1)
			await _wait(0.4)
	var blade: Button = cr._origin_buttons.get(&"blade")
	if blade:
		blade.pressed.emit()
	await _wait(1.6)
	var config := cr.config()
	title.queue_free()
	await _wait(0.05)
	await _ensure_game(config)
	# 공명 장치 기동(도입부)을 끝까지 보여 준다.
	for i in 600:
		if game.intro == null or not is_instance_valid(game.intro):
			break
		await _wait(0.05)
	await _wait(0.6)


func _s_wake() -> void:
	var pl := game.player
	_cinematic(false)
	game.hud.visible = true
	game.field.day_night.advance_to(maxf(game.field.day_night.hour, 7.6))
	_caption("강하선 추락 — 귀환 신호 없음", "약한 구조 신호를 따라 동쪽 정착지 「퍼시」로", 7.0)
	# 둘러보기: 부서진 강하선을 보다가 길 쪽으로 돌아선다.
	var wreck := Vector3(FieldLayout.DROP_SITE.x, 0, FieldLayout.DROP_SITE.y) - pl.global_position
	pl.yaw = atan2(-wreck.x, -wreck.z)
	pl.reset_physics_interpolation()
	var from := pl.yaw
	await _seconds(3.6, func(t: float) -> void:
		var k := t / 3.6
		pl.yaw = from + sin(k * PI * 0.5) * 0.9
		pl.pitch = lerpf(-0.05, 0.05, sin(k * PI)))
	# 길 쪽(동쪽)으로 걷다가 뛴다.
	var road := FieldLayout.ROAD[1]
	await _seconds(7.0, func(t: float) -> void:
		var d := Vector3(road.x, 0, road.y) - pl.global_position
		pl.yaw = lerp_angle(pl.yaw, atan2(-d.x, -d.z), 0.06)
		pl.pitch = lerpf(pl.pitch, 0.0, 0.05)
		Input.action_press(&"move_forward")
		if t > 2.2 and t < 6.0:
			Input.action_press(&"sprint")
		else:
			Input.action_release(&"sprint")
		if absf(t - 4.5) < 0.02:
			Input.action_press(&"jump")
		elif absf(t - 4.6) < 0.02:
			Input.action_release(&"jump"))
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")


func _s_first_fight() -> void:
	var pl := game.player
	var fwd := pl.look_basis() * Vector3.FORWARD
	var here := Vector2(pl.global_position.x, pl.global_position.z)
	var f2 := Vector2(fwd.x, fwd.z).normalized()
	var side := Vector2(-f2.y, f2.x)
	for i in 3:
		_spawn(&"killer_rabbit", here + f2 * (11.0 + 2.0 * i) + side * (-3.0 + 3.0 * i))
	_caption("첫 전투 — 경계 숲의 살인토끼", "작다고 얕보면 큰코다친다. 약점(머리)을 노려라", 9.0)
	pl.weapons.select_slot(WeaponManager.Slot.SECONDARY)
	await _wait(0.5)
	var dodged := {"done": false}
	await _combat(4.6, func(t: float, target: Enemy) -> void:
		_aim(target, 0.35, 0.3)
		pl.weapons.simulate_hold(fmod(t, 0.36) < 0.12)
		if not dodged.done and target.global_position.distance_to(pl.global_position) < 2.6:
			dodged.done = true
			pl.try_dodge())
	pl.weapons.simulate_hold(false)
	pl.weapons.select_slot(WeaponManager.Slot.MELEE)
	var swing := {"next": 0.0}
	await _combat(4.0, func(t: float, target: Enemy) -> void:
		_aim(target, 0.3, 0.3)
		if t > float(swing.next) and target.global_position.distance_to(pl.global_position) < 3.0:
			pl.weapons.press_trigger()
			swing.next = t + 0.28)
	await _wait(0.8)


# --- 게임 소개 ---

func _s_title() -> void:
	var f := game.field
	f.day_night.advance_to(6.3)
	_cinematic(true)
	_card.color = Color(0, 0, 0, 0.0)
	_card_show(1.0, "PERCY FRONTIER", "몬스터를 분석하고 · 약점을 부수고 · 지도에 없는 존재를 쫓는 1인칭 오픈월드 액션 RPG", "어떤 게임인가?")
	var d := FieldLayout.DROP_SITE
	_park_player(d + Vector2(30, 8))
	await _fly(_g(d + Vector2(90, 40), 26.0), _g(d, 2.0), _g(d + Vector2(48, 18), 9.0), _g(d, 3.0), 6.0, func(t: float) -> void:
		_card.modulate.a = 1.0 - smoothstep(0.55, 0.95, t)
		f.day_night.advance_to(lerpf(6.3, 7.4, t)))


func _s_drop_site() -> void:
	var f := game.field
	var d := FieldLayout.DROP_SITE
	_caption("하나로 이어진 세계", "강하 지점에서 첫 마을 「퍼시」까지 — 숲 · 강 · 초원 · 늪이 끊김 없이 이어진 512m 필드", 6.0)
	f.day_night.advance_to(9.0)
	_park_player(d + Vector2(60, 14))
	await _fly(_g(d + Vector2(10, -6), 3.0), _g(d + Vector2(60, 20), 2.0), _g(d + Vector2(40, -20), 34.0),
		_g(FieldLayout.BRIDGE, 0.0), 6.0)


func _s_day_night() -> void:
	var f := game.field
	var c := FieldLayout.OLD_TREE
	_caption("흐르는 낮과 밤", "실제 20분이 하루. 해가 지면 숲에서 다른 것들이 깨어난다", 6.0)
	_park_player(c + Vector2(0, 14))
	await _orbit(_g(c, 9.0), 38.0, 14.0, 200.0, 250.0, 6.0, func(t: float) -> void:
		f.day_night.advance_to(lerpf(15.5, 21.2, t)))


func _s_gunfight() -> void:
	var f := game.field
	var at := Vector2(138, -34)
	f.day_night.advance_to(10.5)
	_cinematic(false)
	var pl := _place_player(at, at + Vector2(0, -20))
	pl.weapons.select_slot(WeaponManager.Slot.PRIMARY)
	for i in 3:
		_spawn([&"goblin_brute", &"goblin_scout", &"goblin_thrower"][i], at + Vector2(-6.0 + 6.0 * i, -17.0 - 2.0 * i))
	await _wait(0.6)
	_caption("총 · 근접 · 몬스터 스킬, 셋 다 주력", "약점을 노리고 장갑을 부숴라", 6.6)
	pl.weapons.simulate_aim(true)
	await _combat(6.8, func(t: float, target: Enemy) -> void:
		_aim(target, 1.0 if target.data.id == &"goblin_scout" else 1.35, 0.25)
		var burst := fmod(t, 0.8) < 0.55
		pl.weapons.simulate_hold(burst)
		var gun := pl.weapons.current_gun()
		if gun and gun.mag <= 0:
			pl.weapons.simulate_hold(false)
			pl.weapons.try_reload())
	pl.weapons.simulate_hold(false)
	pl.weapons.simulate_aim(false)


func _s_twin_moon() -> void:
	var f := game.field
	var at := Vector2(108, -90)
	f.day_night.advance_to(16.8)
	var pl := _place_player(at, at + Vector2(-20, 4))
	pl.weapons.select_slot(WeaponManager.Slot.MELEE)
	for i in 3:
		_spawn(&"ash_wolf", at + Vector2(-9.0, -4.0 + 4.0 * i))
	await _wait(0.5)
	_caption("쌍월 단검", "초승달 한 쌍 — 연속 베기, 몸을 돌려 베는 강공격, 간발의 회피", 6.4)
	var swing := {"next": 0.0}
	var heavy_at := 3.4
	await _combat(6.6, func(t: float, target: Enemy) -> void:
		_aim(target, 0.8, 0.3)
		if t >= heavy_at and t < heavy_at + 0.5:
			pl.weapons.simulate_hold(true)
		elif t >= heavy_at + 0.5 and t < heavy_at + 0.55:
			pl.weapons.simulate_hold(false)
		elif t >= float(swing.next) and target.global_position.distance_to(pl.global_position) < 3.2:
			pl.weapons.press_trigger()
			swing.next = t + 0.3)
	pl.weapons.simulate_hold(false)


func _s_weapons() -> void:
	var f := game.field
	var at := Vector2(-120, 30)
	f.day_night.advance_to(11.0)
	var pl := _place_player(at, at + Vector2(0, -10))
	GameState.equip_item(WeaponItem.create(&"karambit_hook", ItemRarity.Tier.EPIC))
	await _wait(0.1)
	pl.weapons.select_slot(WeaponManager.Slot.MELEE)
	_caption("무기는 한 자루씩", "희귀도와 특성이 다른 무기 — 같은 칸 무기를 버려야 주울 수 있다", 6.0)
	await _wait(0.6)
	pl.weapons.try_inspect()
	await _wait(1.6)
	var fwd := pl.look_basis() * Vector3.FORWARD
	var base := pl.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * 3.2
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	var tiers := [ItemRarity.Tier.IMPROVED, ItemRarity.Tier.RARE, ItemRarity.Tier.EPIC, ItemRarity.Tier.LEGENDARY]
	var ids := [&"scrap_smg", &"twin_moon", &"bolt_rifle", &"sniper_l14"]
	for i in 4:
		WeaponPickup.drop(f, WeaponItem.create(ids[i], tiers[i]), base + right * (-1.8 + 1.2 * i) + Vector3(fwd.x, 0, fwd.z) * (0.4 * absf(i - 1.5)))
	await _turn(pl, deg_to_rad(-26.0), 0.5)
	await _wait(3.4)
	GameState.equip_item(WeaponItem.create(&"twin_moon"))


func _s_monsters() -> void:
	var f := game.field
	var shots := [
		[&"goldhorn_charger", Vector2(196, -150), 11.0, 7.0],
		[&"goblin_chief", Vector2(44, 196), 12.5, 3.6],
		[&"spore_mother", Vector2(-118, -158), 13.0, 5.0],
		[&"silvermane", Vector2(-128, -108), 19.2, 4.0],
	]
	_cinematic(true)
	_caption("1지역에만 몬스터 26종", "목표: 일반 250종 · 희귀 50종 · 보스 12종 · 유니크 8종", 9.6)
	for s: Array in shots:
		var at: Vector2 = s[1]
		f.day_night.advance_to(s[2])
		_park_player(at + Vector2(14, 10))
		var e := _spawn(s[0], at)
		await _wait(0.05)
		var r: float = s[3]
		await _orbit_node(e, r, r * 0.32, 20.0, 60.0, 2.4)
		e.queue_free()
		_spawned.erase(e)


func _s_boss() -> void:
	var f := game.field
	var c := FieldLayout.MAW_CENTER
	var arena := f.mire_arena
	f.day_night.advance_to(18.4)
	_cinematic(true)
	_park_player(c + Vector2(13, -7))
	_caption("1지역 보스 「늪턱 구렁」", "돌진을 돌기둥에 부딪히게 하면 목 아래 약점이 드러난다", 12.6)
	await _fly(_g(c + Vector2(42, -30), 24.0), _g(c, 0.0), _g(c + Vector2(22, -13), 6.0), _g(c, 1.0), 2.6)
	var boss := arena.boss
	if boss == null:
		await _wait(4.0)
		return
	# 진흙 속에서 솟아오르는 모습을 물가 낮은 곳에서 본다.
	boss.awaken(game.player)
	await _orbit_node(boss, 11.0, 2.6, 40.0, 70.0, 3.8)
	var pl := _place_player(c + Vector2(11, -6), c)
	pl.weapons.select_slot(WeaponManager.Slot.PRIMARY)
	await _seconds(3.0, func(t: float) -> void:
		var head := boss.rig().bone_global_position(&"head")
		_aim_point(head, 0.15)
		pl.weapons.simulate_hold(t > 0.8 and fmod(t, 0.9) < 0.6))
	pl.weapons.simulate_hold(false)
	boss._apply_damage(boss.data.max_hp * 0.35, null, Hurtbox.Zone.NORMAL)
	if boss._attack:
		boss._end_attack(false)
	boss._state_timer = 6.0
	boss._set_state(Enemy.State.STUNNED)
	var head := boss.rig().bone_global_position(&"head")
	var eye := Vector2(head.x, head.z) + Vector2(boss.global_basis.z.x, boss.global_basis.z.z) * -5.0 \
		+ Vector2(boss.global_basis.x.x, boss.global_basis.x.z) * 2.5
	pl.global_position = f.terrain.point_at(eye) + Vector3.UP * 0.05
	pl.reset_physics_interpolation()
	pl.weapons.simulate_aim(true)
	await _seconds(3.4, func(t: float) -> void:
		var throat := boss.rig().bone_global_position(&"jaw") if boss.rig().has_bone(&"jaw") else head
		_aim_point(throat + Vector3.DOWN * 0.25, 0.3)
		pl.weapons.simulate_hold(t > 0.5 and fmod(t, 0.7) < 0.5))
	pl.weapons.simulate_hold(false)
	pl.weapons.simulate_aim(false)
	arena.reset_fight()


func _s_town() -> void:
	var f := game.field
	var tc := FieldLayout.TOWN_CENTER
	f.day_night.advance_to(19.0)
	_cinematic(true)
	_park_player(tc + Vector2(-14, 10))
	_caption("첫 마을 「퍼시」", "의뢰 · 잡화점 · 무기 공방 · 여관 — 주민 7명이 사는 거점", 6.0)
	# 광장 위에서 내려오는 크레인 장면(집을 뚫고 지나가지 않게 둥근 광장 안쪽으로만 움직인다).
	await _fly(_g(tc + Vector2(-5, 7), 22.0), _g(tc, 0.0), _g(tc + Vector2(-6, 7), 3.0),
		_g(tc + Vector2(10, -4), 2.6), 6.0, func(t: float) -> void:
		f.day_night.advance_to(lerpf(19.0, 19.4, t)))


func _s_growth() -> void:
	var f := game.field
	var tc := FieldLayout.TOWN_CENTER
	f.day_night.advance_to(10.0)
	var pl := _place_player(tc + Vector2(-10, 8), tc + Vector2(-20, 2))
	pl.weapons.select_slot(WeaponManager.Slot.PRIMARY)
	_caption("공명 장치", "레벨 · 능력치 · 스킬 · 도감 · 의뢰 — VRMMO식 성장과 상태창", 7.6)
	await _wait(0.4)
	GameState.grant_xp(PlayerProgress.xp_to_next(GameState.progress.level) + 5, "탐사")
	await _wait(4.4)
	game.menus.open_status()
	await _wait(1.5)
	game.menus.status_window._tabs.current_tab = StatusWindow.TAB_BESTIARY
	await _wait(1.5)
	game.menus.close_all()


func _s_unique() -> void:
	var f := game.field
	var ev := f.predator_event
	f.day_night.advance_to(23.2)
	GameState.add_clue(&"claw_marks")
	GameState.add_clue(&"explorer_journal")
	var stand := FieldLayout.SHADE_CENTER + Vector2(4, 6)
	var pl := _place_player(stand, FieldLayout.SHADE_CENTER + Vector2(-20, -10))
	pl.weapons.select_slot(WeaponManager.Slot.MELEE)
	ev.player = pl
	_caption("유니크 「밤의 포식자」", "흔적을 모아 출현 조건을 추리하고 — 살아남아라", 8.6)
	await _seconds(3.0, func(_t: float) -> void:
		pass)
	if ev.state == NightPredatorEvent.State.OMEN:
		ev._timer = 0.05
	var placed := {"done": false}
	await _seconds(5.4, func(_t: float) -> void:
		var pred := ev.predator
		if pred and is_instance_valid(pred):
			if not placed.done:
				# 플레이어 앞쪽 몇 걸음에 두어 어둠 속에서도 모습이 보이게 한다.
				placed.done = true
				var fwd := -Basis(Vector3.UP, pl.yaw).z
				pred.global_position = f.terrain.point_at(Vector2(pl.global_position.x, pl.global_position.z) + Vector2(fwd.x, fwd.z) * 8.5)
				pred.look_at(pl.global_position, Vector3.UP, true)
				pred.reset_physics_interpolation()
			f.day_night.eerie = minf(f.day_night.eerie, 0.6)
			_aim_point(pred.global_position + Vector3.UP * 1.0, 0.1))
	if ev.predator and is_instance_valid(ev.predator):
		ev.predator.interest = NightPredator.MAX_INTEREST
		ev.predator.retreat(NightPredator.RetreatReason.INTEREST)
	await _wait(0.3)


func _s_end() -> void:
	_cinematic(true)
	game.field.day_night.advance_to(7.0)
	_park_player(FieldLayout.TOWN_CENTER)
	var tc := FieldLayout.TOWN_CENTER
	_card.color = Color(0, 0, 0, 0.5)
	_card_show(0.0, "다음 편 · 퍼시에 도착하다", "구조 신호를 따라 첫 마을로 — 통신탑을 고치고, 밤의 숲에 남은 흔적을 쫓는다",
		"PERCY FRONTIER · 퍼시 외곽권 개발 빌드 v%s" % ProjectSettings.get_setting("application/config/version"))
	_card_title.label_settings.font_size = 72
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.8)
	await _fly(_g(tc + Vector2(-60, 40), 30.0), _g(tc, 4.0), _g(tc + Vector2(-70, 50), 40.0), _g(tc, 6.0), 7.0)


# --- 연출 도우미 ---

## 지면 기준 높이 lift인 점
func _g(p: Vector2, lift: float) -> Vector3:
	return game.field.terrain.point_at(p) + Vector3.UP * lift


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


## seconds 동안 매 프레임 step(경과 시간)을 부른다.
func _seconds(seconds: float, step: Callable) -> void:
	var t := 0.0
	while t < seconds:
		step.call(t)
		await get_tree().process_frame
		t += get_process_delta_time()


func _fly(a_pos: Vector3, a_look: Vector3, b_pos: Vector3, b_look: Vector3, seconds: float,
		extra: Callable = Callable()) -> void:
	cam.current = true
	await _seconds(seconds, func(t: float) -> void:
		var k := t / seconds
		var e := k * k * (3.0 - 2.0 * k)
		e = lerpf(k, e, 0.6)
		var p := a_pos.lerp(b_pos, e)
		var l := a_look.lerp(b_look, e)
		cam.global_transform = Transform3D(Basis.looking_at(l - p, Vector3.UP), p)
		if extra.is_valid():
			extra.call(k))


func _orbit(center: Vector3, radius: float, height: float, from_deg: float, to_deg: float, seconds: float,
		extra: Callable = Callable()) -> void:
	cam.current = true
	await _seconds(seconds, func(t: float) -> void:
		var k := t / seconds
		var a := deg_to_rad(lerpf(from_deg, to_deg, k))
		var p := center + Vector3(sin(a) * radius, height, cos(a) * radius)
		cam.global_transform = Transform3D(Basis.looking_at(center - p, Vector3.UP), p)
		if extra.is_valid():
			extra.call(k))


## 움직이는 몬스터 둘레를 돌며 비춘다.
func _orbit_node(node: Node3D, radius: float, height: float, from_deg: float, to_deg: float, seconds: float) -> void:
	cam.current = true
	var follow := {"c": node.global_position}
	await _seconds(seconds, func(t: float) -> void:
		if is_instance_valid(node):
			follow.c = (follow.c as Vector3).lerp(node.global_position, 0.12)
		var center: Vector3 = follow.c
		var k := t / seconds
		var a := deg_to_rad(lerpf(from_deg, to_deg, k))
		var look := center + Vector3.UP * height * 0.35
		var p := center + Vector3(sin(a) * radius, height, cos(a) * radius)
		var ground := game.field.terrain.point_at(Vector2(p.x, p.z)).y + 0.6
		p.y = maxf(p.y, ground)
		cam.global_transform = Transform3D(Basis.looking_at(look - p, Vector3.UP), p))


## 영화 장면(따로 된 카메라, 위아래 검은 띠, HUD 숨김)과 1인칭 장면을 바꾼다.
func _cinematic(on: bool) -> void:
	for b in _bars:
		b.visible = on
	game.hud.visible = not on
	if on:
		cam.current = true
	else:
		game.player.camera.current = true


## 영화 장면 동안 플레이어를 그 자리 근처에 둔다(풀·나무·무리가 그 둘레에 채워진다).
func _park_player(at: Vector2) -> void:
	var pl := game.player
	pl.global_position = _g(at, 0.1)
	pl.velocity = Vector3.ZERO
	pl.reset_physics_interpolation()
	game.field.grass.fill_now()


func _place_player(at: Vector2, look: Vector2) -> Player:
	_park_player(at)
	var pl := game.player
	var d := Vector3(look.x, 0, look.y) - Vector3(at.x, 0, at.y)
	pl.yaw = atan2(-d.x, -d.z)
	pl.pitch = deg_to_rad(-3.0)
	pl.reset_physics_interpolation()
	_cinematic(false)
	return pl


func _turn(pl: Player, delta_yaw: float, seconds: float) -> void:
	var from := pl.yaw
	await _seconds(seconds, func(t: float) -> void:
		var k := t / seconds
		pl.yaw = from + delta_yaw * k * k * (3.0 - 2.0 * k))


func _spawn(species: StringName, at: Vector2) -> Enemy:
	var e := EnemyBody.create(species)
	e.position = _g(at, 0.3)
	game.field.add_child(e)
	_spawned.append(e)
	return e


func _clear_spawned() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.queue_free()
	_spawned.clear()


## 가장 가까운 살아 있는 몬스터를 노리며 seconds 동안 step(경과 시간, 대상)을 부른다.
func _combat(seconds: float, step: Callable) -> void:
	await _seconds(seconds, func(t: float) -> void:
		var target := _nearest_alive()
		if target:
			step.call(t, target))


func _nearest_alive() -> Enemy:
	var pl := game.player
	var best: Enemy = null
	var best_d := INF
	for e in _spawned:
		if is_instance_valid(e) and e.is_alive():
			var d := e.global_position.distance_to(pl.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func _aim(target: Enemy, height: float, rate: float) -> void:
	_aim_point(target.global_position + Vector3.UP * height, rate)


func _aim_point(point: Vector3, rate: float) -> void:
	var pl := game.player
	var dir := point - pl.get_eye_position()
	var yaw := atan2(-dir.x, -dir.z)
	var pitch := atan2(dir.y, Vector2(dir.x, dir.z).length())
	pl.yaw = lerp_angle(pl.yaw, yaw, rate)
	pl.pitch = lerpf(pl.pitch, pitch, rate)


# --- 자막 ---

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_right = 1.0
		if top:
			bar.offset_bottom = 58
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -58
		bar.visible = false
		_layer.add_child(bar)
		_bars.append(bar)
	_cap_root = Control.new()
	_cap_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cap_root.modulate.a = 0.0
	_layer.add_child(_cap_root)
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.72))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_top = 1.0
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.72
	shade.offset_top = -190
	shade.offset_bottom = -64
	_cap_root.add_child(shade)
	var accent := ColorRect.new()
	accent.color = Color(0.98, 0.78, 0.36)
	accent.anchor_top = 1.0
	accent.anchor_bottom = 1.0
	accent.offset_left = 56
	accent.offset_right = 62
	accent.offset_top = -168
	accent.offset_bottom = -88
	_cap_root.add_child(accent)
	_cap_title = _label(FONT_BOLD, 44, Color(1, 0.97, 0.9))
	_cap_title.anchor_top = 1.0
	_cap_title.anchor_bottom = 1.0
	_cap_title.offset_left = 78
	_cap_title.offset_top = -176
	_cap_root.add_child(_cap_title)
	_cap_sub = _label(FONT_REGULAR, 23, Color(0.86, 0.9, 0.92))
	_cap_sub.anchor_top = 1.0
	_cap_sub.anchor_bottom = 1.0
	_cap_sub.offset_left = 80
	_cap_sub.offset_top = -116
	_cap_root.add_child(_cap_sub)
	# 제목 카드
	_card = ColorRect.new()
	_card.color = Color(0, 0, 0, 0.0)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.modulate.a = 0.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_card.add_child(box)
	_card_title = _label(FONT_BOLD, 96, Color(1, 0.96, 0.86))
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.label_settings.outline_size = 10
	box.add_child(_card_title)
	var rule := ColorRect.new()
	rule.color = Color(0.98, 0.78, 0.36)
	rule.custom_minimum_size = Vector2(220, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	_card_sub = _label(FONT_REGULAR, 26, Color(0.92, 0.94, 0.95))
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_card_sub)
	_card_foot = _label(FONT_REGULAR, 20, Color(0.75, 0.8, 0.82))
	_card_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_card_foot)


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 0.75)
	ls.shadow_size = 6
	ls.shadow_color = Color(0, 0, 0, 0.45)
	l.label_settings = ls
	return l


## 아래 왼쪽 자막: 잠깐 떠올랐다가 seconds 뒤에 사라진다.
func _caption(title: String, sub: String, seconds: float) -> void:
	_cap_title.text = title
	_cap_sub.text = sub
	var tw := create_tween()
	_cap_root.modulate.a = 0.0
	_cap_root.position.x = -24.0
	# 1인칭 화면에서는 왼쪽 아래 체력 막대를 가리지 않게 위로 올린다.
	var hud_on := game != null and is_instance_valid(game) and game.hud.visible
	_cap_root.position.y = -150.0 if hud_on else 0.0
	tw.tween_property(_cap_root, "modulate:a", 1.0, 0.45)
	tw.parallel().tween_property(_cap_root, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(seconds - 1.0, 0.2))
	tw.tween_property(_cap_root, "modulate:a", 0.0, 0.45)


func _card_show(alpha: float, title: String, sub: String, foot: String) -> void:
	_card_title.text = title
	_card_sub.text = sub
	_card_foot.text = foot
	_card_foot.visible = foot != ""
	_card.modulate.a = alpha

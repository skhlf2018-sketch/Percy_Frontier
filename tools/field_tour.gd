extends Node
## 필드 화면 확인 도구: 퍼시 외곽권의 주요 장소를 여러 시간대에 찍어 PNG로 저장한다.
##   xvfb-run -a godot --path . --resolution 1600x900 res://tools/field_tour.tscn -- --out=/절대/경로 [--only=이름]

const GAME := preload("res://src/main/game.tscn")

var out_dir := "user://field_tour"
var only := ""
var game: Game


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(out_dir if out_dir.is_absolute_path() else ProjectSettings.globalize_path(out_dir))
	# 화면 확인 중의 자동 저장이 실제 저장 칸을 덮지 않게 한다.
	SaveSystem.directory = "user://tool_saves"
	Settings.load_settings("user://field_tour_settings.cfg")
	await _run()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("저장: ", path)


## 장소 p(x, z)에 서서 target(x, z)을 바라본다. 높이는 지면 기준.
func _view(shot_name: String, p: Vector2, target: Vector2, hour: float, pitch_deg: float = 0.0, lift: float = 0.0) -> void:
	if only != "" and not shot_name.contains(only):
		return
	var f := game.field
	f.day_night.advance_to(hour)
	var pos := f.terrain.point_at(p) + Vector3.UP * (0.05 + lift)
	var pl := game.player
	pl.global_position = pos
	pl.velocity = Vector3.ZERO
	var d := Vector3(target.x, 0, target.y) - Vector3(p.x, 0, p.y)
	pl.yaw = atan2(-d.x, -d.z)
	pl.pitch = deg_to_rad(pitch_deg)
	pl.reset_physics_interpolation()
	f.grass.fill_now()
	await _frames(12)
	await _shot(shot_name)


func _menu_shots() -> void:
	var title: Control = load("res://src/ui/menus/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(40)
	await _shot("30_title")
	title._open_creation()
	await _frames(30)
	await _shot("31_character_creation")
	title._creation._step("hair_style", HumanoidModel.HAIR_STYLES.size(), 1)
	title._creation._step("outfit", HumanoidModel.OUTFIT_COLORS.size(), 3)
	title._creation._step("gear", HumanoidModel.GEAR_NAMES.size(), 2)
	await _frames(10)
	await _shot("32_character_creation_changed")
	title.queue_free()
	await _frames(3)
	var g: Game = GAME.instantiate()
	g.new_game_config = {"name": "하람", "origin": &"blade", "appearance": {}}
	add_child(g)
	await _frames(90)
	await _shot("33_intro")
	if g.intro:
		g.intro.skip()
	await _frames(120)
	await _shot("34_after_intro")
	g.queue_free()
	await _frames(3)


func _run() -> void:
	if only == "menus":
		await _menu_shots()
		return
	game = GAME.instantiate()
	game.mode = Game.Mode.FIELD
	add_child(game)
	await _frames(10)
	game.menus.close_all()
	game.hud.visible = false
	var t := game.field.landmarks.spots["new_game"] as Transform3D
	var start := Vector2(t.origin.x, t.origin.z)
	await _view("01_start_morning", start, FieldLayout.DROP_SITE + Vector2(-2, -4), 8.5, -4.0)
	await _view("02_start_toward_road", start, start + Vector2(30, 6), 10.0, -2.0)
	await _view("03_bridge", FieldLayout.BRIDGE + Vector2(-26, 2), FieldLayout.BRIDGE + Vector2(10, -1), 11.0, -3.0)
	await _view("04_percy_gate_afternoon", FieldLayout.TOWN_GATE + Vector2(-26, 0), FieldLayout.TOWN_CENTER, 15.5, 2.0)
	await _view("05_percy_plaza_noon", FieldLayout.TOWN_CENTER + Vector2(-20, 3), FieldLayout.TOWN_CENTER + Vector2(10, -4), 12.5, 1.0)
	await _view("06_percy_night", FieldLayout.TOWN_CENTER + Vector2(-30, 2), FieldLayout.TOWN_CENTER + Vector2(5, 0), 22.0, 2.0)
	await _view("07_shade_forest_day", FieldLayout.SHADE_CENTER + Vector2(20, 30), FieldLayout.SHADE_CENTER, 14.0, 0.0)
	await _view("08_meadow_dusk", FieldLayout.MEADOW_CENTER + Vector2(-40, 20), FieldLayout.MEADOW_CENTER + Vector2(30, -10), 18.7, 1.0)
	await _view("08b_meadow_night", FieldLayout.MEADOW_CENTER + Vector2(-40, 20), FieldLayout.MEADOW_CENTER + Vector2(30, -10), 23.0, 1.0)
	await _view("09_watchtower_view", FieldLayout.WATCHTOWER, FieldLayout.TOWN_CENTER, 13.0, -6.0, 4.1)
	await _view("10_night_forest", FieldLayout.OLD_TREE + Vector2(-30, 25), FieldLayout.OLD_TREE, 0.5, 6.0)
	await _view("11_old_tree", FieldLayout.OLD_TREE + Vector2(0, 26), FieldLayout.OLD_TREE, 9.5, 12.0)
	await _view("12_camp_evening", FieldLayout.CAMP + Vector2(-10, 12), FieldLayout.CAMP, 19.5, -3.0)
	await _view("13_pond", FieldLayout.POND_CENTER + Vector2(30, -12), FieldLayout.POND_CENTER, 10.0, -3.0)
	await _ui_shots()


func _ui_shots() -> void:
	if only != "" and only != "ui":
		return
	only = ""
	game.hud.visible = true
	await _view("20_hud_start", start_point(), FieldLayout.DROP_SITE + Vector2(40, 8), 9.0, -2.0)
	GameState.grant_xp(PlayerProgress.xp_to_next(1) + 10, "시험")
	await _frames(20)
	await _shot("21_hud_levelup_banner")
	game.menus.open_status()
	await _frames(6)
	await _shot("22_status_window")
	game.menus.status_window._tabs.current_tab = StatusWindow.TAB_GEAR
	await _frames(4)
	await _shot("23_status_gear")
	GameState.complete_all_analysis()
	game.menus.status_window._tabs.current_tab = StatusWindow.TAB_SKILLS
	await _frames(4)
	await _shot("24_status_skills")
	game.menus.status_window._tabs.current_tab = StatusWindow.TAB_BESTIARY
	await _frames(4)
	await _shot("25_status_bestiary")
	game.menus.close_all()
	# 쌍검 1인칭: 기본 자세, 좌우 베기, 회전 베기, 방어
	GameState.set_melee_weapon(&"twin_moon")
	game.player.weapons.select_slot(WeaponManager.Slot.MELEE)
	await _frames(40)
	await _shot("26_twin_idle")
	game.player.weapons.press_trigger()
	await _frames(3)
	game.player.weapons.release_trigger()
	await _frames(4)
	await _shot("27_twin_slash")
	await _frames(30)
	game.player.weapons.simulate_aim(true)
	await _frames(20)
	await _shot("28_twin_block")
	game.player.weapons.simulate_aim(false)


func start_point() -> Vector2:
	var t := game.field.landmarks.spots["new_game"] as Transform3D
	return Vector2(t.origin.x, t.origin.z)

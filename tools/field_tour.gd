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


func _run() -> void:
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

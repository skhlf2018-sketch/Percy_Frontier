extends Node3D
## 생물 모델 확인 도구: 종 모델을 스튜디오 조명 아래 나란히 세워 찍는다.
##   xvfb-run -a godot --path . --resolution 1600x900 res://tools/creature_preview.tscn -- --out=/절대/경로 [--only=모델id,..] [--pose=walk]

const MODELS: Array[StringName] = [
	&"killer_rabbit", &"horn_rabbit", &"serial_rabbit", &"ash_wolf", &"wolf_alpha", &"silvermane",
	&"goblin_scout", &"goblin_brute", &"goblin_gunner", &"goblin_thrower", &"goblin_shaman", &"goblin_chief", &"oneeye_sniper",
]

const LINEUPS := {
	"goblins": [&"goblin_scout", &"goblin_brute", &"goblin_gunner", &"goblin_thrower", &"goblin_shaman", &"goblin_chief",
		&"oneeye_sniper"],
	"wolves": [&"ash_wolf", &"wolf_alpha", &"silvermane"],
	"rabbits": [&"killer_rabbit", &"horn_rabbit", &"serial_rabbit"],
}

var out_dir := "user://creature_preview"
var only: Array[String] = []
var pose := ""
var lineup := ""
var cam: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only.assign(arg.substr(7).split(","))
		elif arg.begins_with("--pose="):
			pose = arg.substr(7)
		elif arg.begins_with("--quality="):
			Settings.set_value(&"graphics_quality", int(arg.substr(10)), false)
		elif arg.begins_with("--lineup="):
			lineup = arg.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir if out_dir.is_absolute_path() else ProjectSettings.globalize_path(out_dir))
	_stage()
	if lineup != "":
		await _shoot_lineup(lineup)
		get_tree().quit()
		return
	for id in MODELS:
		if not only.is_empty() and not only.has(String(id)):
			continue
		await _shoot(id)
	get_tree().quit()


func _stage() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.5, 0.72)
	sm.sky_horizon_color = Color(0.72, 0.76, 0.8)
	sm.ground_horizon_color = Color(0.5, 0.48, 0.44)
	sm.ground_bottom_color = Color(0.25, 0.23, 0.2)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssil_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 12.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.36, 0.24)
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)


func _shoot(id: StringName) -> void:
	var t := SpeciesModels.template(id)
	if t == null:
		push_warning("모델 없음: %s" % id)
		return
	var rig := t.instantiate()
	add_child(rig)
	rig.rotation.y = deg_to_rad(150.0)
	var aabb := t.custom_aabb.grow(-0.35)
	var size := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var center := aabb.get_center()
	center.y = aabb.size.y * 0.5
	var body := CreatureAnimator.Body.QUADRUPED
	if String(id).contains("goblin") or id == &"oneeye_sniper":
		body = CreatureAnimator.Body.BIPED
	elif String(id).contains("rabbit"):
		body = CreatureAnimator.Body.HOPPER
	var anim := CreatureAnimator.new(rig, body, aabb.size.y * 0.5, 6.0)
	if pose != "":
		anim.speed = 2.5 if pose == "walk" else 0.0
		anim.action = StringName(pose) if pose != "walk" else &""
		anim.action_weight = 1.0
	for i in 30:
		anim.update(1.0 / 60.0)
	cam.global_position = center + Vector3(0.0, size * 0.22, size * 1.55)
	cam.look_at(center + Vector3(0, -size * 0.05, 0))
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join("%s.png" % id)
	img.save_png(path)
	print("저장: %s (정점 %d)" % [path, t.vertex_count])
	rig.queue_free()
	await get_tree().process_frame


## 실제 적(무기·방패 포함)을 나란히 세워 찍는다.
func _shoot_lineup(which: String) -> void:
	var ids: Array = LINEUPS.get(which, [])
	var enemies: Array[Enemy] = []
	var x := 0.0
	var gap := 1.3 if which == "goblins" else (1.6 if which == "wolves" else 0.9)
	for id: StringName in ids:
		var e: Enemy = EnemyBody.create(id) if EnemyBody.has_plan(id) and EnemyBody.PLANS[id].has("script") else \
			(load("res://src/enemies/%s.tscn" % id) as PackedScene).instantiate()
		add_child(e)
		e.global_position = Vector3(x, 0, 0)
		e.rotation.y = deg_to_rad(160.0)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		enemies.append(e)
		x += gap
	await get_tree().process_frame
	for e in enemies:
		var anim := e.animator()
		if anim == null:
			continue
		if pose != "":
			anim.action = StringName(pose)
			anim.action_weight = 1.0
		elif e is Goblin and ((e as Goblin).role == Goblin.Role.GUNNER or (e as Goblin).role == Goblin.Role.SNIPER):
			anim.action = &"aim"
			anim.action_weight = 1.0
		for i in 40:
			anim.update(1.0 / 60.0)
	var width := x - gap
	var center := Vector3(width * 0.5, 0.55 if which != "rabbits" else 0.25, 0)
	cam.fov = 38.0
	cam.global_position = center + Vector3(0, 0.45 if which != "rabbits" else 0.3, width * 0.95 + 2.2)
	cam.look_at(center)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join("lineup_%s.png" % which)
	img.save_png(path)
	print("저장: %s" % path)

class_name EnemyBody
extends RefCounted
## 종별 몸 설계: 절차적 모델(SpeciesModels), 이동 충돌체, 피격 부위(뼈를 따라 움직인다), 동작 방식.
## 장면 없이 종 id만으로 적을 만들 수 있다(create). 예전 장면(살인토끼 등)은 장면의 충돌체와 피격 부위를 그대로 쓰고
## 모델만 바꾼 뒤 피격 부위를 뼈에 옮겨 붙인다(rehome).
##
## 설계 항목:
##  script, data: 스크립트·데이터 경로(scene: 예전 장면으로 만드는 종)
##  body: CreatureAnimator.Body, leg: 다리 길이(보폭), run: 질주로 바뀌는 속도
##  collision: [반지름, 높이, 중심 높이]
##  eye: 눈 높이
##  hurtboxes: [[이름, 부위, 배율, 부위 이름, 모양, 자리, 추가]] 모양은 ["sphere", r] / ["box", 크기] / ["capsule", r, h],
##    자리는 부착점 이름(StringName, 뼈를 따라감) 또는 위치(Vector3, 몸 기준). 추가: armor, pass, broken_zone, broken_mult, disabled
##  rehome: {장면 피격 부위 이름: 부착점} 장면 피격 부위를 뼈에 옮겨 붙인다.

const W := Hurtbox.Zone.WEAK_POINT
const N := Hurtbox.Zone.NORMAL
const A := Hurtbox.Zone.ARMOR
const B := CreatureAnimator.Body

const PLANS := {
	# --- 토끼류 ---
	&"killer_rabbit": {
		"scene": "res://src/enemies/killer_rabbit.tscn",
		"body": B.HOPPER, "leg": 0.3, "run": 7.0,
		"rehome": {"HeadHurtbox": &"head"},
	},
	&"horn_rabbit": {
		"script": "res://src/enemies/horn_rabbit.gd", "data": "res://data/enemies/horn_rabbit.tres",
		"body": B.HOPPER, "leg": 0.33, "run": 7.0, "collision": [0.3, 0.8, 0.4], "eye": 0.55,
		"hurtboxes": [
			["HeadHurtbox", W, 2.2, "머리", ["sphere", 0.17], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["sphere", 0.3], Vector3(0, 0.32, 0.04), {}],
		],
	},
	&"serial_rabbit": {
		"script": "res://src/enemies/serial_rabbit.gd", "data": "res://data/enemies/serial_rabbit.tres",
		"body": B.HOPPER, "leg": 0.38, "run": 8.0, "collision": [0.34, 0.9, 0.45], "eye": 0.62,
		"hurtboxes": [
			["HeadHurtbox", W, 2.0, "머리", ["sphere", 0.19], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["sphere", 0.36], Vector3(0, 0.36, 0.04), {}],
		],
	},
	# --- 늑대류 ---
	&"ash_wolf": {
		"script": "res://src/enemies/wolf.gd", "data": "res://data/enemies/ash_wolf.tres",
		"body": B.QUADRUPED, "leg": 0.75, "run": 7.5, "collision": [0.34, 0.95, 0.55], "eye": 0.85,
		"hurtboxes": [
			["HeadHurtbox", W, 2.0, "머리", ["sphere", 0.14], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["box", Vector3(0.34, 0.45, 0.95)], Vector3(0, 0.62, 0.05), {}],
		],
	},
	&"wolf_alpha": {
		"script": "res://src/enemies/wolf_alpha.gd", "data": "res://data/enemies/wolf_alpha.tres",
		"body": B.QUADRUPED, "leg": 0.92, "run": 8.0, "collision": [0.42, 1.15, 0.66], "eye": 1.04,
		"hurtboxes": [
			["HeadHurtbox", W, 1.8, "머리", ["sphere", 0.17], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["box", Vector3(0.42, 0.55, 1.15)], Vector3(0, 0.76, 0.06), {}],
		],
	},
	&"silvermane": {
		"script": "res://src/enemies/silvermane.gd", "data": "res://data/enemies/silvermane.tres",
		"body": B.QUADRUPED, "leg": 0.85, "run": 8.0, "collision": [0.38, 1.05, 0.6], "eye": 0.95,
		"hurtboxes": [
			["HeadHurtbox", W, 1.9, "머리", ["sphere", 0.16], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["box", Vector3(0.38, 0.5, 1.05)], Vector3(0, 0.7, 0.05), {}],
		],
	},
	# --- 갑각 짐승 ---
	&"rock_charger": {
		"scene": "res://src/enemies/rock_charger.tscn",
		"body": B.QUADRUPED, "leg": 1.4, "run": 8.0,
		"rehome": {"FrontPlateHurtbox": &"face", "VentHurtbox": &"vent"},
	},
	&"goldhorn_charger": {
		"script": "res://src/enemies/goldhorn_charger.gd", "data": "res://data/enemies/goldhorn_charger.tres",
		"body": B.QUADRUPED, "leg": 1.55, "run": 9.0, "collision": [1.0, 2.2, 1.1], "eye": 1.6,
		"hurtboxes": [
			["FrontPlateHurtbox", A, 1.0, "전면 장갑", ["box", Vector3(1.5, 1.3, 0.55)], &"face",
				{"armor": 220.0, "pass": 0.2, "broken_zone": W, "broken_mult": 1.6}],
			["VentHurtbox", W, 2.0, "등 배기공", ["sphere", 0.36], &"vent", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["box", Vector3(1.65, 1.6, 2.3)], Vector3(0, 1.05, 0.15), {}],
		],
	},
	&"mossback_calf": {
		"script": "res://src/enemies/mossback_calf.gd", "data": "res://data/enemies/mossback_calf.tres",
		"body": B.QUADRUPED, "leg": 0.4, "run": 5.0, "collision": [0.45, 0.95, 0.5], "eye": 0.6,
		"hurtboxes": [
			["HeadHurtbox", W, 2.0, "머리", ["sphere", 0.2], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["box", Vector3(0.6, 0.6, 0.85)], Vector3(0, 0.5, 0.05), {}],
		],
	},
	# --- 멧돼지 ---
	&"thorn_boar": {
		"script": "res://src/enemies/thorn_boar.gd", "data": "res://data/enemies/thorn_boar.tres",
		"body": B.QUADRUPED, "leg": 0.6, "run": 7.0, "collision": [0.34, 0.95, 0.52], "eye": 0.72,
		"hurtboxes": [
			["HeadHurtbox", N, 1.3, "머리", ["sphere", 0.2], &"head", {}],
			["BellyHurtbox", W, 2.0, "배", ["box", Vector3(0.38, 0.18, 0.7)], Vector3(0, 0.36, 0.05), {}],
			["BackHurtbox", A, 1.0, "가시 등", ["box", Vector3(0.5, 0.3, 0.95)], Vector3(0, 0.88, 0.05),
				{"armor": 60.0, "pass": 0.35, "broken_zone": N, "broken_mult": 1.0}],
			["BodyHurtbox", N, 1.0, "몸통", ["box", Vector3(0.5, 0.4, 0.95)], Vector3(0, 0.6, 0.05), {}],
		],
	},
	# --- 늪 ---
	&"bog_toad": {
		"script": "res://src/enemies/bog_toad.gd", "data": "res://data/enemies/bog_toad.tres",
		"body": B.HOPPER, "leg": 0.35, "run": 5.0, "collision": [0.45, 0.9, 0.42], "eye": 0.55,
		"hurtboxes": [
			["HeadHurtbox", W, 1.8, "머리", ["sphere", 0.26], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["box", Vector3(0.9, 0.5, 0.9)], Vector3(0, 0.36, 0.05), {}],
		],
	},
	# --- 곤충·거미·박쥐 ---
	&"bark_mantis": {
		"script": "res://src/enemies/bark_mantis.gd", "data": "res://data/enemies/bark_mantis.tres",
		"body": B.CRAWLER, "leg": 0.7, "run": 6.0, "collision": [0.35, 1.6, 0.8], "eye": 1.45,
		"hurtboxes": [
			["HeadHurtbox", W, 2.2, "머리", ["sphere", 0.16], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["capsule", 0.2, 1.0], Vector3(0, 0.75, 0.15), {}],
		],
	},
	&"cave_spider": {
		"script": "res://src/enemies/cave_spider.gd", "data": "res://data/enemies/cave_spider.tres",
		"body": B.CRAWLER, "leg": 0.9, "run": 7.0, "collision": [0.45, 0.9, 0.5], "eye": 0.6,
		"hurtboxes": [
			["HeadHurtbox", W, 2.0, "머리가슴", ["sphere", 0.2], &"head", {}],
			["AbdomenHurtbox", N, 1.2, "배", ["sphere", 0.34], Vector3(0, 0.66, 0.4), {}],
			["BodyHurtbox", N, 1.0, "몸통", ["sphere", 0.28], Vector3(0, 0.56, -0.1), {}],
		],
	},
	&"cave_bat": {
		"script": "res://src/enemies/cave_bat.gd", "data": "res://data/enemies/cave_bat.tres",
		"body": B.FLYER, "leg": 0.3, "run": 8.0, "collision": [0.22, 0.44, 0.0], "eye": 0.05,
		"hurtboxes": [
			["HeadHurtbox", W, 2.0, "머리", ["sphere", 0.1], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["sphere", 0.2], Vector3(0, 0.0, 0.0), {}],
			["WingHurtbox", N, 0.7, "날개", ["box", Vector3(1.4, 0.08, 0.35)], Vector3(0, 0.03, 0.05), {}],
		],
	},
	# --- 포자 식생체 ---
	&"spore_spitter": {
		"scene": "res://src/enemies/spore_spitter.tscn",
		"body": B.CRAWLER, "leg": 0.6, "run": 5.0,
		"rehome": {"SacHurtbox": &"sac", "CapHurtbox": &"head"},
	},
	&"bloat_pod": {
		"script": "res://src/enemies/bloat_pod.gd", "data": "res://data/enemies/bloat_pod.tres",
		"body": B.STATIC, "leg": 0.3, "run": 1.0, "collision": [0.45, 0.95, 0.47], "eye": 0.6,
		"hurtboxes": [
			["SacHurtbox", W, 1.5, "포자 주머니", ["sphere", 0.5], Vector3(0, 0.45, 0), {}],
		],
	},
	&"spore_mother": {
		"script": "res://src/enemies/spore_mother.gd", "data": "res://data/enemies/spore_mother.tres",
		"body": B.STATIC, "leg": 1.0, "run": 1.0, "collision": [1.2, 2.6, 1.3], "eye": 1.8,
		"hurtboxes": [
			["CoreHurtbox", W, 2.5, "붉은 핵", ["sphere", 0.42], &"core", {"disabled": true}],
			["BodyHurtbox", N, 1.0, "겉껍질", ["capsule", 1.15, 2.6], Vector3(0, 1.1, 0), {}],
		],
	},
	# --- 고블린 ---
	&"goblin_scout": {
		"script": "res://src/enemies/goblin.gd", "data": "res://data/enemies/goblin_scout.tres",
		"body": B.BIPED, "leg": 0.55, "run": 5.0, "collision": [0.3, 1.2, 0.6], "eye": 1.1,
		"hurtboxes": [
			["HeadHurtbox", W, 2.2, "머리", ["sphere", 0.13], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["capsule", 0.22, 0.9], Vector3(0, 0.72, 0), {}],
		],
	},
	&"goblin_brute": {
		"script": "res://src/enemies/goblin.gd", "data": "res://data/enemies/goblin_brute.tres",
		"body": B.BIPED, "leg": 0.6, "run": 4.5, "collision": [0.34, 1.35, 0.67], "eye": 1.22,
		"hurtboxes": [
			["HeadHurtbox", W, 2.0, "머리", ["sphere", 0.14], &"head", {}],
			["ShieldHurtbox", A, 1.0, "나무 방패", ["box", Vector3(0.5, 0.62, 0.12)], &"shield",
				{"armor": 120.0, "pass": 0.1, "broken_zone": N, "broken_mult": 1.0}],
			["BodyHurtbox", N, 1.0, "몸통", ["capsule", 0.25, 1.0], Vector3(0, 0.78, 0), {}],
		],
	},
	&"goblin_gunner": {
		"script": "res://src/enemies/goblin.gd", "data": "res://data/enemies/goblin_gunner.tres",
		"body": B.BIPED, "leg": 0.55, "run": 4.8, "collision": [0.3, 1.2, 0.6], "eye": 1.1,
		"hurtboxes": [
			["HeadHurtbox", W, 2.2, "머리", ["sphere", 0.13], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["capsule", 0.22, 0.9], Vector3(0, 0.72, 0), {}],
		],
	},
	&"goblin_thrower": {
		"script": "res://src/enemies/goblin.gd", "data": "res://data/enemies/goblin_thrower.tres",
		"body": B.BIPED, "leg": 0.55, "run": 4.8, "collision": [0.3, 1.2, 0.6], "eye": 1.1,
		"hurtboxes": [
			["HeadHurtbox", W, 2.2, "머리", ["sphere", 0.13], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["capsule", 0.22, 0.9], Vector3(0, 0.72, 0), {}],
		],
	},
	&"goblin_shaman": {
		"script": "res://src/enemies/goblin.gd", "data": "res://data/enemies/goblin_shaman.tres",
		"body": B.BIPED, "leg": 0.55, "run": 4.3, "collision": [0.3, 1.25, 0.62], "eye": 1.12,
		"hurtboxes": [
			["HeadHurtbox", W, 2.4, "머리", ["sphere", 0.14], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["capsule", 0.22, 0.9], Vector3(0, 0.72, 0), {}],
		],
	},
	&"goblin_chief": {
		"script": "res://src/enemies/goblin.gd", "data": "res://data/enemies/goblin_chief.tres",
		"body": B.BIPED, "leg": 0.72, "run": 4.6, "collision": [0.42, 1.6, 0.8], "eye": 1.48,
		"hurtboxes": [
			["HeadHurtbox", W, 1.8, "머리", ["sphere", 0.17], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["capsule", 0.3, 1.25], Vector3(0, 0.95, 0), {}],
		],
	},
	# --- 보스 ---
	&"mire_maw": {
		"script": "res://src/enemies/mire_maw.gd", "data": "res://data/enemies/mire_maw.tres",
		"body": B.SERPENT, "leg": 1.2, "run": 5.0, "collision": [1.1, 2.2, 1.1], "eye": 1.35,
		"hurtboxes": [
			["ThroatHurtbox", W, 2.5, "목 아래 턱살", ["sphere", 0.45], &"throat", {"disabled": true}],
			["EyeLHurtbox", W, 1.8, "왼눈", ["sphere", 0.14], &"eye_l", {}],
			["EyeRHurtbox", W, 1.8, "오른눈", ["sphere", 0.14], &"eye_r", {}],
			["HeadHurtbox", N, 1.0, "머리", ["box", Vector3(0.95, 0.56, 2.4)], &"head", {}],
			["BackHurtbox", A, 1.0, "등 골판", ["box", Vector3(1.3, 0.45, 2.6)], &"back",
				{"armor": 400.0, "pass": 0.25, "broken_zone": N, "broken_mult": 1.25}],
			["ChestHurtbox", N, 1.0, "몸통", ["box", Vector3(1.8, 1.2, 1.8)], &"chest", {}],
			["BellyHurtbox", N, 1.0, "몸통", ["box", Vector3(1.7, 1.1, 2.3)], &"belly", {}],
			["TailHurtbox", N, 0.8, "꼬리", ["box", Vector3(1.0, 0.8, 2.4)], &"tail", {}],
			["TailTipHurtbox", N, 0.8, "꼬리", ["box", Vector3(0.55, 0.5, 2.4)], &"tail_tip", {}],
		],
	},
	&"oneeye_sniper": {
		"script": "res://src/enemies/goblin.gd", "data": "res://data/enemies/oneeye_sniper.tres",
		"body": B.BIPED, "leg": 0.57, "run": 5.2, "collision": [0.31, 1.25, 0.62], "eye": 1.15,
		"hurtboxes": [
			["HeadHurtbox", W, 2.4, "머리", ["sphere", 0.13], &"head", {}],
			["BodyHurtbox", N, 1.0, "몸통", ["capsule", 0.23, 0.95], Vector3(0, 0.74, 0), {}],
		],
	},
}


static func has_plan(species: StringName) -> bool:
	return PLANS.has(species)


## 종 id로 적을 만든다(장면 없이). 트리에 넣으면 _ready에서 몸이 갖춰진다.
static func create(species: StringName) -> Enemy:
	var plan: Dictionary = PLANS.get(species, {})
	if plan.has("scene"):
		# 예전 장면으로 만든 종(장면의 충돌체·피격 부위를 그대로 쓴다)
		var packed: PackedScene = load(String(plan.scene))
		return packed.instantiate()
	if not plan.has("script"):
		push_error("몸 설계 없음: %s" % species)
		return null
	var script: Script = load(String(plan.script))
	var e: Enemy = script.new()
	e.data = load(String(plan.data))
	e.name = String(species)
	e.eye_height = float(plan.get("eye", 1.0))
	return e


## Enemy._ready에서 부른다: 모델을 입히고 충돌체·피격 부위·동작기를 갖춘다.
static func build(e: Enemy) -> void:
	var species := e.data.id
	var plan: Dictionary = PLANS.get(species, {})
	var model_id := e.data.model_id
	var t := SpeciesModels.template(model_id)
	if t == null:
		return
	var old := e.get_node_or_null(^"Visual")
	if old:
		e.remove_child(old)
		old.queue_free()
	var rig := t.instantiate()
	e.add_child(rig)
	e.move_child(rig, 0)
	if plan.has("collision") and e.get_node_or_null(^"CollisionShape3D") == null:
		var c: Array = plan.collision
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var shape := CapsuleShape3D.new()
		shape.radius = float(c[0])
		shape.height = float(c[1])
		cs.shape = shape
		cs.position = Vector3(0, float(c[2]), 0)
		e.add_child(cs)
	for hb_def: Array in plan.get("hurtboxes", []):
		if e.get_node_or_null(NodePath(String(hb_def[0]))):
			continue
		var hb := _make_hurtbox(hb_def)
		var place: Variant = hb_def[5]
		if place is StringName:
			rig.attach_socket(place, hb)
		else:
			hb.position = place
			e.add_child(hb)
	var rehome: Dictionary = plan.get("rehome", {})
	for hb_name: String in rehome:
		var hb := e.get_node_or_null(NodePath(hb_name)) as Node3D
		if hb == null:
			continue
		e.remove_child(hb)
		rig.attach_socket(rehome[hb_name], hb)
	var anim := CreatureAnimator.new(rig, int(plan.get("body", B.QUADRUPED)), float(plan.get("leg", 0.5)),
		float(plan.get("run", 6.0)))
	e.set_body(rig, anim)
	# 화면 밖이면 동작 갱신을 줄인다.
	var vis := VisibleOnScreenNotifier3D.new()
	vis.name = "OnScreen"
	vis.aabb = t.custom_aabb
	vis.screen_entered.connect(func() -> void: e._on_screen = true)
	vis.screen_exited.connect(func() -> void: e._on_screen = false)
	rig.add_child(vis)
	e._on_body_built(rig)


static func _make_hurtbox(d: Array) -> Hurtbox:
	var hb := Hurtbox.new()
	hb.name = String(d[0])
	hb.zone = int(d[1])
	hb.damage_multiplier = float(d[2])
	hb.part_name = String(d[3])
	var extra: Dictionary = d[6]
	if extra.has("armor"):
		hb.armor_max = float(extra.armor)
		hb.armor_pass_through = float(extra.get("pass", 0.2))
		hb.broken_zone = int(extra.get("broken_zone", N))
		hb.broken_multiplier = float(extra.get("broken_mult", 1.0))
	hb.starts_disabled = bool(extra.get("disabled", false))
	var cs := CollisionShape3D.new()
	var sd: Array = d[4]
	match String(sd[0]):
		"sphere":
			var sh := SphereShape3D.new()
			sh.radius = float(sd[1])
			cs.shape = sh
		"box":
			var bx := BoxShape3D.new()
			bx.size = sd[1]
			cs.shape = bx
		"capsule":
			var cp := CapsuleShape3D.new()
			cp.radius = float(sd[1])
			cp.height = float(sd[2])
			cs.shape = cp
	hb.add_child(cs)
	return hb

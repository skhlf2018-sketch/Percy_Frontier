class_name MireArena
extends Node3D
## 1지역 보스 전장 「늪턱 구렁」(기획서 §16). 남서 늪 끝, 얕은 물이 고인 둥근 구덩이.
## - 가운데 진흙 속에 늪턱 구렁이 잠들어 있고 수면에 거품이 오른다. 구덩이 안으로 들어서면 솟아올라 싸움이 시작된다.
## - 돌기둥 넷: 뛰어들어 물기·몸 굴리기를 여기에 부딪히게 하면 보스가 한참 정신을 잃는다(핵심 질문: 지형 활용).
## - 구렁 동쪽 둔덕에 보스전 직전 거점(휴식·보급·부활, §16.2 재도전 거점과 최소 보급, §19.2)이 있다.
## - 상대가 싸움터를 떠나거나 쓰러지면 싸움이 처음으로 돌아간다. 처치 기록은 저장되고 다시 나타나지 않는다(§19.3).
## - 처음 쓰러뜨리면 전용 보상(유니크 대검 「늪턱 이빨」, 핵, 칭호)을 확정으로 준다(§11.1, §16.2).

signal fight_started
signal fight_reset
signal boss_defeated(first: bool)

const BOSS_ID := &"mire_maw"
## 이 안으로 들어서면 보스가 깨어난다.
const TRIGGER_RADIUS := 17.0
## 보스가 싸우는 범위(이 밖의 상대는 쫓지 않는다)
const FIGHT_RADIUS := 26.0
## 상대가 이보다 멀리 이 시간 넘게 떠나 있으면 싸움을 되돌린다.
const LEAVE_RADIUS := 44.0
const LEAVE_TIME := 6.0
## 보스가 움직이는 바닥 반경(물에 잠긴 평지)
const FLOOR_RADIUS := 17.0
const PILLAR_RING := 11.0
const PILLAR_RADIUS := 1.5
## 돌기둥 자리(가운데에서 본 각도, 도). 연못 쪽 입구(북동)는 비워 둔다.
const PILLAR_ANGLES: Array[float] = [150.0, 215.0, 285.0, 20.0]
## 보스전 직전 거점(구렁 동쪽 둔덕)
const REST_SPOT := Vector2(-156, 210)
const FIRST_KILL_SILVER := 300

var field: FieldWorld
var player: Player
var boss: MireMaw
var center := Vector3.ZERO
var pillars: Array[Vector3] = []
var fighting: bool = false
var supply: SupplyPoint

var _leave_timer: float = 0.0
var _mist: FogVolume


func setup(f: FieldWorld) -> void:
	field = f
	name = "MireArena"
	center = f.terrain.point_at(FieldLayout.MAW_CENTER)


func _ready() -> void:
	if field == null:
		return
	_build_pillars()
	_build_decor()
	_build_mist()
	_place_supply()
	if not GameState.boss_defeated(BOSS_ID):
		spawn_boss()


## 보스를 가운데 진흙 속에 잠든 채로 둔다(이미 쓰러뜨렸으면 두지 않는다).
func spawn_boss() -> void:
	if boss and is_instance_valid(boss):
		return
	boss = EnemyBody.create(BOSS_ID) as MireMaw
	if boss == null:
		return
	boss.set_arena(center, FLOOR_RADIUS, FIGHT_RADIUS, pillars, PILLAR_RADIUS)
	add_child(boss)
	# 머리는 입구(북동, 연못 쪽)를 향한다.
	var to_gate := Vector2(1.0, -0.8).normalized()
	boss.global_position = center + Vector3.UP * 0.1
	boss.rotation.y = atan2(-to_gate.x, -to_gate.y)
	boss.home_position = boss.global_position
	boss.home_yaw = boss.rotation.y
	boss.reset_physics_interpolation()
	boss.died.connect(_on_boss_died)
	boss.awakened.connect(_on_boss_awakened)


func is_boss_alive() -> bool:
	return boss != null and is_instance_valid(boss) and boss.is_alive()


## HUD 보스 체력바를 보일지
func shows_boss_bar() -> bool:
	return fighting and is_boss_alive()


func _process(delta: float) -> void:
	if not is_boss_alive():
		return
	if player == null or not is_instance_valid(player):
		return
	var d := Vector2(player.global_position.x - center.x, player.global_position.z - center.z).length()
	if not fighting:
		if player.alive and d < TRIGGER_RADIUS and boss.dormant:
			boss.awaken(player)
		return
	if not player.alive:
		reset_fight()
		return
	if d > LEAVE_RADIUS:
		_leave_timer += delta
		if _leave_timer > LEAVE_TIME:
			GameEvents.notify("늪턱 구렁이 진흙 속으로 가라앉았다", GameEvents.NoticeKind.INFO)
			reset_fight()
	else:
		_leave_timer = 0.0


func _on_boss_awakened() -> void:
	if fighting:
		return
	fighting = true
	_leave_timer = 0.0
	GameState.record_boss(BOSS_ID, "attempts")
	var first_sight := GameState.record_boss(BOSS_ID, "seen")
	var sub := "돌진을 돌기둥에 부딪히게 하라 — 정신을 잃으면 목 아래 붉은 턱살이 드러난다" if first_sight else "퍼시 외곽권 보스"
	GameEvents.announce("보스 · %s" % boss.data.display_name, sub, GameEvents.AnnounceKind.SYSTEM)
	Sfx.play_ui(&"boss_sting")
	fight_started.emit()


## 싸움을 처음으로 되돌린다(보스는 다시 진흙 속에 잠든다).
func reset_fight() -> void:
	_leave_timer = 0.0
	if is_boss_alive():
		boss.reset_fight()
	if fighting:
		fighting = false
		fight_reset.emit()


## 휴식할 때: 싸우는 중이 아니면 보스를 제자리에 잠재운다.
func reset_if_idle() -> void:
	if not fighting and is_boss_alive() and not boss.dormant:
		boss.reset_fight()


func _on_boss_died(_e: Enemy) -> void:
	fighting = false
	var first := GameState.record_boss(BOSS_ID, "defeated")
	if first:
		_grant_first_kill()
	boss_defeated.emit(first)


## 최초 처치 확정 보상(기획서 §16.2): 유니크 대검, 핵, 비늘판, 은화, 칭호
func _grant_first_kill() -> void:
	var fang := WeaponItem.create(&"maw_fang", ItemRarity.Tier.UNIQUE, [&"butcher", &"serrated", &"heavy_blow"], "늪턱 이빨")
	GameState.store_reward(fang)
	GameState.add_item(&"maw_core", 1)
	GameState.add_item(&"maw_scale", 3)
	GameState.add_silver(FIRST_KILL_SILVER)
	GameState.grant_title(&"maw_hunter")
	GameEvents.announce("보스 처치 · 늪턱 구렁",
		"유니크 대검 「늪턱 이빨」(무기 공방 창고) · 늪턱 구렁의 핵 · 비늘판 3 · 은화 %d · 칭호 「%s」" % [FIRST_KILL_SILVER,
			UniqueDB.title_name(&"maw_hunter")], GameEvents.AnnounceKind.DISCOVERY)
	Sfx.play_ui(&"unlock")


# --- 무대 ---

func _ground(p: Vector2) -> Vector3:
	return field.terrain.point_at(p)


func _build_pillars() -> void:
	var body := StaticBody3D.new()
	body.name = "PillarColliders"
	body.collision_layer = CombatLayers.WORLD
	body.collision_mask = 0
	add_child(body)
	for i in PILLAR_ANGLES.size():
		var a := deg_to_rad(PILLAR_ANGLES[i])
		var p2 := FieldLayout.MAW_CENTER + Vector2(cos(a), sin(a)) * PILLAR_RING
		var base := _ground(p2)
		var height := 6.5 + float(i % 2) * 1.6
		var mi := MeshInstance3D.new()
		mi.name = "Pillar%d" % i
		mi.mesh = RockKit.pillar(700 + i * 13, height, PILLAR_RADIUS)
		mi.position = base
		mi.rotation.y = float(i) * 1.7
		add_child(mi)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = PILLAR_RADIUS
		cyl.height = height + 1.5
		cs.shape = cyl
		cs.position = base + Vector3.UP * (height * 0.5 - 0.5)
		body.add_child(cs)
		pillars.append(base)


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# 둘레 비탈의 죽은 나무
	var dead := MultiMeshInstance3D.new()
	dead.name = "DeadTrees"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = TreeKit.dead(5151)
	var spots: Array[Transform3D] = []
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(FieldLayout.MAW_RADIUS + 2.0, FieldLayout.MAW_RADIUS + 9.0)
		var p := FieldLayout.MAW_CENTER + Vector2(cos(a), sin(a)) * r
		var g := _ground(p)
		var s := rng.randf_range(0.9, 1.5)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.18, 0.18))
		spots.append(Transform3D(basis.scaled(Vector3.ONE * s), g - Vector3.UP * 0.2))
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	dead.multimesh = mm
	dead.material_override = TreeKit.material()
	add_child(dead)
	# 물속의 부러진 통나무와 먹잇감의 뼈(보스의 둥지임을 알린다)
	add_child(_bones_node(rng))
	# 물가의 부들
	add_child(_reeds_node(rng))


## 먹잇감의 뼈: 반쯤 잠긴 갈비뼈와 뿔 달린 두개골, 흩어진 뼈
func _bones_node(rng: RandomNumberGenerator) -> Node3D:
	var b := RigBuilder.new()
	b.bone(&"root", &"", Vector3.ZERO)
	var bone_col := Color(0.8, 0.76, 0.64)
	var dirty := func(v: Vector3, _n: Vector3, c: Color) -> Color:
		return c.lerp(Color(0.34, 0.3, 0.22), smoothstep(0.35, -0.2, v.y) * 0.8)
	# 갈비뼈 우리
	var spine_from := Vector3(-1.6, -0.15, 0.0)
	var spine_to := Vector3(1.8, 0.05, 0.3)
	b.cone(spine_from, spine_to, 0.12, &"root", CreatureMaterials.Kind.HORN, bone_col, Vector3(0, 0.15, 0), 8)
	for i in 7:
		var t := float(i) / 6.0
		var at := spine_from.lerp(spine_to, t)
		for side: float in [-1.0, 1.0]:
			var rib: Array[RigBuilder.P] = []
			var span := lerpf(1.1, 0.7, absf(t - 0.4))
			for k in 5:
				var u := float(k) / 4.0
				var ang := lerpf(0.2, PI * 0.95, u)
				var p := at + Vector3(0.1 * u, sin(ang) * span * 0.9 - 0.2 * u * u, side * (1.0 - cos(ang)) * span * 0.55)
				rib.append(RigBuilder.pt(p, 0.05 * (1.0 - 0.5 * u), 0.04 * (1.0 - 0.5 * u), &"root"))
			b.loft(rib, CreatureMaterials.Kind.HORN, bone_col, bone_col.darkened(0.2), 6, 2, Vector3.UP, true, true, dirty)
	# 두개골과 뿔
	var skull := Vector3(-2.6, 0.05, -0.8)
	b.ellipsoid(skull, Vector3(0.38, 0.3, 0.55), &"root", CreatureMaterials.Kind.HORN, bone_col, bone_col.darkened(0.25), 12,
		Basis(Vector3.UP, 0.6) * Basis(Vector3.FORWARD, 0.35), dirty)
	for side: float in [-1.0, 1.0]:
		var hb := skull + Vector3(side * 0.28, 0.2, -0.1)
		b.cone(hb, hb + Vector3(side * 0.7, 0.45, -0.3), 0.1, &"root", CreatureMaterials.Kind.HORN, bone_col.darkened(0.15),
			Vector3(side * 0.1, 0.2, 0), 8)
		b.ellipsoid(skull + Vector3(side * 0.16, 0.08, -0.32), Vector3(0.08, 0.07, 0.06), &"root", CreatureMaterials.Kind.WET_SKIN,
			Color(0.05, 0.04, 0.03))
	# 흩어진 긴 뼈
	for i in 5:
		var p := Vector3(rng.randf_range(-3.5, 3.5), -0.05, rng.randf_range(-2.5, 2.5))
		var ang := rng.randf() * TAU
		var d := Vector3(cos(ang), 0.05, sin(ang)).normalized() * rng.randf_range(0.6, 1.1)
		b.cone(p - d, p + d, 0.07, &"root", CreatureMaterials.Kind.HORN, bone_col.darkened(0.1), Vector3.ZERO, 6)
	var mi := MeshInstance3D.new()
	mi.name = "PreyBones"
	mi.mesh = b.build().mesh
	var at2 := FieldLayout.MAW_CENTER + Vector2(-7.0, 5.5)
	mi.position = _ground(at2)
	mi.rotation.y = 0.7
	return mi


## 물가의 부들: 가는 잎과 갈색 이삭 덤불
func _reeds_node(rng: RandomNumberGenerator) -> Node3D:
	var kit := MeshKit.Builder.new()
	var leaf := Color(0.36, 0.42, 0.2)
	for c in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(FieldLayout.MAW_RADIUS - 3.5, FieldLayout.MAW_RADIUS + 3.0)
		var p := FieldLayout.MAW_CENTER + Vector2(cos(a), sin(a)) * r
		var base := _ground(p)
		for k in rng.randi_range(5, 9):
			var off := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
			var h := rng.randf_range(1.1, 2.0)
			var tip := base + off + Vector3(rng.randf_range(-0.25, 0.25), h, rng.randf_range(-0.25, 0.25))
			kit.frustum(base + off - Vector3.UP * 0.1, tip, 0.025, 0.004, 3, Color(leaf * rng.randf_range(0.8, 1.15), 0.0),
				0.0, 0.6, false)
			if rng.randf() < 0.45:
				var head := base + off + (tip - base - off) * 0.78
				kit.frustum(head, head + (tip - head).normalized() * 0.28, 0.045, 0.04, 5, Color(0.36, 0.24, 0.14, 0.5), 0.5, 0.6)
	var mi := MeshInstance3D.new()
	mi.name = "Reeds"
	mi.mesh = kit.commit()
	mi.material_override = MeshKit.foliage_material()
	return mi


## 구렁에 고인 낮은 안개(부피 안개를 켠 그래픽 품질에서 보인다)
func _build_mist() -> void:
	_mist = FogVolume.new()
	_mist.name = "Mist"
	_mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	_mist.size = Vector3(FieldLayout.MAW_RADIUS * 2.6, 5.0, FieldLayout.MAW_RADIUS * 2.6)
	var fm := FogMaterial.new()
	fm.density = 0.06
	fm.albedo = Color(0.62, 0.66, 0.55)
	fm.height_falloff = 0.6
	fm.edge_fade = 0.4
	_mist.material = fm
	_mist.position = center + Vector3.UP * 1.0
	add_child(_mist)


## 보스전 직전 거점: 구렁 동쪽 둔덕(구렁이 내려다보이는 곳)
func _place_supply() -> void:
	var at := field._clear_spot(REST_SPOT, 1.6) if field.is_inside_tree() else REST_SPOT
	supply = SupplyPoint.new()
	supply.name = "Supply_maw"
	supply.label_text = "늪턱 구렁 앞"
	var to_center := Vector2(FieldLayout.MAW_CENTER.x - at.x, FieldLayout.MAW_CENTER.y - at.y)
	supply.rotation.y = atan2(to_center.x, to_center.y)
	supply.position = _ground(at)
	add_child(supply)

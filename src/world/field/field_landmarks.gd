class_name FieldLandmarks
extends Node3D
## 멀리서도 알아볼 수 있는 장소(기획서 §4.1, §23.2): 강하선 잔해(시작 지점), 북쪽 야영지, 고목,
## 무너진 감시탑(오를 수 있는 전망 지점), 강을 건너는 나무다리. 안전 거점 비콘도 여기서 놓는다.

var terrain: FieldTerrain
var layout: FieldLayout
## 안전 거점(이름 → SupplyPoint)
var supply_points: Dictionary = {}
var spots: Dictionary = {}

var _solid := MeshKit.Builder.new()
var _body: StaticBody3D
var _fire_lights: Array[OmniLight3D] = []
var _time: float = 0.0


func build(field_terrain: FieldTerrain, field_layout: FieldLayout) -> void:
	terrain = field_terrain
	layout = field_layout
	_body = StaticBody3D.new()
	_body.name = "LandmarkColliders"
	_body.collision_layer = CombatLayers.WORLD
	_body.collision_mask = 0
	add_child(_body)
	_build_drop_site()
	_build_camp()
	_build_old_tree()
	_build_watchtower()
	_build_bridge()
	var mi := MeshInstance3D.new()
	mi.name = "LandmarkMesh"
	mi.mesh = _solid.commit()
	mi.material_override = MeshKit.solid_material()
	add_child(mi)


func _process(delta: float) -> void:
	_time += delta
	for i in _fire_lights.size():
		_fire_lights[i].light_energy = 1.5 + sin(_time * 11.0 + i) * 0.25 + sin(_time * 27.0 + i * 2.0) * 0.12


func _ground(p: Vector2) -> Vector3:
	return terrain.point_at(p)


func _collider(shape: Shape3D, xform: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xform
	_body.add_child(cs)


func _box_collider(size: Vector3, xform: Transform3D) -> void:
	var b := BoxShape3D.new()
	b.size = size
	_collider(b, xform)


func _label(text: String, pos: Vector3, size: int = 56) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.95, 0.95, 0.9)
	l.position = pos
	add_child(l)


func _supply(id: String, label: String, pos: Vector3, yaw: float) -> SupplyPoint:
	var sp := SupplyPoint.new()
	sp.name = "Supply_" + id
	sp.label_text = label
	sp.position = pos
	sp.rotation.y = yaw
	add_child(sp)
	supply_points[id] = sp
	return sp


func _fire(pos: Vector3, scale: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 3.0 + pos.z)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var from := pos + Vector3(cos(a), 0.05, sin(a)) * 0.55 * scale
		_solid.frustum(from, pos + Vector3.UP * 0.15, 0.07 * scale, 0.05 * scale, 5, Color(0.3, 0.2, 0.12, 0.0))
	for i in 7:
		var a := TAU * float(i) / 7.0
		_solid.blob(pos + Vector3(cos(a), 0.0, sin(a)) * 0.75 * scale, 0.17 * scale, Color(0.4, 0.39, 0.37, 0.0), 0.0, rng, 0.2)
	var flame := MeshInstance3D.new()
	var b := MeshKit.Builder.new()
	b.blob(pos + Vector3.UP * 0.3 * scale, 0.32 * scale, Color(1.0, 0.55, 0.18, 0.0), 0.0, rng, 0.3, Vector3(0.8, 1.4, 0.8))
	flame.mesh = b.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.6, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.15)
	m.emission_energy_multiplier = 4.0
	flame.material_override = m
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.28)
	l.omni_range = 9.0 * scale
	l.position = pos + Vector3.UP * 0.8
	add_child(l)
	_fire_lights.append(l)
	var smoke := CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 4.0
	smoke.position = pos + Vector3.UP * 0.6 * scale
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.25, 0.4, 0.0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.scale_amount_min = 0.5 * scale
	smoke.scale_amount_max = 1.2 * scale
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.radial_segments = 6
	sm.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.35, 0.35, 0.35, 0.25)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smat
	smoke.mesh = sm
	add_child(smoke)


# --- 강하선 잔해: 새 게임 시작 지점 ---

func _build_drop_site() -> void:
	var c := _ground(FieldLayout.DROP_SITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var hull := Color(0.78, 0.8, 0.82)
	var stripe := Color(0.92, 0.5, 0.18)
	# 동체: 땅에 비스듬히 박힌 원통
	var yaw := 0.5
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.22) * Basis(Vector3.FORWARD, 0.15)
	var nose := c + basis * Vector3(0, 1.2, -5.0)
	var tail := c + basis * Vector3(0, 1.6, 4.5)
	_solid.frustum(tail, nose, 1.7, 1.2, 10, Color(hull, 0.0), 0.0, 0.0, true)
	_solid.frustum(nose, nose + basis * Vector3(0, -0.2, -1.6), 1.2, 0.3, 10, Color(hull * 0.9, 0.0), 0.0, 0.0, true)
	_solid.frustum(tail + basis * Vector3(0, 0, 0.1), tail + basis * Vector3(0, 0, -0.9), 1.75, 1.75, 10, Color(stripe, 0.0), 0.0, 0.0, false)
	# 부러진 날개와 엔진
	_solid.box(c + basis * Vector3(2.6, 1.3, 1.0), Vector3(3.6, 0.18, 2.2), hull * 0.85, basis * Basis(Vector3.FORWARD, -0.35))
	_solid.box(c + basis * Vector3(-3.4, 0.4, 2.4), Vector3(2.8, 0.18, 2.0), hull * 0.75, Basis(Vector3.UP, 1.4) * Basis(Vector3.FORWARD, 0.9))
	_solid.frustum(tail + basis * Vector3(0, 0, 0.2), tail + basis * Vector3(0, 0, 1.6), 0.9, 1.1, 8, Color(0.3, 0.3, 0.32, 0.0), 0.0, 0.0, true)
	# 창(조종석)
	_solid.box(nose + basis * Vector3(0, 0.75, 0.4), Vector3(1.4, 0.5, 1.2), Color(0.18, 0.28, 0.35), basis)
	_box_collider(Vector3(3.4, 3.2, 10.5), Transform3D(basis, c + basis * Vector3(0, 1.4, -0.3)))
	# 흩어진 잔해와 불길
	for i in 9:
		var a := rng.randf() * TAU
		var d := rng.randf_range(5.0, 12.0)
		var p := _ground(FieldLayout.DROP_SITE + Vector2(cos(a), sin(a)) * d)
		var s := rng.randf_range(0.3, 0.9)
		_solid.box(p + Vector3.UP * s * 0.3, Vector3(s * 1.4, s * 0.4, s), hull * rng.randf_range(0.55, 0.9),
			Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)))
	_fire(c + basis * Vector3(2.0, 0.2, 5.5), 0.8)
	# 땅이 패인 자국
	for i in 6:
		var p := _ground(FieldLayout.DROP_SITE + Vector2(-2.0 - i * 2.2, -3.0 - i * 1.4))
		_solid.box(p + Vector3.UP * 0.02, Vector3(2.0, 0.08, 1.4), Color(0.3, 0.24, 0.17), Basis(Vector3.UP, yaw + 0.2))
	# 공명 장치가 자동으로 펼친 보급 비콘(첫 안전 거점)
	var beacon_pos := _ground(FieldLayout.DROP_SITE + Vector2(7.0, 6.0))
	_supply("drop_site", "강하 지점 비콘", beacon_pos, PI * 0.5)
	# 잔해를 등지고 길이 시작되는 동쪽을 바라본다(잔해는 왼쪽 뒤로 보인다).
	var start := FieldLayout.DROP_SITE + Vector2(13.0, 2.0)
	var look := Vector2(1.0, 0.25).normalized()
	spots["new_game"] = Transform3D(Basis(Vector3.UP, atan2(-look.x, -look.y)), _ground(start) + Vector3.UP * 0.1)


# --- 북쪽 야영지 ---

func _build_camp() -> void:
	var c := _ground(FieldLayout.CAMP)
	var tent := Color(0.62, 0.55, 0.4)
	for i in 2:
		var a := PI * 0.3 + i * PI * 0.9
		var p := c + Vector3(cos(a), 0.0, sin(a)) * 4.2
		var basis := Basis(Vector3.UP, a + PI * 0.5)
		var w := 1.5
		var l := 2.6
		var h := 1.6
		var pts: Array[Vector3] = [
			p + basis * Vector3(-w, 0, -l), p + basis * Vector3(w, 0, -l), p + basis * Vector3(0, h, -l),
			p + basis * Vector3(-w, 0, l), p + basis * Vector3(w, 0, l), p + basis * Vector3(0, h, l),
		]
		_solid.quad(pts[0], pts[3], pts[5], pts[2], Color(tent, 0.0), basis * Vector3(-1, 0.6, 0))
		_solid.quad(pts[1], pts[4], pts[5], pts[2], Color(tent * 0.9, 0.0), basis * Vector3(1, 0.6, 0))
		_solid.tri(pts[0], pts[1], pts[2], Color(tent * 0.8, 0.0), basis * Vector3(0, 0, -1))
		_box_collider(Vector3(w * 2.0, h, l * 2.0), Transform3D(basis, p + Vector3.UP * h * 0.5))
	_fire(c + Vector3(0.0, 0.05, 0.0), 1.0)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var p := c + Vector3(cos(a), 0.25, sin(a)) * 2.2
		var basis := Basis(Vector3.UP, a + PI * 0.5)
		_solid.frustum(p - basis.x * 0.9, p + basis.x * 0.9, 0.22, 0.22, 7, Color(0.38, 0.28, 0.18, 0.0))
	_supply("camp", "북쪽 야영지", c + Vector3(-3.5, 0.0, 3.0), PI * 0.8)


# --- 고목 ---

func _build_old_tree() -> void:
	var c := _ground(FieldLayout.OLD_TREE) - Vector3.UP * 0.3
	var mi := MeshInstance3D.new()
	mi.name = "OldTree"
	mi.mesh = TreeKit.ancient(1)
	mi.material_override = TreeKit.material()
	mi.position = c
	add_child(mi)
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.2
	cyl.height = 14.0
	_collider(cyl, Transform3D(Basis.IDENTITY, c + Vector3.UP * 7.0))
	spots["old_tree"] = Transform3D(Basis.IDENTITY, c + Vector3(0, 0.3, 6.0))


# --- 무너진 감시탑(전망 지점) ---

func _build_watchtower() -> void:
	var c := _ground(FieldLayout.WATCHTOWER)
	var stone := Color(0.55, 0.53, 0.49)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var sides := 8
	var radius := 3.6
	var floor_y := 4.0
	# 경사로가 올라오는 쪽이 입구다(위층 난간이 없다).
	var ramp_dir := Vector3(0.38, 0, 0.92).normalized()
	var ramp_angle_y := fposmod(atan2(ramp_dir.z, ramp_dir.x), TAU)
	var gap := int(floor(ramp_angle_y / (TAU / float(sides)))) % sides
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * radius
		var mid := (p0 + p1) * 0.5
		var len := p0.distance_to(p1)
		var basis := Basis(Vector3.UP, atan2(p1.x - p0.x, p1.z - p0.z) + PI * 0.5)
		var h := floor_y
		if i != gap:
			# 대부분은 허리 높이의 난간만 남고, 두 군데만 기둥처럼 높게 남았다.
			var tall := i == (gap + 3) % sides or i == (gap + 5) % sides
			h = floor_y + (rng.randf_range(2.2, 3.4) if tall else 1.05 + rng.randf_range(0.0, 0.25))
		_solid.box(mid + Vector3.UP * h * 0.5, Vector3(len + 0.1, h, 0.6), stone * rng.randf_range(0.9, 1.08), basis)
		_box_collider(Vector3(len + 0.1, h, 0.6), Transform3D(basis, mid + Vector3.UP * h * 0.5))
	# 위층 바닥과 경사로(무너진 돌무더기)
	_solid.box(c + Vector3.UP * (floor_y - 0.2), Vector3(radius * 1.8, 0.4, radius * 1.8), stone * 0.85)
	_box_collider(Vector3(radius * 1.8, 0.4, radius * 1.8), Transform3D(Basis.IDENTITY, c + Vector3.UP * (floor_y - 0.2)))
	var ramp_len := 9.0
	var ramp_angle := atan2(floor_y, ramp_len - 1.0)
	var ramp_basis := Basis(Vector3.UP, atan2(ramp_dir.x, ramp_dir.z)) * Basis(Vector3.RIGHT, ramp_angle)
	var ramp_center := c + ramp_dir * (radius + ramp_len * 0.42) + Vector3.UP * (floor_y * 0.45)
	_solid.box(ramp_center, Vector3(2.4, 0.5, ramp_len), stone * 0.75, ramp_basis)
	_box_collider(Vector3(2.4, 0.5, ramp_len), Transform3D(ramp_basis, ramp_center))
	for i in 10:
		var p := ramp_center + ramp_basis * Vector3(rng.randf_range(-1.3, 1.3), 0.3, rng.randf_range(-4.0, 4.0))
		_solid.blob(p, rng.randf_range(0.25, 0.5), Color(stone * 0.8, 0.0), 0.0, rng, 0.3)
	# 무너진 벽 조각
	for i in 7:
		var a := rng.randf() * TAU
		var p := _ground(FieldLayout.WATCHTOWER + Vector2(cos(a), sin(a)) * rng.randf_range(5.0, 9.0))
		var s := rng.randf_range(0.5, 1.1)
		_solid.box(p + Vector3.UP * s * 0.3, Vector3(s * 1.2, s * 0.6, s * 0.8), stone * 0.85, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	spots["watchtower_top"] = Transform3D(Basis.IDENTITY, c + Vector3.UP * floor_y)


# --- 나무다리 ---

func _build_bridge() -> void:
	# 길을 따라가며 강에서 16m 떨어진 양쪽 지점을 찾는다.
	var samples: Array[Vector2] = []
	for i in FieldLayout.ROAD.size() - 1:
		var a: Vector2 = FieldLayout.ROAD[i]
		var b: Vector2 = FieldLayout.ROAD[i + 1]
		var steps := int(a.distance_to(b) / 0.5)
		for s in steps:
			samples.append(a.lerp(b, float(s) / float(steps)))
	var west := Vector2.INF
	var east := Vector2.INF
	var crossed := false
	for p in samples:
		var d := layout.distance_to_river(p)
		if not crossed:
			if d > 15.5:
				west = p
			elif d < 2.0:
				crossed = true
		elif d > 15.5:
			east = p
			break
	if west == Vector2.INF or east == Vector2.INF:
		push_warning("다리 위치를 찾지 못했습니다.")
		return
	var a3 := _ground(west) + Vector3.UP * 0.12
	var b3 := _ground(east) + Vector3.UP * 0.12
	var dir := b3 - a3
	var len := dir.length()
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var mid := (a3 + b3) * 0.5
	var wood := Color(0.47, 0.35, 0.22)
	var deck_basis := basis
	_solid.box(mid, Vector3(3.6, 0.3, len + 0.6), wood, deck_basis, wood * 1.08)
	_box_collider(Vector3(3.6, 0.3, len + 0.6), Transform3D(deck_basis, mid))
	# 난간과 기둥
	var posts := int(len / 3.0)
	for i in posts + 1:
		var t := float(i) / float(posts)
		var p := a3.lerp(b3, t)
		for side in [-1.0, 1.0]:
			var q: Vector3 = p + deck_basis.x * side * 1.7
			_solid.box(q + Vector3.UP * 0.6, Vector3(0.16, 1.2, 0.16), wood * 0.8, Basis(Vector3.UP, atan2(flat.x, flat.z)))
			var ground_y := terrain.height_at(q.x, q.z)
			if q.y - ground_y > 0.6:
				_solid.box(Vector3(q.x, (q.y + ground_y) * 0.5 - 0.2, q.z), Vector3(0.28, q.y - ground_y + 0.4, 0.28), wood * 0.65)
	for side in [-1.0, 1.0]:
		var ra: Vector3 = a3 + deck_basis.x * side * 1.7 + Vector3.UP * 1.15
		var rb: Vector3 = b3 + deck_basis.x * side * 1.7 + Vector3.UP * 1.15
		_solid.box((ra + rb) * 0.5, Vector3(0.12, 0.12, len), wood * 0.9, deck_basis)
		_box_collider(Vector3(0.2, 1.3, len), Transform3D(deck_basis, (ra + rb) * 0.5 - Vector3.UP * 0.55))
	spots["bridge"] = Transform3D(deck_basis, mid)

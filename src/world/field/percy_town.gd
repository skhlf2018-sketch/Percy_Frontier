class_name PercyTown
extends Node3D
## 퍼시 마을 외관(기획서 §18): 목책과 정문, 광장과 우물, 여관·잡화점·무기 공방·공명 연구소·의뢰 게시판,
## 통신탑(랜드마크), 민가, 가로등. 건물 안으로는 들어가지 않고, 시설은 문과 카운터 앞에서 이용한다.
## 밤이면 창문과 가로등이 켜진다. 시설과 주민이 설 자리는 spots에 이름으로 남긴다.

const PLASTER := Color(0.87, 0.83, 0.73)
const TIMBER := Color(0.34, 0.23, 0.15)
const STONE := Color(0.52, 0.5, 0.47)
const DARK_WOOD := Color(0.24, 0.17, 0.11)
const ROOF_COLORS: Array[Color] = [
	Color(0.56, 0.25, 0.18), Color(0.3, 0.36, 0.46), Color(0.47, 0.34, 0.21), Color(0.63, 0.46, 0.26),
]
const PALISADE_RADIUS := 44.0
const GATE_HALF_WIDTH := 4.0

var center := Vector3.ZERO
var window_material: StandardMaterial3D
var lantern_material: StandardMaterial3D
var lantern_lights: Array[OmniLight3D] = []
var forge_light: OmniLight3D
var tower_light: OmniLight3D
## 시설·주민 자리: 이름 → Transform3D(앞쪽이 -Z가 아니라 바라보는 방향 +Z)
var spots: Dictionary = {}

var _solid := MeshKit.Builder.new()
var _windows := MeshKit.Builder.new()
var _glow := MeshKit.Builder.new()
var _body: StaticBody3D
var _time: float = 0.0
var _night: float = 0.0


func build(layout: FieldLayout) -> void:
	center = Vector3(FieldLayout.TOWN_CENTER.x, FieldLayout.TOWN_HEIGHT, FieldLayout.TOWN_CENTER.y)
	_body = StaticBody3D.new()
	_body.name = "TownColliders"
	_body.collision_layer = CombatLayers.WORLD
	_body.collision_mask = 0
	add_child(_body)
	window_material = StandardMaterial3D.new()
	window_material.vertex_color_use_as_albedo = true
	window_material.emission_enabled = true
	window_material.emission = Color(1.0, 0.72, 0.38)
	window_material.emission_energy_multiplier = 0.0
	lantern_material = StandardMaterial3D.new()
	lantern_material.albedo_color = Color(1.0, 0.85, 0.55)
	lantern_material.emission_enabled = true
	lantern_material.emission = Color(1.0, 0.72, 0.36)
	lantern_material.emission_energy_multiplier = 0.4
	_build_palisade()
	_build_gate()
	_build_plaza()
	_build_facilities()
	_build_houses()
	_build_tower()
	_build_lanterns()
	_build_props()
	_emit(_solid, MeshKit.solid_material(), "TownSolid")
	_emit(_windows, window_material, "TownWindows")
	var glow_mat := StandardMaterial3D.new()
	glow_mat.vertex_color_use_as_albedo = true
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.45, 0.95, 1.0)
	glow_mat.emission_energy_multiplier = 2.2
	_emit(_glow, glow_mat, "TownGlow")


## 0(낮)..1(밤): 창문과 가로등 밝기
func set_night_amount(amount: float) -> void:
	_night = amount
	window_material.emission_energy_multiplier = amount * 2.4
	lantern_material.emission_energy_multiplier = 0.4 + amount * 3.0
	for l in lantern_lights:
		l.light_energy = amount * 1.5
		l.visible = amount > 0.05


func _process(delta: float) -> void:
	_time += delta
	if forge_light:
		forge_light.light_energy = 1.6 + sin(_time * 9.0) * 0.25 + sin(_time * 23.0) * 0.15
	if tower_light:
		# 고장 난 통신탑: 붉은 등이 불규칙하게 깜박인다.
		tower_light.light_energy = 1.2 if fmod(_time, 2.7) < 0.25 or fmod(_time, 5.3) < 0.12 else 0.0


# --- 도우미 ---

func _world(local: Vector3, basis: Basis, origin: Vector3) -> Vector3:
	return origin + basis * local


func _collider(size: Vector3, xform: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xform
	_body.add_child(cs)


func _label(text: String, xform: Transform3D, size: int = 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = Color(0.97, 0.93, 0.82)
	l.outline_modulate = Color(0.12, 0.08, 0.05, 0.9)
	# 뒤에서 보면 글자가 뒤집혀 보이므로 앞면만 그린다.
	l.double_sided = false
	l.transform = xform
	add_child(l)
	return l


func _emit(builder: MeshKit.Builder, material: Material, node_name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = builder.commit()
	mi.material_override = material
	add_child(mi)


## 광장을 바라보는 방향
func _facing_center(p: Vector3) -> Basis:
	var d := center - p
	return Basis(Vector3.UP, atan2(d.x, d.z))


# --- 목책과 정문 ---

func _build_palisade() -> void:
	var circumference := TAU * PALISADE_RADIUS
	var count := int(circumference / 0.75)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in count:
		var a := TAU * float(i) / float(count)
		var p := center + Vector3(cos(a), 0.0, sin(a)) * PALISADE_RADIUS
		if _in_gate(p):
			continue
		var h := rng.randf_range(2.9, 3.4)
		var col := Color(0.42, 0.31, 0.2) * rng.randf_range(0.85, 1.1)
		_solid.frustum(p + Vector3.DOWN * 0.4, p + Vector3.UP * h, 0.17, 0.15, 6, Color(col, 0.0))
		_solid.frustum(p + Vector3.UP * h, p + Vector3.UP * (h + 0.45), 0.15, 0.0, 6, Color(col * 0.9, 0.0), 0.0, 0.0, false)
	# 가로 버팀목
	var segments := 48
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := center + Vector3(cos(a0), 0.0, sin(a0)) * (PALISADE_RADIUS - 0.22)
		var p1 := center + Vector3(cos(a1), 0.0, sin(a1)) * (PALISADE_RADIUS - 0.22)
		var mid := (p0 + p1) * 0.5
		if _in_gate(mid) or _in_gate(p0) or _in_gate(p1):
			continue
		var len := p0.distance_to(p1)
		var basis := Basis(Vector3.UP, atan2(p1.x - p0.x, p1.z - p0.z))
		for y in [1.0, 2.3]:
			_solid.box(mid + Vector3.UP * y, Vector3(0.12, 0.16, len + 0.1), Color(0.36, 0.26, 0.17), basis)
		_collider(Vector3(0.5, 4.0, len + 0.2), Transform3D(basis, mid + Vector3.UP * 1.6))


func _in_gate(p: Vector3) -> bool:
	var gate := center + Vector3(-PALISADE_RADIUS, 0.0, 0.0)
	return absf(p.z - gate.z) < GATE_HALF_WIDTH and p.x < center.x


func _build_gate() -> void:
	var g := center + Vector3(-PALISADE_RADIUS, 0.0, 0.0)
	for side in [-1.0, 1.0]:
		var post := g + Vector3(0.0, 0.0, side * (GATE_HALF_WIDTH + 0.3))
		_solid.box(post + Vector3.UP * 2.6, Vector3(0.6, 5.2, 0.6), DARK_WOOD)
		_collider(Vector3(0.6, 5.2, 0.6), Transform3D(Basis.IDENTITY, post + Vector3.UP * 2.6))
		# 횃불
		var torch := post + Vector3(-0.45, 3.1, 0.0)
		_solid.frustum(torch + Vector3.DOWN * 0.5, torch, 0.05, 0.07, 5, Color(0.3, 0.2, 0.1, 0.0))
		_add_lantern_light(torch + Vector3.UP * 0.25, 8.0)
		_glow_blob(torch + Vector3.UP * 0.15, 0.14, Color(1.0, 0.6, 0.2))
	_solid.box(g + Vector3.UP * 5.0, Vector3(0.5, 0.6, GATE_HALF_WIDTH * 2.0 + 1.6), DARK_WOOD)
	_solid.box(g + Vector3(-0.3, 4.1, 0.0), Vector3(0.12, 1.0, 3.2), Color(0.5, 0.38, 0.24))
	_label("퍼시", Transform3D(Basis(Vector3.UP, -PI * 0.5), g + Vector3(-0.4, 4.1, 0.0)), 110)
	spots["gate_guard"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), g + Vector3(2.5, 0.0, GATE_HALF_WIDTH + 2.0))
	spots["gate_outside"] = Transform3D(Basis(Vector3.UP, PI * 0.5), g + Vector3(-6.0, 0.0, 0.0))


# --- 광장 ---

func _build_plaza() -> void:
	# 둥근 돌바닥(바깥 테두리와 안쪽 두 겹)
	var paving := MeshKit.Builder.new()
	paving.disc(center + Vector3.UP * 0.04, 13.0, 28, Color(STONE * 0.72, 0.0), Vector3.UP)
	paving.disc(center + Vector3.UP * 0.05, 11.8, 28, Color(STONE * 0.86, 0.0), Vector3.UP)
	paving.disc(center + Vector3.UP * 0.06, 5.0, 20, Color(STONE * 0.78, 0.0), Vector3.UP)
	var paving_mi := MeshInstance3D.new()
	paving_mi.name = "Paving"
	paving_mi.mesh = paving.commit()
	paving_mi.material_override = MeshKit.solid_material()
	paving_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(paving_mi)
	# 우물
	_solid.frustum(center, center + Vector3.UP * 0.85, 1.5, 1.45, 10, Color(STONE, 0.0))
	_solid.disc(center + Vector3.UP * 0.6, 1.25, 10, Color(0.12, 0.2, 0.24, 0.0), Vector3.UP)
	for side in [-1.0, 1.0]:
		_solid.box(center + Vector3(side * 1.3, 1.7, 0.0), Vector3(0.18, 1.9, 0.18), DARK_WOOD)
	_solid.box(center + Vector3(0.0, 2.7, 0.0), Vector3(3.2, 0.14, 0.2), DARK_WOOD)
	_solid.frustum(center + Vector3(0.0, 2.75, 0.0), center + Vector3(0.0, 3.5, 0.0), 1.9, 0.1, 4, Color(ROOF_COLORS[0], 0.0))
	_collider(Vector3(3.0, 1.0, 3.0), Transform3D(Basis.IDENTITY, center + Vector3.UP * 0.5))
	spots["plaza"] = Transform3D(Basis.IDENTITY, center + Vector3(0.0, 0.0, 4.0))


# --- 시설 ---

func _build_facilities() -> void:
	var inn := _building(Vector2(-15, -18), Vector3(12.0, 7.0, 9.0), ROOF_COLORS[0], 2, "여관 「첫 등불」")
	spots["inn_door"] = _front_spot(inn, 9.0, 1.4)
	spots["innkeeper"] = _front_spot(inn, 9.0, 2.4, 2.2)
	var store := _building(Vector2(18, -15), Vector3(8.0, 4.6, 7.0), ROOF_COLORS[3], 1, "잡화점")
	_counter(store, 7.0, Color(0.72, 0.28, 0.24), Color(0.92, 0.88, 0.78))
	spots["store_counter"] = _front_spot(store, 7.0, 2.6)
	spots["merchant"] = _front_spot(store, 7.0, 0.9)
	var shop := _building(Vector2(19, 15), Vector3(9.0, 5.0, 8.0), ROOF_COLORS[2], 1, "무기 공방")
	_forge(shop, 8.0)
	spots["workshop_counter"] = _front_spot(shop, 8.0, 2.8, -1.5)
	spots["smith"] = _front_spot(shop, 8.0, 1.0, -1.5)
	var lab := _building(Vector2(-16, 16), Vector3(9.0, 6.0, 8.0), ROOF_COLORS[1], 2, "공명 연구소")
	_antenna(lab, Vector3(9.0, 6.0, 8.0))
	spots["lab_door"] = _front_spot(lab, 8.0, 1.4)
	spots["researcher"] = _front_spot(lab, 8.0, 2.4, 2.0)
	# 의뢰 게시판(정문에서 광장으로 오는 길목)
	var board_pos := center + Vector3(-15.0, 0.0, 5.5)
	var board_basis := Basis(Vector3.UP, PI * 0.5)
	for side in [-1.0, 1.0]:
		_solid.box(board_pos + board_basis * Vector3(side * 1.2, 1.1, 0.0), Vector3(0.16, 2.2, 0.16), DARK_WOOD, board_basis)
	_solid.box(board_pos + board_basis * Vector3(0.0, 1.55, 0.0), Vector3(2.6, 1.3, 0.1), Color(0.5, 0.38, 0.24), board_basis)
	for i in 5:
		var off := Vector3(-0.9 + i * 0.45, 1.55 + (0.2 if i % 2 else -0.15), 0.07)
		_solid.box(board_pos + board_basis * off, Vector3(0.34, 0.42, 0.02), Color(0.93, 0.9, 0.8), board_basis)
	_collider(Vector3(2.8, 2.2, 0.4), Transform3D(board_basis, board_pos + Vector3.UP * 1.1))
	_label("의뢰 게시판", Transform3D(board_basis, board_pos + board_basis * Vector3(0.0, 2.45, 0.1)), 52)
	spots["notice_board"] = Transform3D(board_basis, board_pos + board_basis * Vector3(0.0, 0.0, 1.3))
	spots["clerk"] = Transform3D(board_basis, board_pos + board_basis * Vector3(1.9, 0.0, 0.9))


## 건물 앞쪽(광장 쪽)의 한 점. depth는 건물 깊이, dist는 벽에서 떨어진 거리, side는 옆으로 옮긴 거리.
func _front_spot(xform: Transform3D, depth: float, dist: float, side: float = 0.0) -> Transform3D:
	var p := xform.origin + xform.basis * Vector3(side, 0.0, depth * 0.5 + dist)
	# 바라보는 방향: 건물 반대쪽(광장)
	return Transform3D(xform.basis, p)


## 목조 골조 건물. 반환값은 건물의 위치와 방향(+Z가 광장을 향한 정면).
func _building(rel: Vector2, size: Vector3, roof_col: Color, floors: int, sign_text: String = "") -> Transform3D:
	var p := center + Vector3(rel.x, 0.0, rel.y)
	var basis := _facing_center(p)
	var y0 := 0.45
	_solid.box(_world(Vector3(0, y0 * 0.5, 0), basis, p), Vector3(size.x + 0.4, y0, size.z + 0.4), STONE, basis)
	_solid.box(_world(Vector3(0, y0 + size.y * 0.5, 0), basis, p), size, PLASTER, basis)
	# 골조: 모서리 기둥과 층마다 띠
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_solid.box(_world(Vector3(sx * size.x * 0.5, y0 + size.y * 0.5, sz * size.z * 0.5), basis, p),
				Vector3(0.32, size.y, 0.32), TIMBER, basis)
	for f in floors + 1:
		var y := y0 + size.y * float(f) / float(floors) - (0.1 if f == floors else 0.0)
		_solid.box(_world(Vector3(0, y, size.z * 0.5 + 0.03), basis, p), Vector3(size.x, 0.22, 0.12), TIMBER, basis)
		_solid.box(_world(Vector3(0, y, -size.z * 0.5 - 0.03), basis, p), Vector3(size.x, 0.22, 0.12), TIMBER, basis)
		_solid.box(_world(Vector3(size.x * 0.5 + 0.03, y, 0), basis, p), Vector3(0.12, 0.22, size.z), TIMBER, basis)
		_solid.box(_world(Vector3(-size.x * 0.5 - 0.03, y, 0), basis, p), Vector3(0.12, 0.22, size.z), TIMBER, basis)
	# 대각 버팀목(정면)
	var floor_h := size.y / float(floors)
	for f in floors:
		for sx in [-1.0, 1.0]:
			var a := Vector3(sx * size.x * 0.5, y0 + floor_h * f, size.z * 0.5 + 0.04)
			var b := Vector3(sx * size.x * 0.22, y0 + floor_h * (f + 1), size.z * 0.5 + 0.04)
			_beam(_world(a, basis, p), _world(b, basis, p), basis)
	# 문
	_solid.box(_world(Vector3(0, y0 + 1.2, size.z * 0.5 + 0.06), basis, p), Vector3(1.5, 2.4, 0.12), DARK_WOOD, basis)
	_solid.box(_world(Vector3(0, y0 + 2.5, size.z * 0.5 + 0.1), basis, p), Vector3(1.8, 0.18, 0.2), TIMBER, basis)
	# 창문(밤에 켜진다)
	for f in floors:
		var wy := y0 + floor_h * (f + 0.55)
		for wx in [-size.x * 0.32, size.x * 0.32]:
			if f == 0 and absf(wx) < 1.2:
				continue
			_window(_world(Vector3(wx, wy, size.z * 0.5 + 0.05), basis, p), basis)
		for sz in [-size.z * 0.25, size.z * 0.25]:
			_window(_world(Vector3(size.x * 0.5 + 0.05, wy, sz), basis, p), basis * Basis(Vector3.UP, PI * 0.5))
			_window(_world(Vector3(-size.x * 0.5 - 0.05, wy, sz), basis, p), basis * Basis(Vector3.UP, -PI * 0.5))
	_roof(p, basis, size, y0 + size.y, roof_col)
	# 굴뚝
	_solid.box(_world(Vector3(size.x * 0.3, y0 + size.y + size.z * 0.42, -size.z * 0.15), basis, p),
		Vector3(0.7, size.z * 0.6, 0.7), STONE, basis)
	_collider(Vector3(size.x + 0.4, size.y + y0, size.z + 0.4), Transform3D(basis, _world(Vector3(0, (size.y + y0) * 0.5, 0), basis, p)))
	if sign_text != "":
		_solid.box(_world(Vector3(0, y0 + 3.0, size.z * 0.5 + 0.12), basis, p), Vector3(minf(size.x * 0.7, 5.5), 0.62, 0.08),
			Color(0.3, 0.21, 0.13), basis)
		_label(sign_text, Transform3D(basis, _world(Vector3(0, y0 + 3.0, size.z * 0.5 + 0.18), basis, p)), 56)
	return Transform3D(basis, p)


func _beam(a: Vector3, b: Vector3, _basis: Basis) -> void:
	var mid := (a + b) * 0.5
	var dir := (b - a)
	var len := dir.length()
	var up := dir / len
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	_solid.box(mid, Vector3(0.16, len, 0.1), TIMBER, Basis(side, up, fwd))


func _window(p: Vector3, basis: Basis) -> void:
	_windows.box(p, Vector3(0.95, 1.05, 0.06), Color(0.24, 0.28, 0.33), basis)
	_solid.box(p + basis * Vector3(0, 0, 0.03), Vector3(0.1, 1.1, 0.06), TIMBER, basis)
	_solid.box(p + basis * Vector3(0, 0, 0.03), Vector3(1.05, 0.1, 0.06), TIMBER, basis)
	_solid.box(p + basis * Vector3(0, -0.58, 0.06), Vector3(1.15, 0.1, 0.2), TIMBER, basis)


## 박공지붕(용마루는 건물의 가로 방향)
func _roof(p: Vector3, basis: Basis, size: Vector3, y0: float, col: Color) -> void:
	var w := size.x * 0.5 + 0.55
	var d := size.z * 0.5 + 0.7
	var rh := size.z * 0.42
	var ridge_y := y0 + rh
	var pts := func(x: float, y: float, z: float) -> Vector3: return _world(Vector3(x, y, z), basis, p)
	var c := Color(col, 0.0)
	var under := Color(col.darkened(0.45), 0.0)
	for sz in [1.0, -1.0]:
		var a: Vector3 = pts.call(-w, y0 - 0.12, sz * d)
		var b: Vector3 = pts.call(w, y0 - 0.12, sz * d)
		var r1: Vector3 = pts.call(w, ridge_y, 0.0)
		var r0: Vector3 = pts.call(-w, ridge_y, 0.0)
		var out: Vector3 = basis * Vector3(0.0, 1.0, sz * 0.8)
		_solid.quad(a, b, r1, r0, c, out)
		_solid.quad(a, b, r1 - Vector3.UP * 0.12, r0 - Vector3.UP * 0.12, under, -out)
		# 지붕 끝 두께
		_solid.quad(a, b, b + Vector3.DOWN * 0.14, a + Vector3.DOWN * 0.14, under, basis * Vector3(0, 0, sz))
	# 박공 벽(오각형)
	var wall_y := y0 + rh * (1.0 - (size.z * 0.5) / d)
	for sx in [1.0, -1.0]:
		var x: float = sx * size.x * 0.5
		var poly: Array[Vector3] = [
			pts.call(x, y0, -size.z * 0.5), pts.call(x, y0, size.z * 0.5), pts.call(x, wall_y, size.z * 0.5),
			pts.call(x, ridge_y - 0.05, 0.0), pts.call(x, wall_y, -size.z * 0.5),
		]
		var out: Vector3 = basis * Vector3(sx, 0, 0)
		for i in range(1, poly.size() - 1):
			_solid.tri(poly[0], poly[i], poly[i + 1], Color(PLASTER * 0.96, 0.0), out)
		_solid.box(_world(Vector3(x + sx * 0.03, (y0 + ridge_y) * 0.5, 0.0), basis, p), Vector3(0.12, rh, 0.22), TIMBER, basis)


## 잡화점 앞 차양과 계산대
func _counter(xform: Transform3D, depth: float, stripe_a: Color, stripe_b: Color) -> void:
	var basis := xform.basis
	var p := xform.origin
	var front := depth * 0.5
	_solid.box(_world(Vector3(0, 0.55, front + 1.6), basis, p), Vector3(3.4, 1.1, 0.8), Color(0.45, 0.32, 0.2), basis,
		Color(0.55, 0.4, 0.26))
	_collider(Vector3(3.4, 1.1, 0.8), Transform3D(basis, _world(Vector3(0, 0.55, front + 1.6), basis, p)))
	for i in 6:
		var x0 := -3.0 + i
		var col := stripe_a if i % 2 == 0 else stripe_b
		var a := _world(Vector3(x0, 3.2, front + 0.05), basis, p)
		var b := _world(Vector3(x0 + 1.0, 3.2, front + 0.05), basis, p)
		var c := _world(Vector3(x0 + 1.0, 2.6, front + 2.3), basis, p)
		var d := _world(Vector3(x0, 2.6, front + 2.3), basis, p)
		_solid.quad(a, b, c, d, Color(col, 0.0), basis * Vector3(0, 1, 0.3))
		_solid.quad(a, b, c, d, Color(col.darkened(0.3), 0.0), basis * Vector3(0, -1, -0.3))
	for sx in [-3.0, 3.0]:
		_solid.box(_world(Vector3(sx, 1.3, front + 2.25), basis, p), Vector3(0.12, 2.6, 0.12), DARK_WOOD, basis)
	# 상자와 자루
	for i in 3:
		_solid.box(_world(Vector3(-1.1 + i * 1.1, 1.25, front + 1.6), basis, p), Vector3(0.5, 0.3, 0.4),
			[Color(0.8, 0.3, 0.25), Color(0.85, 0.7, 0.3), Color(0.4, 0.6, 0.35)][i], basis)


## 무기 공방 앞 화로와 모루
func _forge(xform: Transform3D, depth: float) -> void:
	var basis := xform.basis
	var p := xform.origin
	var front := depth * 0.5
	var forge_pos := _world(Vector3(2.4, 0.6, front + 1.5), basis, p)
	_solid.box(forge_pos, Vector3(1.6, 1.2, 1.3), STONE * 0.8, basis)
	_glow_blob(forge_pos + Vector3.UP * 0.62, 0.45, Color(1.0, 0.45, 0.12), Vector3(1.3, 0.25, 1.0))
	_collider(Vector3(1.6, 1.2, 1.3), Transform3D(basis, forge_pos))
	forge_light = OmniLight3D.new()
	forge_light.light_color = Color(1.0, 0.55, 0.2)
	forge_light.omni_range = 7.0
	forge_light.position = forge_pos + Vector3.UP * 1.2
	add_child(forge_light)
	var anvil := _world(Vector3(-0.2, 0.0, front + 1.8), basis, p)
	_solid.box(anvil + Vector3.UP * 0.3, Vector3(0.5, 0.6, 0.5), DARK_WOOD, basis)
	_solid.box(anvil + Vector3.UP * 0.72, Vector3(0.9, 0.25, 0.4), Color(0.25, 0.26, 0.28), basis)
	_collider(Vector3(0.9, 0.85, 0.5), Transform3D(basis, anvil + Vector3.UP * 0.42))
	# 무기 걸이
	var rack := _world(Vector3(-2.6, 0.0, front + 0.6), basis, p)
	_solid.box(rack + Vector3.UP * 1.0, Vector3(2.2, 0.1, 0.1), DARK_WOOD, basis)
	for i in 4:
		_solid.box(rack + basis * Vector3(-0.8 + i * 0.55, 0.9, 0.08), Vector3(0.06, 1.3, 0.04), Color(0.7, 0.72, 0.75), basis)


## 공명 연구소 지붕의 결정 안테나
func _antenna(xform: Transform3D, size: Vector3) -> void:
	var top := xform.origin + xform.basis * Vector3(-size.x * 0.25, 0.45 + size.y + size.z * 0.42 + 0.2, 0.0)
	_solid.frustum(top, top + Vector3.UP * 2.6, 0.08, 0.05, 5, Color(0.3, 0.32, 0.36, 0.0))
	_glow_blob(top + Vector3.UP * 2.9, 0.35, Color(0.45, 0.95, 1.0), Vector3(0.7, 1.3, 0.7))
	var l := OmniLight3D.new()
	l.light_color = Color(0.45, 0.95, 1.0)
	l.light_energy = 0.8
	l.omni_range = 6.0
	l.position = top + Vector3.UP * 2.9
	add_child(l)


func _glow_blob(p: Vector3, radius: float, col: Color, squash := Vector3.ONE) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x * 13.0 + p.z * 7.0)
	var b := MeshKit.Builder.new()
	b.blob(p, radius, Color(col, 0.0), 0.0, rng, 0.15, squash, -2.0, 0.0, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- 민가 ---

func _build_houses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1777
	var places: Array[Vector2] = [
		Vector2(-31, -14), Vector2(-31, 15), Vector2(-5, -33), Vector2(10, -34),
		Vector2(-6, 33), Vector2(10, 34), Vector2(33, 21), Vector2(31, -25),
	]
	for rel in places:
		var size := Vector3(rng.randf_range(7.0, 9.0), rng.randf_range(4.2, 5.2), rng.randf_range(6.0, 7.2))
		var xf := _building(rel, size, ROOF_COLORS[rng.randi() % ROOF_COLORS.size()], 1 if rng.randf() < 0.6 else 2)
		# 집 앞 작은 울타리나 꽃밭
		if rng.randf() < 0.6:
			for i in 4:
				var fp := xf.origin + xf.basis * Vector3(-1.8 + i * 1.2, 0.35, size.z * 0.5 + 1.6)
				_solid.box(fp, Vector3(0.1, 0.7, 0.1), DARK_WOOD, xf.basis)
			_solid.box(xf.origin + xf.basis * Vector3(0.0, 0.5, size.z * 0.5 + 1.6), Vector3(3.8, 0.08, 0.06), DARK_WOOD, xf.basis)


# --- 통신탑 ---

func _build_tower() -> void:
	var base := center + Vector3(31.0, 0.0, -2.0)
	var height := 22.0
	var legs: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var foot := base + Vector3(sx * 2.4, 0.0, sz * 2.4)
			var head := base + Vector3(sx * 0.7, height, sz * 0.7)
			_solid.frustum(foot, head, 0.2, 0.14, 5, Color(0.35, 0.33, 0.32, 0.0))
			legs.append(foot)
			_collider(Vector3(0.6, 3.0, 0.6), Transform3D(Basis.IDENTITY, foot + Vector3.UP * 1.5))
	for level in [4.0, 9.0, 14.0, 19.0]:
		var t: float = level / height
		var half := lerpf(2.4, 0.7, t)
		for axis in 2:
			for s in [-1.0, 1.0]:
				var c := base + Vector3(0, level, 0) + (Vector3(s * half, 0, 0) if axis == 0 else Vector3(0, 0, s * half))
				var size := Vector3(0.14, 0.14, half * 2.0) if axis == 0 else Vector3(half * 2.0, 0.14, 0.14)
				_solid.box(c, size, Color(0.38, 0.36, 0.34))
	_solid.box(base + Vector3.UP * height, Vector3(2.6, 0.3, 2.6), DARK_WOOD)
	_solid.frustum(base + Vector3.UP * height, base + Vector3.UP * (height + 6.0), 0.12, 0.05, 5, Color(0.4, 0.4, 0.42, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_solid.blob(base + Vector3(0.9, height + 2.2, 0.0), 0.9, Color(0.7, 0.7, 0.72, 0.0), 0.0, rng, 0.05, Vector3(0.25, 1.0, 1.0))
	var tip := base + Vector3.UP * (height + 6.2)
	var tip_mat_col := Color(1.0, 0.2, 0.15)
	_glow_blob(tip, 0.2, tip_mat_col)
	tower_light = OmniLight3D.new()
	tower_light.light_color = tip_mat_col
	tower_light.omni_range = 12.0
	tower_light.position = tip
	add_child(tower_light)
	spots["tower"] = Transform3D(Basis(Vector3.UP, -PI * 0.5), base + Vector3(-4.0, 0.0, 0.0))


# --- 가로등 ---

func _build_lanterns() -> void:
	var places: Array[Vector2] = [
		Vector2(-38, 4.5), Vector2(-29, -4.5), Vector2(-20, 4.5),
		Vector2(-9, -10), Vector2(9, -10), Vector2(10, 10), Vector2(-10, 10), Vector2(24, 1),
	]
	for rel in places:
		var p := center + Vector3(rel.x, 0.0, rel.y)
		_solid.frustum(p, p + Vector3.UP * 3.2, 0.09, 0.07, 6, Color(0.2, 0.2, 0.22, 0.0))
		_solid.box(p + Vector3(0.3, 3.15, 0.0), Vector3(0.6, 0.08, 0.08), Color(0.2, 0.2, 0.22))
		var lamp := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.42, 0.3)
		lamp.mesh = bm
		lamp.material_override = lantern_material
		lamp.position = p + Vector3(0.55, 2.85, 0.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_add_lantern_light(p + Vector3(0.55, 2.7, 0.0), 10.0)
		_collider(Vector3(0.25, 3.2, 0.25), Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.6))


func _add_lantern_light(p: Vector3, range_m: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.74, 0.42)
	l.omni_range = range_m
	l.omni_attenuation = 1.4
	l.light_energy = 0.0
	l.visible = false
	l.position = p
	add_child(l)
	lantern_lights.append(l)


# --- 소품 ---

func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var groups: Array[Vector2] = [Vector2(24, -8), Vector2(26, 8), Vector2(-22, -8), Vector2(-24, 25), Vector2(4, -24)]
	for g in groups:
		for i in rng.randi_range(2, 4):
			var p := center + Vector3(g.x + rng.randf_range(-1.6, 1.6), 0.0, g.y + rng.randf_range(-1.6, 1.6))
			if rng.randf() < 0.5:
				_solid.frustum(p, p + Vector3.UP * 0.95, 0.36, 0.33, 8, Color(0.48, 0.33, 0.2, 0.0))
				_solid.box(p + Vector3.UP * 0.35, Vector3(0.75, 0.06, 0.75), Color(0.3, 0.3, 0.3))
				_collider(Vector3(0.7, 0.95, 0.7), Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.47))
			else:
				var s := rng.randf_range(0.6, 0.9)
				var basis := Basis(Vector3.UP, rng.randf() * TAU)
				_solid.box(p + Vector3.UP * s * 0.5, Vector3.ONE * s, Color(0.55, 0.42, 0.26), basis)
				_collider(Vector3.ONE * s, Transform3D(basis, p + Vector3.UP * s * 0.5))
	# 수레
	var cart := center + Vector3(-26.0, 0.0, -24.0)
	var cb := Basis(Vector3.UP, 0.6)
	_solid.box(cart + cb * Vector3(0, 0.9, 0), Vector3(1.6, 0.5, 2.6), Color(0.5, 0.36, 0.22), cb)
	for sx in [-1.0, 1.0]:
		var hub := cart + cb * Vector3(sx * 0.9, 0.55, 0.3)
		_solid.frustum(hub - cb.x * 0.08, hub + cb.x * 0.08, 0.55, 0.55, 10, Color(0.32, 0.23, 0.14, 0.0))
	_solid.box(cart + cb * Vector3(0, 0.8, 2.0), Vector3(0.1, 0.1, 1.6), DARK_WOOD, cb)
	_collider(Vector3(1.8, 1.3, 2.8), Transform3D(cb, cart + cb * Vector3(0, 0.65, 0)))

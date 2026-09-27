class_name MeshKit
extends RefCounted
## 절차적 저다각형 모델 도구: 나무, 바위, 덤불, 풀, 꽃, 건물 부품.
## 정식 에셋이 들어오기 전까지 쓰는 임시 모델이며, 면마다 법선을 따로 둬 각진 저다각형 느낌을 낸다.
## 정점 색의 알파는 바람에 흔들리는 정도(0 = 고정, 1 = 잎 끝)다.

const FOLIAGE_SHADER := preload("res://assets/shaders/foliage.gdshader")
const GRASS_SHADER := preload("res://assets/shaders/grass.gdshader")

static var _foliage_material: ShaderMaterial
static var _grass_material: ShaderMaterial
static var _solid_material: StandardMaterial3D


static func foliage_material() -> ShaderMaterial:
	if _foliage_material == null:
		_foliage_material = ShaderMaterial.new()
		_foliage_material.shader = FOLIAGE_SHADER
	return _foliage_material


static func grass_material() -> ShaderMaterial:
	if _grass_material == null:
		_grass_material = ShaderMaterial.new()
		_grass_material.shader = GRASS_SHADER
	return _grass_material


## 흔들리지 않는 물체(바위, 건물)용 정점 색 재질
static func solid_material() -> StandardMaterial3D:
	if _solid_material == null:
		_solid_material = StandardMaterial3D.new()
		_solid_material.vertex_color_use_as_albedo = true
		_solid_material.roughness = 0.9
	return _solid_material


# --- 기본 도형 조립 ---

class Builder:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## 삼각형 하나. outward 쪽에서 보이도록 방향을 자동으로 맞춘다.
	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, outward: Vector3) -> void:
		var n := (c - a).cross(b - a)
		if n.dot(outward) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(a)
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(b)
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(c)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward: Vector3) -> void:
		tri(a, b, c, col, outward)
		tri(a, c, d, col, outward)

	## 축이 세로인 각기둥(원뿔대). 아래 반지름 r0, 위 반지름 r1.
	func frustum(base: Vector3, top: Vector3, r0: float, r1: float, sides: int, col: Color,
			sway0: float = 0.0, sway1: float = 0.0, cap_top: bool = true, jitter: float = 0.0,
			rng: RandomNumberGenerator = null) -> void:
		var axis := (top - base).normalized()
		var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var fwd := axis.cross(side).normalized()
		var ring0: Array[Vector3] = []
		var ring1: Array[Vector3] = []
		for i in sides:
			var a := TAU * float(i) / float(sides)
			var dir := side * cos(a) + fwd * sin(a)
			var j0 := 1.0 + (rng.randf_range(-jitter, jitter) if rng else 0.0)
			var j1 := 1.0 + (rng.randf_range(-jitter, jitter) if rng else 0.0)
			ring0.append(base + dir * r0 * j0)
			ring1.append(top + dir * r1 * j1)
		var c0 := Color(col, sway0)
		var c1 := Color(col, sway1)
		for i in sides:
			var k := (i + 1) % sides
			var mid := (base + top) * 0.5
			var face_center := (ring0[i] + ring0[k] + ring1[i] + ring1[k]) * 0.25
			var shade := 0.9 + 0.2 * float(i % 2)
			tri(ring0[i], ring0[k], ring1[i], Color(c0.r * shade, c0.g * shade, c0.b * shade, sway0), face_center - mid)
			if r1 > 0.001:
				tri(ring0[k], ring1[k], ring1[i], Color(c1.r * shade, c1.g * shade, c1.b * shade, sway1), face_center - mid)
		if cap_top and r1 > 0.001:
			for i in sides:
				tri(top, ring1[i], ring1[(i + 1) % sides], c1, axis)

	## 원판(normal 쪽에서 보인다)
	func disc(center: Vector3, radius: float, sides: int, col: Color, normal: Vector3) -> void:
		var side := normal.cross(Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var fwd := normal.cross(side).normalized()
		for i in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			tri(center, center + (side * cos(a0) + fwd * sin(a0)) * radius,
				center + (side * cos(a1) + fwd * sin(a1)) * radius, col, normal)

	## 울퉁불퉁한 공(잎 뭉치, 바위, 덤불). squash는 축별 배율.
	func blob(center: Vector3, radius: float, col: Color, sway: float, rng: RandomNumberGenerator,
			roughness: float = 0.22, squash := Vector3.ONE, flat_bottom: float = -2.0,
			col_variation: float = 0.08, bottom_dark: float = 0.25) -> void:
		var ico := MeshKit.icosphere()
		var verts: Array[Vector3] = []
		for v: Vector3 in ico.verts:
			var r := radius * (1.0 + rng.randf_range(-roughness, roughness))
			var p := v * r * squash
			if p.y < flat_bottom * radius:
				p.y = flat_bottom * radius
			verts.append(center + p)
		for f: Vector3i in ico.faces:
			var a := verts[f.x]
			var b := verts[f.y]
			var c := verts[f.z]
			var centroid := (a + b + c) / 3.0
			var height_t := clampf((centroid.y - center.y) / (radius * squash.y) * 0.5 + 0.5, 0.0, 1.0)
			var v := 1.0 + rng.randf_range(-col_variation, col_variation)
			var dark := lerpf(1.0 - bottom_dark, 1.0, height_t) * v
			tri(a, b, c, Color(col.r * dark, col.g * dark, col.b * dark, sway), centroid - center)

	## 상자(건물 벽, 판자). 면마다 색을 조금씩 달리한다.
	func box(center: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY, top_col := Color(0, 0, 0, 0)) -> void:
		var h := size * 0.5
		var corners: Array[Vector3] = []
		for i in 8:
			var p := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
			corners.append(center + basis * p)
		# 모서리 번호의 비트: 1 = +x, 2 = +y, 4 = +z
		var faces := [
			[0, 1, 5, 4, Vector3(0, -1, 0)], [2, 6, 7, 3, Vector3(0, 1, 0)],
			[0, 2, 3, 1, Vector3(0, 0, -1)], [4, 5, 7, 6, Vector3(0, 0, 1)],
			[0, 4, 6, 2, Vector3(-1, 0, 0)], [1, 3, 7, 5, Vector3(1, 0, 0)],
		]
		for f in faces:
			var n: Vector3 = basis * f[4]
			var c := col
			if f[4].y > 0.5 and top_col.a > 0.0:
				c = top_col
			var shade := 1.0 - 0.06 * absf(f[4].x) - 0.12 * maxf(-f[4].y, 0.0)
			quad(corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]], Color(c.r * shade, c.g * shade, c.b * shade, 0.0), n)

	func commit() -> ArrayMesh:
		st.index()
		return st.commit()


class Icosphere:
	var verts: Array[Vector3] = []
	var faces: Array[Vector3i] = []


static var _ico: Icosphere


## 한 번 나눈 정이십면체(정점 42개, 면 80개)
static func icosphere() -> Icosphere:
	if _ico:
		return _ico
	var t := (1.0 + sqrt(5.0)) / 2.0
	var base_verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var base_faces: Array[Vector3i] = [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]
	var ico := Icosphere.new()
	for v in base_verts:
		ico.verts.append(v.normalized())
	var cache := {}
	var mid := func(a: int, b: int) -> int:
		var key := Vector2i(mini(a, b), maxi(a, b))
		if cache.has(key):
			return cache[key]
		ico.verts.append(((ico.verts[a] + ico.verts[b]) * 0.5).normalized())
		cache[key] = ico.verts.size() - 1
		return ico.verts.size() - 1
	for f in base_faces:
		var ab: int = mid.call(f.x, f.y)
		var bc: int = mid.call(f.y, f.z)
		var ca: int = mid.call(f.z, f.x)
		ico.faces.append_array([Vector3i(f.x, ab, ca), Vector3i(f.y, bc, ab), Vector3i(f.z, ca, bc), Vector3i(ab, bc, ca)])
	_ico = ico
	return ico


# --- 식생 ---

const BARK := Color(0.36, 0.27, 0.19)
const LEAF_COLORS: Array[Color] = [
	Color(0.27, 0.43, 0.18), Color(0.33, 0.47, 0.19), Color(0.24, 0.38, 0.17), Color(0.38, 0.5, 0.2),
]
const PINE_COLOR := Color(0.15, 0.29, 0.17)


## 활엽수. 반환 메시의 원점은 밑동.
static func broadleaf_tree(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Builder.new()
	var height := rng.randf_range(4.8, 7.0)
	var lean := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
	var r0 := rng.randf_range(0.26, 0.36)
	var mid := Vector3(0, height * 0.5, 0) + lean * 0.4
	var top := Vector3(0, height, 0) + lean
	b.frustum(Vector3.ZERO, mid, r0, r0 * 0.75, 6, BARK, 0.0, 0.1, false, 0.1, rng)
	b.frustum(mid, top, r0 * 0.75, r0 * 0.45, 6, BARK, 0.1, 0.3, true, 0.1, rng)
	# 굵은 가지 두어 개
	for i in rng.randi_range(1, 2):
		var a := rng.randf() * TAU
		var from := mid + Vector3(0, rng.randf_range(0.3, 1.2), 0)
		var to := from + Vector3(cos(a) * 1.4, 1.2, sin(a) * 1.4)
		b.frustum(from, to, r0 * 0.35, r0 * 0.18, 5, BARK, 0.15, 0.45, true)
	var leaf := LEAF_COLORS[rng.randi() % LEAF_COLORS.size()]
	var blobs := rng.randi_range(3, 5)
	for i in blobs:
		var a := TAU * float(i) / float(blobs) + rng.randf_range(-0.4, 0.4)
		var dist := rng.randf_range(0.7, 1.6) if i > 0 else 0.0
		var c := top + Vector3(cos(a) * dist, rng.randf_range(-0.6, 0.9), sin(a) * dist)
		var tint := leaf * rng.randf_range(0.9, 1.1)
		b.blob(c, rng.randf_range(1.5, 2.3), Color(tint, 1.0), rng.randf_range(0.75, 1.0), rng, 0.2, Vector3(1.0, 0.82, 1.0))
	return b.commit()


## 침엽수(원뿔을 겹쳐 쌓는다)
static func pine_tree(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Builder.new()
	var height := rng.randf_range(7.5, 11.0)
	b.frustum(Vector3.ZERO, Vector3(0, height * 0.45, 0), 0.3, 0.2, 6, BARK * 0.9, 0.0, 0.15, false)
	var tiers := 4
	var col := PINE_COLOR * rng.randf_range(0.9, 1.12)
	for i in tiers:
		var t := float(i) / float(tiers)
		var y0 := height * (0.25 + t * 0.62)
		var r := lerpf(2.5, 0.9, t) * rng.randf_range(0.9, 1.1)
		var tip := Vector3(rng.randf_range(-0.1, 0.1), y0 + lerpf(3.2, 2.2, t), rng.randf_range(-0.1, 0.1))
		var shade := lerpf(0.8, 1.1, t)
		b.frustum(Vector3(0, y0, 0), tip, r, 0.0, 8, Color(col.r * shade, col.g * shade, col.b * shade),
			lerpf(0.4, 0.7, t), lerpf(0.8, 1.0, t), false, 0.12, rng)
		# 원뿔 아랫면(아래에서 올려다볼 때 속이 비어 보이지 않게)
		b.disc(Vector3(0, y0 + 0.02, 0), r * 0.97, 8, Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, lerpf(0.4, 0.7, t)), Vector3.DOWN)
	return b.commit()


## 죽은 나무(그늘 숲)
static func dead_tree(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Builder.new()
	var height := rng.randf_range(5.0, 8.0)
	var bark := Color(0.28, 0.25, 0.22)
	var top := Vector3(rng.randf_range(-0.5, 0.5), height, rng.randf_range(-0.5, 0.5))
	b.frustum(Vector3.ZERO, top, 0.32, 0.1, 6, bark, 0.0, 0.2, true, 0.12, rng)
	for i in rng.randi_range(3, 5):
		var from := top * rng.randf_range(0.4, 0.9)
		var a := rng.randf() * TAU
		var to := from + Vector3(cos(a) * rng.randf_range(1.2, 2.4), rng.randf_range(0.4, 1.6), sin(a) * rng.randf_range(1.2, 2.4))
		b.frustum(from, to, 0.12, 0.03, 4, bark, 0.1, 0.3, true)
	return b.commit()


static func bush(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Builder.new()
	var col := LEAF_COLORS[rng.randi() % LEAF_COLORS.size()] * 0.92
	for i in rng.randi_range(2, 4):
		var c := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.35, 0.6), rng.randf_range(-0.6, 0.6))
		b.blob(c, rng.randf_range(0.65, 1.05), Color(col * rng.randf_range(0.9, 1.1), 1.0), 0.45, rng, 0.25,
			Vector3(1.1, 0.75, 1.1), -0.55)
	# 산딸기처럼 보이는 작은 점
	if rng.randf() < 0.5:
		var berry := Color(0.75, 0.16, 0.2) if rng.randf() < 0.6 else Color(0.35, 0.3, 0.75)
		for i in 6:
			var a := rng.randf() * TAU
			var c := Vector3(cos(a) * 0.9, rng.randf_range(0.4, 0.9), sin(a) * 0.9)
			b.blob(c, 0.07, Color(berry, 0.5), 0.5, rng, 0.0, Vector3.ONE, -2.0, 0.0, 0.0)
	return b.commit()


static func rock(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Builder.new()
	var grey := rng.randf_range(0.27, 0.36)
	var col := Color(grey, grey * 0.98, grey * 0.93)
	b.blob(Vector3(0, 0.4, 0), 1.0, Color(col, 0.0), 0.0, rng, 0.38,
		Vector3(rng.randf_range(0.9, 1.25), rng.randf_range(0.7, 0.95), rng.randf_range(0.85, 1.15)), -0.5, 0.14, 0.35)
	# 이끼 낀 윗면
	if rng.randf() < 0.6:
		b.blob(Vector3(rng.randf_range(-0.2, 0.2), 0.75, rng.randf_range(-0.2, 0.2)), 0.55,
			Color(0.3, 0.42, 0.2, 0.0), 0.0, rng, 0.2, Vector3(1.2, 0.3, 1.1), -2.0, 0.08, 0.0)
	return b.commit()


## 풀잎 묶음(가는 삼각형 여러 개). 알파 = 흔들림(밑동 0, 끝 1).
static func grass_tuft(seed_value: int, blades: int = 7) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in blades:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.3)
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0.0, sin(facing)) * rng.randf_range(0.02, 0.034)
		var h := rng.randf_range(0.22, 0.48)
		var bend := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.04, 0.14)
		var tip := base + Vector3(0, h, 0) + bend
		# 색은 풀밭 배치에서 구역 색으로 곱해지므로 여기서는 밝기 차이만 준다.
		var tint := rng.randf_range(0.85, 1.1)
		var col := Color(0.95 * tint, tint, 0.9 * tint)
		for v in [[base - side, 0.0], [base + side, 0.0], [tip, 1.0]]:
			st.set_color(Color(col, v[1]))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	return st.commit()


## 들꽃 묶음
static func flower_tuft(seed_value: int, petal: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Builder.new()
	for i in 5:
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.25)
		var h := rng.randf_range(0.25, 0.45)
		b.frustum(base, base + Vector3(0, h, 0), 0.012, 0.01, 3, Color(0.3, 0.5, 0.22), 0.0, 0.8, false)
		b.blob(base + Vector3(0, h, 0), 0.05, Color(petal * rng.randf_range(0.9, 1.1), 1.0), 1.0, rng, 0.1,
			Vector3(1.0, 0.5, 1.0), -2.0, 0.05, 0.1)
	return b.commit()

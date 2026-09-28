class_name TreeKit
extends RefCounted
## 사실적인 나무·덤불 모델(기획서 §23.1 고품질 숲, §12 지역 1의 숲).
## 줄기와 가지는 매끈한 관이고 나무껍질 결이 UV를 따라 감긴다. 잎은 잎가지·솔잎 가지 텍스처를 알파로 오려 낸
## 카드(사각판)를 수관에 빽빽이 모은 것이다. 카드 법선은 수관 가운데에서 바깥을 향해, 수관 전체가 부드럽게 빛을 받는다.
## 정점 색: RGB = 껍질·잎의 바탕색, A = 바람에 흔들리는 정도(밑동 0 → 잎 끝 1).
## UV2.x = 종류(0 껍질, 1 잎가지, 2 솔잎 가지), UV2.y = 카드마다 다른 난수(색 변화).
## 가까운 모델(detail = 1)과 먼 모델(detail = 0, 카드가 적고 크다)을 따로 만든다.

const KIND_BARK := 0.0
const KIND_LEAF := 1.0
const KIND_NEEDLE := 2.0
const TREE_SHADER := preload("res://assets/shaders/tree.gdshader")

const BARK_BROWN := Color(0.29, 0.24, 0.19)
const BARK_PINE := Color(0.36, 0.26, 0.19)
const BARK_DEAD := Color(0.42, 0.39, 0.35)
const LEAF_TINTS: Array[Color] = [
	Color(0.36, 0.5, 0.24), Color(0.42, 0.54, 0.24), Color(0.32, 0.46, 0.22), Color(0.46, 0.55, 0.26),
]
const PINE_TINT := Color(0.26, 0.4, 0.26)

static var _material: ShaderMaterial

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tangents := PackedFloat32Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = TREE_SHADER
		_material.set_shader_parameter(&"leaf_tex", FoliageTextures.get_texture(&"leaves"))
		_material.set_shader_parameter(&"needle_tex", FoliageTextures.get_texture(&"needles"))
		_material.set_shader_parameter(&"bark_tex", FoliageTextures.get_texture(&"bark"))
	return _material


static func clear_cache() -> void:
	_material = null


# --- 기본 도형 ---

func _vert(p: Vector3, n: Vector3, t: Vector3, uv: Vector2, kind: float, rnd: float, col: Color) -> int:
	verts.append(p)
	normals.append(n)
	tangents.append_array([t.x, t.y, t.z, 1.0])
	uvs.append(uv)
	uv2s.append(Vector2(kind, rnd))
	colors.append(col)
	return verts.size() - 1


## 줄기·가지: 점을 따라 이어진 매끈한 관. radii는 점마다의 반지름, sways는 점마다 흔들림.
func tube(points: Array[Vector3], radii: Array[float], sides: int, col: Color, sways: Array[float]) -> void:
	var n := points.size()
	if n < 2:
		return
	var tans: Array[Vector3] = []
	for i in n:
		var d := points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]
		tans.append(d.normalized() if d.length_squared() > 1e-8 else Vector3.UP)
	var side := tans[0].cross(Vector3.FORWARD if absf(tans[0].z) < 0.9 else Vector3.RIGHT).normalized()
	var circ := TAU * radii[0]
	var repeats := maxf(roundf(circ / 0.45), 1.0)
	var along := 0.0
	var base := verts.size()
	for i in n:
		if i > 0:
			side = (side - tans[i] * tans[i].dot(side)).normalized()
			along += points[i].distance_to(points[i - 1])
		var up := tans[i].cross(side).normalized()
		for j in sides + 1:
			var a := TAU * float(j) / float(sides)
			var dir := side * cos(a) + up * sin(a)
			var tangent := (-side * sin(a) + up * cos(a)).normalized()
			var v := along / 0.45
			_vert(points[i] + dir * radii[i], dir, tangent, Vector2(float(j) / float(sides) * repeats, v), KIND_BARK, 0.0,
				Color(col, sways[i]))
	for i in n - 1:
		for j in sides:
			var a := base + i * (sides + 1) + j
			var b := a + 1
			var c := a + sides + 1
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])


## 잎 카드: center를 가운데로 right·up 방향 크기 w·h의 판. 아래(밑동) 쪽 흔들림 sway0, 위쪽 sway1.
func card(center: Vector3, right: Vector3, up: Vector3, w: float, h: float, normal: Vector3, col: Color, kind: float,
		rnd: float, sway0: float, sway1: float) -> void:
	var r := right.normalized() * w * 0.5
	var u := up.normalized() * h * 0.5
	var t := right.normalized()
	var a := _vert(center - r - u, normal, t, Vector2(0, 1), kind, rnd, Color(col, sway0))
	var b := _vert(center + r - u, normal, t, Vector2(1, 1), kind, rnd, Color(col, sway0))
	var c := _vert(center + r + u, normal, t, Vector2(1, 0), kind, rnd, Color(col, sway1))
	var d := _vert(center - r + u, normal, t, Vector2(0, 0), kind, rnd, Color(col, sway1))
	indices.append_array([a, b, c, a, c, d])


func commit() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- 도우미 ---

static func _rand_dir(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a))


## 수관(타원체) 가운데에서 바깥을 향하는 법선
static func _crown_normal(p: Vector3, center: Vector3, squash: float) -> Vector3:
	var d := p - center
	d.y /= squash
	return d.normalized() if d.length_squared() > 1e-6 else Vector3.UP


## 잎가지 뭉치: 뭉치 가운데 둘레에 카드를 흩어 놓는다. 카드는 대체로 바깥·위를 향해 뻗는다.
func _leaf_cluster(rng: RandomNumberGenerator, at: Vector3, count: int, size: float, crown: Vector3, squash: float,
		tint: Color, kind: float) -> void:
	for k in count:
		var off := _rand_dir(rng) * rng.randf_range(0.1, size * 0.45)
		var c := at + off
		var outward := _crown_normal(c, crown, squash)
		# 카드의 위(잎가지 끝) 방향: 바깥쪽과 위쪽 사이, 조금씩 흐트러진다.
		var up := (outward * 0.7 + Vector3.UP * 0.5 + _rand_dir(rng) * 0.45).normalized()
		var right := up.cross(_rand_dir(rng)).normalized()
		if right.length_squared() < 0.01:
			right = Vector3.RIGHT
		var s := size * rng.randf_range(0.8, 1.15)
		var shade := rng.randf_range(0.85, 1.12)
		card(c + up * s * 0.3, right, up, s * 0.72, s, (outward + up * 0.2).normalized(), tint * shade, kind, rng.randf(),
			0.55, 1.0)


# --- 나무 ---

## 활엽수. detail 1 = 가까운 모델, 0 = 먼 모델(잎 카드가 적고 크다). 반환 메시의 원점은 밑동.
static func broadleaf(seed_value: int, detail: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := TreeKit.new()
	var height := rng.randf_range(6.5, 9.5)
	var trunk_top := height * rng.randf_range(0.55, 0.65)
	var lean := Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
	var r0 := rng.randf_range(0.26, 0.36)
	var trunk: Array[Vector3] = []
	var trunk_r: Array[float] = []
	var trunk_s: Array[float] = []
	var segs := 6
	for i in segs + 1:
		var t := float(i) / float(segs)
		var wob := Vector3(sin(t * 5.0 + float(seed_value)) * 0.08, 0.0, cos(t * 4.0 + float(seed_value)) * 0.08)
		trunk.append(Vector3(0, trunk_top * t, 0) + lean * t * t + wob * t)
		# 밑동은 뿌리 쪽으로 넓게 퍼진다.
		trunk_r.append(r0 * (1.0 + 0.55 * pow(1.0 - t, 6.0)) * lerpf(1.0, 0.62, t))
		trunk_s.append(t * 0.2)
	var bark := BARK_BROWN * rng.randf_range(0.9, 1.1)
	k.tube(trunk, trunk_r, 10 if detail > 0 else 6, bark, trunk_s)
	var crown := Vector3(0, height * 0.74, 0) + lean
	var crown_r := height * rng.randf_range(0.3, 0.36)
	var squash := 0.8
	var tint := LEAF_TINTS[rng.randi() % LEAF_TINTS.size()] * rng.randf_range(0.92, 1.08)
	var branches := rng.randi_range(5, 7)
	var tips: Array[Vector3] = []
	for i in branches:
		var a := TAU * float(i) / float(branches) + rng.randf_range(-0.35, 0.35)
		var from_t := rng.randf_range(0.7, 1.0)
		var from := trunk[int(from_t * segs)]
		var el := deg_to_rad(rng.randf_range(28.0, 58.0))
		var dir := Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el))
		var length := crown_r * rng.randf_range(0.85, 1.2)
		var mid := from + dir * length * 0.5 + Vector3.UP * 0.25
		var tip := from + dir * length + Vector3.UP * 0.5
		var br: Array[Vector3] = [from, mid, tip]
		var rr: Array[float] = [trunk_r[int(from_t * segs)] * 0.55, 0.07, 0.03]
		var ss: Array[float] = [0.2, 0.4, 0.6]
		k.tube(br, rr, 6 if detail > 0 else 4, bark, ss)
		tips.append(tip)
		tips.append(mid + Vector3.UP * 0.4)
	# 수관 윗부분과 안쪽을 채우는 뭉치(수관이 비어 보이지 않게)
	tips.append(crown + Vector3(0, crown_r * 0.6, 0))
	tips.append(crown + Vector3(rng.randf_range(-0.5, 0.5), crown_r * 0.1, rng.randf_range(-0.5, 0.5)))
	for i in 9:
		var dirv := _rand_dir(rng)
		dirv.y = absf(dirv.y) * 0.8 + 0.1
		tips.append(crown + dirv.normalized() * Vector3(crown_r, crown_r * squash, crown_r) * rng.randf_range(0.45, 0.85))
	var per := 9 if detail > 0 else 3
	var size := 1.45 if detail > 0 else 2.6
	for tip in tips:
		k._leaf_cluster(rng, tip, per, size, crown, squash, tint, KIND_LEAF)
	return k.commit()


## 고목(랜드마크): 뿌리가 땅 위로 드러난 굵은 밑동, 크게 벌어진 굵은 가지, 넓은 수관. 높이 약 20m.
static func ancient(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := TreeKit.new()
	var bark := BARK_BROWN * 0.95
	var trunk: Array[Vector3] = []
	var trunk_r: Array[float] = []
	var trunk_s: Array[float] = []
	var top_y := 11.0
	for i in 9:
		var t := float(i) / 8.0
		trunk.append(Vector3(sin(t * 3.1) * 0.5, top_y * t, cos(t * 2.3) * 0.4 - 0.2))
		trunk_r.append(2.2 * (1.0 + 0.5 * pow(1.0 - t, 5.0)) * lerpf(1.0, 0.55, t))
		trunk_s.append(t * 0.05)
	k.tube(trunk, trunk_r, 18, bark, trunk_s)
	# 드러난 뿌리
	for i in 7:
		var a := TAU * float(i) / 7.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0.0, sin(a))
		var root: Array[Vector3] = [out * 1.6 + Vector3.UP * 1.4, out * 3.2 + Vector3.UP * 0.35, out * 5.2 - Vector3.UP * 0.25]
		var rr: Array[float] = [0.9, 0.55, 0.2]
		var ss: Array[float] = [0.0, 0.0, 0.0]
		k.tube(root, rr, 10, bark * 0.9, ss)
	var crown := Vector3(0, 16.5, 0)
	var crown_r := 8.0
	var squash := 0.6
	var tips: Array[Vector3] = []
	for i in 8:
		var a := TAU * float(i) / 8.0 + rng.randf_range(-0.25, 0.25)
		var from := trunk[rng.randi_range(6, 8)]
		var el := deg_to_rad(rng.randf_range(22.0, 48.0))
		var dir := Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el))
		var length := rng.randf_range(6.0, 8.5)
		var mid := from + dir * length * 0.5 + Vector3.UP * 0.8
		var tip := from + dir * length + Vector3.UP * 1.6
		var br: Array[Vector3] = [from, mid, tip]
		var rr: Array[float] = [0.75, 0.38, 0.12]
		var ss: Array[float] = [0.05, 0.15, 0.3]
		k.tube(br, rr, 10, bark, ss)
		tips.append(tip)
		tips.append(mid + Vector3.UP * 1.2)
		tips.append(from.lerp(tip, 0.8) + Vector3(rng.randf_range(-1, 1), 1.5, rng.randf_range(-1, 1)))
	for i in 14:
		var dirv := _rand_dir(rng)
		dirv.y = absf(dirv.y) * 0.7 + 0.15
		tips.append(crown + dirv.normalized() * Vector3(crown_r, crown_r * squash, crown_r) * rng.randf_range(0.4, 0.9))
	var tint := LEAF_TINTS[1] * 0.92
	for tip in tips:
		k._leaf_cluster(rng, tip, 11, 2.4, crown, squash, tint, KIND_LEAF)
	return k.commit()


## 침엽수: 곧은 줄기를 따라 돌려난 가지 층. 가지마다 솔잎 가지 카드가 아래로 처진다. 위로 갈수록 짧다.
static func pine(seed_value: int, detail: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := TreeKit.new()
	var height := rng.randf_range(9.0, 13.0)
	var r0 := rng.randf_range(0.22, 0.3)
	var trunk: Array[Vector3] = []
	var trunk_r: Array[float] = []
	var trunk_s: Array[float] = []
	for i in 7:
		var t := float(i) / 6.0
		trunk.append(Vector3(sin(t * 3.0 + float(seed_value)) * 0.05, height * t, cos(t * 2.0) * 0.05))
		trunk_r.append(r0 * (1.0 + 0.4 * pow(1.0 - t, 6.0)) * lerpf(1.0, 0.1, t))
		trunk_s.append(t * 0.3)
	k.tube(trunk, trunk_r, 8 if detail > 0 else 5, BARK_PINE * rng.randf_range(0.9, 1.1), trunk_s)
	var tint := PINE_TINT * rng.randf_range(0.88, 1.1)
	var y := height * rng.randf_range(0.22, 0.3)
	var whorl := 0
	while y < height - 0.6:
		var t := y / height
		var count := (rng.randi_range(6, 8) if detail > 0 else 5)
		var length := lerpf(3.4, 0.9, pow(t, 0.9)) * rng.randf_range(0.9, 1.1)
		for i in count:
			var a := TAU * float(i) / float(count) + float(whorl) * 0.7 + rng.randf_range(-0.2, 0.2)
			var out := Vector3(cos(a), 0.0, sin(a))
			var droop := rng.randf_range(0.15, 0.4)
			var dir := (out - Vector3.UP * droop).normalized()
			var right := out.cross(Vector3.UP).normalized()
			var center := Vector3(0, y, 0) + dir * length * 0.5
			var normal := (out * 0.8 + Vector3.UP * 0.6).normalized()
			# 가지 하나 = 가지 방향으로 누운 카드 두 장(위에서 봐도, 옆에서 봐도 보이게)
			var w := length * (0.62 if detail > 0 else 0.9)
			k.card(center, right, dir, w, length, normal, tint * rng.randf_range(0.85, 1.1), KIND_NEEDLE, rng.randf(),
				0.35, 0.9)
			# 비스듬히 세운 두 번째 카드(옆에서 봐도 가지가 두툼하게)
			var tilted := (right * 0.5 + Vector3.UP * 0.866).normalized()
			k.card(center + Vector3.UP * 0.08, tilted, dir, w * 0.85, length * 0.95, normal,
				tint * rng.randf_range(0.8, 1.05), KIND_NEEDLE, rng.randf(), 0.35, 0.9)
		y += lerpf(0.75, 0.45, t) * rng.randf_range(0.9, 1.15)
		whorl += 1
	# 꼭대기 순
	var top := Vector3(0, height - 0.2, 0)
	for i in 2:
		var right := Vector3(cos(float(i) * PI * 0.5), 0.0, sin(float(i) * PI * 0.5))
		k.card(top, right, Vector3.UP, 0.8, 1.8, Vector3.UP, tint * 1.05, KIND_NEEDLE, rng.randf(), 0.8, 1.0)
	return k.commit()


## 죽은 나무: 잎 없이 회색으로 마른 줄기와 꺾인 가지
static func dead(seed_value: int, detail: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := TreeKit.new()
	var height := rng.randf_range(5.0, 8.0)
	var r0 := rng.randf_range(0.24, 0.32)
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
	var trunk: Array[Vector3] = []
	var trunk_r: Array[float] = []
	var trunk_s: Array[float] = []
	for i in 6:
		var t := float(i) / 5.0
		trunk.append(Vector3(0, height * t, 0) + lean * t * t)
		trunk_r.append(r0 * (1.0 + 0.5 * pow(1.0 - t, 6.0)) * lerpf(1.0, 0.25, t))
		trunk_s.append(t * 0.15)
	var bark := BARK_DEAD * rng.randf_range(0.85, 1.1)
	k.tube(trunk, trunk_r, 8 if detail > 0 else 5, bark, trunk_s)
	for i in rng.randi_range(3, 5):
		var from_t := rng.randf_range(0.35, 0.9)
		var idx := int(from_t * 5.0)
		var from := trunk[idx]
		var a := rng.randf() * TAU
		var el := deg_to_rad(rng.randf_range(10.0, 50.0))
		var dir := Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el))
		var length := rng.randf_range(1.2, 2.6)
		var kink := dir.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
		var br: Array[Vector3] = [from, from + dir * length * 0.55, from + dir * length * 0.55 + kink * length * 0.45]
		var rr: Array[float] = [trunk_r[idx] * 0.5, 0.06, 0.02]
		var ss: Array[float] = [0.1, 0.25, 0.4]
		k.tube(br, rr, 5 if detail > 0 else 4, bark, ss)
	return k.commit()


## 덤불: 땅에 붙은 낮은 잎가지 뭉치
static func bush(seed_value: int, detail: int = 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := TreeKit.new()
	var tint := LEAF_TINTS[rng.randi() % LEAF_TINTS.size()] * rng.randf_range(0.8, 0.95)
	var crown := Vector3(0, 0.55, 0)
	var clusters := rng.randi_range(3, 5)
	for i in clusters:
		var a := TAU * float(i) / float(clusters) + rng.randf_range(-0.4, 0.4)
		var at := crown + Vector3(cos(a) * 0.55, rng.randf_range(-0.1, 0.25), sin(a) * 0.55)
		k._leaf_cluster(rng, at, 8 if detail > 0 else 3, 1.0 if detail > 0 else 1.5, crown, 0.7, tint, KIND_LEAF)
	k._leaf_cluster(rng, crown + Vector3(0, 0.35, 0), 7 if detail > 0 else 3, 1.0, crown, 0.7, tint * 1.05, KIND_LEAF)
	return k.commit()

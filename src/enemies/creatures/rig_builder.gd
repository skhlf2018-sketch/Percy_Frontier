class_name RigBuilder
extends RefCounted
## 절차적 생물 모델 만들기: 뼈대 + 뼈에 입힌 매끈한 몸.
## 몸통·목·다리·꼬리는 척추 곡선을 따라 타원 단면을 이은 관(loft)으로 만들고, 관절에서는 두 뼈에 나눠 입혀
## 굽힐 때 살이 부드럽게 접힌다. 눈·발톱·뿔 같은 작은 부품은 한 뼈에만 붙인다.
## 색은 정점 색으로 칠한다: 등(위)은 짙고 배(아래)는 옅은 보호색에 무늬 함수를 곱한다.
## 결과(RigTemplate)는 종마다 한 번 만들어 모든 개체가 나눠 쓴다.

## 관 단면의 제어점 하나
class P:
	var pos: Vector3
	var rx: float
	var ry: float
	var bone: StringName

	func _init(p: Vector3, x: float, y: float, b: StringName) -> void:
		pos = p
		rx = x
		ry = y
		bone = b


## 재질별로 모으는 표면 배열
class Surf:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()


var names: Array[StringName] = []
var parents := PackedInt32Array()
## 뼈의 쉬는 자세 위치(모델 공간). 쉬는 자세의 회전은 모두 없음(모델 축과 같다).
var positions := PackedVector3Array()
var _index: Dictionary = {}
var _surfs: Dictionary = {}
## 무늬: func(pos: Vector3, radial: Vector3, base: Color) -> Color. 비어 있으면 무늬 없음.
var pattern: Callable = Callable()
## 뼈 부착점(판정·무기·빛 등). 이름 → [뼈, 변환]
var sockets: Dictionary = {}
## 이후 만드는 털 관의 털 길이 비율(0 = 털 없음). 정점 색 알파에 담겨 털 껍질이 쓴다.
var fur: float = 1.0
## 털 껍질의 가장 긴 털(미터)과 밀도
var fur_length: float = 0.025
var fur_density: float = 9.0
## 털이 없는 자리(눈, 코, 입). [중심, 반지름]
var _bald: Array = []


static func pt(pos: Vector3, rx: float, ry: float, bone: StringName) -> P:
	return P.new(pos, rx, ry, bone)


func bone(name: StringName, parent: StringName, pos: Vector3) -> int:
	var idx := names.size()
	names.append(name)
	parents.append(_index.get(parent, -1) if parent != &"" else -1)
	positions.append(pos)
	_index[name] = idx
	return idx


func bone_index(name: StringName) -> int:
	return _index.get(name, -1)


func bone_pos(name: StringName) -> Vector3:
	return positions[bone_index(name)]


## 털을 비울 자리(눈·코 둘레). 완성할 때 털 길이를 줄인다.
func bald(center: Vector3, radius: float) -> void:
	_bald.append([center, radius])


## 부착점을 적어 둔다(무기를 쥘 손, 판정 상자 자리).
func socket(name: StringName, bone_name: StringName, xf: Transform3D) -> void:
	sockets[name] = [bone_name, xf]


func _surf(kind: int) -> Surf:
	if not _surfs.has(kind):
		_surfs[kind] = Surf.new()
	return _surfs[kind]


# --- 곡선 보간 ---

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func _catmull_f(a: float, b: float, c: float, d: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (-a + 3.0 * b - 3.0 * c + d) * t3)


# --- 관(loft) ---

## 제어점을 따라 매끈한 관을 만든다.
## up_hint: 단면 타원의 ry 축이 향할 방향(몸통은 위, 다리는 앞).
## top/bottom: 등쪽·배쪽 색. caps: 양 끝을 둥글게 막을지.
## color_fn: func(pos: Vector3, normal: Vector3, col: Color) -> Color. 이 관에만 쓰는 무늬(뿔 끝 색 등).
## arc: 단면을 일부만 두를 때(망토·방패처럼 트인 면)의 시작·끝 각도. 기본은 한 바퀴.
##   각도 0은 옆(+side), 90도는 ry 축(up_hint) 쪽이다. 트인 면은 끝을 막지 않는다.
func loft(points: Array[P], kind: int, top: Color, bottom: Color, sides: int = 14, sub: int = 4,
		up_hint := Vector3.UP, cap_start: bool = true, cap_end: bool = true, color_fn: Callable = Callable(),
		arc := Vector2(0.0, TAU)) -> void:
	var open := arc.y - arc.x < TAU - 0.001
	if open:
		cap_start = false
		cap_end = false
	var ring_n := sides + 1 if open else sides
	var n := points.size()
	if n < 2:
		return
	# 1) 곡선 보간
	var cen: Array[Vector3] = []
	var rxs: Array[float] = []
	var rys: Array[float] = []
	var b0: Array[int] = []
	var b1: Array[int] = []
	var bw: Array[float] = []
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		var pp0 := p0.pos if i > 0 else p1.pos * 2.0 - p2.pos
		var pp3 := p3.pos if i + 2 < n else p2.pos * 2.0 - p1.pos
		for k in sub:
			var t := float(k) / float(sub)
			cen.append(_catmull(pp0, p1.pos, p2.pos, pp3, t))
			rxs.append(maxf(_catmull_f(p0.rx, p1.rx, p2.rx, p3.rx, t), 0.002))
			rys.append(maxf(_catmull_f(p0.ry, p1.ry, p2.ry, p3.ry, t), 0.002))
			b0.append(bone_index(p1.bone))
			b1.append(bone_index(p2.bone))
			bw.append(smoothstep(0.0, 1.0, t))
	var last := points[n - 1]
	cen.append(last.pos)
	rxs.append(maxf(last.rx, 0.002))
	rys.append(maxf(last.ry, 0.002))
	b0.append(bone_index(last.bone))
	b1.append(bone_index(last.bone))
	bw.append(0.0)
	var rings := cen.size()
	# 2) 접선과 틀(평행 이동으로 비틀림 없이)
	var tan: Array[Vector3] = []
	for r in rings:
		var a := cen[maxi(r - 1, 0)]
		var b := cen[mini(r + 1, rings - 1)]
		var t := (b - a)
		tan.append(t.normalized() if t.length_squared() > 1e-10 else Vector3.FORWARD)
	var ups: Array[Vector3] = []
	var hint := up_hint
	if absf(tan[0].dot(hint.normalized())) > 0.97:
		hint = Vector3.BACK if absf(tan[0].y) > 0.9 else Vector3.UP
	var u := (hint - tan[0] * tan[0].dot(hint)).normalized()
	for r in rings:
		if r > 0:
			u = (u - tan[r] * tan[r].dot(u))
			u = u.normalized() if u.length_squared() > 1e-10 else ups[r - 1]
		ups.append(u)
	# 3) 끝 막음: 반구 모양으로 고리를 줄여 가다 한 점으로 모은다.
	var grid: Array = []  # [center, side, up, rx, ry, b0, b1, w]
	const CAP_STEPS := 3
	if cap_start:
		for c in range(CAP_STEPS, 0, -1):
			var phi := PI * 0.5 * float(c) / float(CAP_STEPS + 1)
			var along := sin(phi) * minf(rxs[0], rys[0]) * 0.9
			var s := cos(phi)
			grid.append([cen[0] - tan[0] * along, tan[0].cross(ups[0]), ups[0], rxs[0] * s, rys[0] * s, b0[0], b1[0], bw[0]])
	for r in rings:
		grid.append([cen[r], tan[r].cross(ups[r]), ups[r], rxs[r], rys[r], b0[r], b1[r], bw[r]])
	if cap_end:
		var e := rings - 1
		for c in range(1, CAP_STEPS + 1):
			var phi := PI * 0.5 * float(c) / float(CAP_STEPS + 1)
			var along := sin(phi) * minf(rxs[e], rys[e]) * 0.9
			var s := cos(phi)
			grid.append([cen[e] + tan[e] * along, tan[e].cross(ups[e]), ups[e], rxs[e] * s, rys[e] * s, b0[e], b1[e], bw[e]])
	# 4) 정점
	var surf := _surf(kind)
	var base := surf.verts.size()
	var gr := grid.size()
	var pos: Array[PackedVector3Array] = []
	for g in grid:
		var ring := PackedVector3Array()
		var c: Vector3 = g[0]
		var sd: Vector3 = g[1]
		var up: Vector3 = g[2]
		var rx: float = g[3]
		var ry: float = g[4]
		for j in ring_n:
			var th := arc.x + (arc.y - arc.x) * float(j) / float(sides)
			ring.append(c + sd * cos(th) * rx + up * sin(th) * ry)
		pos.append(ring)
	for r in gr:
		var g: Array = grid[r]
		var c: Vector3 = g[0]
		for j in ring_n:
			var v := pos[r][j]
			# 법선: 곡면의 두 방향 미분
			var ds := pos[mini(r + 1, gr - 1)][j] - pos[maxi(r - 1, 0)][j]
			var da: Vector3
			if open:
				da = pos[r][mini(j + 1, sides)] - pos[r][maxi(j - 1, 0)]
			else:
				da = pos[r][(j + 1) % sides] - pos[r][(j - 1 + sides) % sides]
			var nrm := ds.cross(da)
			var radial := v - c
			if nrm.length_squared() < 1e-12:
				nrm = radial
			nrm = nrm.normalized()
			if nrm.dot(radial) < 0.0:
				nrm = -nrm
			surf.verts.append(v)
			surf.normals.append(nrm)
			surf.colors.append(_shade(v, nrm, top, bottom, color_fn, kind))
			_add_weights(surf, int(g[5]), int(g[6]), float(g[7]))
	# 끝의 극점
	var pole_start := -1
	var pole_end := -1
	if cap_start:
		var g: Array = grid[0]
		pole_start = surf.verts.size()
		var tip: Vector3 = cen[0] - tan[0] * minf(rxs[0], rys[0]) * 0.9
		surf.verts.append(tip)
		surf.normals.append(-tan[0])
		surf.colors.append(_shade(tip, -tan[0], top, bottom, color_fn, kind))
		_add_weights(surf, int(g[5]), int(g[6]), float(g[7]))
	if cap_end:
		var g: Array = grid[gr - 1]
		pole_end = surf.verts.size()
		var e := rings - 1
		var tip: Vector3 = cen[e] + tan[e] * minf(rxs[e], rys[e]) * 0.9
		surf.verts.append(tip)
		surf.normals.append(tan[e])
		surf.colors.append(_shade(tip, tan[e], top, bottom, color_fn, kind))
		_add_weights(surf, int(g[5]), int(g[6]), float(g[7]))
	# 5) 면(고데: 앞면은 시계 방향, (c-a)×(b-a)가 바깥)
	for r in gr - 1:
		for j in sides:
			var j1 := j + 1 if open else (j + 1) % sides
			var a := base + r * ring_n + j
			var b := base + r * ring_n + j1
			var c2 := base + (r + 1) * ring_n + j1
			var d := base + (r + 1) * ring_n + j
			_tri_out(surf, a, b, c2)
			_tri_out(surf, a, c2, d)
	if pole_start >= 0:
		for j in sides:
			_tri_out(surf, pole_start, base + j, base + (j + 1) % sides)
	if pole_end >= 0:
		var lr := base + (gr - 1) * sides
		for j in sides:
			_tri_out(surf, pole_end, lr + (j + 1) % sides, lr + j)


## 앞면이 바깥(정점 법선 쪽)을 보도록 순서를 맞춰 넣는다.
func _tri_out(s: Surf, a: int, b: int, c: int) -> void:
	var va := s.verts[a]
	var n := (s.verts[c] - va).cross(s.verts[b] - va)
	var outward := s.normals[a] + s.normals[b] + s.normals[c]
	if n.dot(outward) < 0.0:
		s.indices.append_array([a, c, b])
	else:
		s.indices.append_array([a, b, c])


func _add_weights(s: Surf, a: int, b: int, w: float) -> void:
	if a == b or w <= 0.001:
		s.bones.append_array([maxi(a, 0), 0, 0, 0])
		s.weights.append_array([1.0, 0.0, 0.0, 0.0])
	elif w >= 0.999:
		s.bones.append_array([maxi(b, 0), 0, 0, 0])
		s.weights.append_array([1.0, 0.0, 0.0, 0.0])
	else:
		s.bones.append_array([maxi(a, 0), maxi(b, 0), 0, 0])
		s.weights.append_array([1.0 - w, w, 0.0, 0.0])


## 보호색: 법선이 위를 볼수록 등 색, 아래를 볼수록 배 색. 무늬 함수를 곱한다.
## 알파는 털 길이 비율(털 재질만). 무늬 함수가 알파를 바꾸면 그 자리 털 길이가 바뀐다.
func _shade(v: Vector3, nrm: Vector3, top: Color, bottom: Color, color_fn: Callable = Callable(), kind: int = -1) -> Color:
	var f := smoothstep(-0.45, 0.6, nrm.y)
	var furry := kind == CreatureMaterials.Kind.FUR or kind == CreatureMaterials.Kind.FUR_THIN
	var col := Color(bottom.lerp(top, f), fur if furry else 0.0)
	if pattern.is_valid():
		col = pattern.call(v, nrm, col)
	if color_fn.is_valid():
		col = color_fn.call(v, nrm, col)
	return Color(col.r, col.g, col.b, clampf(col.a, 0.0, 1.0) if furry else 0.0)


# --- 작은 부품 ---

## 타원체(한 뼈에 붙는다)
func ellipsoid(center: Vector3, radii: Vector3, bone_name: StringName, kind: int, top: Color, bottom: Color = Color(0, 0, 0, 0),
		sides: int = 12, basis := Basis.IDENTITY, color_fn: Callable = Callable()) -> void:
	var fwd := basis * Vector3(0, 0, 1)
	var pts: Array[P] = []
	var steps := 5
	for i in steps:
		var t := -1.0 + 2.0 * float(i) / float(steps - 1)
		var s := sqrt(maxf(1.0 - t * t, 0.0))
		pts.append(P.new(center + fwd * t * radii.z * 0.82, maxf(radii.x * s, radii.x * 0.25), maxf(radii.y * s, radii.y * 0.25), bone_name))
	loft(pts, kind, top, bottom if bottom.a > 0.0 else top, sides, 2, basis * Vector3.UP, true, true, color_fn)


## 눈알: 바탕(흰자 또는 짐승 눈의 바탕색) + 홍채 + 동공. forward는 눈이 바라보는 방향.
func eye(center: Vector3, radius: float, bone_name: StringName, forward: Vector3, iris: Color,
		sclera := Color(0.08, 0.06, 0.05), pupil: float = 0.4, iris_size: float = 0.85) -> void:
	var f := forward.normalized()
	var fn := func(v: Vector3, _n: Vector3, _c: Color) -> Color:
		var d := (v - center).normalized().dot(f)
		var ang := acos(clampf(d, -1.0, 1.0)) / (PI * 0.5)
		if ang < pupil * 0.55:
			return Color(0.01, 0.01, 0.012)
		if ang < iris_size * 0.8:
			var edge := smoothstep(iris_size * 0.5, iris_size * 0.8, ang)
			return iris.lerp(iris.darkened(0.6), edge)
		return sclera
	var basis := Basis.looking_at(-f, Vector3.UP if absf(f.y) < 0.95 else Vector3.BACK)
	ellipsoid(center, Vector3(radius, radius, radius), bone_name, CreatureMaterials.Kind.EYE, sclera, sclera, 14, basis, fn)
	bald(center, radius * 1.7)


## 뿔·발톱·이빨·가시: 밑동에서 끝으로 가늘어지는 원뿔. bend는 가운데를 휘게 하는 방향과 크기.
func cone(base_pos: Vector3, tip: Vector3, radius: float, bone_name: StringName, kind: int, col: Color,
		bend := Vector3.ZERO, sides: int = 8, tip_col := Color(0, 0, 0, 0)) -> void:
	var pts: Array[P] = []
	var steps := 5
	for i in steps:
		var t := float(i) / float(steps - 1)
		var p := base_pos.lerp(tip, t) + bend * (4.0 * t * (1.0 - t))
		var r := radius * (1.0 - t) * (1.0 - 0.25 * t) + 0.002
		pts.append(P.new(p, r, r, bone_name))
	var fn := Callable()
	if tip_col.a > 0.0:
		var axis := tip - base_pos
		var length := maxf(axis.length(), 0.001)
		var dir := axis / length
		fn = func(v: Vector3, _n: Vector3, _c: Color) -> Color:
			var t := clampf((v - base_pos).dot(dir) / length, 0.0, 1.0)
			return col.lerp(tip_col, t * t)
	loft(pts, kind, col, col, sides, 2, Vector3.UP, true, false, fn)


## 판(귀, 지느러미, 막): 두께가 얇은 타원체
func flap(center: Vector3, size: Vector2, thickness: float, bone_name: StringName, kind: int, col: Color, basis: Basis) -> void:
	ellipsoid(center, Vector3(size.x, thickness, size.y), bone_name, kind, col, col.darkened(0.15), 10, basis)


# --- 완성 ---

func build() -> RigTemplate:
	# 털 없는 자리: 털 길이(정점 색 알파)를 줄인다.
	if not _bald.is_empty():
		for kind: int in [CreatureMaterials.Kind.FUR, CreatureMaterials.Kind.FUR_THIN]:
			if not _surfs.has(kind):
				continue
			var sf: Surf = _surfs[kind]
			for vi in sf.verts.size():
				var keep := 1.0
				for spot: Array in _bald:
					var r: float = spot[1]
					keep = minf(keep, smoothstep(r * 0.55, r, sf.verts[vi].distance_to(spot[0])))
				if keep < 1.0:
					var c := sf.colors[vi]
					sf.colors[vi] = Color(c.r, c.g, c.b, c.a * keep)
	var t := RigTemplate.new()
	t.names = names.duplicate()
	t.parents = parents.duplicate()
	t.positions = positions.duplicate()
	t.sockets = sockets.duplicate(true)
	var mesh := ArrayMesh.new()
	var kinds := _surfs.keys()
	kinds.sort()
	var aabb := AABB()
	var first := true
	for kind: int in kinds:
		var s: Surf = _surfs[kind]
		if s.indices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.verts
		arrays[Mesh.ARRAY_NORMAL] = s.normals
		arrays[Mesh.ARRAY_COLOR] = s.colors
		arrays[Mesh.ARRAY_BONES] = s.bones
		arrays[Mesh.ARRAY_WEIGHTS] = s.weights
		arrays[Mesh.ARRAY_INDEX] = s.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, CreatureMaterials.get_material(kind))
		for v in s.verts:
			if first:
				aabb = AABB(v, Vector3.ZERO)
				first = false
			else:
				aabb = aabb.expand(v)
	t.mesh = mesh
	# 털 껍질용: 털 재질 표면만 모은 메시
	var fur_mesh := ArrayMesh.new()
	for kind: int in [CreatureMaterials.Kind.FUR, CreatureMaterials.Kind.FUR_THIN]:
		if not _surfs.has(kind):
			continue
		var s: Surf = _surfs[kind]
		if s.indices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.verts
		arrays[Mesh.ARRAY_NORMAL] = s.normals
		arrays[Mesh.ARRAY_COLOR] = s.colors
		arrays[Mesh.ARRAY_BONES] = s.bones
		arrays[Mesh.ARRAY_WEIGHTS] = s.weights
		arrays[Mesh.ARRAY_INDEX] = s.indices
		fur_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if fur_mesh.get_surface_count() > 0:
		t.fur_mesh = fur_mesh
		t.fur_length = fur_length
		t.fur_density = fur_density
	# 굽힌 자세에서도 잘려 보이지 않도록 경계 상자를 넉넉히 잡는다.
	t.custom_aabb = aabb.grow(0.4)
	var skin := Skin.new()
	for i in names.size():
		skin.add_named_bind(String(names[i]), Transform3D(Basis(), -positions[i]))
	t.skin = skin
	var verts := 0
	for kind: int in kinds:
		verts += (_surfs[kind] as Surf).verts.size()
	t.vertex_count = verts
	return t

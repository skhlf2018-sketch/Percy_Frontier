class_name BladeMesh
extends RefCounted
## 곡선 날·손잡이·고리 메시(1인칭 근접 무기와 바닥에 떨어진 무기, 기획서 §23.4).
## 윤곽은 X-Y 평면에 그리고 Z가 두께다. 윤곽의 두 옆선(a, b)을 같은 수의 점으로 주면
## 단면마다 모양대로 두께를 주어 잇는다.
##  - SINGLE_EDGE: a는 두툼한 등, b는 날. 등 → 평평한 면 → 연마 비탈 → 날 순서로 얇아진다.
##  - DOUBLE_EDGE: 양쪽 모두 날(가운데가 두툼하다).
##  - ROUNDED: 모서리를 둥글게 깎은 납작한 띠(손잡이 판, 손가락 고리).
## 날 끝의 좁은 비탈(날빛)은 따로 된 메시로 돌려준다: 번쩍이는 날이나 은은한 빛을 따로 칠할 수 있다.

enum Profile { SINGLE_EDGE, DOUBLE_EDGE, ROUNDED }

## 단면에서 날빛 띠로 칠할 띠 번호(단면 점 i와 i+1 사이)
const _EDGE_BANDS := {
	Profile.SINGLE_EDGE: [2, 3],
	Profile.DOUBLE_EDGE: [0, 4, 5, 9],
	Profile.ROUNDED: [],
}

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## a[i], b[i]: i번째 단면의 양 끝(날이면 a가 등, b가 날). half_t[i]: 가장 두꺼운 곳의 두께 절반.
## closed: 마지막 단면을 첫 단면과 이어 고리로 만든다(끝 막음 없음).
## 돌려주는 값: {&"body": ArrayMesh, &"edge": ArrayMesh(날빛 띠가 없으면 null)}. key가 있으면 같은 모양을 다시 쓴다.
static func band(a: PackedVector2Array, b: PackedVector2Array, half_t: PackedFloat32Array, profile: int,
		closed: bool = false, key: String = "") -> Dictionary:
	if key != "" and _cache.has(key):
		return _cache[key]
	var n := a.size()
	var sections: Array[PackedVector3Array] = []
	for i in n:
		sections.append(_section(a[i], b[i], half_t[i], profile))
	var m := sections[0].size()
	var edge_bands: Array = _EDGE_BANDS[profile]
	var smooth := profile == Profile.ROUNDED
	var segs := n if closed else n - 1
	# 띠마다, 단면마다 바깥 법선
	var band_n: Array[PackedVector3Array] = []
	for j in m:
		var col := PackedVector3Array()
		col.resize(n)
		for i in n:
			col[i] = _band_normal(sections, i, j, closed)
		band_n.append(col)
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_edge := false
	for j in m:
		var j2 := (j + 1) % m
		var st := body
		if edge_bands.has(j):
			st = edge
			has_edge = true
		for i in segs:
			var i2 := (i + 1) % n
			var p00: Vector3 = sections[i][j]
			var p01: Vector3 = sections[i][j2]
			var p10: Vector3 = sections[i2][j]
			var p11: Vector3 = sections[i2][j2]
			var n00: Vector3 = band_n[j][i]
			var n10: Vector3 = band_n[j][i2]
			var n01 := n00
			var n11 := n10
			if smooth:
				var jp := (j - 1 + m) % m
				n00 = (band_n[jp][i] + band_n[j][i]).normalized()
				n10 = (band_n[jp][i2] + band_n[j][i2]).normalized()
				n01 = (band_n[j][i] + band_n[j2][i]).normalized()
				n11 = (band_n[j][i2] + band_n[j2][i2]).normalized()
			_tri(st, p00, p10, p11, n00, n10, n11)
			_tri(st, p00, p11, p01, n00, n11, n01)
	if not closed:
		_cap(body, sections[0], _along(sections, 0, false) * -1.0)
		_cap(body, sections[n - 1], _along(sections, n - 1, false))
	var out := {&"body": body.commit(), &"edge": edge.commit() if has_edge else null}
	if key != "":
		_cache[key] = out
	return out


## 초승달 윤곽의 두 옆선. 두 원(바깥 co·ro, 안쪽 ci·ri)이 만나는 두 뿔 사이에서 t0..t1 구간을 steps개로 나눈다.
## 돌려주는 값: [안쪽 호(오목한 쪽), 바깥 호(볼록한 쪽)]. 두 원은 반드시 두 점에서 만나야 한다.
static func crescent(co: Vector2, ro: float, ci: Vector2, ri: float, steps: int,
		t0: float = 0.0, t1: float = 1.0) -> Array[PackedVector2Array]:
	var d := co.distance_to(ci)
	# 두 원의 교점(뿔)
	var along := (d * d + ro * ro - ri * ri) / (2.0 * d)
	var h := sqrt(maxf(ro * ro - along * along, 0.0))
	var dir := (ci - co) / d
	var base := co + dir * along
	var perp := Vector2(-dir.y, dir.x)
	var h1 := base + perp * h
	var h2 := base - perp * h
	# 볼록한 쪽(안쪽 원 중심의 반대편)을 지나는 호를 고른다.
	var outer := _arc_between(co, h1, h2, co - dir * ro)
	var inner := _arc_between(ci, h1, h2, ci - dir * ri)
	var inner_pts := PackedVector2Array()
	var outer_pts := PackedVector2Array()
	for s in steps:
		var t := lerpf(t0, t1, float(s) / float(steps - 1))
		inner_pts.append(ci + Vector2.from_angle(lerpf(inner[0], inner[1], t)) * ri)
		outer_pts.append(co + Vector2.from_angle(lerpf(outer[0], outer[1], t)) * ro)
	var out: Array[PackedVector2Array] = [inner_pts, outer_pts]
	return out


## 3차 베지어 곡선의 점들
static func bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for s in steps:
		var t := float(s) / float(steps - 1)
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out


## 중심선(line)의 양옆으로 left_w·right_w만큼 벌린 두 옆선. 왼쪽은 진행 방향의 왼쪽(반시계).
static func offset_sides(line: PackedVector2Array, left_w: PackedFloat32Array, right_w: PackedFloat32Array) -> Array[PackedVector2Array]:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := line.size()
	for i in n:
		var tan := (line[mini(i + 1, n - 1)] - line[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-tan.y, tan.x)
		left.append(line[i] + nrm * left_w[i])
		right.append(line[i] - nrm * right_w[i])
	var out: Array[PackedVector2Array] = [left, right]
	return out


## 원(중심 c, 반지름 r)을 steps개 점으로(고리용, 첫 점과 끝 점이 겹치지 않는다)
static func circle(c: Vector2, r: float, steps: int, start_deg: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for s in steps:
		out.append(c + Vector2.from_angle(deg_to_rad(start_deg) + TAU * float(s) / float(steps)) * r)
	return out


# --- 내부 ---

## 단면의 점들(Z가 두께). 점 순서는 둘레를 한 바퀴 돈다.
static func _section(a: Vector2, b: Vector2, t: float, profile: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var at := func(f: float, z: float) -> Vector3:
		var p := a.lerp(b, f)
		return Vector3(p.x, p.y, z)
	match profile:
		Profile.SINGLE_EDGE:
			# 등(+) → 평평한 면 끝 → 연마 비탈 끝 → 날 → 반대쪽
			pts.append(at.call(0.0, t))
			pts.append(at.call(0.38, t * 0.92))
			pts.append(at.call(0.86, t * 0.2))
			pts.append(at.call(1.0, 0.0))
			pts.append(at.call(0.86, -t * 0.2))
			pts.append(at.call(0.38, -t * 0.92))
			pts.append(at.call(0.0, -t))
		Profile.DOUBLE_EDGE:
			pts.append(at.call(0.0, 0.0))
			pts.append(at.call(0.1, t * 0.22))
			pts.append(at.call(0.34, t))
			pts.append(at.call(0.66, t))
			pts.append(at.call(0.9, t * 0.22))
			pts.append(at.call(1.0, 0.0))
			pts.append(at.call(0.9, -t * 0.22))
			pts.append(at.call(0.66, -t))
			pts.append(at.call(0.34, -t))
			pts.append(at.call(0.1, -t * 0.22))
		_:
			# 모서리를 깎은 납작한 띠
			var w := a.distance_to(b)
			var k := clampf(t * 0.55 / maxf(w, 0.0001), 0.0, 0.45)
			pts.append(at.call(0.0, t * 0.45))
			pts.append(at.call(k, t))
			pts.append(at.call(1.0 - k, t))
			pts.append(at.call(1.0, t * 0.45))
			pts.append(at.call(1.0, -t * 0.45))
			pts.append(at.call(1.0 - k, -t))
			pts.append(at.call(k, -t))
			pts.append(at.call(0.0, -t * 0.45))
	return pts


## i번째 단면의 진행 방향
static func _along(sections: Array[PackedVector3Array], i: int, closed: bool) -> Vector3:
	var n := sections.size()
	var ia := i - 1
	var ib := i + 1
	if closed:
		ia = (ia + n) % n
		ib = ib % n
	else:
		ia = maxi(ia, 0)
		ib = mini(ib, n - 1)
	var d := _center(sections[ib]) - _center(sections[ia])
	return d.normalized() if d.length_squared() > 1e-12 else Vector3.UP


static func _center(pts: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / float(pts.size())


## 띠 j(단면 점 j → j+1)의 i번째 단면에서의 바깥 법선. 단면이 한 점으로 모이면(날 끝) 이웃 단면 것을 쓴다.
static func _band_normal(sections: Array[PackedVector3Array], i: int, j: int, closed: bool) -> Vector3:
	var n := sections.size()
	var m := sections[0].size()
	var j2 := (j + 1) % m
	for k in [0, -1, 1, -2, 2, -3, 3]:
		var ii: int = i + k
		if closed:
			ii = (ii + n) % n
		elif ii < 0 or ii >= n:
			continue
		var sec := sections[ii]
		var across := sec[j2] - sec[j]
		if across.length_squared() < 1e-12:
			continue
		var along := _along(sections, ii, closed)
		var nrm := along.cross(across)
		if nrm.length_squared() < 1e-14:
			continue
		nrm = nrm.normalized()
		var outward := (sec[j] + sec[j2]) * 0.5 - _center(sec)
		if nrm.dot(outward) < 0.0:
			nrm = -nrm
		return nrm
	return Vector3.BACK


## 앞면이 법선 쪽을 보도록 세 점의 순서를 맞춰 넣는다(Godot는 시계 방향이 앞면).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var fn := (c - a).cross(b - a)
	if fn.length_squared() < 1e-16:
		return
	if fn.dot(na + nb + nc) < 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	for pair in [[a, na], [b, nb], [c, nc]]:
		var p: Vector3 = pair[0]
		st.set_normal(pair[1])
		st.set_uv(Vector2(p.x + p.z, p.y))
		st.add_vertex(p)


## 단면을 부채꼴로 막는다(한 점으로 모인 단면은 건너뛴다).
static func _cap(st: SurfaceTool, sec: PackedVector3Array, nrm: Vector3) -> void:
	var c := _center(sec)
	var spread := 0.0
	for p in sec:
		spread = maxf(spread, p.distance_to(c))
	if spread < 1e-5:
		return
	for k in sec.size():
		_tri(st, c, sec[k], sec[(k + 1) % sec.size()], nrm, nrm, nrm)


## 원 위에서 h1 → h2로 가되 through 쪽을 지나는 호의 [시작 각, 끝 각]
static func _arc_between(c: Vector2, h1: Vector2, h2: Vector2, through: Vector2) -> Array[float]:
	var a1 := (h1 - c).angle()
	var a2 := (h2 - c).angle()
	var am := (through - c).angle()
	# a1에서 a2까지 반시계로 돌 때 am을 지나는지
	var ccw := fposmod(a2 - a1, TAU)
	var mid := fposmod(am - a1, TAU)
	var out: Array[float] = []
	if mid <= ccw:
		out = [a1, a1 + ccw]
	else:
		out = [a1, a1 - (TAU - ccw)]
	return out

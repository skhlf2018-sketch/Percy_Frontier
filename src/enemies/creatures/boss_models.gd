class_name BossModels
extends RefCounted
## 보스 모델. 늪턱 구렁: 악어의 머리·앞몸·다리와 뱀의 긴 몸·꼬리를 가진 늪의 포식자(기획서 §16.1 퍼시 외곽권).
## 몸은 척추 사슬 뼈(spine0~spine9)를 따라 이어진 하나의 관이라, 뼈를 차례로 돌리면 뱀처럼 물결친다.
## 단면은 등이 넓고 배가 평평한 둥근 사각형, 꼬리는 옆으로 납작해진다. 등에는 용골이 선 비늘판이 줄지어 있고
## 꼬리 위에서 두 줄이 한 줄의 톱니 볏으로 합쳐진다.

const K := CreatureMaterials.Kind
const SPINE_BONES := 10


## 늪턱 구렁: 길이 약 14.5m. 등은 이끼 낀 비늘판, 배는 누런 비늘, 목 아래 턱살(약점)은 붉게 부풀어 있다.
static func mire_maw() -> RigBuilder:
	var b := RigBuilder.new()
	var top := Color(0.16, 0.18, 0.11)
	var bottom := Color(0.64, 0.58, 0.37)
	var moss := Color(0.22, 0.31, 0.12)
	var mud := Color(0.29, 0.24, 0.16)
	var mot := SpeciesModels.mottle(0.22, 1.1)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col: Color = mot.call(v, n, c)
		# 옆구리와 꼬리의 짙은 가로 띠(악어 무늬). 배에는 없다.
		var band := smoothstep(0.3, 0.85, sin(v.z * 2.0 + SpeciesModels.noise3(v * 0.6) * 1.8))
		col = col.lerp(col.darkened(0.55), band * smoothstep(-0.35, 0.4, n.y) * 0.6 * smoothstep(-1.0, 1.5, v.z))
		# 등의 이끼
		var m := smoothstep(0.45, 0.9, n.y) * smoothstep(0.05, 0.5, SpeciesModels.noise3(v * 0.8 + Vector3(3, 1, 7)))
		col = col.lerp(moss, m * 0.75)
		# 몸 아래쪽과 발에 말라붙은 진흙
		col = col.lerp(mud, smoothstep(0.42, 0.05, v.y) * 0.65)
		return Color(col, c.a)
	# --- 뼈대 ---
	var spine_pts: Array[Vector3] = []
	for i in SPINE_BONES:
		var z := -1.2 + float(i) * 1.15
		var y := 0.8 - clampf(float(i - 2) * 0.06, 0.0, 0.4)
		spine_pts.append(Vector3(0, y, z))
	b.bone(&"root", &"", Vector3(0, 0.8, 0.0))
	for i in SPINE_BONES:
		var parent := &"root" if i == 0 else StringName("spine%d" % (i - 1))
		b.bone(StringName("spine%d" % i), parent, spine_pts[i])
	b.bone(&"neck", &"spine0", Vector3(0, 0.86, -2.0))
	b.bone(&"head", &"neck", Vector3(0, 0.92, -2.55))
	b.bone(&"jaw", &"head", Vector3(0, 0.78, -2.5))
	# --- 몸통과 꼬리 ---
	# 단면: 둥근 사각형(초타원), 배는 더 평평하게
	b.section = func(th: float, _c: Vector3) -> float:
		var s := sin(th)
		var m := pow(pow(absf(cos(th)), 2.8) + pow(absf(s), 2.8), -1.0 / 2.8)
		return m * (lerpf(1.0, 0.84, -s) if s < 0.0 else 1.0)
	var radii: Array[Vector2] = [Vector2(0.86, 0.54), Vector2(1.02, 0.6), Vector2(1.06, 0.62), Vector2(0.98, 0.6),
		Vector2(0.8, 0.56), Vector2(0.6, 0.52), Vector2(0.44, 0.46), Vector2(0.3, 0.38), Vector2(0.17, 0.28), Vector2(0.07, 0.15)]
	var body: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.93, -2.45), 0.52, 0.34, &"head"),
		RigBuilder.pt(Vector3(0, 0.9, -2.12), 0.62, 0.42, &"neck"),
		RigBuilder.pt(Vector3(0, 0.86, -1.65), 0.76, 0.5, &"spine0"),
	]
	for i in SPINE_BONES:
		var r := radii[i]
		body.append(RigBuilder.pt(spine_pts[i] + Vector3(0, 0.0, 0.3), r.x, r.y, StringName("spine%d" % i)))
	body.append(RigBuilder.pt(spine_pts[9] + Vector3(0, 0.02, 0.85), 0.02, 0.05, &"spine9"))
	b.loft(body, K.PLATED, top, bottom, 28, 4)
	# --- 머리: 넓적하고 윗면이 평평한 악어 머리 ---
	b.section = func(th: float, _c: Vector3) -> float:
		var s := sin(th)
		var m := pow(pow(absf(cos(th)), 2.6) + pow(absf(s), 2.6), -1.0 / 2.6)
		return m * (lerpf(1.0, 0.72, -s) if s < 0.0 else lerpf(1.0, 0.9, s))
	var mouth := Color(0.72, 0.52, 0.44)
	var inside_up := func(v: Vector3, n: Vector3, c: Color) -> Color:
		# 위턱 안쪽(입천장)은 옅은 살색
		return c.lerp(mouth, smoothstep(-0.72, -0.93, n.y)) if v.z < -2.6 else c
	var head: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.95, -2.3), 0.58, 0.34, &"head"),
		RigBuilder.pt(Vector3(0, 1.0, -2.75), 0.62, 0.3, &"head"),
		RigBuilder.pt(Vector3(0, 0.98, -3.2), 0.5, 0.24, &"head"),
		RigBuilder.pt(Vector3(0, 0.95, -3.7), 0.4, 0.2, &"head"),
		RigBuilder.pt(Vector3(0, 0.93, -4.1), 0.32, 0.17, &"head"),
		RigBuilder.pt(Vector3(0, 0.94, -4.36), 0.31, 0.17, &"head"),
		RigBuilder.pt(Vector3(0, 0.92, -4.52), 0.21, 0.12, &"head"),
	]
	b.loft(head, K.PLATED, top, bottom.lerp(top, 0.35), 24, 4, Vector3.UP, true, true, inside_up)
	var inside_low := func(v: Vector3, n: Vector3, c: Color) -> Color:
		# 아래턱 안쪽(혀와 잇몸)
		return c.lerp(mouth.darkened(0.1), smoothstep(0.7, 0.92, n.y)) if v.z < -2.6 else c
	b.section = func(th: float, _c: Vector3) -> float:
		var s := sin(th)
		var m := pow(pow(absf(cos(th)), 2.6) + pow(absf(s), 2.6), -1.0 / 2.6)
		return m * (lerpf(1.0, 0.8, s) if s > 0.0 else 1.0)
	var jaw: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.72, -2.35), 0.52, 0.2, &"jaw"),
		RigBuilder.pt(Vector3(0, 0.74, -2.8), 0.55, 0.17, &"jaw"),
		RigBuilder.pt(Vector3(0, 0.76, -3.35), 0.45, 0.12, &"jaw"),
		RigBuilder.pt(Vector3(0, 0.78, -3.85), 0.35, 0.09, &"jaw"),
		RigBuilder.pt(Vector3(0, 0.8, -4.28), 0.29, 0.08, &"jaw"),
		RigBuilder.pt(Vector3(0, 0.8, -4.46), 0.21, 0.06, &"jaw"),
	]
	b.loft(jaw, K.PLATED, bottom.lerp(top, 0.25), bottom, 22, 3, Vector3.UP, true, true, inside_low)
	b.section = Callable()
	# 목 아래 턱살(약점): 붉게 부풀어 핏줄이 비치는 주머니
	var throat_c := Vector3(0, 0.56, -2.55)
	var veins := func(v: Vector3, _n: Vector3, c: Color) -> Color:
		var vein := smoothstep(0.08, 0.0, absf(SpeciesModels.noise3(v * 7.0)))
		return c.lerp(Color(0.35, 0.06, 0.08), vein * 0.6)
	b.ellipsoid(throat_c, Vector3(0.4, 0.22, 0.5), &"jaw", K.WET_SKIN, Color(0.66, 0.22, 0.2), Color(0.8, 0.36, 0.3),
		14, Basis.IDENTITY, veins)
	# 이빨: 위턱은 바깥으로 비어져 아래로, 아래턱은 안쪽에서 위로. 앞쪽 넷째 아랫니는 크게 솟는다.
	for side: float in [-1.0, 1.0]:
		for k in 11:
			var t := float(k) / 10.0
			var z := lerpf(-2.95, -4.38, t)
			var width := _head_width(z)
			var big := 1.0 + 0.6 * float(k == 1 or k == 8)
			var up_base := Vector3(side * (width * 0.9 - 0.03), 0.83, z)
			b.cone(up_base, up_base + Vector3(side * 0.02, -0.13 * big - 0.03 * float(k % 2), -0.02), 0.035 * big, &"head",
				K.TEETH, Color(0.88, 0.84, 0.68), Vector3.ZERO, 6, Color(0.95, 0.93, 0.85))
			var lo_big := 1.0 + 0.9 * float(k == 7)
			var lo_base := Vector3(side * (width * 0.8 - 0.05), 0.82, z - 0.07)
			b.cone(lo_base, lo_base + Vector3(side * 0.03 * lo_big, (0.11 + 0.03 * float((k + 1) % 2)) * lo_big, -0.02),
				0.03 * lo_big, &"jaw", K.TEETH, Color(0.85, 0.8, 0.64), Vector3.ZERO, 6, Color(0.95, 0.93, 0.85))
		# 솟은 눈두덩과 노란 눈, 눈 위의 눈꺼풀 판, 눈 뒤의 비늘 돌기
		var eye := Vector3(side * 0.3, 1.19, -2.78)
		b.ellipsoid(eye + Vector3(0, -0.05, 0.02), Vector3(0.17, 0.12, 0.23), &"head", K.PLATED, top, top.lerp(bottom, 0.3), 12)
		_slit_eye(b, eye + Vector3(side * 0.05, 0.02, -0.06), 0.09, &"head", Vector3(side * 0.85, 0.35, -0.5),
			Color(0.78, 0.66, 0.16))
		b.ellipsoid(eye + Vector3(-side * 0.02, 0.07, 0.03), Vector3(0.14, 0.035, 0.12), &"head", K.PLATED, top.darkened(0.2),
			top.darkened(0.2), 8)
		for k in 3:
			_scute(b, Vector3(side * (0.22 + 0.08 * k), 1.07, -2.42 + 0.02 * k), Vector3(0.07, 0.05, 0.09), &"head",
				top.darkened(0.15))
		# 콧구멍
		b.ellipsoid(Vector3(side * 0.05, 1.08, -4.36), Vector3(0.035, 0.02, 0.04), &"head", K.WET_SKIN, Color(0.05, 0.04, 0.03))
	# 코끝의 솟은 콧등
	b.ellipsoid(Vector3(0, 1.04, -4.34), Vector3(0.15, 0.07, 0.13), &"head", K.PLATED, top, top, 12)
	# 목덜미의 큰 비늘판 무리
	for row in 3:
		for side: float in [-1.0, 1.0]:
			var z := -2.05 + row * 0.28
			_scute(b, Vector3(side * (0.16 + 0.04 * row), 1.27 + 0.02 * row, z), Vector3(0.13, 0.055, 0.14), &"neck",
				top.darkened(0.25))
	# 등의 비늘판: 몸통은 네 줄, 꼬리 밑동은 두 줄, 그 뒤는 한 줄의 톱니 볏
	var z0 := -1.35
	while z0 < 10.0:
		var bone_i := clampi(int(round((z0 + 1.2) / 1.15)), 0, SPINE_BONES - 1)
		var bone_name := StringName("spine%d" % bone_i)
		var r := _body_radius(z0, radii, spine_pts)
		var yb := _body_y(z0, spine_pts) + r.y * 0.97
		var shade := top.darkened(0.3)
		if z0 < 4.2:
			for side: float in [-1.0, 1.0]:
				for k in 2:
					var x := side * r.x * (0.14 + 0.28 * k)
					var drop := r.y * 0.12 * k
					var s := lerpf(1.0, 0.8, float(k)) * clampf(r.x / 1.0, 0.6, 1.0)
					_scute(b, Vector3(x, yb - drop, z0), Vector3(0.12 * s, 0.045 * s, 0.17 * s), bone_name, shade)
		elif z0 < 6.4:
			for side: float in [-1.0, 1.0]:
				_crest(b, Vector3(side * r.x * 0.32, yb - 0.01, z0), 0.2, 0.18, bone_name, shade)
		else:
			var h := lerpf(0.22, 0.08, clampf((z0 - 6.4) / 3.4, 0.0, 1.0))
			_crest(b, Vector3(0, yb - 0.01, z0), h * 1.1, h * 0.95, bone_name, shade)
		z0 += 0.42
	# --- 다리: 옆으로 벌어진 짧고 굵은 악어 다리. 뒷다리가 더 크다. ---
	_leg(b, &"spine1", 0, -0.2, 0.9, top, bottom)
	_leg(b, &"spine3", 2, 2.2 - b.bone_pos(&"spine3").z, 1.15, top, bottom)
	# --- 부착점 ---
	b.socket(&"head", &"head", Transform3D(Basis(), Vector3(0, 0.0, -1.0)))
	b.socket(&"throat", &"jaw", Transform3D(Basis(), throat_c - b.bone_pos(&"jaw")))
	b.socket(&"eye_l", &"head", Transform3D(Basis(), Vector3(-0.32, 0.28, -0.25)))
	b.socket(&"eye_r", &"head", Transform3D(Basis(), Vector3(0.32, 0.28, -0.25)))
	b.socket(&"mouth", &"head", Transform3D(Basis(), Vector3(0, -0.1, -2.0)))
	b.socket(&"back", &"spine2", Transform3D(Basis(), Vector3(0, 0.55, 0.3)))
	# 몸통·꼬리 피격 부위 자리(몸을 따라 물결친다)
	b.socket(&"chest", &"spine1", Transform3D(Basis(), Vector3(0, 0.0, 0.3)))
	b.socket(&"belly", &"spine3", Transform3D(Basis(), Vector3(0, 0.0, 0.3)))
	b.socket(&"tail", &"spine6", Transform3D(Basis(), Vector3(0, 0.0, 0.3)))
	b.socket(&"tail_tip", &"spine8", Transform3D(Basis(), Vector3(0, 0.0, 0.3)))
	return b


## 머리 폭(위턱 가장자리, 이빨 자리)
static func _head_width(z: float) -> float:
	var zs: Array[float] = [-2.3, -2.75, -3.2, -3.7, -4.1, -4.36, -4.52]
	var ws: Array[float] = [0.58, 0.62, 0.5, 0.4, 0.32, 0.31, 0.21]
	for i in zs.size() - 1:
		if z <= zs[i] and z >= zs[i + 1]:
			return lerpf(ws[i], ws[i + 1], (zs[i] - z) / (zs[i] - zs[i + 1]))
	return 0.2


## 몸통 관의 반지름(z에서 보간)
static func _body_radius(z: float, radii: Array[Vector2], pts: Array[Vector3]) -> Vector2:
	if z <= pts[0].z + 0.3:
		return radii[0]
	for i in pts.size() - 1:
		var za := pts[i].z + 0.3
		var zb := pts[i + 1].z + 0.3
		if z <= zb:
			return radii[i].lerp(radii[i + 1], clampf((z - za) / (zb - za), 0.0, 1.0))
	return radii[radii.size() - 1]


## 몸통 관의 중심 높이(z에서 보간)
static func _body_y(z: float, pts: Array[Vector3]) -> float:
	if z <= pts[0].z + 0.3:
		return pts[0].y
	for i in pts.size() - 1:
		var za := pts[i].z + 0.3
		var zb := pts[i + 1].z + 0.3
		if z <= zb:
			return lerpf(pts[i].y, pts[i + 1].y, clampf((z - za) / (zb - za), 0.0, 1.0))
	return pts[pts.size() - 1].y


## 파충류 눈: 노란 홍채에 세로로 찢어진 동공, 홍채 가장자리는 어둡고 결이 방사형으로 퍼진다.
static func _slit_eye(b: RigBuilder, center: Vector3, radius: float, bone_name: StringName, forward: Vector3, iris: Color) -> void:
	var f := forward.normalized()
	var basis := Basis.looking_at(-f, Vector3.UP)
	var fn := func(v: Vector3, _n: Vector3, _c: Color) -> Color:
		var d := (v - center) / radius
		var along := d.dot(f)
		if along < 0.2:
			return Color(0.06, 0.05, 0.03)
		var lx := d.dot(basis.x)
		var ly := d.dot(basis.y)
		# 세로 동공(가운데가 가장 넓다)
		if absf(lx) < 0.16 * sqrt(maxf(1.0 - ly * ly / 0.6, 0.0)):
			return Color(0.01, 0.01, 0.01)
		var rad := sqrt(lx * lx + ly * ly)
		var streak := 0.85 + 0.15 * sin(atan2(ly, lx) * 23.0)
		return iris.lerp(iris.darkened(0.7), smoothstep(0.55, 0.95, rad)) * streak
	b.ellipsoid(center, Vector3(radius, radius, radius), bone_name, K.EYE, Color(0.06, 0.05, 0.03), Color(0.06, 0.05, 0.03),
		14, basis, fn)


## 용골이 선 비늘판: 납작한 타원체의 위 가운데가 날카롭게 솟는다.
static func _scute(b: RigBuilder, center: Vector3, size: Vector3, bone_name: StringName, col: Color) -> void:
	var old := b.section
	b.section = func(th: float, _c: Vector3) -> float:
		var s := sin(th)
		return 1.0 + 1.5 * pow(s, 12.0) if s > 0.0 else 0.7
	b.ellipsoid(center, size, bone_name, K.HORN, col, col.darkened(0.2), 12)
	b.section = old


## 꼬리 볏: 옆으로 납작한 세모 판(끝이 뒤로 살짝 누운 톱니)
static func _crest(b: RigBuilder, base_pos: Vector3, height: float, length: float, bone_name: StringName, col: Color) -> void:
	var old := b.section
	b.section = func(th: float, _c: Vector3) -> float:
		return lerpf(0.28, 1.0, absf(sin(th)))
	b.cone(base_pos, base_pos + Vector3(0, height, length * 0.35), length * 0.5, bone_name, K.HORN, col, Vector3.ZERO, 8,
		col.lerp(Color(0.45, 0.42, 0.3), 0.5))
	b.section = old


## 다리 한 쌍: 어깨(엉덩이)에서 옆으로 뻗은 윗다리, 아래로 꺾인 아랫다리, 앞을 향해 벌어진 발가락과 발톱.
## first_index: 첫 다리 번호(leg0/leg1이 앞다리, leg2/leg3이 뒷다리), z_off: 붙는 뼈에서 앞뒤로 옮길 거리
static func _leg(b: RigBuilder, parent: StringName, first_index: int, z_off: float, size: float, top: Color,
		bottom: Color) -> void:
	var pz := b.bone_pos(parent).z + z_off
	var li := first_index
	for side: float in [-1.0, 1.0]:
		var up := StringName("leg%d_upper" % li)
		var lo := StringName("leg%d_lower" % li)
		var hip := Vector3(side * 0.72 * size, 0.62, pz)
		var knee := Vector3(side * 1.32 * size, 0.5, pz - 0.18 * size)
		var ankle := Vector3(side * 1.38 * size, 0.13, pz + 0.06)
		var foot := ankle + Vector3(side * 0.05, -0.07, -0.3 * size)
		b.bone(up, parent, hip)
		b.bone(lo, up, knee)
		var leg: Array[RigBuilder.P] = [
			RigBuilder.pt(hip - Vector3(side * 0.3, -0.02, 0), 0.34 * size, 0.36 * size, parent),
			RigBuilder.pt(hip, 0.29 * size, 0.31 * size, up),
			RigBuilder.pt((hip + knee) * 0.5, 0.25 * size, 0.25 * size, up),
			RigBuilder.pt(knee, 0.2 * size, 0.2 * size, lo),
			RigBuilder.pt(ankle + Vector3(0, 0.08, 0), 0.15 * size, 0.14 * size, lo),
			RigBuilder.pt(foot, 0.17 * size, 0.06 * size, lo),
		]
		b.loft(leg, K.PLATED, top, bottom, 14, 3, Vector3.FORWARD)
		# 발가락(앞으로 부챗살처럼)과 검은 발톱
		var toes := 5 if first_index == 0 else 4
		for c in toes:
			var spread := (float(c) - float(toes - 1) * 0.5) / float(toes - 1)
			var dir := Vector3(side * 0.35 + spread * 0.9, 0.0, -1.0).normalized()
			var base_p := foot + Vector3(spread * 0.18 * size, 0.0, -0.05)
			var tip := base_p + dir * 0.26 * size + Vector3(0, -0.04, 0)
			var toe: Array[RigBuilder.P] = [
				RigBuilder.pt(base_p, 0.06 * size, 0.045 * size, lo),
				RigBuilder.pt(base_p.lerp(tip, 0.6), 0.045 * size, 0.035 * size, lo),
				RigBuilder.pt(tip, 0.03 * size, 0.025 * size, lo),
			]
			b.loft(toe, K.PLATED, top, bottom, 8, 2, Vector3.UP)
			b.cone(tip - dir * 0.02, tip + dir * 0.1 * size + Vector3(0, -0.04, 0), 0.025 * size, lo, K.HORN,
				Color(0.12, 0.1, 0.08), Vector3(0, 0.02, 0), 6)
		li += 1

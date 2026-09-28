class_name BossModels
extends RefCounted
## 보스 모델. 늪턱 구렁: 악어의 머리·앞몸과 뱀의 긴 몸·꼬리를 가진 늪의 포식자(기획서 §16.1 퍼시 외곽권).
## 몸은 척추 사슬 뼈(spine0~spine9)를 따라 이어진 하나의 관이라, 뼈를 차례로 돌리면 뱀처럼 물결친다.

const K := CreatureMaterials.Kind
const SPINE_BONES := 10


## 늪턱 구렁: 길이 약 12m. 등은 이끼 낀 비늘판(골판), 배는 누런 비늘, 목 아래 턱살(약점)은 붉게 부풀어 있다.
static func mire_maw() -> RigBuilder:
	var b := RigBuilder.new()
	var top := Color(0.2, 0.22, 0.14)
	var bottom := Color(0.62, 0.56, 0.32)
	var moss := Color(0.24, 0.34, 0.14)
	var mot := SpeciesModels.mottle(0.18, 0.9)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col: Color = mot.call(v, n, c)
		# 등의 짙은 띠무늬(뱀 무늬)
		var band := smoothstep(0.55, 0.9, sin(v.z * 1.6 + SpeciesModels.noise3(v * 0.5) * 2.0))
		col = col.lerp(col.darkened(0.45), band * smoothstep(0.1, 0.7, n.y) * 0.8)
		# 등의 이끼
		var m := smoothstep(0.5, 0.9, n.y) * smoothstep(0.1, 0.5, SpeciesModels.noise3(v * 0.7 + Vector3(3, 1, 7)))
		return Color(col.lerp(moss, m * 0.7), c.a)
	# 척추 사슬: 머리(-Z) 쪽에서 꼬리(+Z) 쪽으로. 어깨(spine1)와 엉덩이(spine3)에 다리가 붙는다.
	var spine_pts: Array[Vector3] = []
	for i in SPINE_BONES:
		var z := -1.2 + float(i) * 1.15
		var y := 0.85 - clampf(float(i - 3) * 0.1, 0.0, 0.55)
		spine_pts.append(Vector3(0, y, z))
	b.bone(&"root", &"", Vector3(0, 0.85, 0.0))
	for i in SPINE_BONES:
		var parent := &"root" if i == 0 else StringName("spine%d" % (i - 1))
		b.bone(StringName("spine%d" % i), parent, spine_pts[i])
	b.bone(&"neck", &"spine0", Vector3(0, 0.95, -2.2))
	b.bone(&"head", &"neck", Vector3(0, 1.0, -3.0))
	b.bone(&"jaw", &"head", Vector3(0, 0.82, -3.2))
	# 몸통: 목 → 넓은 어깨 → 배 → 가늘어지는 뱀 몸 → 꼬리 끝
	var radii := [Vector2(0.62, 0.5), Vector2(0.95, 0.7), Vector2(1.0, 0.72), Vector2(0.92, 0.66), Vector2(0.78, 0.56),
		Vector2(0.64, 0.48), Vector2(0.5, 0.4), Vector2(0.38, 0.32), Vector2(0.26, 0.23), Vector2(0.14, 0.13)]
	var body: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.95, -2.35), 0.55, 0.48, &"neck"),
		RigBuilder.pt(Vector3(0, 0.92, -1.75), 0.66, 0.54, &"spine0"),
	]
	for i in SPINE_BONES:
		var r: Vector2 = radii[i]
		body.append(RigBuilder.pt(spine_pts[i] + Vector3(0, 0.0, 0.3), r.x, r.y, StringName("spine%d" % i)))
	b.loft(body, K.SCALE, top, bottom, 22, 4)
	# 등의 골판(돌기 비늘) 두 줄
	for i in range(0, SPINE_BONES - 2):
		var r: Vector2 = radii[i]
		var bone_name := StringName("spine%d" % i)
		for side: float in [-1.0, 1.0]:
			for k in 2:
				var c := spine_pts[i] + Vector3(side * r.x * 0.32, r.y * 0.92, 0.1 + k * 0.5)
				var s := r.x * 0.2
				b.ellipsoid(c, Vector3(s * 0.8, s * 0.55, s * 1.1), bone_name, K.HORN, top.darkened(0.2), top.darkened(0.45), 8)
	# 머리: 납작하고 긴 악어 주둥이, 위로 솟은 눈두덩, 콧구멍
	var hp := Vector3(0, 1.0, -3.0)
	var head: Array[RigBuilder.P] = [
		RigBuilder.pt(hp + Vector3(0, 0.0, 0.55), 0.6, 0.44, &"head"),
		RigBuilder.pt(hp + Vector3(0, 0.05, 0.0), 0.62, 0.36, &"head"),
		RigBuilder.pt(hp + Vector3(0, 0.0, -0.6), 0.44, 0.24, &"head"),
		RigBuilder.pt(hp + Vector3(0, -0.04, -1.2), 0.34, 0.17, &"head"),
		RigBuilder.pt(hp + Vector3(0, -0.02, -1.55), 0.3, 0.15, &"head"),
	]
	b.loft(head, K.SCALE, top, bottom.lerp(top, 0.4), 20, 4)
	var jaw: Array[RigBuilder.P] = [
		RigBuilder.pt(hp + Vector3(0, -0.28, 0.45), 0.55, 0.22, &"jaw"),
		RigBuilder.pt(hp + Vector3(0, -0.24, -0.3), 0.46, 0.14, &"jaw"),
		RigBuilder.pt(hp + Vector3(0, -0.22, -1.2), 0.32, 0.1, &"jaw"),
		RigBuilder.pt(hp + Vector3(0, -0.2, -1.52), 0.27, 0.09, &"jaw"),
	]
	b.loft(jaw, K.SCALE, bottom.lerp(top, 0.2), bottom, 18, 3)
	# 목 아래 턱살(약점): 붉게 부푼 주머니
	b.ellipsoid(hp + Vector3(0, -0.42, 0.6), Vector3(0.42, 0.26, 0.5), &"jaw", K.WET_SKIN, Color(0.62, 0.3, 0.26), Color(0.75, 0.42, 0.3))
	# 이빨: 위아래 턱을 따라 들쭉날쭉
	for side: float in [-1.0, 1.0]:
		for k in 9:
			var z := -0.05 - k * 0.16
			var width := lerpf(0.52, 0.28, float(k) / 8.0)
			var up_base := hp + Vector3(side * width * 0.92, -0.12, z)
			b.cone(up_base, up_base + Vector3(side * 0.02, -0.14 - 0.04 * (k % 2), -0.02), 0.035, &"head", K.TEETH,
				Color(0.86, 0.82, 0.66), Vector3.ZERO, 6)
			var lo_base := hp + Vector3(side * width * 0.85, -0.15, z - 0.08)
			b.cone(lo_base, lo_base + Vector3(side * 0.02, 0.12 + 0.04 * ((k + 1) % 2), -0.02), 0.03, &"jaw", K.TEETH,
				Color(0.84, 0.8, 0.64), Vector3.ZERO, 6)
		# 눈두덩과 노란 눈
		var eye := hp + Vector3(side * 0.36, 0.34, 0.2)
		b.ellipsoid(eye + Vector3(0, -0.02, 0), Vector3(0.16, 0.14, 0.2), &"head", K.SCALE, top)
		b.eye(eye + Vector3(side * 0.04, 0.05, -0.08), 0.085, &"head", Vector3(side * 0.8, 0.3, -0.6), Color(0.95, 0.75, 0.15),
			Color(0.55, 0.45, 0.12), 0.25, 1.4)
		b.ellipsoid(hp + Vector3(side * 0.1, 0.12, -1.5), Vector3(0.06, 0.04, 0.05), &"head", K.WET_SKIN, Color(0.08, 0.07, 0.05))
	# 다리 넷: 짧고 굵게 옆으로 벌어진 악어 다리
	var leg_spots := [[&"spine1", 0.9, -0.2], [&"spine3", 0.85, 0.1]]
	var li := 0
	for spot: Array in leg_spots:
		var parent: StringName = spot[0]
		var pz: float = b.bone_pos(parent).z + float(spot[2])
		for side: float in [-1.0, 1.0]:
			var up := StringName("leg%d_upper" % li)
			var lo := StringName("leg%d_lower" % li)
			var hip := Vector3(side * float(spot[1]) * 0.8, 0.6, pz)
			var knee := Vector3(side * 1.45, 0.55, pz - 0.15)
			var foot := Vector3(side * 1.55, 0.05, pz - 0.35)
			b.bone(up, parent, hip)
			b.bone(lo, up, knee)
			var leg: Array[RigBuilder.P] = [
				RigBuilder.pt(hip - Vector3(side * 0.25, 0, 0), 0.3, 0.3, parent),
				RigBuilder.pt(hip, 0.26, 0.28, up),
				RigBuilder.pt(knee, 0.2, 0.2, lo),
				RigBuilder.pt(foot + Vector3(0, 0.12, 0.05), 0.16, 0.14, lo),
				RigBuilder.pt(foot + Vector3(0, 0.02, -0.18), 0.2, 0.08, lo),
			]
			b.loft(leg, K.SCALE, top, bottom, 12, 3, Vector3.FORWARD)
			for c in 4:
				var cp := foot + Vector3(side * (-0.12 + 0.08 * c), 0.0, -0.3)
				b.cone(cp, cp + Vector3(side * 0.03, -0.04, -0.14), 0.03, lo, K.HORN, Color(0.15, 0.13, 0.1), Vector3.ZERO, 5)
			li += 1
	b.socket(&"head", &"head", Transform3D(Basis(), Vector3(0, 0.1, -0.6)))
	b.socket(&"throat", &"jaw", Transform3D(Basis(), hp + Vector3(0, -0.45, 0.6) - b.bone_pos(&"jaw")))
	b.socket(&"eye_l", &"head", Transform3D(Basis(), Vector3(-0.4, 0.38, 0.12)))
	b.socket(&"eye_r", &"head", Transform3D(Basis(), Vector3(0.4, 0.38, 0.12)))
	b.socket(&"back", &"spine2", Transform3D(Basis(), Vector3(0, 0.6, 0.0)))
	b.socket(&"mouth", &"head", Transform3D(Basis(), Vector3(0, -0.15, -1.3)))
	return b

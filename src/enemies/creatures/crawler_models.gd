class_name CrawlerModels
extends RefCounted
## 다리가 여럿인 생물(포자 식생체, 나무껍질 사마귀, 동굴 거미)과 날짐승(동굴 박쥐) 모델.
## 다리 뼈 이름: leg{i}_upper / leg{i}_lower (i: 왼0, 오0, 왼1, 오1 … 순서). 동작기의 CRAWLER 걸음이 쓴다.

const K := CreatureMaterials.Kind


## 다리 하나: 몸에서 옆으로 나와 무릎에서 꺾여 땅에 닿는다.
static func _leg(b: RigBuilder, i: int, hip: Vector3, knee: Vector3, foot: Vector3, r0: float, r1: float, kind: int,
		top: Color, bottom: Color, parent: StringName, tip_col := Color(0, 0, 0, 0)) -> void:
	var up := StringName("leg%d_upper" % i)
	var lo := StringName("leg%d_lower" % i)
	b.bone(up, parent, hip)
	b.bone(lo, up, knee)
	var pts: Array[RigBuilder.P] = [
		RigBuilder.pt(hip.lerp(knee, -0.15), r0 * 1.1, r0 * 1.1, parent),
		RigBuilder.pt(hip, r0, r0, up),
		RigBuilder.pt(hip.lerp(knee, 0.55), r0 * 0.85, r0 * 0.85, up),
		RigBuilder.pt(knee, r0 * 0.75, r0 * 0.75, lo),
		RigBuilder.pt(knee.lerp(foot, 0.6), r1, r1, lo),
		RigBuilder.pt(foot, r1 * 0.35, r1 * 0.35, lo),
	]
	var fn := Callable()
	if tip_col.a > 0.0:
		fn = func(v: Vector3, _n: Vector3, c: Color) -> Color:
			var t := clampf(inverse_lerp(knee.y, foot.y, v.y), 0.0, 1.0)
			return Color(c.lerp(tip_col, t * t), c.a)
	b.loft(pts, kind, top, bottom, 10, 3, Vector3.UP, true, true, fn)


# --- 포자 식생체 ---

## 포자 사수: 뿌리 다리 넷으로 걷는 큰 버섯. 붉은 갈색 갓의 흰 점, 줄무늬 자루, 갓 뒤의 포자 주머니(따로 붙인다).
static func spore_walker() -> RigBuilder:
	var b := RigBuilder.new()
	var stalk_top := Color(0.72, 0.64, 0.5)
	var stalk_bottom := Color(0.5, 0.42, 0.32)
	var mot := SpeciesModels.mottle(0.12, 5.0)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		return Color((mot.call(v, n, c) as Color), c.a)
	b.bone(&"root", &"", Vector3(0, 0.45, 0))
	b.bone(&"body", &"root", Vector3(0, 0.85, 0))
	b.bone(&"head", &"body", Vector3(0, 1.2, 0))
	b.bone(&"jaw", &"head", Vector3(0, 1.05, -0.28))
	# 자루: 세로 줄무늬
	var stalk: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.25, 0), 0.38, 0.36, &"root"),
		RigBuilder.pt(Vector3(0, 0.55, 0), 0.33, 0.32, &"root"),
		RigBuilder.pt(Vector3(0, 0.85, 0), 0.29, 0.28, &"body"),
		RigBuilder.pt(Vector3(0, 1.12, 0), 0.31, 0.3, &"head"),
	]
	b.loft(stalk, K.SPORE, stalk_top, stalk_bottom, 20, 4, Vector3.FORWARD, true, false,
		func(v: Vector3, _n: Vector3, c: Color) -> Color:
			var ang := atan2(v.x, v.z)
			var streak := 0.85 + 0.15 * sin(ang * 14.0 + SpeciesModels.noise3(v * 4.0) * 2.0)
			return Color(c.r * streak, c.g * streak, c.b * streak, c.a))
	# 갓 아래 주름(어둡다)
	b.ellipsoid(Vector3(0, 1.14, 0), Vector3(0.56, 0.05, 0.56), &"head", K.SPORE, Color(0.28, 0.2, 0.16), Color(0, 0, 0, 0), 22,
		Basis(Vector3.RIGHT, PI * 0.5),
		func(v: Vector3, _n: Vector3, c: Color) -> Color:
			var ang := atan2(v.x, v.z)
			return Color(c * (0.7 + 0.3 * absf(sin(ang * 24.0))), c.a))
	# 갓: 넓게 덮인 반구, 흰 점무늬
	var cap_col := Color(0.55, 0.2, 0.12)
	var cap: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 1.16, 0), 0.6, 0.6, &"head"),
		RigBuilder.pt(Vector3(0, 1.28, 0), 0.64, 0.64, &"head"),
		RigBuilder.pt(Vector3(0, 1.42, 0), 0.54, 0.54, &"head"),
		RigBuilder.pt(Vector3(0, 1.52, 0), 0.3, 0.3, &"head"),
	]
	b.loft(cap, K.SPORE, cap_col, cap_col.darkened(0.3), 24, 4, Vector3.FORWARD, false, true,
		func(v: Vector3, _n: Vector3, c: Color) -> Color:
			var spot := smoothstep(0.42, 0.5, SpeciesModels.noise3(v * 7.0 + Vector3(1, 7, 3)))
			return Color(c.lerp(Color(0.92, 0.88, 0.76), spot), c.a))
	# 입과 눈
	b.ellipsoid(Vector3(0, 1.02, -0.29), Vector3(0.14, 0.03, 0.04), &"jaw", K.SPORE, Color(0.12, 0.06, 0.04))
	for side: float in [-1.0, 1.0]:
		b.ellipsoid(Vector3(side * 0.11, 1.12, -0.27), Vector3(0.035, 0.03, 0.02), &"head", K.GLOW, Color(1.0, 0.85, 0.3))
	# 뿌리 다리 넷
	var i := 0
	for zside: float in [-1.0, 1.0]:
		for side: float in [-1.0, 1.0]:
			var hip := Vector3(side * 0.24, 0.35, zside * 0.18)
			var knee := Vector3(side * 0.55, 0.32, zside * 0.42)
			var foot := Vector3(side * 0.72, 0.0, zside * 0.58)
			_leg(b, i, hip, knee, foot, 0.1, 0.06, K.WOOD, Color(0.4, 0.3, 0.22), Color(0.3, 0.22, 0.16), &"root",
				Color(0.2, 0.15, 0.1))
			i += 1
	b.socket(&"sac", &"head", Transform3D(Basis(), Vector3(0, 0.42, 0.12)))
	b.socket(&"head", &"head", Transform3D(Basis(), Vector3(0, 0.05, 0)))
	return b


## 부푼 포자낭: 땅에 박힌 부푼 주머니. 가까이 가면 부풀어 터진다.
static func bloat_pod() -> RigBuilder:
	var b := RigBuilder.new()
	var skin := Color(0.62, 0.58, 0.3)
	var mot := SpeciesModels.mottle(0.15, 6.0)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col: Color = mot.call(v, n, c)
		# 주황 핏줄
		var vein := smoothstep(0.08, 0.0, absf(SpeciesModels.noise3(v * 9.0)))
		return Color(col.lerp(Color(0.9, 0.42, 0.12), vein * 0.8), c.a)
	b.bone(&"root", &"", Vector3(0, 0.0, 0))
	b.bone(&"body", &"root", Vector3(0, 0.4, 0))
	var bulb: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.05, 0), 0.3, 0.3, &"root"),
		RigBuilder.pt(Vector3(0, 0.32, 0), 0.47, 0.47, &"body"),
		RigBuilder.pt(Vector3(0, 0.62, 0), 0.4, 0.4, &"body"),
		RigBuilder.pt(Vector3(0, 0.84, 0), 0.14, 0.14, &"body"),
		RigBuilder.pt(Vector3(0, 0.92, 0), 0.1, 0.1, &"body"),
	]
	b.loft(bulb, K.SPORE, skin, skin.darkened(0.25), 22, 4, Vector3.FORWARD, true, false)
	b.ellipsoid(Vector3(0, 0.93, 0), Vector3(0.08, 0.03, 0.08), &"body", K.GLOW, Color(1.0, 0.55, 0.15), Color(0, 0, 0, 0), 12,
		Basis(Vector3.RIGHT, PI * 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var c := Vector3(cos(a) * 0.36, 0.45 + rng.randf_range(-0.1, 0.12), sin(a) * 0.36)
		b.ellipsoid(c, Vector3(0.05, 0.05, 0.05), &"body", K.GLOW, Color(1.0, 0.6, 0.2))
	for i in 6:
		var a := TAU * float(i) / 6.0
		var base_p := Vector3(cos(a) * 0.25, 0.08, sin(a) * 0.25)
		b.cone(base_p, base_p + Vector3(cos(a) * 0.4, -0.08, sin(a) * 0.4), 0.05, &"root", K.WOOD, Color(0.35, 0.28, 0.18),
			Vector3(0, 0.06, 0), 6)
	b.socket(&"core", &"body", Transform3D(Basis(), Vector3(0, 0.1, 0)))
	return b


## 포자 모체: 여러 갈래 갓이 핵을 감싼 큰 균체. 숨을 쉴 때 갓이 벌어져 핵이 드러난다.
static func spore_mother() -> RigBuilder:
	var b := RigBuilder.new()
	var body_col := Color(0.42, 0.3, 0.36)
	var mot := SpeciesModels.mottle(0.14, 3.0)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		return Color((mot.call(v, n, c) as Color), c.a)
	b.bone(&"root", &"", Vector3(0, 0.0, 0))
	b.bone(&"body", &"root", Vector3(0, 0.9, 0))
	var mass: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.1, 0), 1.1, 1.1, &"root"),
		RigBuilder.pt(Vector3(0, 0.55, 0), 1.15, 1.15, &"body"),
		RigBuilder.pt(Vector3(0, 1.1, 0), 0.8, 0.8, &"body"),
		RigBuilder.pt(Vector3(0, 1.5, 0), 0.45, 0.45, &"body"),
	]
	b.loft(mass, K.SPORE, body_col, body_col.darkened(0.3), 26, 4, Vector3.FORWARD, true, false)
	# 갓 다섯 갈래: 가운데를 감싼 꽃잎처럼 선다(뼈를 돌려 벌린다).
	for i in 5:
		var a := TAU * float(i) / 5.0
		var dirv := Vector3(sin(a), 0, cos(a))
		var bone_name := StringName("petal%d" % i)
		var base_p := Vector3(0, 1.3, 0) + dirv * 0.38
		b.bone(bone_name, &"body", base_p)
		var petal: Array[RigBuilder.P] = [
			RigBuilder.pt(base_p, 0.32, 0.12, bone_name),
			RigBuilder.pt(base_p + dirv * 0.15 + Vector3(0, 0.55, 0), 0.42, 0.1, bone_name),
			RigBuilder.pt(base_p - dirv * 0.05 + Vector3(0, 1.05, 0), 0.28, 0.07, bone_name),
			RigBuilder.pt(base_p - dirv * 0.25 + Vector3(0, 1.3, 0), 0.06, 0.04, bone_name),
		]
		var petal_col := Color(0.55, 0.26, 0.38)
		b.loft(petal, K.SPORE, petal_col, petal_col.darkened(0.3), 14, 3, dirv, true, true,
			func(v: Vector3, _n: Vector3, c: Color) -> Color:
				var spot := smoothstep(0.4, 0.5, SpeciesModels.noise3(v * 6.0 + Vector3(0, 3, 0)))
				return Color(c.lerp(Color(0.95, 0.8, 0.5), spot * 0.8), c.a))
	# 몸 둘레의 작은 포자낭과 뿌리
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 9:
		var a := rng.randf() * TAU
		var h := rng.randf_range(0.2, 0.9)
		var c := Vector3(sin(a) * 1.05, h, cos(a) * 1.05)
		b.ellipsoid(c, Vector3.ONE * rng.randf_range(0.12, 0.2), &"body", K.SPORE, Color(0.62, 0.56, 0.3))
		b.ellipsoid(c + Vector3(sin(a), 0.2, cos(a)) * 0.1, Vector3.ONE * 0.05, &"body", K.GLOW, Color(1.0, 0.6, 0.2))
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		var base_p := Vector3(sin(a) * 0.9, 0.12, cos(a) * 0.9)
		b.cone(base_p, base_p + Vector3(sin(a), 0, cos(a)) * 0.9 + Vector3(0, -0.12, 0), 0.14, &"root", K.WOOD,
			Color(0.3, 0.22, 0.2), Vector3(0, 0.15, 0), 8)
	b.socket(&"core", &"body", Transform3D(Basis(), Vector3(0, 0.75, 0)))
	b.socket(&"mouth", &"body", Transform3D(Basis(), Vector3(0, 1.0, 0)))
	return b


# --- 나무껍질 사마귀 ---

## 나무껍질 사마귀: 나무껍질 무늬 껍질, 긴 앞가슴과 삼각 머리, 큰 겹눈, 낫처럼 접힌 앞다리 둘, 걷는 다리 넷, 접은 날개.
static func bark_mantis() -> RigBuilder:
	var b := RigBuilder.new()
	var bark := Color(0.46, 0.39, 0.3)
	var bark_dark := Color(0.28, 0.23, 0.17)
	var lichen := Color(0.45, 0.52, 0.34)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		# 나무껍질 줄무늬와 이끼 얼룩
		var grain := 0.8 + 0.2 * sin(v.y * 40.0 + SpeciesModels.noise3(v * 5.0) * 4.0)
		var col := Color(c.r * grain, c.g * grain, c.b * grain)
		var moss := smoothstep(0.35, 0.55, SpeciesModels.noise3(v * 4.0 + Vector3(5, 5, 5)))
		return Color(col.lerp(lichen, moss * 0.55), c.a)
	b.bone(&"root", &"", Vector3(0, 0.62, 0.05))
	b.bone(&"abdomen", &"root", Vector3(0, 0.66, 0.35))
	b.bone(&"chest", &"root", Vector3(0, 0.72, -0.2))
	b.bone(&"neck", &"chest", Vector3(0, 0.95, -0.35))
	b.bone(&"head", &"neck", Vector3(0, 1.45, -0.5))
	b.bone(&"jaw", &"head", Vector3(0, 1.4, -0.62))
	# 배(뒤로 길게), 가슴, 긴 앞가슴(세운 목)
	var abdomen: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.66, 0.1), 0.14, 0.12, &"root"),
		RigBuilder.pt(Vector3(0, 0.7, 0.4), 0.2, 0.16, &"abdomen"),
		RigBuilder.pt(Vector3(0, 0.66, 0.75), 0.16, 0.13, &"abdomen"),
		RigBuilder.pt(Vector3(0, 0.6, 1.0), 0.06, 0.06, &"abdomen"),
	]
	b.loft(abdomen, K.WOOD, bark, bark_dark, 16, 4, Vector3.UP, true, true,
		func(v: Vector3, _n: Vector3, c: Color) -> Color:
			var seg := 0.85 + 0.15 * smoothstep(0.6, 1.0, sin(v.z * 38.0))
			return Color(c.r * seg, c.g * seg, c.b * seg, c.a))
	var thorax: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.68, 0.12), 0.12, 0.11, &"root"),
		RigBuilder.pt(Vector3(0, 0.72, -0.18), 0.11, 0.12, &"chest"),
		RigBuilder.pt(Vector3(0, 0.95, -0.34), 0.08, 0.08, &"neck"),
		RigBuilder.pt(Vector3(0, 1.25, -0.44), 0.065, 0.065, &"neck"),
		RigBuilder.pt(Vector3(0, 1.4, -0.48), 0.07, 0.07, &"head"),
	]
	b.loft(thorax, K.WOOD, bark, bark_dark, 14, 4)
	# 삼각 머리와 큰 겹눈
	b.ellipsoid(Vector3(0, 1.47, -0.52), Vector3(0.14, 0.09, 0.08), &"head", K.WOOD, bark.lightened(0.1), bark_dark)
	b.cone(Vector3(0, 1.44, -0.56), Vector3(0, 1.34, -0.66), 0.05, &"jaw", K.WOOD, bark_dark, Vector3.ZERO, 8)
	for side: float in [-1.0, 1.0]:
		b.eye(Vector3(side * 0.13, 1.5, -0.54), 0.05, &"head", Vector3(side, 0.2, -0.5), Color(0.45, 0.5, 0.2), Color(0.35, 0.4, 0.15),
			0.15, 1.6)
		b.cone(Vector3(side * 0.04, 1.55, -0.58), Vector3(side * 0.18, 1.85, -0.7), 0.008, &"head", K.WOOD, bark_dark,
			Vector3(side * 0.02, 0.03, 0.05), 5)
	# 접은 날개(나뭇잎처럼)
	for side: float in [-1.0, 1.0]:
		var wing: Array[RigBuilder.P] = [
			RigBuilder.pt(Vector3(side * 0.06, 0.82, -0.05), 0.08, 0.015, &"root"),
			RigBuilder.pt(Vector3(side * 0.1, 0.84, 0.35), 0.13, 0.015, &"abdomen"),
			RigBuilder.pt(Vector3(side * 0.07, 0.78, 0.78), 0.06, 0.012, &"abdomen"),
		]
		b.loft(wing, K.SKIN_THIN, Color(0.4, 0.42, 0.26), Color(0.32, 0.3, 0.2), 10, 3, Vector3.UP, true, true,
			func(v: Vector3, _n: Vector3, c: Color) -> Color:
				var vein := smoothstep(0.02, 0.0, absf(fmod(v.z * 12.0, 1.0) - 0.5) * 0.1)
				return Color(c.darkened(vein * 0.3), c.a))
	# 낫 다리(앞다리): 위팔(넓적다리)은 앞으로, 아래팔(낫)은 접혀 가슴 앞에
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var up := StringName("arm_upper_" + sn)
		var lo := StringName("arm_lower_" + sn)
		var sh := Vector3(side * 0.07, 1.22, -0.44)
		var el := Vector3(side * 0.14, 1.05, -0.72)
		var tip := Vector3(side * 0.12, 1.32, -0.62)
		b.bone(up, &"neck", sh)
		b.bone(lo, up, el)
		var femur: Array[RigBuilder.P] = [
			RigBuilder.pt(sh, 0.05, 0.05, up),
			RigBuilder.pt(sh.lerp(el, 0.5), 0.05, 0.075, up),
			RigBuilder.pt(el, 0.04, 0.05, lo),
		]
		b.loft(femur, K.WOOD, bark, bark_dark, 10, 3, Vector3.FORWARD)
		var blade: Array[RigBuilder.P] = [
			RigBuilder.pt(el, 0.035, 0.045, lo),
			RigBuilder.pt(el.lerp(tip, 0.5), 0.025, 0.05, lo),
			RigBuilder.pt(tip, 0.012, 0.02, lo),
		]
		b.loft(blade, K.WOOD, bark_dark, bark_dark, 10, 3, Vector3.FORWARD)
		# 낫 안쪽의 가시
		for k in 4:
			var tp := el.lerp(tip, 0.2 + 0.2 * k)
			b.cone(tp, tp + Vector3(0, -0.02, -0.05), 0.008, lo, K.HORN, Color(0.75, 0.7, 0.55), Vector3.ZERO, 5)
	# 걷는 다리 넷
	var i := 0
	for zi in 2:
		for side: float in [-1.0, 1.0]:
			var z := -0.12 + 0.2 * zi
			var hip := Vector3(side * 0.08, 0.66, z)
			var knee := Vector3(side * 0.42, 0.75, z + (-0.1 if zi == 0 else 0.15))
			var foot := Vector3(side * 0.62, 0.0, z + (-0.2 if zi == 0 else 0.35))
			_leg(b, i, hip, knee, foot, 0.025, 0.018, K.WOOD, bark, bark_dark, &"chest" if zi == 0 else &"root")
			i += 1
	b.socket(&"head", &"head", Transform3D(Basis(), Vector3(0, 0.03, -0.04)))
	b.socket(&"blade_l", &"arm_lower_l", Transform3D(Basis(), Vector3(0.0, 0.1, 0.05)))
	b.socket(&"blade_r", &"arm_lower_r", Transform3D(Basis(), Vector3(0.0, 0.1, 0.05)))
	return b


# --- 동굴 거미 ---

## 동굴 거미: 털 난 큰 배, 반들거리는 머리가슴, 여덟 개의 붉은 눈, 엄니, 마디진 다리 여덟.
static func cave_spider() -> RigBuilder:
	var b := RigBuilder.new()
	b.fur_length = 0.018
	b.fur_density = 14.0
	var shell := Color(0.16, 0.13, 0.11)
	var hair := Color(0.22, 0.18, 0.15)
	var band := Color(0.55, 0.35, 0.18)
	var mot := SpeciesModels.mottle(0.12, 8.0)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		return Color((mot.call(v, n, c) as Color), c.a)
	b.bone(&"root", &"", Vector3(0, 0.55, 0))
	b.bone(&"chest", &"root", Vector3(0, 0.55, -0.1))
	b.bone(&"abdomen", &"root", Vector3(0, 0.62, 0.35))
	b.bone(&"head", &"chest", Vector3(0, 0.55, -0.32))
	b.bone(&"jaw", &"head", Vector3(0, 0.46, -0.45))
	var ceph: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.55, 0.05), 0.2, 0.13, &"chest"),
		RigBuilder.pt(Vector3(0, 0.58, -0.15), 0.24, 0.15, &"chest"),
		RigBuilder.pt(Vector3(0, 0.56, -0.35), 0.16, 0.12, &"head"),
	]
	b.loft(ceph, K.CHITIN, shell.lightened(0.1), shell, 18, 4)
	var abd: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.6, 0.12), 0.14, 0.13, &"abdomen"),
		RigBuilder.pt(Vector3(0, 0.68, 0.38), 0.32, 0.28, &"abdomen"),
		RigBuilder.pt(Vector3(0, 0.64, 0.66), 0.26, 0.24, &"abdomen"),
	]
	b.loft(abd, K.FUR, hair, hair.darkened(0.3), 20, 4, Vector3.UP, true, true,
		func(v: Vector3, n: Vector3, c: Color) -> Color:
			# 등의 주황 줄무늬
			var stripe := smoothstep(0.02, 0.0, absf(absf(v.x) - 0.1)) * smoothstep(0.3, 0.8, n.y)
			return Color(c.lerp(band, stripe * 0.8), c.a))
	# 여덟 눈(두 줄)
	for k in 8:
		var row := k / 4
		var col := (k % 4) - 1.5
		var ep := Vector3(col * 0.05, 0.64 - row * 0.04, -0.47 + absf(col) * 0.02)
		b.ellipsoid(ep, Vector3.ONE * (0.022 if absf(col) < 1.0 else 0.015), &"head", K.EYE, Color(0.55, 0.05, 0.03))
	# 엄니
	for side: float in [-1.0, 1.0]:
		var fb := Vector3(side * 0.06, 0.48, -0.47)
		b.ellipsoid(fb, Vector3(0.045, 0.06, 0.045), &"jaw", K.FUR, hair)
		b.cone(fb + Vector3(0, -0.04, -0.02), fb + Vector3(-side * 0.03, -0.14, -0.04), 0.02, &"jaw", K.HORN, Color(0.1, 0.08, 0.07),
			Vector3(0, 0, -0.02), 6, Color(0.55, 0.1, 0.08))
	# 다리 여덟: 앞 두 쌍은 앞으로, 뒤 두 쌍은 뒤로 뻗는다.
	var angles := [-60.0, -25.0, 15.0, 50.0]
	var i := 0
	for k in 4:
		for side: float in [-1.0, 1.0]:
			var a := deg_to_rad(float(angles[k]))
			var outv := Vector3(side * cos(a), 0, sin(a))
			var hip := Vector3(side * 0.16, 0.56, -0.2 + 0.1 * k)
			var knee := hip + outv * 0.55 + Vector3(0, 0.38, 0)
			var foot := hip + outv * 1.05 + Vector3(0, -0.56, 0)
			_leg(b, i, hip, knee, foot, 0.035, 0.025, K.CHITIN, shell, shell.darkened(0.2), &"chest", band.darkened(0.3))
			i += 1
	b.socket(&"head", &"head", Transform3D(Basis(), Vector3(0, 0.02, -0.08)))
	b.socket(&"mouth", &"jaw", Transform3D(Basis(), Vector3(0, -0.05, -0.05)))
	return b


# --- 동굴 박쥐 ---

## 동굴 박쥐: 털 난 작은 몸, 큰 귀, 손가락 뼈 사이에 막을 친 날개. 원점은 몸 가운데다(날아다닌다).
static func cave_bat() -> RigBuilder:
	var b := RigBuilder.new()
	b.fur_length = 0.012
	b.fur_density = 16.0
	var fur := Color(0.3, 0.24, 0.2)
	var belly := Color(0.42, 0.34, 0.28)
	var membrane := Color(0.16, 0.12, 0.11)
	b.bone(&"root", &"", Vector3(0, 0, 0))
	b.bone(&"chest", &"root", Vector3(0, 0.02, -0.06))
	b.bone(&"head", &"chest", Vector3(0, 0.05, -0.16))
	b.bone(&"jaw", &"head", Vector3(0, 0.02, -0.23))
	b.bone(&"ear_l", &"head", Vector3(-0.04, 0.1, -0.16))
	b.bone(&"ear_r", &"head", Vector3(0.04, 0.1, -0.16))
	var body: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, -0.01, 0.14), 0.05, 0.05, &"root"),
		RigBuilder.pt(Vector3(0, 0.0, 0.04), 0.09, 0.085, &"root"),
		RigBuilder.pt(Vector3(0, 0.02, -0.08), 0.085, 0.08, &"chest"),
		RigBuilder.pt(Vector3(0, 0.04, -0.15), 0.06, 0.06, &"head"),
	]
	b.loft(body, K.FUR, fur, belly, 16, 4)
	var head: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.05, -0.14), 0.055, 0.055, &"head"),
		RigBuilder.pt(Vector3(0, 0.05, -0.2), 0.05, 0.048, &"head"),
		RigBuilder.pt(Vector3(0, 0.035, -0.25), 0.028, 0.025, &"head"),
	]
	b.loft(head, K.FUR, fur, belly, 14, 3)
	b.ellipsoid(Vector3(0, 0.035, -0.263), Vector3(0.018, 0.014, 0.01), &"head", K.WET_SKIN, Color(0.25, 0.16, 0.15))
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.eye(Vector3(side * 0.028, 0.06, -0.235), 0.009, &"head", Vector3(side * 0.5, 0.1, -1.0), Color(0.1, 0.06, 0.05),
			Color(0.05, 0.03, 0.03), 0.6, 1.2)
		var eb := b.bone_pos(StringName("ear_" + sn))
		var ear: Array[RigBuilder.P] = [
			RigBuilder.pt(eb, 0.03, 0.008, StringName("ear_" + sn)),
			RigBuilder.pt(eb + Vector3(side * 0.03, 0.06, 0.01), 0.032, 0.006, StringName("ear_" + sn)),
			RigBuilder.pt(eb + Vector3(side * 0.04, 0.11, 0.02), 0.004, 0.004, StringName("ear_" + sn)),
		]
		b.loft(ear, K.SKIN_THIN, membrane.lightened(0.15), membrane, 10, 3, Vector3.BACK)
		b.cone(Vector3(side * 0.012, 0.0, -0.25), Vector3(side * 0.012, -0.03, -0.252), 0.005, &"jaw", K.TEETH, Color(0.92, 0.9, 0.82))
		# 날개: 위팔 → 아래팔 → 손가락 셋, 뼈 사이를 막으로 채운다.
		var up := StringName("wing_upper_" + sn)
		var lo := StringName("wing_lower_" + sn)
		var sh := Vector3(side * 0.07, 0.04, -0.07)
		var el := Vector3(side * 0.3, 0.07, -0.02)
		var wr := Vector3(side * 0.55, 0.05, 0.04)
		b.bone(up, &"chest", sh)
		b.bone(lo, up, el)
		var arm: Array[RigBuilder.P] = [
			RigBuilder.pt(sh, 0.02, 0.02, up),
			RigBuilder.pt(el, 0.012, 0.012, lo),
			RigBuilder.pt(wr, 0.009, 0.009, lo),
		]
		b.loft(arm, K.SKIN, membrane.lightened(0.1), membrane, 8, 3, Vector3.UP)
		var tips := [Vector3(side * 0.85, 0.02, 0.0), Vector3(side * 0.78, 0.0, 0.2), Vector3(side * 0.55, -0.01, 0.3)]
		for t: Vector3 in tips:
			b.cone(wr, t, 0.007, lo, K.SKIN, membrane.lightened(0.1), Vector3.ZERO, 5)
		# 막: 몸 옆에서 손가락 끝까지 얇은 판 두 장
		var mem1: Array[RigBuilder.P] = [
			RigBuilder.pt(Vector3(side * 0.08, 0.0, 0.05), 0.02, 0.004, &"root"),
			RigBuilder.pt(el.lerp(Vector3(side * 0.3, 0.0, 0.22), 0.5), 0.13, 0.004, up),
			RigBuilder.pt(wr.lerp(tips[2], 0.5), 0.12, 0.004, lo),
			RigBuilder.pt(tips[1], 0.03, 0.003, lo),
		]
		b.loft(mem1, K.SKIN_THIN, membrane, membrane, 8, 3, Vector3.UP)
		var mem2: Array[RigBuilder.P] = [
			RigBuilder.pt(wr, 0.02, 0.004, lo),
			RigBuilder.pt(wr.lerp(tips[0], 0.5) + Vector3(0, 0, 0.06), 0.08, 0.004, lo),
			RigBuilder.pt(tips[0].lerp(tips[1], 0.5), 0.04, 0.003, lo),
		]
		b.loft(mem2, K.SKIN_THIN, membrane, membrane, 8, 3, Vector3.UP)
		# 늘어진 뒷발
		b.cone(Vector3(side * 0.04, -0.03, 0.12), Vector3(side * 0.05, -0.1, 0.16), 0.012, &"root", K.SKIN, membrane, Vector3.ZERO, 5)
	b.socket(&"head", &"head", Transform3D(Basis(), Vector3(0, 0.0, -0.05)))
	b.socket(&"mouth", &"jaw", Transform3D(Basis(), Vector3(0, -0.02, -0.03)))
	return b

class_name RockKit
extends RefCounted
## 바위(기획서 §23.1 사실적 재질): 매끈하게 깎인 바위 덩이를 돌 결 재질(물체 공간 삼면 투영 법선)로 만든다.
## 윗면에는 이끼가 앉고, 땅에 묻힌 아랫부분은 짙다. 구렁의 돌기둥도 같은 방식으로 만든다.

const ROCK := Color(0.42, 0.4, 0.36)
const MOSS := Color(0.26, 0.34, 0.14)


## 바위 덩이(원점이 밑면 가운데, 대략 반지름 1m). flat: 납작한 정도(1이면 둥글다)
static func boulder(seed_value: int, flat: float = 0.62) -> Mesh:
	var b := RigBuilder.new()
	b.bone(&"root", &"", Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var seed_off := Vector3(float(seed_value) * 0.71, float(seed_value) * 0.13, float(seed_value) * 0.37)
	var height := 1.0 * flat * rng.randf_range(0.85, 1.15)
	var pts: Array[RigBuilder.P] = []
	var steps := 6
	for i in steps:
		var t := float(i) / float(steps - 1)
		var y := lerpf(-0.35, height, t)
		# 아래는 넓고 위로 둥글게 좁아진다.
		var r := sqrt(maxf(1.0 - pow(t, 2.2), 0.02)) * rng.randf_range(0.9, 1.1)
		pts.append(RigBuilder.pt(Vector3(rng.randf_range(-0.08, 0.08), y, rng.randf_range(-0.08, 0.08)), r,
			r * rng.randf_range(0.75, 1.0), &"root"))
	b.section = func(th: float, c: Vector3) -> float:
		var q := Vector3(cos(th) * 1.3, c.y * 1.6, sin(th) * 1.3) + seed_off
		return 1.0 + 0.24 * SpeciesModels.noise3(q) + 0.08 * SpeciesModels.noise3(q * 3.3)
	b.loft(pts, CreatureMaterials.Kind.STONE, ROCK, ROCK.darkened(0.25), 16, 3, Vector3.BACK, false, true, _paint(seed_off))
	b.section = Callable()
	return b.build().mesh


## 구렁의 돌기둥: 물에 깎여 울퉁불퉁한 바위 기둥. 물 높이 아래는 젖어 짙고, 윗면에는 이끼가 앉았다.
static func pillar(seed_value: int, height: float, radius: float) -> Mesh:
	var b := RigBuilder.new()
	b.bone(&"root", &"", Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts: Array[RigBuilder.P] = []
	var steps := 8
	var lean := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
	for i in steps:
		var t := float(i) / float(steps - 1)
		var y := lerpf(-1.4, height, t)
		var r := lerpf(radius * 1.12, radius * 0.72, t) * rng.randf_range(0.9, 1.1)
		pts.append(RigBuilder.pt(Vector3(0, y, 0) + lean * t * t, r, r * rng.randf_range(0.85, 1.1), &"root"))
	var seed_off := Vector3(float(seed_value) * 0.37, 0.0, float(seed_value) * 0.11)
	b.section = func(th: float, c: Vector3) -> float:
		var q := Vector3(cos(th) * 1.6, c.y * 0.45, sin(th) * 1.6) + seed_off
		return 1.0 + 0.2 * SpeciesModels.noise3(q) + 0.07 * SpeciesModels.noise3(q * 3.1)
	var paint := func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col := c
		# 결을 따라 층진 바위
		col = col.darkened(0.12 * (0.5 + 0.5 * sin(v.y * 5.0 + SpeciesModels.noise3(v * 0.8) * 2.0)))
		# 물에 잠겼던 아랫부분은 짙고 미끈하다
		col = col.lerp(Color(0.16, 0.15, 0.11), smoothstep(0.9, 0.1, v.y) * 0.8)
		# 윗면과 틈의 이끼
		var moss := smoothstep(0.35, 0.85, n.y) + smoothstep(0.2, 0.6, SpeciesModels.noise3(v * 1.3 + seed_off)) * 0.35
		col = col.lerp(MOSS.darkened(0.05), clampf(moss, 0.0, 1.0) * 0.75)
		return Color(col, c.a)
	b.loft(pts, CreatureMaterials.Kind.STONE, ROCK, ROCK.darkened(0.25), 20, 3, Vector3.BACK, true, true, paint)
	b.section = Callable()
	BeastModels.rock_lumps(b, &"root", Vector3(0, -0.1, 0), 5, 0.55, rng, 0.8, ROCK.darkened(0.1))
	return b.build().mesh


## 바위 무늬: 갈라진 금, 윗면의 이끼, 땅에 묻힌 아랫부분의 흙물
static func _paint(seed_off: Vector3) -> Callable:
	return func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col := c
		var crack := smoothstep(0.06, 0.0, absf(SpeciesModels.noise3(v * 2.6 + seed_off)))
		col = col.darkened(crack * 0.45)
		col = col.darkened(0.1 * SpeciesModels.noise3(v * 1.1 + seed_off))
		var moss := smoothstep(0.45, 0.9, n.y) * smoothstep(-0.1, 0.45, SpeciesModels.noise3(v * 1.4 + seed_off * 1.7))
		col = col.lerp(MOSS, moss * 0.8)
		col = col.lerp(Color(0.24, 0.21, 0.16), smoothstep(0.15, -0.2, v.y) * 0.7)
		return Color(col, c.a)

class_name SpeciesModels
extends RefCounted
## 종별 절차적 모델. 모델 id마다 한 번 만들어 캐시하고 개체는 뼈대만 따로 가진다.
## 좌표: 앞 = -Z, 위 = +Y, 원점 = 몸 아래 땅. 단위는 미터.
## 해부학적 비례(등선, 가슴 깊이, 관절 위치)를 먼저 잡고 보호색·얼룩·결 재질로 사실감을 낸다.

const K := CreatureMaterials.Kind

static var _cache: Dictionary = {}
static var _noise: FastNoiseLite


static func clear_cache() -> void:
	_cache.clear()
	CreatureMaterials.clear_cache()


static func template(model_id: StringName) -> RigTemplate:
	if _cache.has(model_id):
		return _cache[model_id]
	var b: RigBuilder = null
	match model_id:
		&"ash_wolf":
			b = wolf({})
		&"wolf_alpha":
			b = wolf({"scale": 1.22, "top": Color(0.2, 0.19, 0.19), "bottom": Color(0.5, 0.47, 0.43), "mane": 1.45,
				"scars": true})
		&"silvermane":
			b = wolf({"scale": 1.12, "top": Color(0.62, 0.64, 0.66), "bottom": Color(0.86, 0.86, 0.84), "mane": 1.7,
				"eye": Color(0.35, 0.75, 1.0), "saddle": Color(0.42, 0.45, 0.5)})
		&"killer_rabbit":
			b = rabbit({})
		&"horn_rabbit":
			b = rabbit({"top": Color(0.45, 0.33, 0.22), "bottom": Color(0.8, 0.72, 0.6), "horn": true, "scale": 1.1,
				"eye": Color(0.15, 0.1, 0.08)})
		&"serial_rabbit":
			b = rabbit({"top": Color(0.12, 0.11, 0.12), "bottom": Color(0.3, 0.26, 0.26), "scale": 1.25,
				"eye": Color(1.0, 0.1, 0.05), "stripes": Color(0.55, 0.08, 0.08)})
		_:
			if String(model_id).begins_with("goblin_") or model_id == &"oneeye_sniper":
				b = goblin(model_id)
	if b == null:
		return null
	var t := b.build()
	_cache[model_id] = t
	return t


# --- 공통 무늬 ---

static func noise3(p: Vector3) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.fractal_octaves = 3
	return _noise.get_noise_3dv(p)


## 얼룩: 낮은 주파수 잡음으로 밝기를 조금씩 흔든다.
static func mottle(amount: float, freq: float, seed_offset: Vector3 = Vector3.ZERO) -> Callable:
	return func(v: Vector3, _n: Vector3, c: Color) -> Color:
		var k := 1.0 + noise3(v * freq + seed_offset) * amount
		return Color(c.r * k, c.g * k, c.b * k)


static func _v(p: Dictionary, key: String, default: Variant) -> Variant:
	return p.get(key, default)


# --- 네발짐승(늑대형) ---

## 늑대: 깊고 좁은 가슴, 잘록한 허리, 긴 다리, 넓은 두개골과 주둥이, 세운 귀, 숱 많은 꼬리.
## 색: 등은 끝이 검은 회색 털(안장), 옆구리는 회갈색, 다리는 황갈색, 배·목·뺨은 크림색, 꼬리 끝은 검다.
static func wolf(p: Dictionary) -> RigBuilder:
	var s: float = _v(p, "scale", 1.0)
	var top: Color = _v(p, "top", Color(0.36, 0.34, 0.31))
	var bottom: Color = _v(p, "bottom", Color(0.72, 0.67, 0.58))
	var saddle: Color = _v(p, "saddle", Color(0.17, 0.16, 0.15))
	var leg_col: Color = _v(p, "legs", Color(0.55, 0.44, 0.31))
	var mane: float = _v(p, "mane", 1.25)
	var eye_col: Color = _v(p, "eye", Color(0.88, 0.62, 0.16))
	var b := RigBuilder.new()
	b.fur_length = 0.032 * s
	var H := 0.8 * s
	var L := 0.62 * s
	var chest := Vector2(0.14, 0.23) * s
	var waist := Vector2(0.1, 0.13) * s
	var hip := Vector2(0.12, 0.15) * s
	var grizzle := mottle(0.16, 7.0 / s)
	var scars: bool = _v(p, "scars", false)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col: Color = grizzle.call(v, n, c)
		# 다리: 황갈색(몸통 아래쪽부터)
		var leg := smoothstep(H * 0.52, H * 0.3, v.y)
		col = col.lerp(leg_col * (0.9 + 0.2 * n.x * n.x), leg * 0.85)
		# 등 안장: 어깨부터 엉덩이까지 등쪽이 짙다.
		var back := smoothstep(0.2, 0.75, n.y) * smoothstep(H * 0.7, H * 0.92, v.y) \
			* smoothstep(0.62 * L, 0.2 * L, absf(v.z - 0.1 * L))
		col = col.lerp(saddle, back * 0.75)
		if scars:
			# 우두머리의 흉터: 어깨를 비스듬히 가로지르는 옅은 줄 셋
			for k in 3:
				var d := absf((v.z + L * 0.35 + 0.05 * k * s) - (v.y - H * 0.8) * 0.8)
				var mark := smoothstep(0.012 * s, 0.0, d) * smoothstep(0.0, 0.1 * s, v.x) * smoothstep(H * 0.62, H * 0.9, v.y)
				col = col.lerp(Color(0.66, 0.54, 0.48), mark * 0.7)
		return Color(col, c.a)
	# 뼈대
	b.bone(&"root", &"", Vector3(0, H - chest.y, 0))
	b.bone(&"pelvis", &"root", Vector3(0, H * 0.955 - hip.y, L * 0.46))
	b.bone(&"spine", &"root", Vector3(0, H * 0.965 - waist.y, 0.02 * L))
	b.bone(&"chest", &"spine", Vector3(0, H - chest.y, -L * 0.36))
	var neck_base := Vector3(0, H - 0.08 * s, -L * 0.52)
	var neck_dir := Vector3(0, sin(deg_to_rad(28.0)), -cos(deg_to_rad(28.0)))
	var neck_len := 0.24 * s
	var head_pos := neck_base + neck_dir * neck_len
	b.bone(&"neck", &"chest", neck_base)
	b.bone(&"head", &"neck", head_pos)
	var skull_len := 0.15 * s
	var snout_len := 0.14 * s
	var skull := Vector2(0.078, 0.074) * s
	b.bone(&"jaw", &"head", head_pos + Vector3(0, -skull.y * 0.55, -skull_len * 0.25))
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.bone(StringName("ear_" + sn), &"head", head_pos + Vector3(side * skull.x * 0.58, skull.y * 0.72, -skull_len * 0.02))
	var tail_base := Vector3(0, H * 0.92 - hip.y * 0.3, L * 0.5 + hip.x * 0.95)
	var tail_len := 0.46 * s
	var tail_pts: Array[Vector3] = []
	for i in 5:
		var t := float(i) / 4.0
		tail_pts.append(tail_base + Vector3(0, -tail_len * (0.45 * t + 0.35 * t * t), tail_len * (0.75 * t)))
	b.bone(&"tail1", &"pelvis", tail_pts[0])
	b.bone(&"tail2", &"tail1", tail_pts[2])
	b.bone(&"tail3", &"tail2", tail_pts[3])
	var fx := chest.x * 0.72
	var hx := hip.x * 0.78
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.bone(StringName("fl_upper_" + sn), &"chest", Vector3(side * fx, H - chest.y * 1.08, -L * 0.46))
		b.bone(StringName("fl_lower_" + sn), StringName("fl_upper_" + sn), Vector3(side * fx * 1.02, H * 0.45, -L * 0.4))
		b.bone(StringName("fl_foot_" + sn), StringName("fl_lower_" + sn), Vector3(side * fx, H * 0.085, -L * 0.44))
		b.bone(StringName("hl_upper_" + sn), &"pelvis", Vector3(side * hx, H * 0.955 - hip.y * 1.05, L * 0.5))
		b.bone(StringName("hl_lower_" + sn), StringName("hl_upper_" + sn), Vector3(side * hx * 1.05, H * 0.5, L * 0.36))
		b.bone(StringName("hl_meta_" + sn), StringName("hl_lower_" + sn), Vector3(side * hx, H * 0.24, L * 0.62))
		b.bone(StringName("hl_foot_" + sn), StringName("hl_meta_" + sn), Vector3(side * hx, H * 0.055, L * 0.57))
	# 몸통
	var body: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, H * 0.92 - hip.y * 0.75, L * 0.5 + hip.x * 0.8), hip.x * 0.62, hip.y * 0.62, &"pelvis"),
		RigBuilder.pt(Vector3(0, H * 0.955 - hip.y, L * 0.44), hip.x, hip.y, &"pelvis"),
		RigBuilder.pt(Vector3(0, H * 0.96 - waist.y * 1.02, L * 0.16), waist.x, waist.y, &"spine"),
		RigBuilder.pt(Vector3(0, H * 0.97 - waist.y * 1.25, -0.06 * L), waist.x * 1.18, waist.y * 1.32, &"spine"),
		RigBuilder.pt(Vector3(0, H * 0.985 - chest.y * 0.95, -L * 0.26), chest.x * 0.97, chest.y * 0.95, &"chest"),
		RigBuilder.pt(Vector3(0, H - chest.y, -L * 0.44), chest.x, chest.y, &"chest"),
		RigBuilder.pt(Vector3(0, H - chest.y * 1.0, -L * 0.6), chest.x * 0.8, chest.y * 0.84, &"chest"),
	]
	b.loft(body, K.FUR, top, bottom, 20, 4)
	# 목과 갈기
	b.fur = 1.0
	var nr := Vector2(0.1, 0.13) * s * mane
	var neck: Array[RigBuilder.P] = [
		RigBuilder.pt(neck_base + Vector3(0, -0.1 * s, 0.07 * s), nr.x * 1.1, nr.y * 1.25, &"chest"),
		RigBuilder.pt(neck_base + neck_dir * neck_len * 0.45 + Vector3(0, -0.02 * s, 0), nr.x, nr.y, &"neck"),
		RigBuilder.pt(head_pos + Vector3(0, -0.02 * s, 0.035 * s), nr.x * 0.8, nr.y * 0.8, &"head"),
	]
	b.loft(neck, K.FUR, top, bottom, 18, 4)
	# 머리: 넓은 두개골 → 이마 턱(stop) → 주둥이 → 코끝
	var cream := bottom.lerp(Color(0.95, 0.92, 0.85), 0.4)
	var tawny := leg_col.lerp(top, 0.3)
	var hp := head_pos
	b.fur = 0.45
	var head: Array[RigBuilder.P] = [
		RigBuilder.pt(hp + Vector3(0, 0.0, skull.x * 0.5), skull.x * 0.82, skull.y * 0.82, &"head"),
		RigBuilder.pt(hp + Vector3(0, skull.y * 0.1, -skull_len * 0.35), skull.x, skull.y, &"head"),
		RigBuilder.pt(hp + Vector3(0, skull.y * 0.0, -skull_len * 0.9), skull.x * 0.72, skull.y * 0.8, &"head"),
		RigBuilder.pt(hp + Vector3(0, -skull.y * 0.2, -skull_len - snout_len * 0.45), skull.x * 0.52, skull.y * 0.55, &"head"),
		RigBuilder.pt(hp + Vector3(0, -skull.y * 0.26, -skull_len - snout_len * 0.95), skull.x * 0.4, skull.y * 0.4, &"head"),
	]
	var eye_z := -skull_len * 0.88
	b.loft(head, K.FUR, top, cream, 18, 4, Vector3.UP, true, true,
		func(v: Vector3, n: Vector3, c: Color) -> Color:
			var local := v - hp
			# 주둥이 윗면은 황갈색, 입가·뺨은 크림색, 눈 둘레는 짙다.
			var muzzle := smoothstep(eye_z, eye_z - snout_len * 0.3, local.z)
			var col := c.lerp(tawny, muzzle * smoothstep(-0.1, 0.6, n.y) * 0.8)
			var cheek := smoothstep(0.1, -0.5, n.y) * smoothstep(-skull_len * 0.2, eye_z, local.z)
			col = col.lerp(cream, cheek * 0.7)
			var eye_ring := smoothstep(0.03 * s, 0.012 * s, Vector2(absf(local.x) - skull.x * 0.56, local.y - skull.y * 0.22).length() \
				+ absf(local.z - eye_z) * 0.6)
			col = col.lerp(Color(0.1, 0.08, 0.07), eye_ring * 0.8)
			return Color(col, c.a))
	# 아래턱과 입술
	b.fur = 0.3
	var jaw: Array[RigBuilder.P] = [
		RigBuilder.pt(hp + Vector3(0, -skull.y * 0.52, -skull_len * 0.2), skull.x * 0.62, skull.y * 0.36, &"jaw"),
		RigBuilder.pt(hp + Vector3(0, -skull.y * 0.66, -skull_len - snout_len * 0.3), skull.x * 0.4, skull.y * 0.25, &"jaw"),
		RigBuilder.pt(hp + Vector3(0, -skull.y * 0.64, -skull_len - snout_len * 0.8), skull.x * 0.3, skull.y * 0.17, &"jaw"),
	]
	b.loft(jaw, K.FUR, cream, cream, 12, 3)
	# 코와 콧등
	var nose_pos := hp + Vector3(0, -skull.y * 0.16, -skull_len - snout_len * 1.03)
	b.ellipsoid(nose_pos, Vector3(0.026, 0.02, 0.02) * s, &"head", K.WET_SKIN, Color(0.05, 0.045, 0.045))
	b.bald(nose_pos, 0.035 * s)
	b.bald(hp + Vector3(0, -skull.y * 0.55, -skull_len - snout_len * 0.7), 0.03 * s)
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var eye := hp + Vector3(side * skull.x * 0.6, skull.y * 0.22, eye_z)
		var look := Vector3(side * 0.55, 0.05, -1.0)
		b.eye(eye, 0.016 * s, &"head", look, eye_col, Color(0.22, 0.15, 0.08), 0.35, 1.0)
		# 눈두덩
		b.fur = 0.3
		b.ellipsoid(eye + Vector3(-side * 0.004, 0.013 * s, 0.006 * s), Vector3(0.022, 0.009, 0.022) * s, &"head", K.FUR, top)
		# 송곳니(윗니·아랫니)
		b.cone(hp + Vector3(side * skull.x * 0.26, -skull.y * 0.44, -skull_len - snout_len * 0.72),
			hp + Vector3(side * skull.x * 0.26, -skull.y * 0.74, -skull_len - snout_len * 0.76), 0.008 * s,
			&"head", K.TEETH, Color(0.92, 0.89, 0.8), Vector3.ZERO, 6)
		b.cone(hp + Vector3(side * skull.x * 0.22, -skull.y * 0.6, -skull_len - snout_len * 0.62),
			hp + Vector3(side * skull.x * 0.22, -skull.y * 0.38, -skull_len - snout_len * 0.64), 0.006 * s,
			&"jaw", K.TEETH, Color(0.9, 0.87, 0.78), Vector3.ZERO, 6)
		# 귀: 세운 둥근 삼각 귀(앞면은 크림색 속털, 뒷면은 짙다)
		var ear_bone := StringName("ear_" + sn)
		var eb := b.bone_pos(ear_bone)
		b.fur = 0.5
		var ear: Array[RigBuilder.P] = [
			RigBuilder.pt(eb, 0.045 * s, 0.02 * s, ear_bone),
			RigBuilder.pt(eb + Vector3(side * 0.015, 0.05, 0.01) * s, 0.037 * s, 0.014 * s, ear_bone),
			RigBuilder.pt(eb + Vector3(side * 0.025, 0.1, 0.018) * s, 0.012 * s, 0.006 * s, ear_bone),
		]
		var ear_in := cream.lerp(tawny, 0.3)
		b.loft(ear, K.FUR_THIN, top.darkened(0.25), top.darkened(0.25), 12, 3, Vector3.BACK, true, true,
			func(_v2: Vector3, n: Vector3, c: Color) -> Color:
				return Color(c.lerp(ear_in, smoothstep(0.1, 0.7, -n.z)), c.a))
	# 다리
	b.fur = 1.0
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var u := StringName("fl_upper_" + sn)
		var lo := StringName("fl_lower_" + sn)
		var ft := StringName("fl_foot_" + sn)
		var a := b.bone_pos(u)
		var e := b.bone_pos(lo)
		var w := b.bone_pos(ft)
		# 다리털은 위쪽만 길고 아래로 갈수록 짧다(정점 알파).
		var leg_fur := func(v: Vector3, _n: Vector3, c: Color) -> Color:
			return Color(c, c.a * lerpf(0.25, 0.85, smoothstep(H * 0.3, H * 0.55, v.y)))
		var fore: Array[RigBuilder.P] = [
			RigBuilder.pt(a + Vector3(-side * 0.04, chest.y * 0.45, 0.06 * s), 0.04 * s, chest.y * 0.28, &"chest"),
			RigBuilder.pt(a, 0.056 * s, 0.075 * s, u),
			RigBuilder.pt(a.lerp(e, 0.6), 0.044 * s, 0.056 * s, u),
			RigBuilder.pt(e + Vector3(0, 0.02 * s, 0), 0.034 * s, 0.045 * s, lo),
			RigBuilder.pt(e.lerp(w, 0.5), 0.027 * s, 0.031 * s, lo),
			RigBuilder.pt(w + Vector3(0, 0.02 * s, 0), 0.023 * s, 0.026 * s, ft),
			RigBuilder.pt(w + Vector3(0, -0.035 * s, -0.035 * s), 0.033 * s, 0.024 * s, ft),
			RigBuilder.pt(w + Vector3(0, -0.05 * s, -0.075 * s), 0.028 * s, 0.018 * s, ft),
		]
		b.loft(fore, K.FUR, top, bottom, 12, 3, Vector3.FORWARD, true, true, leg_fur)
		var hu := StringName("hl_upper_" + sn)
		var hlo := StringName("hl_lower_" + sn)
		var hm := StringName("hl_meta_" + sn)
		var hf := StringName("hl_foot_" + sn)
		var h0 := b.bone_pos(hu)
		var h1 := b.bone_pos(hlo)
		var h2 := b.bone_pos(hm)
		var h3 := b.bone_pos(hf)
		var hind: Array[RigBuilder.P] = [
			RigBuilder.pt(h0 + Vector3(-side * 0.04, hip.y * 0.5, 0.0), 0.05 * s, hip.y * 0.36, &"pelvis"),
			RigBuilder.pt(h0, 0.072 * s, 0.1 * s, hu),
			RigBuilder.pt(h0.lerp(h1, 0.55), 0.056 * s, 0.078 * s, hu),
			RigBuilder.pt(h1, 0.035 * s, 0.045 * s, hlo),
			RigBuilder.pt(h1.lerp(h2, 0.5), 0.029 * s, 0.036 * s, hlo),
			RigBuilder.pt(h2, 0.021 * s, 0.03 * s, hm),
			RigBuilder.pt(h2.lerp(h3, 0.5), 0.021 * s, 0.024 * s, hm),
			RigBuilder.pt(h3 + Vector3(0, -0.005, -0.03) * s, 0.033 * s, 0.024 * s, hf),
			RigBuilder.pt(h3 + Vector3(0, -0.018, -0.075) * s, 0.028 * s, 0.018 * s, hf),
		]
		b.loft(hind, K.FUR, top, bottom, 12, 3, Vector3.FORWARD, true, true, leg_fur)
		for foot in [ft, hf]:
			var fp := b.bone_pos(foot) + (Vector3(0, -0.05, -0.1) if foot == ft else Vector3(0, -0.02, -0.1)) * s
			for c in [-1.0, 0.0, 1.0]:
				var base_p: Vector3 = fp + Vector3(c * 0.014 * s, 0.0, 0.0)
				b.cone(base_p, base_p + Vector3(c * 0.004, -0.018, -0.02) * s, 0.005 * s, foot, K.HORN,
					Color(0.16, 0.14, 0.13), Vector3.ZERO, 5)
	# 꼬리: 숱이 많고 끝이 검다.
	b.fur = 1.0
	var tr := 0.06 * s
	var tail: Array[RigBuilder.P] = [
		RigBuilder.pt(tail_pts[0], tr * 0.55, tr * 0.6, &"tail1"),
		RigBuilder.pt(tail_pts[1], tr * 0.95, tr, &"tail1"),
		RigBuilder.pt(tail_pts[2], tr * 1.1, tr * 1.1, &"tail2"),
		RigBuilder.pt(tail_pts[3], tr * 0.95, tr * 0.95, &"tail3"),
		RigBuilder.pt(tail_pts[4], tr * 0.35, tr * 0.35, &"tail3"),
	]
	var tip_col := Color(0.08, 0.07, 0.07)
	var tail_tip := tail_pts[4]
	b.loft(tail, K.FUR, top, bottom, 12, 3, Vector3.UP, true, true,
		func(v: Vector3, _n: Vector3, c: Color) -> Color:
			return Color(c.lerp(tip_col, smoothstep(0.14 * s, 0.03 * s, v.distance_to(tail_tip))), c.a))
	b.socket(&"head", &"head", Transform3D(Basis(), Vector3(0, 0, -skull_len * 0.5)))
	b.socket(&"mouth", &"head", Transform3D(Basis(), Vector3(0, -skull.y * 0.4, -skull_len - snout_len)))
	return b


# --- 토끼 ---

## 토끼: 달걀 모양 몸(엉덩이가 크다), 몸 옆에 접힌 큰 넓적다리와 땅에 붙은 긴 뒷발, 짧은 앞다리,
## 둥근 머리와 옆을 보는 큰 눈, 긴 귀, 솜뭉치 꼬리.
static func rabbit(p: Dictionary) -> RigBuilder:
	var s: float = _v(p, "scale", 1.25)
	var top: Color = _v(p, "top", Color(0.7, 0.68, 0.64))
	var bottom: Color = _v(p, "bottom", Color(0.9, 0.89, 0.86))
	var eye_col: Color = _v(p, "eye", Color(0.8, 0.06, 0.05))
	var stripes: Color = _v(p, "stripes", Color(0, 0, 0, 0))
	var b := RigBuilder.new()
	b.fur_length = 0.018 * s
	b.fur_density = 12.0
	var mot := mottle(0.08, 9.0 / s)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col: Color = mot.call(v, n, c)
		if stripes.a > 0.0:
			var band := smoothstep(0.55, 0.9, sin(v.z * 38.0 / s + noise3(v * 6.0) * 2.0))
			col = col.lerp(stripes, band * smoothstep(0.1, 0.6, n.y) * 0.8)
		return Color(col, c.a)
	var P := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * s
	b.bone(&"root", &"", P.call(0, 0.22, 0.02))
	b.bone(&"pelvis", &"root", P.call(0, 0.2, 0.12))
	b.bone(&"spine", &"root", P.call(0, 0.24, 0.0))
	b.bone(&"chest", &"spine", P.call(0, 0.22, -0.1))
	b.bone(&"neck", &"chest", P.call(0, 0.26, -0.16))
	b.bone(&"head", &"neck", P.call(0, 0.32, -0.2))
	b.bone(&"jaw", &"head", P.call(0, 0.3, -0.27))
	b.bone(&"ear_l", &"head", P.call(-0.03, 0.39, -0.2))
	b.bone(&"ear_r", &"head", P.call(0.03, 0.39, -0.2))
	b.bone(&"tail1", &"pelvis", P.call(0, 0.22, 0.28))
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.bone(StringName("fl_upper_" + sn), &"chest", P.call(side * 0.06, 0.17, -0.12))
		b.bone(StringName("fl_lower_" + sn), StringName("fl_upper_" + sn), P.call(side * 0.062, 0.09, -0.14))
		b.bone(StringName("fl_foot_" + sn), StringName("fl_lower_" + sn), P.call(side * 0.062, 0.025, -0.15))
		b.bone(StringName("hl_upper_" + sn), &"pelvis", P.call(side * 0.1, 0.19, 0.11))
		b.bone(StringName("hl_lower_" + sn), StringName("hl_upper_" + sn), P.call(side * 0.12, 0.09, 0.03))
		b.bone(StringName("hl_foot_" + sn), StringName("hl_lower_" + sn), P.call(side * 0.105, 0.035, 0.2))
	var body: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 0.19, 0.26), 0.11 * s, 0.1 * s, &"pelvis"),
		RigBuilder.pt(P.call(0, 0.21, 0.15), 0.155 * s, 0.155 * s, &"pelvis"),
		RigBuilder.pt(P.call(0, 0.225, 0.03), 0.145 * s, 0.15 * s, &"spine"),
		RigBuilder.pt(P.call(0, 0.22, -0.09), 0.115 * s, 0.125 * s, &"chest"),
		RigBuilder.pt(P.call(0, 0.25, -0.16), 0.08 * s, 0.09 * s, &"neck"),
	]
	b.loft(body, K.FUR, top, bottom, 20, 4)
	var head: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 0.325, -0.155), 0.07 * s, 0.075 * s, &"head"),
		RigBuilder.pt(P.call(0, 0.335, -0.215), 0.082 * s, 0.082 * s, &"head"),
		RigBuilder.pt(P.call(0, 0.318, -0.275), 0.066 * s, 0.064 * s, &"head"),
		RigBuilder.pt(P.call(0, 0.302, -0.318), 0.042 * s, 0.042 * s, &"head"),
	]
	b.loft(head, K.FUR, top, bottom, 18, 4)
	# 볼록한 볼과 코
	for side in [-1.0, 1.0]:
		b.ellipsoid(P.call(side * 0.04, 0.3, -0.285), Vector3(0.036, 0.03, 0.04) * s, &"head", K.FUR, bottom.lerp(top, 0.4))
	var nose := P.call(0, 0.307, -0.338) as Vector3
	b.ellipsoid(nose, Vector3(0.011, 0.008, 0.007) * s, &"head", K.WET_SKIN, Color(0.55, 0.32, 0.33))
	b.bald(nose, 0.018 * s)
	# 앞니(살인토끼의 상징)
	b.ellipsoid(P.call(0, 0.277, -0.325), Vector3(0.013, 0.02, 0.006) * s, &"jaw", K.TEETH, Color(0.95, 0.93, 0.85))
	b.bald(P.call(0, 0.28, -0.325), 0.025 * s)
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var eye := P.call(side * 0.063, 0.345, -0.255) as Vector3
		b.eye(eye, 0.02 * s, &"head", Vector3(side, 0.1, -0.45), eye_col, eye_col.darkened(0.6), 0.5, 1.1)
		# 긴 귀: 뒤로 살짝 누운 판(안쪽은 옅은 분홍, 끝은 짙다)
		var ear_bone := StringName("ear_" + sn)
		var eb := b.bone_pos(ear_bone)
		var ear: Array[RigBuilder.P] = [
			RigBuilder.pt(eb, 0.026 * s, 0.013 * s, ear_bone),
			RigBuilder.pt(eb + Vector3(side * 0.015, 0.08, 0.03) * s, 0.037 * s, 0.011 * s, ear_bone),
			RigBuilder.pt(eb + Vector3(side * 0.028, 0.17, 0.06) * s, 0.027 * s, 0.009 * s, ear_bone),
			RigBuilder.pt(eb + Vector3(side * 0.032, 0.21, 0.075) * s, 0.007 * s, 0.005 * s, ear_bone),
		]
		var inner := Color(0.78, 0.6, 0.56) if stripes.a <= 0.0 else Color(0.45, 0.2, 0.2)
		var tip := top.darkened(0.45)
		var ear_tip := eb + Vector3(side * 0.032, 0.21, 0.075) * s
		b.fur = 0.35
		b.loft(ear, K.FUR_THIN, top, top, 10, 3, Vector3.BACK, true, true,
			func(v2: Vector3, n: Vector3, c: Color) -> Color:
				var col := c.lerp(inner, smoothstep(0.3, 0.85, -n.z) * 0.45)
				col = col.lerp(tip, smoothstep(0.07 * s, 0.015 * s, v2.distance_to(ear_tip)) * 0.8)
				return Color(col, c.a))
		b.fur = 1.0
	if _v(p, "horn", false):
		b.cone(P.call(0, 0.395, -0.245), P.call(0, 0.52, -0.33), 0.022 * s, &"head", K.HORN,
			Color(0.5, 0.43, 0.34), P.call(0, 0.02, 0.02), 8, Color(0.9, 0.86, 0.75))
		b.bald(P.call(0, 0.39, -0.245), 0.03 * s)
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var fu := StringName("fl_upper_" + sn)
		var fl := StringName("fl_lower_" + sn)
		var ff := StringName("fl_foot_" + sn)
		b.fur = 0.6
		var fore: Array[RigBuilder.P] = [
			RigBuilder.pt(P.call(side * 0.05, 0.21, -0.1), 0.04 * s, 0.045 * s, &"chest"),
			RigBuilder.pt(P.call(side * 0.06, 0.15, -0.13), 0.03 * s, 0.031 * s, fu),
			RigBuilder.pt(P.call(side * 0.062, 0.075, -0.145), 0.02 * s, 0.022 * s, fl),
			RigBuilder.pt(P.call(side * 0.062, 0.028, -0.152), 0.02 * s, 0.018 * s, ff),
			RigBuilder.pt(P.call(side * 0.062, 0.016, -0.19), 0.022 * s, 0.013 * s, ff),
		]
		b.loft(fore, K.FUR, top, bottom, 10, 3, Vector3.FORWARD)
		# 뒷다리: 몸 옆에 접힌 넓적다리 → 앞쪽 무릎 → 뒤꿈치 → 땅에 붙은 긴 발
		var hu := StringName("hl_upper_" + sn)
		var hl := StringName("hl_lower_" + sn)
		var hf := StringName("hl_foot_" + sn)
		b.fur = 1.0
		var thigh: Array[RigBuilder.P] = [
			RigBuilder.pt(P.call(side * 0.07, 0.24, 0.14), 0.07 * s, 0.09 * s, &"pelvis"),
			RigBuilder.pt(P.call(side * 0.11, 0.17, 0.1), 0.07 * s, 0.085 * s, hu),
			RigBuilder.pt(P.call(side * 0.12, 0.095, 0.04), 0.04 * s, 0.045 * s, hl),
			RigBuilder.pt(P.call(side * 0.115, 0.06, 0.12), 0.03 * s, 0.034 * s, hl),
			RigBuilder.pt(P.call(side * 0.105, 0.036, 0.2), 0.026 * s, 0.028 * s, hf),
		]
		b.loft(thigh, K.FUR, top, bottom, 12, 3, Vector3.FORWARD)
		b.fur = 0.6
		var foot: Array[RigBuilder.P] = [
			RigBuilder.pt(P.call(side * 0.105, 0.03, 0.205), 0.026 * s, 0.02 * s, hf),
			RigBuilder.pt(P.call(side * 0.1, 0.022, 0.1), 0.031 * s, 0.018 * s, hf),
			RigBuilder.pt(P.call(side * 0.097, 0.018, 0.0), 0.025 * s, 0.013 * s, hf),
		]
		b.loft(foot, K.FUR, bottom.lerp(top, 0.3), bottom, 12, 3)
		b.fur = 1.0
	b.fur = 1.0
	b.ellipsoid(P.call(0, 0.235, 0.29), Vector3(0.045, 0.045, 0.04) * s, &"tail1", K.FUR, bottom, bottom)
	b.socket(&"head", &"head", Transform3D(Basis(), P.call(0, 0, -0.04)))
	b.socket(&"mouth", &"head", Transform3D(Basis(), P.call(0, -0.03, -0.12)))
	return b


# --- 고블린 ---

## 고블린: 사람보다 작고 구부정하다. 큰 머리와 매부리코, 옆으로 뻗은 긴 귀, 가는 팔다리, 불룩한 배.
## 역할마다 옷과 장비가 다르다(척후병 두건, 도끼잡이 방패, 사수 고글, 주술사 가면, 두목 투구, 외눈 저격수 안대·망토).
static func goblin(role: StringName) -> RigBuilder:
	var s := 1.0
	var skin := Color(0.33, 0.36, 0.23)
	var belly := Color(0.47, 0.46, 0.33)
	match role:
		&"goblin_brute":
			s = 1.12
			skin = Color(0.3, 0.34, 0.22)
		&"goblin_chief":
			s = 1.32
			skin = Color(0.27, 0.3, 0.2)
		&"goblin_shaman":
			skin = Color(0.36, 0.36, 0.28)
		&"oneeye_sniper":
			s = 1.05
			skin = Color(0.3, 0.32, 0.24)
		&"goblin_scout":
			s = 0.94
			skin = Color(0.35, 0.37, 0.24)
	var b := RigBuilder.new()
	var mot := mottle(0.1, 7.0)
	var blotch := mottle(0.14, 2.2, Vector3(11, 3, 7))
	var dirt := Color(0.24, 0.19, 0.12)
	var ribs := role != &"goblin_chief" and role != &"goblin_brute"
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col: Color = blotch.call(v, n, mot.call(v, n, c))
		# 누런 얼룩(큰 반점)
		var yl := smoothstep(0.25, 0.6, noise3(v * 3.1 + Vector3(5, 1, 2)))
		col = col.lerp(col * Color(1.15, 1.05, 0.7), yl * 0.5)
		# 발과 발목은 흙투성이
		col = col.lerp(dirt, smoothstep(0.2 * s, 0.05 * s, v.y) * 0.75)
		# 앙상한 갈비뼈: 옆구리에 가로 그늘
		if ribs:
			var side_f := smoothstep(0.35, 0.8, absf(n.x))
			var band := smoothstep(0.6, 1.0, sin(v.y / s * 95.0)) * smoothstep(0.78 * s, 0.86 * s, v.y) * smoothstep(1.0 * s, 0.92 * s, v.y)
			col = col.lerp(col.darkened(0.35), band * side_f * 0.7)
		return Color(col, c.a)
	var P := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * s
	b.bone(&"root", &"", P.call(0, 0.62, 0))
	b.bone(&"spine", &"root", P.call(0, 0.76, -0.01))
	b.bone(&"chest", &"spine", P.call(0, 0.93, -0.07))
	b.bone(&"neck", &"chest", P.call(0, 1.04, -0.15))
	b.bone(&"head", &"neck", P.call(0, 1.12, -0.19))
	b.bone(&"jaw", &"head", P.call(0, 1.08, -0.24))
	b.bone(&"ear_l", &"head", P.call(-0.1, 1.17, -0.19))
	b.bone(&"ear_r", &"head", P.call(0.1, 1.17, -0.19))
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.bone(StringName("arm_upper_" + sn), &"chest", P.call(side * 0.16, 0.99, -0.1))
		b.bone(StringName("arm_lower_" + sn), StringName("arm_upper_" + sn), P.call(side * 0.22, 0.77, -0.06))
		b.bone(StringName("hand_" + sn), StringName("arm_lower_" + sn), P.call(side * 0.24, 0.56, -0.1))
		b.bone(StringName("leg_upper_" + sn), &"root", P.call(side * 0.085, 0.6, 0.0))
		b.bone(StringName("leg_lower_" + sn), StringName("leg_upper_" + sn), P.call(side * 0.1, 0.34, -0.05))
		b.bone(StringName("foot_" + sn), StringName("leg_lower_" + sn), P.call(side * 0.1, 0.075, 0.02))
	# 몸통(골반 → 불룩한 배 → 앙상한 가슴 → 좁은 어깨). 세로 관이라 단면의 ry는 앞뒤 두께다.
	var torso: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 0.55, 0.01), 0.12 * s, 0.1 * s, &"root"),
		RigBuilder.pt(P.call(0, 0.64, -0.015), 0.14 * s, 0.135 * s, &"root"),
		RigBuilder.pt(P.call(0, 0.73, -0.05), 0.145 * s, 0.16 * s, &"spine"),
		RigBuilder.pt(P.call(0, 0.84, -0.055), 0.14 * s, 0.12 * s, &"spine"),
		RigBuilder.pt(P.call(0, 0.94, -0.08), 0.155 * s, 0.1 * s, &"chest"),
		RigBuilder.pt(P.call(0, 1.0, -0.115), 0.12 * s, 0.075 * s, &"chest"),
	]
	b.loft(torso, K.SKIN, skin, belly, 20, 4, Vector3.FORWARD)
	# 가슴근육, 굽은 등(승모근), 어깨
	for side in [-1.0, 1.0]:
		b.ellipsoid(P.call(side * 0.06, 0.935, -0.155), Vector3(0.065, 0.045, 0.03) * s, &"chest", K.SKIN, skin, belly)
		b.ellipsoid(P.call(side * 0.165, 0.985, -0.1), Vector3(0.05, 0.048, 0.052) * s, StringName("arm_upper_" + ("l" if side < 0.0 else "r")),
			K.SKIN, skin)
	b.ellipsoid(P.call(0, 1.0, -0.06), Vector3(0.12, 0.055, 0.065) * s, &"chest", K.SKIN, skin.darkened(0.08))
	# 목
	var neck: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 1.0, -0.12), 0.062 * s, 0.058 * s, &"chest"),
		RigBuilder.pt(P.call(0, 1.07, -0.17), 0.046 * s, 0.046 * s, &"neck"),
		RigBuilder.pt(P.call(0, 1.11, -0.19), 0.052 * s, 0.05 * s, &"head"),
	]
	b.loft(neck, K.SKIN, skin, belly, 12, 3, Vector3.FORWARD)
	# 머리: 큰 뒤통수 + 얼굴판 + 눈두덩 + 광대 + 매부리코 + 넓은 입 + 주걱턱
	var skull: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 1.16, -0.1), 0.085 * s, 0.09 * s, &"head"),
		RigBuilder.pt(P.call(0, 1.19, -0.18), 0.11 * s, 0.115 * s, &"head"),
		RigBuilder.pt(P.call(0, 1.185, -0.25), 0.1 * s, 0.1 * s, &"head"),
		RigBuilder.pt(P.call(0, 1.16, -0.29), 0.08 * s, 0.075 * s, &"head"),
	]
	b.loft(skull, K.SKIN, skin, skin.lerp(belly, 0.3), 20, 4)
	b.ellipsoid(P.call(0, 1.14, -0.285), Vector3(0.09, 0.08, 0.06) * s, &"head", K.SKIN, skin, skin.lerp(belly, 0.4))
	b.ellipsoid(P.call(0, 1.19, -0.318), Vector3(0.092, 0.018, 0.024) * s, &"head", K.SKIN, skin.darkened(0.12))
	for side in [-1.0, 1.0]:
		b.ellipsoid(P.call(side * 0.07, 1.125, -0.298), Vector3(0.028, 0.02, 0.028) * s, &"head", K.SKIN, skin)
	var nose_col := skin.lerp(Color(0.55, 0.32, 0.26), 0.45)
	var nose: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 1.18, -0.338), 0.017 * s, 0.018 * s, &"head"),
		RigBuilder.pt(P.call(0, 1.155, -0.372), 0.021 * s, 0.021 * s, &"head"),
		RigBuilder.pt(P.call(0, 1.128, -0.404), 0.028 * s, 0.026 * s, &"head"),
		RigBuilder.pt(P.call(0, 1.108, -0.398), 0.022 * s, 0.018 * s, &"head"),
	]
	b.loft(nose, K.SKIN, skin, nose_col, 12, 3, Vector3.UP, true, true,
		func(v: Vector3, _n: Vector3, c: Color) -> Color:
			return Color(c.lerp(nose_col, smoothstep(-0.36 * s, -0.405 * s, v.z) * 0.8), c.a))
	for side in [-1.0, 1.0]:
		b.ellipsoid(P.call(side * 0.012, 1.104, -0.402), Vector3(0.007, 0.004, 0.006) * s, &"head", K.SKIN, Color(0.08, 0.05, 0.04))
	# 윗입술과 입 선
	b.ellipsoid(P.call(0, 1.095, -0.33), Vector3(0.066, 0.022, 0.034) * s, &"head", K.SKIN, skin, belly)
	b.ellipsoid(P.call(0, 1.082, -0.345), Vector3(0.052, 0.005, 0.014) * s, &"head", K.SKIN, Color(0.12, 0.06, 0.05))
	var jaw: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 1.09, -0.2), 0.086 * s, 0.046 * s, &"jaw"),
		RigBuilder.pt(P.call(0, 1.068, -0.29), 0.076 * s, 0.04 * s, &"jaw"),
		RigBuilder.pt(P.call(0, 1.058, -0.345), 0.052 * s, 0.03 * s, &"jaw"),
	]
	b.loft(jaw, K.SKIN, skin, belly, 16, 3)
	# 사마귀 몇 개
	var wr := RandomNumberGenerator.new()
	wr.seed = hash(String(role))
	for i in 5:
		var a := wr.randf_range(-1.2, 1.2)
		var h := wr.randf_range(1.12, 1.24)
		var wp := P.call(sin(a) * 0.105, h, -0.19 - cos(a) * 0.1) as Vector3
		b.ellipsoid(wp, Vector3.ONE * wr.randf_range(0.006, 0.011) * s, &"head", K.SKIN, skin.darkened(0.15))
	for side in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.cone(P.call(side * 0.036, 1.082, -0.345), P.call(side * 0.042, 1.122, -0.352), 0.009 * s, &"jaw", K.TEETH,
			Color(0.82, 0.76, 0.55), Vector3.ZERO, 6, Color(0.95, 0.9, 0.75))
		# 눈: 깊숙한 노란 눈(외눈 저격수는 왼쪽에 안대)
		var eye_pos: Vector3 = P.call(side * 0.047, 1.163, -0.328)
		if role == &"oneeye_sniper" and side < 0.0:
			b.ellipsoid(eye_pos + Vector3(0, 0, -0.006 * s), Vector3(0.03, 0.028, 0.012) * s, &"head", K.LEATHER, Color(0.1, 0.08, 0.07))
			var band: Array[RigBuilder.P] = [
				RigBuilder.pt(P.call(0, 1.2, -0.19), 0.113 * s, 0.114 * s, &"head"),
				RigBuilder.pt(P.call(0, 1.19, -0.19), 0.113 * s, 0.114 * s, &"head"),
			]
			b.loft(band, K.LEATHER, Color(0.1, 0.08, 0.07), Color(0.1, 0.08, 0.07), 18, 2, Vector3(0.3, 0, -1), false, false)
		else:
			b.eye(eye_pos, 0.02 * s, &"head", Vector3(side * 0.3, 0.0, -1.0), Color(0.98, 0.62, 0.08), Color(0.82, 0.78, 0.5), 0.3, 0.75)
		# 긴 귀: 옆으로 뻗은 얇은 판. 가장자리는 해가 비쳐 붉다.
		var ear_bone := StringName("ear_" + sn)
		var eb := b.bone_pos(ear_bone)
		var ear: Array[RigBuilder.P] = [
			RigBuilder.pt(eb, 0.032 * s, 0.013 * s, ear_bone),
			RigBuilder.pt(eb + Vector3(side * 0.08, 0.025, 0.02) * s, 0.046 * s, 0.01 * s, ear_bone),
			RigBuilder.pt(eb + Vector3(side * 0.19, 0.06, 0.05) * s, 0.019 * s, 0.006 * s, ear_bone),
			RigBuilder.pt(eb + Vector3(side * 0.24, 0.08, 0.065) * s, 0.004 * s, 0.004 * s, ear_bone),
		]
		var ear_in := skin.lerp(Color(0.62, 0.4, 0.34), 0.5)
		b.loft(ear, K.SKIN_THIN, skin, skin, 10, 3, Vector3.FORWARD, true, true,
			func(_v2: Vector3, n: Vector3, c: Color) -> Color:
				return Color(c.lerp(ear_in, smoothstep(0.2, 0.8, -n.z) * 0.7), c.a))
		# 팔: 가늘고 긴 팔, 도드라진 팔꿈치
		var au := StringName("arm_upper_" + sn)
		var al := StringName("arm_lower_" + sn)
		var hd := StringName("hand_" + sn)
		var a0 := b.bone_pos(au)
		var a1 := b.bone_pos(al)
		var a2 := b.bone_pos(hd)
		var arm: Array[RigBuilder.P] = [
			RigBuilder.pt(a0 + Vector3(-side * 0.04, 0.02, 0) * s, 0.052 * s, 0.05 * s, &"chest"),
			RigBuilder.pt(a0, 0.046 * s, 0.045 * s, au),
			RigBuilder.pt(a0.lerp(a1, 0.5), 0.034 * s, 0.036 * s, au),
			RigBuilder.pt(a1, 0.029 * s, 0.03 * s, al),
			RigBuilder.pt(a1.lerp(a2, 0.35), 0.035 * s, 0.033 * s, al),
			RigBuilder.pt(a2, 0.023 * s, 0.021 * s, hd),
		]
		b.loft(arm, K.SKIN, skin, skin.lerp(belly, 0.25), 12, 3, Vector3.FORWARD)
		b.ellipsoid(a1 + Vector3(0, 0, 0.018) * s, Vector3(0.022, 0.022, 0.02) * s, al, K.SKIN, skin.darkened(0.1))
		# 손: 손바닥 + 굵은 손가락 넷, 손끝은 때가 탔다.
		var hand_col := skin.lerp(dirt, 0.25)
		b.ellipsoid(a2 + Vector3(0, -0.045, -0.01) * s, Vector3(0.03, 0.045, 0.034) * s, hd, K.SKIN, hand_col)
		for f in 4:
			var fp := a2 + Vector3(side * (0.018 - 0.012 * f), -0.085, -0.028) * s
			b.cone(fp, fp + Vector3(0, -0.04, 0.012) * s, 0.01 * s, hd, K.SKIN, hand_col, Vector3.ZERO, 6, Color(0.14, 0.12, 0.08))
		b.cone(a2 + Vector3(-side * 0.02, -0.05, -0.03) * s, a2 + Vector3(-side * 0.035, -0.085, -0.055) * s, 0.011 * s, hd,
			K.SKIN, hand_col, Vector3.ZERO, 6, Color(0.14, 0.12, 0.08))
		# 다리: 앙상한 넓적다리, 튀어나온 무릎, 종아리
		var lu := StringName("leg_upper_" + sn)
		var ll := StringName("leg_lower_" + sn)
		var ftb := StringName("foot_" + sn)
		var l0 := b.bone_pos(lu)
		var l1 := b.bone_pos(ll)
		var l2 := b.bone_pos(ftb)
		var leg: Array[RigBuilder.P] = [
			RigBuilder.pt(l0 + Vector3(0, 0.03, 0) * s, 0.07 * s, 0.075 * s, &"root"),
			RigBuilder.pt(l0, 0.06 * s, 0.064 * s, lu),
			RigBuilder.pt(l0.lerp(l1, 0.55), 0.045 * s, 0.048 * s, lu),
			RigBuilder.pt(l1, 0.035 * s, 0.037 * s, ll),
			RigBuilder.pt(l1.lerp(l2, 0.35) + Vector3(0, 0, 0.014) * s, 0.04 * s, 0.046 * s, ll),
			RigBuilder.pt(l2 + Vector3(0, 0.03, 0) * s, 0.025 * s, 0.027 * s, ftb),
		]
		b.loft(leg, K.SKIN, skin, skin.lerp(belly, 0.2), 12, 3, Vector3.FORWARD)
		b.ellipsoid(l1 + Vector3(0, 0.005, -0.022) * s, Vector3(0.028, 0.03, 0.022) * s, ll, K.SKIN, skin.darkened(0.08))
		# 큰 맨발과 발톱
		var foot: Array[RigBuilder.P] = [
			RigBuilder.pt(l2 + Vector3(0, -0.02, 0.035) * s, 0.034 * s, 0.03 * s, ftb),
			RigBuilder.pt(l2 + Vector3(0, -0.035, -0.04) * s, 0.048 * s, 0.03 * s, ftb),
			RigBuilder.pt(l2 + Vector3(0, -0.045, -0.12) * s, 0.042 * s, 0.022 * s, ftb),
		]
		b.loft(foot, K.SKIN, skin, dirt, 12, 3)
		for c in [-1.0, 0.0, 1.0]:
			var tp := l2 + Vector3(c * 0.022, -0.05, -0.14) * s
			b.cone(tp, tp + Vector3(0, -0.012, -0.025) * s, 0.008 * s, ftb, K.HORN, Color(0.2, 0.17, 0.13), Vector3.ZERO, 5)
	# 옷: 허리띠와 해진 허리 천
	var cloth := Color(0.36, 0.28, 0.2)
	var leather := Color(0.27, 0.19, 0.13)
	match role:
		&"goblin_shaman":
			cloth = Color(0.32, 0.22, 0.3)
		&"goblin_chief":
			cloth = Color(0.42, 0.14, 0.12)
		&"oneeye_sniper":
			cloth = Color(0.24, 0.28, 0.22)
	var skirt: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 0.66, -0.01), 0.148 * s, 0.14 * s, &"root"),
		RigBuilder.pt(P.call(0, 0.58, 0.0), 0.16 * s, 0.15 * s, &"root"),
		RigBuilder.pt(P.call(0, 0.47, 0.0), 0.175 * s, 0.16 * s, &"root"),
	]
	b.loft(skirt, K.CLOTH, cloth, cloth.darkened(0.2), 16, 3, Vector3.FORWARD, false, false,
		func(v: Vector3, _n: Vector3, c: Color) -> Color:
			return c * (0.8 + 0.3 * noise3(v * Vector3(18.0, 2.0, 18.0))))
	var belt: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 0.675, -0.012), 0.152 * s, 0.143 * s, &"root"),
		RigBuilder.pt(P.call(0, 0.645, -0.008), 0.154 * s, 0.145 * s, &"root"),
	]
	b.loft(belt, K.LEATHER, leather, leather, 16, 2, Vector3.FORWARD, false, false)
	b.ellipsoid(P.call(0, 0.66, -0.16), Vector3(0.03, 0.025, 0.012) * s, &"root", K.METAL, Color(0.55, 0.45, 0.3))
	# 가슴을 가로지르는 가죽끈
	var strap: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(-0.13, 1.0, -0.1), 0.02 * s, 0.008 * s, &"chest"),
		RigBuilder.pt(P.call(-0.02, 0.9, -0.2), 0.022 * s, 0.008 * s, &"chest"),
		RigBuilder.pt(P.call(0.1, 0.76, -0.2), 0.022 * s, 0.008 * s, &"spine"),
		RigBuilder.pt(P.call(0.15, 0.66, -0.13), 0.02 * s, 0.008 * s, &"root"),
	]
	b.loft(strap, K.LEATHER, leather, leather, 8, 3, Vector3.FORWARD)
	_goblin_role_gear(b, role, s, skin, cloth, leather)
	# 부착점: 오른손 무기, 왼손(방패·지팡이), 머리(약점)
	b.socket(&"hand_r", &"hand_r", Transform3D(Basis(), Vector3(0, -0.07, -0.02) * s))
	b.socket(&"hand_l", &"hand_l", Transform3D(Basis(), Vector3(0, -0.07, -0.02) * s))
	b.socket(&"forearm_l", &"arm_lower_l", Transform3D(Basis(), Vector3(-0.05, -0.1, -0.02) * s))
	# 방패: 왼팔 바깥쪽. 판의 앞면(+Z)이 팔 바깥(-X)을 본다.
	b.socket(&"shield", &"arm_lower_l", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.07, -0.12, -0.01) * s))
	b.socket(&"head", &"head", Transform3D(Basis(), Vector3(0, 0.05, -0.08) * s))
	b.socket(&"back", &"chest", Transform3D(Basis(), Vector3(0, 0.0, 0.14) * s))
	return b


static func _goblin_role_gear(b: RigBuilder, role: StringName, s: float, skin: Color, cloth: Color, leather: Color) -> void:
	var P := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * s
	var metal := Color(0.45, 0.43, 0.4)
	var bone_col := Color(0.86, 0.82, 0.7)
	match role:
		&"goblin_scout":
			# 두건: 머리를 덮는 천
			var hood: Array[RigBuilder.P] = [
				RigBuilder.pt(P.call(0, 1.1, -0.06), 0.1 * s, 0.1 * s, &"neck"),
				RigBuilder.pt(P.call(0, 1.18, -0.12), 0.125 * s, 0.12 * s, &"head"),
				RigBuilder.pt(P.call(0, 1.215, -0.2), 0.125 * s, 0.12 * s, &"head"),
				RigBuilder.pt(P.call(0, 1.225, -0.27), 0.1 * s, 0.09 * s, &"head"),
			]
			b.loft(hood, K.CLOTH, Color(0.25, 0.3, 0.2), Color(0.2, 0.24, 0.16), 16, 3, Vector3.UP, true, false)
		&"goblin_brute":
			# 뼈 어깨받이
			for side in [-1.0, 1.0]:
				b.ellipsoid(P.call(side * 0.17, 1.02, -0.09), Vector3(0.07, 0.035, 0.07) * s, &"chest", K.HORN, bone_col.darkened(0.1))
				b.cone(P.call(side * 0.19, 1.04, -0.09), P.call(side * 0.25, 1.12, -0.07), 0.018 * s, &"chest", K.HORN, bone_col)
		&"goblin_gunner":
			# 이마에 올린 고글(쇠 테 + 주황 유리)
			for side in [-1.0, 1.0]:
				var gp := P.call(side * 0.042, 1.235, -0.285) as Vector3
				var ring: Array[RigBuilder.P] = [
					RigBuilder.pt(gp + Vector3(0, 0, 0.012) * s, 0.026 * s, 0.024 * s, &"head"),
					RigBuilder.pt(gp + Vector3(0, 0.004, -0.014) * s, 0.026 * s, 0.024 * s, &"head"),
				]
				b.loft(ring, K.METAL, metal, metal.darkened(0.2), 12, 2, Vector3.UP)
				b.ellipsoid(gp + Vector3(0, 0.005, -0.02) * s, Vector3(0.02, 0.019, 0.005) * s, &"head", K.GLOW, Color(0.95, 0.55, 0.15))
			b.ellipsoid(P.call(0, 1.24, -0.28), Vector3(0.014, 0.008, 0.01) * s, &"head", K.METAL, metal)
			# 탄띠
			for i in 5:
				var t := float(i) / 4.0
				var bp: Vector3 = P.call(lerpf(-0.1, 0.1, t), lerpf(0.97, 0.72, t), -0.21 + 0.02 * absf(t - 0.5))
				b.ellipsoid(bp, Vector3(0.012, 0.03, 0.012) * s, &"chest" if t < 0.5 else &"spine", K.METAL, Color(0.7, 0.55, 0.3))
		&"goblin_thrower":
			# 등에 멘 뼈창 묶음
			for i in 3:
				var x := (float(i) - 1.0) * 0.035
				b.cone(P.call(x, 0.72, 0.13), P.call(x * 1.5, 1.32, 0.2), 0.012 * s, &"chest", K.HORN, bone_col.darkened(0.15),
					Vector3.ZERO, 6, bone_col)
			b.ellipsoid(P.call(0, 0.86, 0.14), Vector3(0.08, 0.1, 0.05) * s, &"chest", K.LEATHER, leather)
		&"goblin_shaman":
			# 짐승 두개골 가면과 깃털
			b.ellipsoid(P.call(0, 1.18, -0.3), Vector3(0.09, 0.08, 0.035) * s, &"head", K.HORN, bone_col)
			for side in [-1.0, 1.0]:
				b.ellipsoid(P.call(side * 0.04, 1.185, -0.33), Vector3(0.018, 0.016, 0.01) * s, &"head", K.GLOW, Color(0.4, 1.0, 0.6))
				b.cone(P.call(side * 0.06, 1.25, -0.24), P.call(side * 0.14, 1.42, -0.18), 0.02 * s, &"head", K.HORN, bone_col,
					Vector3(side * 0.02, 0.0, 0.03) * s, 8, Color(0.35, 0.3, 0.25))
			for i in 4:
				var a := float(i) / 3.0
				b.cone(P.call(lerpf(-0.06, 0.06, a), 1.26, -0.12), P.call(lerpf(-0.14, 0.14, a), 1.44, -0.02), 0.012 * s,
					&"head", K.CLOTH, Color(0.2, 0.45, 0.4).lerp(Color(0.6, 0.15, 0.15), a), Vector3(0, 0, 0.04) * s)
			# 구슬 목걸이
			for i in 7:
				var a := lerpf(-1.1, 1.1, float(i) / 6.0)
				b.ellipsoid(P.call(sin(a) * 0.11, 0.99 - cos(a) * 0.05, -0.12 - cos(a) * 0.08), Vector3(0.014, 0.014, 0.014) * s,
					&"chest", K.HORN, Color(0.3, 0.6, 0.55) if i % 2 == 0 else bone_col)
		&"goblin_chief":
			# 뿔 달린 쇠 투구, 쇠 어깨받이, 털 망토
			var helm: Array[RigBuilder.P] = [
				RigBuilder.pt(P.call(0, 1.17, -0.18), 0.125 * s, 0.125 * s, &"head"),
				RigBuilder.pt(P.call(0, 1.23, -0.19), 0.12 * s, 0.12 * s, &"head"),
				RigBuilder.pt(P.call(0, 1.29, -0.2), 0.07 * s, 0.07 * s, &"head"),
			]
			b.loft(helm, K.METAL, metal, metal.darkened(0.3), 16, 3, Vector3.FORWARD, false, true)
			for side in [-1.0, 1.0]:
				b.cone(P.call(side * 0.1, 1.24, -0.18), P.call(side * 0.26, 1.4, -0.1), 0.035 * s, &"head", K.HORN,
					Color(0.35, 0.28, 0.2), Vector3(side * 0.03, -0.03, 0.02) * s, 10, bone_col)
				b.ellipsoid(P.call(side * 0.18, 1.03, -0.09), Vector3(0.09, 0.045, 0.09) * s, &"chest", K.METAL, metal)
			var mantle: Array[RigBuilder.P] = [
				RigBuilder.pt(P.call(0, 1.03, -0.07), 0.2 * s, 0.13 * s, &"chest"),
				RigBuilder.pt(P.call(0, 0.9, 0.0), 0.2 * s, 0.14 * s, &"chest"),
				RigBuilder.pt(P.call(0, 0.7, 0.05), 0.19 * s, 0.14 * s, &"spine"),
			]
			b.loft(mantle, K.FUR, Color(0.3, 0.24, 0.18), Color(0.22, 0.17, 0.12), 16, 3, Vector3.FORWARD, false, false)
		&"oneeye_sniper":
			# 두건 달린 망토
			var cloak: Array[RigBuilder.P] = [
				RigBuilder.pt(P.call(0, 1.2, -0.17), 0.12 * s, 0.12 * s, &"head"),
				RigBuilder.pt(P.call(0, 1.06, -0.1), 0.15 * s, 0.13 * s, &"neck"),
				RigBuilder.pt(P.call(0, 0.9, -0.02), 0.2 * s, 0.14 * s, &"chest"),
				RigBuilder.pt(P.call(0, 0.62, 0.03), 0.22 * s, 0.16 * s, &"spine"),
				RigBuilder.pt(P.call(0, 0.42, 0.06), 0.23 * s, 0.17 * s, &"root"),
			]
			# 앞이 트인 망토: 단면의 앞쪽(90도 부근)을 비운다.
			b.loft(cloak, K.CLOTH, cloth, cloth.darkened(0.25), 18, 3, Vector3.FORWARD, false, false,
				func(v: Vector3, _n: Vector3, c: Color) -> Color:
					return c * (0.85 + 0.25 * noise3(v * Vector3(10.0, 1.5, 10.0))),
				Vector2(deg_to_rad(125.0), deg_to_rad(415.0)))

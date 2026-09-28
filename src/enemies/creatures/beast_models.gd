class_name BeastModels
extends RefCounted
## 무거운 네발짐승(바위등 돌격수 계열, 가시등 멧돼지)과 늪 두꺼비 모델.
## heavy_quad: 비례(등 높이, 몸길이, 가슴·허리·엉덩이 단면, 목, 머리, 다리 굵기)만 바꿔 여러 종을 만드는 네발 골격.

const K := CreatureMaterials.Kind


static func _v(p: Dictionary, key: String, default: Variant) -> Variant:
	return p.get(key, default)


## 네발 골격. 뼈 이름은 늑대와 같다(동작기가 그대로 쓴다).
static func heavy_quad(p: Dictionary) -> RigBuilder:
	var s: float = _v(p, "scale", 1.0)
	var H: float = float(_v(p, "height", 1.0)) * s
	var L: float = float(_v(p, "length", 0.9)) * s
	var chest: Vector2 = (_v(p, "chest", Vector2(0.3, 0.38)) as Vector2) * s
	var waist: Vector2 = (_v(p, "waist", Vector2(0.27, 0.34)) as Vector2) * s
	var hip: Vector2 = (_v(p, "hip", Vector2(0.28, 0.34)) as Vector2) * s
	var belly: float = float(_v(p, "belly", 0.0)) * s
	var kind: int = _v(p, "kind", K.FUR)
	var top: Color = _v(p, "top", Color(0.3, 0.26, 0.22))
	var bottom: Color = _v(p, "bottom", Color(0.45, 0.4, 0.34))
	var eye_col: Color = _v(p, "eye", Color(0.3, 0.2, 0.1))
	var neck_len: float = float(_v(p, "neck_len", 0.25)) * s
	var neck_pitch: float = deg_to_rad(float(_v(p, "neck_pitch", 10.0)))
	var neck_r: Vector2 = (_v(p, "neck_r", Vector2(0.18, 0.22)) as Vector2) * s
	var skull_len: float = float(_v(p, "skull_len", 0.3)) * s
	var skull: Vector2 = (_v(p, "skull", Vector2(0.17, 0.19)) as Vector2) * s
	var snout_len: float = float(_v(p, "snout_len", 0.25)) * s
	var snout: Vector2 = (_v(p, "snout", Vector2(0.08, 0.08)) as Vector2) * s
	var head_drop: float = float(_v(p, "head_drop", 0.2))
	var leg_u: float = float(_v(p, "leg_upper", 0.1)) * s
	var leg_l: float = float(_v(p, "leg_lower", 0.06)) * s
	var foot_r: float = float(_v(p, "foot", 0.07)) * s
	var hoof: bool = _v(p, "hoof", true)
	var hoof_col: Color = _v(p, "hoof_col", Color(0.16, 0.14, 0.12))
	var tail_len: float = float(_v(p, "tail_len", 0.3)) * s
	var tail_r: float = float(_v(p, "tail_r", 0.03)) * s
	var ear_len: float = float(_v(p, "ear_len", 0.1)) * s
	var ear_w: float = float(_v(p, "ear_w", 0.05)) * s
	var b := RigBuilder.new()
	b.fur = float(_v(p, "fur", 1.0))
	b.fur_length = float(_v(p, "fur_length", 0.03)) * s
	b.fur_density = float(_v(p, "fur_density", 7.0))
	var pattern: Callable = _v(p, "pattern", SpeciesModels.mottle(0.12, 3.0 / s))
	b.pattern = pattern
	# 뼈대
	b.bone(&"root", &"", Vector3(0, H - chest.y, 0))
	b.bone(&"pelvis", &"root", Vector3(0, H * 0.96 - hip.y, L * 0.46))
	b.bone(&"spine", &"root", Vector3(0, H * 0.97 - waist.y, 0.02 * L))
	b.bone(&"chest", &"spine", Vector3(0, H - chest.y, -L * 0.36))
	var neck_base := Vector3(0, H - neck_r.y * 0.8, -L * 0.5)
	var neck_dir := Vector3(0, sin(neck_pitch), -cos(neck_pitch))
	var head_pos := neck_base + neck_dir * neck_len
	b.bone(&"neck", &"chest", neck_base)
	b.bone(&"head", &"neck", head_pos)
	# 머리는 앞으로 숙인다(head_drop: 주둥이가 내려가는 정도).
	var fwd := Vector3(0, -sin(head_drop), -cos(head_drop))
	var up := Vector3(0, cos(head_drop), -sin(head_drop))
	b.bone(&"jaw", &"head", head_pos + up * (-skull.y * 0.55) + fwd * skull_len * 0.25)
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.bone(StringName("ear_" + sn), &"head", head_pos + Vector3(side * skull.x * 0.7, 0, 0) + up * skull.y * 0.6 + fwd * skull_len * 0.05)
	var tail_base := Vector3(0, H * 0.93 - hip.y * 0.35, L * 0.5 + hip.x * 0.9)
	var tail_pts: Array[Vector3] = []
	for i in 5:
		var t := float(i) / 4.0
		tail_pts.append(tail_base + Vector3(0, -tail_len * (0.55 * t + 0.25 * t * t), tail_len * 0.7 * t))
	b.bone(&"tail1", &"pelvis", tail_pts[0])
	b.bone(&"tail2", &"tail1", tail_pts[2])
	b.bone(&"tail3", &"tail2", tail_pts[3])
	var fx := chest.x * 0.72
	var hx := hip.x * 0.74
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.bone(StringName("fl_upper_" + sn), &"chest", Vector3(side * fx, H - chest.y * 1.1, -L * 0.45))
		b.bone(StringName("fl_lower_" + sn), StringName("fl_upper_" + sn), Vector3(side * fx, H * 0.48, -L * 0.42))
		b.bone(StringName("fl_foot_" + sn), StringName("fl_lower_" + sn), Vector3(side * fx, H * 0.1, -L * 0.44))
		b.bone(StringName("hl_upper_" + sn), &"pelvis", Vector3(side * hx, H * 0.95 - hip.y * 1.05, L * 0.5))
		b.bone(StringName("hl_lower_" + sn), StringName("hl_upper_" + sn), Vector3(side * hx, H * 0.52, L * 0.42))
		b.bone(StringName("hl_meta_" + sn), StringName("hl_lower_" + sn), Vector3(side * hx, H * 0.26, L * 0.56))
		b.bone(StringName("hl_foot_" + sn), StringName("hl_meta_" + sn), Vector3(side * hx, H * 0.08, L * 0.53))
	# 몸통: 곧은 등선, 늘어진 배
	var body: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, H * 0.92 - hip.y * 0.72, L * 0.5 + hip.x * 0.72), hip.x * 0.66, hip.y * 0.64, &"pelvis"),
		RigBuilder.pt(Vector3(0, H * 0.96 - hip.y, L * 0.44), hip.x, hip.y, &"pelvis"),
		RigBuilder.pt(Vector3(0, H * 0.965 - waist.y - belly * 0.5, L * 0.16), waist.x, waist.y + belly * 0.5, &"spine"),
		RigBuilder.pt(Vector3(0, H * 0.975 - waist.y * 1.1 - belly, -0.08 * L), waist.x * 1.1, waist.y * 1.1 + belly, &"spine"),
		RigBuilder.pt(Vector3(0, H * 0.99 - chest.y * 0.97, -L * 0.28), chest.x * 0.98, chest.y * 0.97, &"chest"),
		RigBuilder.pt(Vector3(0, H - chest.y, -L * 0.45), chest.x, chest.y, &"chest"),
		RigBuilder.pt(Vector3(0, H - chest.y * 1.0, -L * 0.6), chest.x * 0.78, chest.y * 0.84, &"chest"),
	]
	b.loft(body, kind, top, bottom, 22, 4)
	var neck: Array[RigBuilder.P] = [
		RigBuilder.pt(neck_base + Vector3(0, -neck_r.y * 0.3, neck_r.y * 0.5), neck_r.x * 1.1, neck_r.y * 1.15, &"chest"),
		RigBuilder.pt(neck_base + neck_dir * neck_len * 0.5, neck_r.x, neck_r.y, &"neck"),
		RigBuilder.pt(head_pos + up * (-skull.y * 0.05), skull.x * 0.95, skull.y * 0.95, &"head"),
	]
	b.loft(neck, kind, top, bottom, 20, 4)
	# 머리: 뒤통수 → 정수리 → 이마 → 주둥이 → 코
	var hp := head_pos
	var head: Array[RigBuilder.P] = [
		RigBuilder.pt(hp - fwd * skull.x * 0.4, skull.x * 0.85, skull.y * 0.85, &"head"),
		RigBuilder.pt(hp + fwd * skull_len * 0.3 + up * skull.y * 0.08, skull.x, skull.y, &"head"),
		RigBuilder.pt(hp + fwd * skull_len * 0.85, skull.x * 0.82, skull.y * 0.86, &"head"),
		RigBuilder.pt(hp + fwd * (skull_len + snout_len * 0.5) - up * skull.y * 0.18, lerpf(skull.x * 0.6, snout.x, 0.5),
			lerpf(skull.y * 0.62, snout.y, 0.5), &"head"),
		RigBuilder.pt(hp + fwd * (skull_len + snout_len) - up * skull.y * 0.22, snout.x, snout.y, &"head"),
	]
	b.loft(head, kind, top, bottom.lerp(top, 0.3), 20, 4)
	var jaw: Array[RigBuilder.P] = [
		RigBuilder.pt(hp + fwd * skull_len * 0.25 - up * skull.y * 0.52, skull.x * 0.65, skull.y * 0.35, &"jaw"),
		RigBuilder.pt(hp + fwd * (skull_len + snout_len * 0.3) - up * skull.y * 0.62, snout.x * 1.05, snout.y * 0.55, &"jaw"),
		RigBuilder.pt(hp + fwd * (skull_len + snout_len * 0.8) - up * skull.y * 0.6, snout.x * 0.8, snout.y * 0.4, &"jaw"),
	]
	b.loft(jaw, kind, bottom, bottom, 14, 3)
	var nose := hp + fwd * (skull_len + snout_len * 1.02) - up * skull.y * 0.2
	b.ellipsoid(nose, Vector3(snout.x * 0.9, snout.y * 0.7, snout.x * 0.35), &"head", K.WET_SKIN, _v(p, "nose_col", Color(0.12, 0.09, 0.08)),
		Color(0, 0, 0, 0), 12, Basis.looking_at(-fwd, up))
	b.bald(nose, snout.x * 1.5)
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var eye := hp + Vector3(side * skull.x * 0.78, 0, 0) + fwd * skull_len * 0.72 + up * skull.y * 0.25
		b.eye(eye, maxf(skull.x * 0.13, 0.012 * s) * float(_v(p, "eye_scale", 1.0)), &"head", Vector3(side, 0.05, -0.6),
			eye_col, eye_col.darkened(0.6), 0.45, 1.0)
		var ear_bone := StringName("ear_" + sn)
		var eb := b.bone_pos(ear_bone)
		var ear_dir: Vector3 = (_v(p, "ear_dir", Vector3(0.6, 0.8, 0.1)) as Vector3)
		ear_dir = Vector3(ear_dir.x * side, ear_dir.y, ear_dir.z).normalized()
		var ear: Array[RigBuilder.P] = [
			RigBuilder.pt(eb, ear_w, ear_w * 0.4, ear_bone),
			RigBuilder.pt(eb + ear_dir * ear_len * 0.5, ear_w * 0.85, ear_w * 0.3, ear_bone),
			RigBuilder.pt(eb + ear_dir * ear_len, ear_w * 0.15, ear_w * 0.12, ear_bone),
		]
		b.loft(ear, K.FUR_THIN if kind == K.FUR else K.SKIN_THIN, top, top.darkened(0.2), 10, 3, Vector3.BACK)
	# 다리(굵은 기둥형 다리와 발굽)
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var u := StringName("fl_upper_" + sn)
		var lo := StringName("fl_lower_" + sn)
		var ft := StringName("fl_foot_" + sn)
		var a := b.bone_pos(u)
		var e := b.bone_pos(lo)
		var w := b.bone_pos(ft)
		var fore: Array[RigBuilder.P] = [
			RigBuilder.pt(a + Vector3(-side * leg_u * 0.3, chest.y * 0.45, leg_u * 0.4), leg_u * 0.9, chest.y * 0.35, &"chest"),
			RigBuilder.pt(a, leg_u, leg_u * 1.25, u),
			RigBuilder.pt(a.lerp(e, 0.6), leg_u * 0.82, leg_u, u),
			RigBuilder.pt(e, leg_l * 1.05, leg_l * 1.15, lo),
			RigBuilder.pt(e.lerp(w, 0.55), leg_l * 0.85, leg_l * 0.9, lo),
			RigBuilder.pt(w + Vector3(0, foot_r * 0.4, 0), leg_l * 0.8, leg_l * 0.85, ft),
			RigBuilder.pt(w + Vector3(0, -H * 0.05, -foot_r * 0.2), foot_r, foot_r * 0.9, ft),
		]
		b.loft(fore, kind, top, bottom, 14, 3, Vector3.FORWARD)
		var hu := StringName("hl_upper_" + sn)
		var hlo := StringName("hl_lower_" + sn)
		var hm := StringName("hl_meta_" + sn)
		var hf := StringName("hl_foot_" + sn)
		var h0 := b.bone_pos(hu)
		var h1 := b.bone_pos(hlo)
		var h2 := b.bone_pos(hm)
		var h3 := b.bone_pos(hf)
		var hind: Array[RigBuilder.P] = [
			RigBuilder.pt(h0 + Vector3(-side * leg_u * 0.3, hip.y * 0.5, 0), leg_u * 1.1, hip.y * 0.45, &"pelvis"),
			RigBuilder.pt(h0, leg_u * 1.2, leg_u * 1.5, hu),
			RigBuilder.pt(h0.lerp(h1, 0.55), leg_u * 0.95, leg_u * 1.2, hu),
			RigBuilder.pt(h1, leg_l * 1.1, leg_l * 1.25, hlo),
			RigBuilder.pt(h2, leg_l * 0.85, leg_l * 0.95, hm),
			RigBuilder.pt(h3 + Vector3(0, foot_r * 0.4, 0), leg_l * 0.8, leg_l * 0.85, hf),
			RigBuilder.pt(h3 + Vector3(0, -H * 0.06, -foot_r * 0.2), foot_r, foot_r * 0.9, hf),
		]
		b.loft(hind, kind, top, bottom, 14, 3, Vector3.FORWARD)
		if hoof:
			for foot_bone: StringName in [ft, hf]:
				var fp := b.bone_pos(foot_bone) + Vector3(0, -H * 0.075, -foot_r * 0.15)
				var hoof_pts: Array[RigBuilder.P] = [
					RigBuilder.pt(fp + Vector3(0, foot_r * 0.35, 0), foot_r * 1.02, foot_r * 0.95, foot_bone),
					RigBuilder.pt(fp, foot_r * 1.08, foot_r * 1.0, foot_bone),
				]
				b.loft(hoof_pts, K.HORN, hoof_col, hoof_col.darkened(0.2), 14, 2, Vector3.FORWARD)
	# 꼬리
	var tail: Array[RigBuilder.P] = [
		RigBuilder.pt(tail_pts[0], tail_r * 1.3, tail_r * 1.3, &"tail1"),
		RigBuilder.pt(tail_pts[2], tail_r, tail_r, &"tail2"),
		RigBuilder.pt(tail_pts[3], tail_r * 0.8, tail_r * 0.8, &"tail3"),
		RigBuilder.pt(tail_pts[4], tail_r * 0.45, tail_r * 0.45, &"tail3"),
	]
	b.loft(tail, kind, top, bottom, 10, 3)
	# 부착점의 -Z가 머리 앞을 본다.
	var face_basis := Basis.looking_at(fwd, up)
	b.socket(&"head", &"head", Transform3D(face_basis, fwd * skull_len * 0.5))
	b.socket(&"mouth", &"head", Transform3D(face_basis, fwd * (skull_len + snout_len) - up * skull.y * 0.4))
	b.socket(&"face", &"head", Transform3D(face_basis, fwd * (skull_len * 0.75) + up * skull.y * 0.15))
	b.socket(&"back", &"spine", Transform3D(Basis(), Vector3(0, waist.y + belly * 0.2, 0.1 * L)))
	b.socket(&"rump", &"pelvis", Transform3D(Basis(), Vector3(0, hip.y * 0.95, hip.x * 0.2)))
	return b


## 등의 바위(이끼 낀 윗면). 뼈 위치 기준으로 붙인다.
static func rock_lumps(b: RigBuilder, bone_name: StringName, center: Vector3, count: int, size: float, rng: RandomNumberGenerator,
		moss: float = 0.5, rock := Color(0.42, 0.4, 0.37)) -> void:
	for i in count:
		var off := Vector3(rng.randf_range(-1.0, 1.0) * size * 1.2, rng.randf_range(-0.2, 0.3) * size, rng.randf_range(-1.0, 1.0) * size * 1.4)
		var r := size * rng.randf_range(0.55, 1.0)
		var c := center + off
		var mossy := rng.randf() < moss
		var moss_col := Color(0.26, 0.36, 0.16)
		b.ellipsoid(c, Vector3(r * rng.randf_range(0.9, 1.3), r * rng.randf_range(0.55, 0.8), r * rng.randf_range(0.9, 1.3)), bone_name, K.STONE,
			rock * rng.randf_range(0.85, 1.12), rock.darkened(0.3), 12, Basis(Vector3.UP, rng.randf() * TAU),
			func(v: Vector3, n: Vector3, col: Color) -> Color:
				if mossy:
					return Color(col.lerp(moss_col, smoothstep(0.3, 0.8, n.y) * 0.85), col.a)
				return col)


# --- 바위등 돌격수 계열 ---

## 바위등 돌격수(정예): 코뿔소만 한 몸, 이끼 낀 바위 등, 짧고 굵은 목, 낮게 든 머리. 전면 장갑판은 따로 붙인다.
static func charger(p: Dictionary) -> RigBuilder:
	var s: float = _v(p, "scale", 1.0)
	var hide_top: Color = _v(p, "top", Color(0.34, 0.32, 0.29))
	var hide_bottom: Color = _v(p, "bottom", Color(0.5, 0.46, 0.4))
	var q := {
		"scale": s, "height": 1.72, "length": 1.35, "chest": Vector2(0.6, 0.7), "waist": Vector2(0.55, 0.6),
		"hip": Vector2(0.56, 0.62), "belly": 0.06, "kind": K.HIDE, "top": hide_top, "bottom": hide_bottom,
		"neck_len": 0.4, "neck_pitch": -8.0, "neck_r": Vector2(0.42, 0.46), "skull_len": 0.5, "skull": Vector2(0.34, 0.33),
		"snout_len": 0.34, "snout": Vector2(0.2, 0.18), "head_drop": 0.35, "leg_upper": 0.24, "leg_lower": 0.17, "foot": 0.2,
		"tail_len": 0.55, "tail_r": 0.1, "ear_len": 0.14, "ear_w": 0.07, "ear_dir": Vector3(0.9, 0.3, 0.3),
		"eye": _v(p, "eye", Color(0.9, 0.55, 0.15)), "eye_scale": 1.1, "hoof_col": Color(0.2, 0.18, 0.15),
		"pattern": SpeciesModels.mottle(0.12, 2.0),
	}
	var b := heavy_quad(q)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_v(p, "seed", 7))
	var moss: float = _v(p, "moss", 0.6)
	var rock: Color = _v(p, "rock", Color(0.42, 0.4, 0.37))
	# 등의 바위 껍질: 어깨부터 엉덩이까지 등을 덮는 판 모양 바위들(이름 그대로 "바위등")
	var shell: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 1.5 * s, 0.75 * s), 0.42 * s, 0.2 * s, &"pelvis"),
		RigBuilder.pt(Vector3(0, 1.62 * s, 0.35 * s), 0.55 * s, 0.26 * s, &"pelvis"),
		RigBuilder.pt(Vector3(0, 1.68 * s, -0.1 * s), 0.6 * s, 0.28 * s, &"spine"),
		RigBuilder.pt(Vector3(0, 1.7 * s, -0.55 * s), 0.55 * s, 0.25 * s, &"chest"),
		RigBuilder.pt(Vector3(0, 1.58 * s, -0.85 * s), 0.4 * s, 0.16 * s, &"chest"),
	]
	var moss_col := Color(0.25, 0.36, 0.15)
	b.loft(shell, K.STONE, rock, rock.darkened(0.35), 22, 4, Vector3.UP, true, true,
		func(v: Vector3, n: Vector3, c: Color) -> Color:
			var crack := smoothstep(0.06, 0.0, absf(SpeciesModels.noise3(v * 2.4 / s)))
			var col := c.darkened(crack * 0.55)
			var m := smoothstep(0.35, 0.85, n.y) * smoothstep(0.1, 0.5, SpeciesModels.noise3(v * 1.6 / s + Vector3(4, 0, 2)) + moss * 0.5)
			return Color(col.lerp(moss_col, m * 0.9), c.a))
	rock_lumps(b, &"chest", Vector3(0, 1.86 * s, -0.5 * s), 4, 0.24 * s, rng, moss, rock)
	rock_lumps(b, &"spine", Vector3(0, 1.84 * s, 0.0), 5, 0.26 * s, rng, moss, rock)
	rock_lumps(b, &"pelvis", Vector3(0, 1.74 * s, 0.5 * s), 3, 0.22 * s, rng, moss, rock)
	# 등 뒤 배기공(약점): 붉게 달아오른 구멍
	var vent := Vector3(0, 1.6 * s, 0.95 * s)
	b.ellipsoid(vent, Vector3(0.2, 0.08, 0.16) * s, &"pelvis", K.STONE, Color(0.2, 0.17, 0.15))
	b.ellipsoid(vent + Vector3(0, 0.035, 0) * s, Vector3(0.12, 0.04, 0.1) * s, &"pelvis", K.GLOW, _v(p, "vent_col", Color(1.0, 0.45, 0.15)))
	b.socket(&"vent", &"pelvis", Transform3D(Basis(), vent - b.bone_pos(&"pelvis")))
	# 뿔: 머리 옆으로 휜 굵은 뿔(황금뿔은 금빛)
	var horn_col: Color = _v(p, "horn", Color(0.55, 0.5, 0.42))
	var horn_tip: Color = _v(p, "horn_tip", Color(0.85, 0.8, 0.7))
	var head_pos := b.bone_pos(&"head")
	for side: float in [-1.0, 1.0]:
		var base_p := head_pos + Vector3(side * 0.3, 0.12, -0.28) * s
		b.cone(base_p, base_p + Vector3(side * 0.42, 0.28, -0.35) * s, 0.12 * s, &"head", K.HORN, horn_col,
			Vector3(side * 0.05, 0.12, 0.05) * s, 12, horn_tip)
	if _v(p, "nose_horn", false):
		var nb := head_pos + Vector3(0, 0.05, -0.75) * s
		b.cone(nb, nb + Vector3(0, 0.45, -0.25) * s, 0.1 * s, &"head", K.HORN, horn_col, Vector3(0, 0.05, 0.08) * s, 12, horn_tip)
	return b


## 이끼등 새끼: 둥글고 작은 몸, 큰 눈, 등에는 이끼와 작은 돌만 있다.
static func mossback_calf() -> RigBuilder:
	var s := 0.5
	var q := {
		"scale": s, "height": 1.6, "length": 1.1, "chest": Vector2(0.62, 0.7), "waist": Vector2(0.6, 0.66),
		"hip": Vector2(0.6, 0.64), "belly": 0.1, "kind": K.HIDE, "top": Color(0.38, 0.36, 0.3), "bottom": Color(0.58, 0.54, 0.46),
		"neck_len": 0.36, "neck_pitch": 5.0, "neck_r": Vector2(0.42, 0.46), "skull_len": 0.5, "skull": Vector2(0.38, 0.37),
		"snout_len": 0.28, "snout": Vector2(0.24, 0.22), "head_drop": 0.25, "leg_upper": 0.24, "leg_lower": 0.19, "foot": 0.21,
		"tail_len": 0.4, "tail_r": 0.1, "ear_len": 0.2, "ear_w": 0.1, "ear_dir": Vector3(0.9, 0.35, 0.3),
		"eye": Color(0.35, 0.25, 0.12), "eye_scale": 1.6, "pattern": SpeciesModels.mottle(0.1, 3.0),
	}
	var b := heavy_quad(q)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	rock_lumps(b, &"spine", Vector3(0, 1.62 * s, 0.0), 4, 0.2 * s, rng, 0.9)
	rock_lumps(b, &"chest", Vector3(0, 1.62 * s, -0.4 * s), 2, 0.18 * s, rng, 0.9)
	var moss: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 1.58 * s, 0.5 * s), 0.35 * s, 0.1 * s, &"pelvis"),
		RigBuilder.pt(Vector3(0, 1.62 * s, 0.0), 0.45 * s, 0.12 * s, &"spine"),
		RigBuilder.pt(Vector3(0, 1.62 * s, -0.45 * s), 0.4 * s, 0.1 * s, &"chest"),
	]
	b.loft(moss, K.FUR, Color(0.28, 0.4, 0.18), Color(0.22, 0.3, 0.14), 16, 3)
	return b


# --- 가시등 멧돼지 ---

## 가시등 멧돼지: 짧은 다리, 큰 머리와 휜 엄니, 등을 따라 선 가시 갈기, 거친 털.
static func thorn_boar() -> RigBuilder:
	var q := {
		"scale": 1.0, "height": 0.95, "length": 0.78, "chest": Vector2(0.28, 0.4), "waist": Vector2(0.25, 0.33),
		"hip": Vector2(0.26, 0.35), "belly": 0.03, "kind": K.FUR, "top": Color(0.2, 0.16, 0.13), "bottom": Color(0.36, 0.3, 0.24),
		"neck_len": 0.22, "neck_pitch": 0.0, "neck_r": Vector2(0.24, 0.3), "skull_len": 0.3, "skull": Vector2(0.17, 0.2),
		"snout_len": 0.28, "snout": Vector2(0.075, 0.075), "head_drop": 0.35, "leg_upper": 0.085, "leg_lower": 0.045,
		"foot": 0.05, "tail_len": 0.25, "tail_r": 0.02, "ear_len": 0.13, "ear_w": 0.055, "ear_dir": Vector3(0.5, 0.8, 0.3),
		"eye": Color(0.3, 0.12, 0.06), "fur_length": 0.035, "fur_density": 6.0, "nose_col": Color(0.3, 0.2, 0.2),
		"pattern": SpeciesModels.mottle(0.18, 6.0),
	}
	var b := heavy_quad(q)
	# 등을 따라 선 가시(갈기 속 가시)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 11:
		var t := float(i) / 10.0
		var z := lerpf(-0.42, 0.42, t)
		var y := 0.95 + 0.04 * sin(t * PI)
		var bone_name: StringName = &"chest" if z < -0.15 else (&"spine" if z < 0.2 else &"pelvis")
		for side: float in [-1.0, 0.0, 1.0]:
			var base_p := Vector3(side * 0.05, y - 0.03, z + rng.randf_range(-0.03, 0.03))
			var h := rng.randf_range(0.14, 0.24) * (1.0 - absf(side) * 0.3)
			b.cone(base_p, base_p + Vector3(side * 0.06, h, 0.06), 0.022, bone_name, K.HORN, Color(0.3, 0.26, 0.2),
				Vector3.ZERO, 6, Color(0.8, 0.75, 0.6))
	# 엄니
	var head_pos := b.bone_pos(&"head")
	var fwd := Vector3(0, -sin(0.35), -cos(0.35))
	for side: float in [-1.0, 1.0]:
		var base_p := head_pos + fwd * 0.48 + Vector3(side * 0.06, -0.09, 0)
		b.cone(base_p, base_p + Vector3(side * 0.07, 0.12, -0.04), 0.022, &"jaw", K.TEETH, Color(0.9, 0.86, 0.74),
			Vector3(side * 0.02, 0.0, 0.02), 8)
	return b


# --- 늪 두꺼비 ---

## 늪 두꺼비: 납작하고 넓은 몸, 넓은 입, 머리 위로 튀어나온 눈, 접힌 굵은 뒷다리, 사마귀 돋은 젖은 피부.
static func bog_toad() -> RigBuilder:
	var s := 1.0
	var b := RigBuilder.new()
	var top := Color(0.3, 0.33, 0.2)
	var bottom := Color(0.72, 0.68, 0.5)
	var mot := SpeciesModels.mottle(0.15, 4.0)
	b.pattern = func(v: Vector3, n: Vector3, c: Color) -> Color:
		var col: Color = mot.call(v, n, c)
		# 등의 짙은 얼룩
		var spot := smoothstep(0.35, 0.55, SpeciesModels.noise3(v * 6.0 + Vector3(3, 0, 1)))
		col = col.lerp(Color(0.14, 0.16, 0.09), spot * smoothstep(0.2, 0.7, n.y) * 0.7)
		return Color(col, c.a)
	var P := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * s
	b.bone(&"root", &"", P.call(0, 0.35, 0.05))
	b.bone(&"pelvis", &"root", P.call(0, 0.32, 0.3))
	b.bone(&"spine", &"root", P.call(0, 0.38, 0.05))
	b.bone(&"chest", &"spine", P.call(0, 0.38, -0.2))
	b.bone(&"neck", &"chest", P.call(0, 0.4, -0.35))
	b.bone(&"head", &"neck", P.call(0, 0.42, -0.45))
	b.bone(&"jaw", &"head", P.call(0, 0.32, -0.42))
	b.bone(&"ear_l", &"head", P.call(-0.15, 0.55, -0.5))
	b.bone(&"ear_r", &"head", P.call(0.15, 0.55, -0.5))
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		b.bone(StringName("fl_upper_" + sn), &"chest", P.call(side * 0.26, 0.3, -0.28))
		b.bone(StringName("fl_lower_" + sn), StringName("fl_upper_" + sn), P.call(side * 0.36, 0.16, -0.36))
		b.bone(StringName("fl_foot_" + sn), StringName("fl_lower_" + sn), P.call(side * 0.38, 0.03, -0.42))
		b.bone(StringName("hl_upper_" + sn), &"pelvis", P.call(side * 0.3, 0.3, 0.3))
		b.bone(StringName("hl_lower_" + sn), StringName("hl_upper_" + sn), P.call(side * 0.46, 0.2, 0.05))
		b.bone(StringName("hl_foot_" + sn), StringName("hl_lower_" + sn), P.call(side * 0.44, 0.05, 0.45))
	# 넓적한 몸통(가로로 넓은 단면)
	var body: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 0.3, 0.48), 0.26 * s, 0.16 * s, &"pelvis"),
		RigBuilder.pt(P.call(0, 0.34, 0.3), 0.4 * s, 0.24 * s, &"pelvis"),
		RigBuilder.pt(P.call(0, 0.37, 0.05), 0.46 * s, 0.27 * s, &"spine"),
		RigBuilder.pt(P.call(0, 0.37, -0.2), 0.42 * s, 0.25 * s, &"chest"),
		RigBuilder.pt(P.call(0, 0.38, -0.36), 0.38 * s, 0.2 * s, &"neck"),
	]
	b.loft(body, K.WET_SKIN, top, bottom, 24, 4)
	# 넓은 머리와 입
	var head: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 0.42, -0.36), 0.37 * s, 0.17 * s, &"head"),
		RigBuilder.pt(P.call(0, 0.42, -0.5), 0.34 * s, 0.14 * s, &"head"),
		RigBuilder.pt(P.call(0, 0.4, -0.62), 0.22 * s, 0.1 * s, &"head"),
	]
	b.loft(head, K.WET_SKIN, top, bottom, 22, 4)
	var jaw: Array[RigBuilder.P] = [
		RigBuilder.pt(P.call(0, 0.3, -0.34), 0.34 * s, 0.1 * s, &"jaw"),
		RigBuilder.pt(P.call(0, 0.29, -0.52), 0.3 * s, 0.07 * s, &"jaw"),
		RigBuilder.pt(P.call(0, 0.3, -0.62), 0.18 * s, 0.05 * s, &"jaw"),
	]
	b.loft(jaw, K.WET_SKIN, bottom.lerp(top, 0.3), bottom, 20, 3)
	# 입 선
	b.ellipsoid(P.call(0, 0.345, -0.55), Vector3(0.3, 0.012, 0.1) * s, &"head", K.WET_SKIN, Color(0.1, 0.08, 0.06))
	# 튀어나온 눈
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var eb := b.bone_pos(StringName("ear_" + sn))
		b.ellipsoid(eb + P.call(0, -0.02, 0), Vector3(0.075, 0.06, 0.075) * s, &"head", K.WET_SKIN, top)
		b.eye(eb + P.call(side * 0.01, 0.02, -0.03), 0.055 * s, &"head", Vector3(side * 0.6, 0.35, -0.7), Color(0.85, 0.6, 0.1),
			Color(0.55, 0.45, 0.15), 0.55, 1.2)
	# 다리
	for side: float in [-1.0, 1.0]:
		var sn := "l" if side < 0.0 else "r"
		var fu := b.bone_pos(StringName("fl_upper_" + sn))
		var fl := b.bone_pos(StringName("fl_lower_" + sn))
		var ff := b.bone_pos(StringName("fl_foot_" + sn))
		var fore: Array[RigBuilder.P] = [
			RigBuilder.pt(fu + P.call(-side * 0.06, 0.06, 0), 0.09 * s, 0.08 * s, &"chest"),
			RigBuilder.pt(fu, 0.07 * s, 0.065 * s, StringName("fl_upper_" + sn)),
			RigBuilder.pt(fl, 0.05 * s, 0.05 * s, StringName("fl_lower_" + sn)),
			RigBuilder.pt(ff + P.call(0, 0.02, 0), 0.045 * s, 0.04 * s, StringName("fl_foot_" + sn)),
		]
		b.loft(fore, K.WET_SKIN, top, bottom, 12, 3, Vector3.FORWARD)
		for f in 3:
			var ang := deg_to_rad(-40.0 + 40.0 * f) * side
			var dirv := Vector3(sin(ang) * side * -1.0, 0, -cos(ang))
			b.cone(ff + P.call(0, -0.01, 0), ff + dirv * 0.12 * s + P.call(0, -0.02, 0), 0.02 * s,
				StringName("fl_foot_" + sn), K.WET_SKIN, top, Vector3.ZERO, 6, bottom)
		var hu := b.bone_pos(StringName("hl_upper_" + sn))
		var hl := b.bone_pos(StringName("hl_lower_" + sn))
		var hf := b.bone_pos(StringName("hl_foot_" + sn))
		var hind: Array[RigBuilder.P] = [
			RigBuilder.pt(hu + P.call(-side * 0.08, 0.04, 0), 0.14 * s, 0.13 * s, &"pelvis"),
			RigBuilder.pt(hu.lerp(hl, 0.5), 0.12 * s, 0.11 * s, StringName("hl_upper_" + sn)),
			RigBuilder.pt(hl, 0.07 * s, 0.07 * s, StringName("hl_lower_" + sn)),
			RigBuilder.pt(hl.lerp(hf, 0.5) + P.call(0, -0.04, 0), 0.06 * s, 0.06 * s, StringName("hl_lower_" + sn)),
			RigBuilder.pt(hf, 0.05 * s, 0.045 * s, StringName("hl_foot_" + sn)),
		]
		b.loft(hind, K.WET_SKIN, top, bottom, 12, 3, Vector3.FORWARD)
		for f in 4:
			var spread := deg_to_rad(-30.0 + 20.0 * f)
			var dirv := Vector3(sin(spread) * side, 0, -cos(spread))
			b.cone(hf, hf + dirv * 0.2 * s + P.call(0, -0.03, 0), 0.022 * s, StringName("hl_foot_" + sn), K.WET_SKIN, top,
				Vector3.ZERO, 6, bottom)
	# 사마귀
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 26:
		var a := rng.randf() * TAU
		var z := rng.randf_range(-0.3, 0.45)
		var wp := P.call(cos(a) * 0.38 * sqrt(1.0 - (z * 0.9) * (z * 0.9)), 0.37 + absf(sin(a)) * 0.2, z) as Vector3
		if sin(a) < 0.0:
			continue
		b.ellipsoid(wp, Vector3.ONE * rng.randf_range(0.015, 0.03) * s, &"spine", K.WET_SKIN, top.darkened(0.25))
	b.socket(&"head", &"head", Transform3D(Basis(), P.call(0, 0.02, -0.08)))
	b.socket(&"mouth", &"head", Transform3D(Basis(), P.call(0, -0.07, -0.17)))
	b.socket(&"belly", &"spine", Transform3D(Basis(), P.call(0, -0.2, 0)))
	return b

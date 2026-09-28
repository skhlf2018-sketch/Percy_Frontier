class_name HandModel
extends RefCounted
## 1인칭 손(기획서 §23.4): 장갑 낀 손과 소매. 무기를 쥔 자세로 만든다.
##  - grip: 권총 손잡이처럼 세로(+Y) 축을 감싸 쥔 오른손. 검지는 방아쇠 쪽으로 곧게 뻗거나(총) 함께 감싼다(근접 무기).
##  - support: 총열 덮개처럼 앞뒤(-Z) 축을 아래에서 받친 왼손. 손가락은 오른쪽 위로 감아 올리고 엄지는 왼쪽에 붙인다.
## 손의 원점은 쥔 축의 가운데이고, 소매는 sleeve_dir 방향(카메라 쪽 화면 밖)으로 뻗는다.
## 모양은 RigBuilder의 관을 쓰되 뼈 없이 고정 메시로 쓴다. 정점 색: 장갑·소매 색.
## 결과는 {&"leather": 장갑 메시, &"cloth": 소매 메시}로 나눠 돌려준다(부위마다 재질을 따로 입힌다).

const K := CreatureMaterials.Kind

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## 세로 축(반지름 r)을 감싸 쥔 오른손. trigger_finger: 검지를 앞(-Z)으로 곧게 뻗는다.
static func grip(r: float, glove: Color, sleeve: Color, sleeve_dir: Vector3, trigger_finger: bool) -> Dictionary:
	var key := "g_%.3f_%s_%s_%s_%s" % [r, glove.to_html(), sleeve.to_html(), str(sleeve_dir), trigger_finger]
	if _cache.has(key):
		return _cache[key]
	var b := RigBuilder.new()
	b.bone(&"root", &"", Vector3.ZERO)
	var knuckle_x := r + 0.022
	# 손바닥·손등: 축의 오른쪽(+X)에 붙는다.
	b.ellipsoid(Vector3(knuckle_x - 0.004, -0.006, 0.012), Vector3(0.019, 0.048, 0.042), &"root", K.LEATHER, glove, glove.darkened(0.15), 14)
	# 손가락 넷(검지·중지·약지·새끼): 오른쪽 옆에서 앞(-Z)을 돌아 왼쪽 옆까지 감는다.
	var fingers := [[0.034, 0.0098], [0.012, 0.0102], [-0.01, 0.0098], [-0.03, 0.0088]]
	for i in fingers.size():
		var y: float = fingers[i][0]
		var fr: float = fingers[i][1]
		if i == 0 and trigger_finger:
			# 검지: 방아쇠울 옆을 따라 앞으로 곧게
			var idx: Array[RigBuilder.P] = [
				RigBuilder.pt(Vector3(knuckle_x - 0.004, y + 0.012, -0.012), fr, fr, &"root"),
				RigBuilder.pt(Vector3(r + 0.012, y + 0.014, -0.045), fr * 0.95, fr * 0.95, &"root"),
				RigBuilder.pt(Vector3(r + 0.006, y + 0.012, -0.075), fr * 0.85, fr * 0.85, &"root"),
			]
			b.loft(idx, K.LEATHER, glove, glove.darkened(0.12), 8, 3)
			continue
		var pts: Array[RigBuilder.P] = []
		var R := r + fr + 0.001
		var steps := 6
		for s in steps:
			var t := float(s) / float(steps - 1)
			var ang := deg_to_rad(lerpf(18.0, -200.0, t))
			var p := Vector3(cos(ang) * R, y - t * 0.004, sin(ang) * R)
			if s == 0:
				p = Vector3(knuckle_x, y, -0.006)
			pts.append(RigBuilder.pt(p, fr * lerpf(1.0, 0.86, t), fr * lerpf(1.0, 0.86, t), &"root"))
		b.loft(pts, K.LEATHER, glove, glove.darkened(0.12), 8, 3)
	# 엄지: 손바닥 위쪽 뒤에서 축 뒤(+Z)를 돌아 왼쪽 위로
	var thumb: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(knuckle_x - 0.006, 0.028, 0.03), 0.012, 0.012, &"root"),
		RigBuilder.pt(Vector3(r * 0.4, 0.046, r + 0.016), 0.0105, 0.0105, &"root"),
		RigBuilder.pt(Vector3(-r - 0.004, 0.05, 0.006), 0.0095, 0.0095, &"root"),
	]
	b.loft(thumb, K.LEATHER, glove, glove.darkened(0.12), 8, 3)
	_wrist_and_sleeve(b, Vector3(knuckle_x - 0.002, -0.05, 0.03), sleeve_dir, glove, sleeve)
	var parts := _split(b.build().mesh)
	_cache[key] = parts
	return parts


## 앞뒤(-Z) 축(반지름 r)을 아래에서 받친 왼손
static func support(r: float, glove: Color, sleeve: Color, sleeve_dir: Vector3) -> Dictionary:
	var key := "s_%.3f_%s_%s_%s" % [r, glove.to_html(), sleeve.to_html(), str(sleeve_dir)]
	if _cache.has(key):
		return _cache[key]
	var b := RigBuilder.new()
	b.bone(&"root", &"", Vector3.ZERO)
	# 손바닥: 축 아래
	b.ellipsoid(Vector3(-0.006, -r - 0.016, 0.004), Vector3(0.042, 0.018, 0.048), &"root", K.LEATHER, glove, glove.darkened(0.15), 14)
	# 손가락 넷: 아래에서 오른쪽(+X)을 돌아 위쪽으로 감는다(축 방향으로 나란히).
	for i in 4:
		var z := -0.034 + float(i) * 0.022
		var fr := 0.0098 if i < 3 else 0.0086
		var pts: Array[RigBuilder.P] = []
		var R := r + fr + 0.001
		for s in 5:
			var t := float(s) / 4.0
			var ang := deg_to_rad(lerpf(-80.0, 35.0, t))
			var p := Vector3(cos(ang) * R, sin(ang) * R, z)
			pts.append(RigBuilder.pt(p, fr * lerpf(1.0, 0.86, t), fr * lerpf(1.0, 0.86, t), &"root"))
		b.loft(pts, K.LEATHER, glove, glove.darkened(0.12), 8, 3, Vector3.FORWARD)
	# 엄지: 왼쪽 옆을 따라 앞으로
	var thumb: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(-0.03, -r - 0.004, 0.03), 0.012, 0.012, &"root"),
		RigBuilder.pt(Vector3(-r - 0.012, -0.004, 0.0), 0.0105, 0.0105, &"root"),
		RigBuilder.pt(Vector3(-r - 0.008, 0.012, -0.03), 0.0095, 0.0095, &"root"),
	]
	b.loft(thumb, K.LEATHER, glove, glove.darkened(0.12), 8, 3)
	_wrist_and_sleeve(b, Vector3(-0.018, -r - 0.03, 0.045), sleeve_dir, glove, sleeve)
	var parts := _split(b.build().mesh)
	_cache[key] = parts
	return parts


## 손목(장갑 끝)과 소매: at에서 dir 쪽으로 화면 밖까지 뻗는다. 소매 끝에는 접힌 단이 있다.
static func _wrist_and_sleeve(b: RigBuilder, at: Vector3, dir: Vector3, glove: Color, sleeve: Color) -> void:
	var d := dir.normalized()
	var wrist: Array[RigBuilder.P] = [
		RigBuilder.pt(at - d * 0.02, 0.028, 0.022, &"root"),
		RigBuilder.pt(at + d * 0.04, 0.027, 0.023, &"root"),
		RigBuilder.pt(at + d * 0.075, 0.03, 0.026, &"root"),
	]
	b.loft(wrist, K.LEATHER, glove, glove.darkened(0.1), 12, 2, Vector3.UP, true, false)
	var cuff := at + d * 0.07
	var arm: Array[RigBuilder.P] = [
		RigBuilder.pt(cuff, 0.039, 0.035, &"root"),
		RigBuilder.pt(cuff + d * 0.015, 0.041, 0.037, &"root"),
		RigBuilder.pt(cuff + d * 0.03, 0.038, 0.034, &"root"),
		RigBuilder.pt(cuff + d * 0.2, 0.045, 0.041, &"root"),
		RigBuilder.pt(cuff + d * 0.42, 0.05, 0.046, &"root"),
	]
	b.loft(arm, K.CLOTH, sleeve, sleeve.darkened(0.2), 14, 3, Vector3.UP, true, false)


## 재질(가죽·천)별로 면을 나눠 따로 된 메시로 만든다. 뼈 정보는 뺀다.
static func _split(mesh: ArrayMesh) -> Dictionary:
	var out := {}
	var cloth := CreatureMaterials.get_material(K.CLOTH)
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		var part := ArrayMesh.new()
		part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out[&"cloth" if mesh.surface_get_material(i) == cloth else &"leather"] = part
	return out

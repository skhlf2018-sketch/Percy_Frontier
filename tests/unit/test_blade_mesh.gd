extends TestCase
## 곡선 날·손잡이·고리 메시(BladeMesh): 초승달 윤곽, 단면 두께, 바깥을 보는 법선, 닫힌 고리.


func after_each() -> void:
	BladeMesh.clear_cache()


func _straight(n: int, width: float) -> Array[PackedVector2Array]:
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for i in n:
		var y := 0.1 * float(i) / float(n - 1)
		a.append(Vector2(0.0, y))
		b.append(Vector2(width, y))
	var out: Array[PackedVector2Array] = [a, b]
	return out


func _thick(n: int, t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		out.append(t)
	return out


func test_crescent_horns_meet_and_bulge_outward() -> void:
	var co := Vector2(-0.06, 0.12)
	var ci := Vector2(-0.16, 0.12)
	var ro := Vector2(0.0, 0.0).distance_to(co)
	var ri := Vector2(0.0, 0.0).distance_to(ci)
	var sides := BladeMesh.crescent(co, ro, ci, ri, 21)
	var inner := sides[0]
	var outer := sides[1]
	assert_eq(inner.size(), 21)
	assert_lt(inner[0].distance_to(outer[0]), 0.0005, "아래 뿔에서 두 호가 만난다")
	assert_lt(inner[20].distance_to(outer[20]), 0.0005, "위 뿔에서 두 호가 만난다")
	assert_gt(inner[10].distance_to(outer[10]), 0.02, "가운데가 가장 두툼하다")
	assert_near(outer[10].x, co.x + ro, 0.002, "볼록한 쪽이 바깥(+X)으로 부푼다")


func test_single_edge_band_has_edge_part_and_outward_normals() -> void:
	var sides := _straight(12, 0.02)
	var parts := BladeMesh.band(sides[0], sides[1], _thick(12, 0.002), BladeMesh.Profile.SINGLE_EDGE)
	var body: ArrayMesh = parts[&"body"]
	var edge: ArrayMesh = parts[&"edge"]
	assert_not_null(body)
	assert_not_null(edge, "날 쪽 비탈은 따로 된 메시")
	for mesh: ArrayMesh in [body, edge]:
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		assert_gt(verts.size(), 30)
		for i in verts.size():
			assert_near(normals[i].length(), 1.0, 0.01, "법선 길이")
			# 평평한 칼몸: 두께 쪽(Z)에 있는 점의 법선은 같은 쪽을 본다(양 끝 막음은 길이 방향을 보므로 뺀다).
			if absf(normals[i].y) < 0.5 and absf(verts[i].z) > 0.0015 and verts[i].x > 0.001 and verts[i].x < 0.015:
				assert_gt(normals[i].z * signf(verts[i].z), 0.0, "법선이 바깥을 본다")


func test_edge_is_thin_and_spine_is_thick() -> void:
	var sides := _straight(6, 0.02)
	var body: ArrayMesh = BladeMesh.band(sides[0], sides[1], _thick(6, 0.002), BladeMesh.Profile.SINGLE_EDGE)[&"body"]
	var edge: ArrayMesh = BladeMesh.band(sides[0], sides[1], _thick(6, 0.002), BladeMesh.Profile.SINGLE_EDGE)[&"edge"]
	var max_edge_z := 0.0
	for v: Vector3 in edge.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		max_edge_z = maxf(max_edge_z, absf(v.z))
	var max_body_z := 0.0
	for v: Vector3 in body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		max_body_z = maxf(max_body_z, absf(v.z))
	assert_near(max_body_z, 0.002, 0.0001, "등이 가장 두껍다")
	assert_lt(max_edge_z, 0.0005, "날 끝은 얇다")


func test_closed_ring_has_no_caps_or_edge() -> void:
	var inner := BladeMesh.circle(Vector2.ZERO, 0.012, 24)
	var outer := BladeMesh.circle(Vector2.ZERO, 0.019, 24)
	var parts := BladeMesh.band(inner, outer, _thick(24, 0.005), BladeMesh.Profile.ROUNDED, true)
	assert_null(parts[&"edge"], "고리에는 날이 없다")
	var verts: PackedVector3Array = (parts[&"body"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# 단면 8점 × 띠 8개 × 24구간 × 삼각형 2개 × 점 3개
	assert_eq(verts.size(), 8 * 24 * 2 * 3, "닫힌 고리는 끝 막음이 없다")
	for v in verts:
		var r := Vector2(v.x, v.y).length()
		assert_true(r > 0.0115 and r < 0.0195, "고리 두께 안")


func test_band_cache_reuses_meshes() -> void:
	var sides := _straight(5, 0.01)
	var a := BladeMesh.band(sides[0], sides[1], _thick(5, 0.001), BladeMesh.Profile.DOUBLE_EDGE, false, "test_key")
	var b := BladeMesh.band(sides[0], sides[1], _thick(5, 0.001), BladeMesh.Profile.DOUBLE_EDGE, false, "test_key")
	assert_true(a[&"body"] == b[&"body"], "같은 이름이면 같은 메시를 다시 쓴다")

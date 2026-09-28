class_name FieldTerrain
extends Node3D
## 퍼시 외곽권 지형. FieldLayout의 높이로 격자(2m 간격)를 만들고,
## 같은 격자로 메시(구역별로 나눠 화면 밖 구역을 그리지 않는다)와 충돌체를 만든다.

const TERRAIN_SHADER := preload("res://assets/shaders/terrain.gdshader")
const WATER_SHADER := preload("res://assets/shaders/water.gdshader")

const CELL := 2.0
const CELLS := 256
const SIDE := CELLS + 1
const CHUNK_CELLS := 32

var layout: FieldLayout
var heights := PackedFloat32Array()
var colors := PackedColorArray()
## 지표 종류 비율(흙길, 진흙, 낙엽, 자갈). 지형 셰이더가 결을 섞는 데 쓴다.
var weights := PackedColorArray()


func build(field_layout: FieldLayout) -> void:
	layout = field_layout
	_compute()
	_build_meshes()
	_build_collision()
	_build_water()


func _compute() -> void:
	heights.resize(SIDE * SIDE)
	colors.resize(SIDE * SIDE)
	weights.resize(SIDE * SIDE)
	var half := FieldLayout.HALF_SIZE
	for zi in SIDE:
		var z := -half + zi * CELL
		for xi in SIDE:
			var x := -half + xi * CELL
			var h := layout.height(x, z)
			heights[zi * SIDE + xi] = h
			colors[zi * SIDE + xi] = layout.ground_color(Vector2(x, z), h)
			weights[zi * SIDE + xi] = layout.ground_weights(Vector2(x, z), h)


# --- 조회 ---

## 격자를 보간한 지면 높이(충돌체와 같다)
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + FieldLayout.HALF_SIZE) / CELL, 0.0, CELLS - 0.001)
	var fz := clampf((z + FieldLayout.HALF_SIZE) / CELL, 0.0, CELLS - 0.001)
	var xi := int(fx)
	var zi := int(fz)
	var tx := fx - xi
	var tz := fz - zi
	var h00 := heights[zi * SIDE + xi]
	var h10 := heights[zi * SIDE + xi + 1]
	var h01 := heights[(zi + 1) * SIDE + xi]
	var h11 := heights[(zi + 1) * SIDE + xi + 1]
	# 충돌체 삼각형 분할과 같은 방식(대각선 기준)으로 보간한다.
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func point_at(p: Vector2) -> Vector3:
	return Vector3(p.x, height_at(p.x, p.y), p.y)


func is_underwater(x: float, z: float) -> bool:
	return height_at(x, z) < FieldLayout.WATER_LEVEL - 0.05


# --- 메시 ---

func _vertex_normal(xi: int, zi: int) -> Vector3:
	var l := heights[zi * SIDE + maxi(xi - 1, 0)]
	var r := heights[zi * SIDE + mini(xi + 1, SIDE - 1)]
	var d := heights[maxi(zi - 1, 0) * SIDE + xi]
	var u := heights[mini(zi + 1, SIDE - 1) * SIDE + xi]
	return Vector3(l - r, 2.0 * CELL, d - u).normalized()


## 지형 재질: 지표 결 텍스처를 넣는다.
static func make_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	for kind in TerrainTextures.KINDS:
		mat.set_shader_parameter(StringName("tex_%s" % kind), TerrainTextures.get_texture(kind))
	return mat


func _build_meshes() -> void:
	var mat := make_material()
	var chunks := CELLS / CHUNK_CELLS
	var half := FieldLayout.HALF_SIZE
	for cz in chunks:
		for cx in chunks:
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var cols := PackedColorArray()
			var custom := PackedByteArray()
			var indices := PackedInt32Array()
			var n := CHUNK_CELLS + 1
			for j in n:
				var zi := cz * CHUNK_CELLS + j
				for i in n:
					var xi := cx * CHUNK_CELLS + i
					verts.append(Vector3(-half + xi * CELL, heights[zi * SIDE + xi], -half + zi * CELL))
					normals.append(_vertex_normal(xi, zi))
					cols.append(colors[zi * SIDE + xi])
					var wgt := weights[zi * SIDE + xi]
					custom.append_array([int(wgt.r * 255.0), int(wgt.g * 255.0), int(wgt.b * 255.0), int(wgt.a * 255.0)])
			for j in CHUNK_CELLS:
				for i in CHUNK_CELLS:
					var a := j * n + i
					var b := a + 1
					var c := a + n
					var d := c + 1
					# 충돌체(HeightMapShape3D)와 같은 대각선으로 나눈다.
					indices.append_array([a, b, c, b, d, c])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_CUSTOM0] = custom
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
				Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cz]
			mi.mesh = mesh
			mi.material_override = mat
			add_child(mi)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = CombatLayers.WORLD
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	shape.map_width = SIDE
	shape.map_depth = SIDE
	# 충돌체는 균일 배율(2배)로 키우므로 높이는 절반으로 넣는다.
	var data := PackedFloat32Array()
	data.resize(SIDE * SIDE)
	for i in SIDE * SIDE:
		data[i] = heights[i] / CELL
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * CELL
	body.add_child(cs)
	add_child(body)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(FieldLayout.HALF_SIZE * 2.0, FieldLayout.HALF_SIZE * 2.0)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter(&"murk_a", Vector4(FieldLayout.POND_CENTER.x, FieldLayout.POND_CENTER.y, FieldLayout.POND_RADIUS + 15.0, 0.0))
	mat.set_shader_parameter(&"murk_b", Vector4(FieldLayout.MAW_CENTER.x, FieldLayout.MAW_CENTER.y,
		FieldLayout.MAW_RADIUS + FieldLayout.MAW_BLEND + 3.0, 0.0))
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = mat
	water.position.y = FieldLayout.WATER_LEVEL
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

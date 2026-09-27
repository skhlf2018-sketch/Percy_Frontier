class_name GrassField
extends Node3D
## 플레이어 주변에만 풀밭을 깔고, 멀어진 구역은 치운다(전체 지도에 풀을 미리 깔면 메모리를 많이 쓴다).
## 구역마다 시드가 고정이라 다시 돌아와도 같은 풀이 난다. 한 프레임에 한 구역씩 만들어 끊김을 막는다.

const CHUNK := 16.0
const RADIUS := 60.0
## 1제곱미터당 최대 풀 묶음 수
const MAX_DENSITY := 1.8

var terrain: FieldTerrain
var layout: FieldLayout
var focus: Node3D

var _meshes: Array[Mesh] = []
var _chunks: Dictionary = {}   # Vector2i -> MultiMeshInstance3D


func setup(field_terrain: FieldTerrain, field_layout: FieldLayout) -> void:
	terrain = field_terrain
	layout = field_layout
	for i in 3:
		_meshes.append(MeshKit.grass_tuft(501 + i, 9 + i * 2))


func _process(_delta: float) -> void:
	if focus == null or not is_instance_valid(focus) or terrain == null:
		return
	var p := focus.global_position
	var center := Vector2i(int(floor((p.x + FieldLayout.HALF_SIZE) / CHUNK)), int(floor((p.z + FieldLayout.HALF_SIZE) / CHUNK)))
	var reach := int(ceil(RADIUS / CHUNK))
	# 멀어진 구역 치우기
	for key: Vector2i in _chunks.keys():
		if absi(key.x - center.x) > reach + 1 or absi(key.y - center.y) > reach + 1:
			_chunks[key].queue_free()
			_chunks.erase(key)
	# 가장 가까운 빈 구역 하나 만들기
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := center + Vector2i(dx, dz)
			if _chunks.has(key) or key.x < 0 or key.y < 0 or key.x * CHUNK >= FieldLayout.HALF_SIZE * 2.0 or key.y * CHUNK >= FieldLayout.HALF_SIZE * 2.0:
				continue
			var d := Vector2(dx, dz).length()
			if d * CHUNK > RADIUS + CHUNK:
				continue
			if d < best_d:
				best_d = d
				best = key
	if best_d < INF:
		_chunks[best] = _build_chunk(best)


## 시작할 때 주변 풀을 한꺼번에 만든다(첫 화면에 풀이 비어 보이지 않게).
func fill_now() -> void:
	for i in 80:
		_process(0.0)


func _build_chunk(key: Vector2i) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ FieldLayout.SEED
	var x0 := -FieldLayout.HALF_SIZE + key.x * CHUNK
	var z0 := -FieldLayout.HALF_SIZE + key.y * CHUNK
	var candidates := int(CHUNK * CHUNK * MAX_DENSITY)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in candidates:
		var x := x0 + rng.randf() * CHUNK
		var z := z0 + rng.randf() * CHUNK
		var h := terrain.height_at(x, z)
		var p := Vector2(x, z)
		if rng.randf() > layout.grass_density(p, h):
			continue
		var s := rng.randf_range(0.8, 1.25) * (1.0 + layout.meadow_factor(p) * 0.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
		xforms.append(Transform3D(basis, Vector3(x, h - 0.03, z)))
		var ground := layout.ground_color(p, h)
		colors.append(ground.lightened(0.08).lerp(Color(0.5, 0.6, 0.28), 0.2))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _meshes[rng.randi() % _meshes.size()]
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, Color(colors[i], 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = MeshKit.grass_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func chunk_count() -> int:
	return _chunks.size()

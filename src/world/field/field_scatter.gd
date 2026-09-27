class_name FieldScatter
extends Node3D
## 나무·바위·덤불·들꽃 배치. 종류별 모델을 구역 단위 MultiMesh로 묶어 그리고,
## 나무 밑동과 큰 바위에는 충돌체를 둔다. 같은 시드로 항상 같은 숲이 만들어진다.

const TREE_CHUNK := 128.0
const SMALL_CHUNK := 64.0
const FLOWER_CHUNK := 32.0

enum Kind { BROADLEAF, PINE, DEAD, BUSH, ROCK, FLOWER }

var terrain: FieldTerrain
var layout: FieldLayout
## 배치된 나무 위치(단서 배치 등 다른 시스템이 쓴다)
var tree_positions: Array[Vector3] = []
## 덤불 위치(살인토끼 매복 후보)
var bush_positions: Array[Vector3] = []

var _meshes: Dictionary = {}          # Kind -> Array[Mesh]
var _buckets: Dictionary = {}         # "kind:variant:cx:cz" -> Array[Transform3D]
var _body: StaticBody3D


func build(field_terrain: FieldTerrain, field_layout: FieldLayout) -> void:
	terrain = field_terrain
	layout = field_layout
	_make_meshes()
	_body = StaticBody3D.new()
	_body.name = "ScatterColliders"
	_body.collision_layer = CombatLayers.WORLD
	_body.collision_mask = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = FieldLayout.SEED + 100
	_place_trees(rng)
	_place_rocks(rng)
	_place_bushes(rng)
	_place_flowers(rng)
	_emit_multimeshes()
	# 충돌체를 다 붙인 뒤 한 번에 넣어야 물리 등록이 빠르다.
	add_child(_body)


func _make_meshes() -> void:
	var broadleaf: Array[Mesh] = []
	for i in 4:
		broadleaf.append(MeshKit.broadleaf_tree(11 + i))
	var pine: Array[Mesh] = []
	for i in 3:
		pine.append(MeshKit.pine_tree(31 + i))
	var dead: Array[Mesh] = []
	for i in 2:
		dead.append(MeshKit.dead_tree(51 + i))
	var bushes: Array[Mesh] = []
	for i in 3:
		bushes.append(MeshKit.bush(71 + i))
	var rocks: Array[Mesh] = []
	for i in 4:
		rocks.append(MeshKit.rock(91 + i))
	var flowers: Array[Mesh] = [
		MeshKit.flower_tuft(111, Color(0.95, 0.93, 0.85)),
		MeshKit.flower_tuft(112, Color(0.98, 0.82, 0.25)),
		MeshKit.flower_tuft(113, Color(0.66, 0.5, 0.92)),
	]
	_meshes = {
		Kind.BROADLEAF: broadleaf, Kind.PINE: pine, Kind.DEAD: dead,
		Kind.BUSH: bushes, Kind.ROCK: rocks, Kind.FLOWER: flowers,
	}


func _chunk_size(kind: int) -> float:
	match kind:
		Kind.BROADLEAF, Kind.PINE, Kind.DEAD:
			return TREE_CHUNK
		Kind.FLOWER:
			return FLOWER_CHUNK
	return SMALL_CHUNK


func _add(kind: int, variant: int, xform: Transform3D) -> void:
	var size := _chunk_size(kind)
	var cx := int(floor((xform.origin.x + FieldLayout.HALF_SIZE) / size))
	var cz := int(floor((xform.origin.z + FieldLayout.HALF_SIZE) / size))
	var key := "%d:%d:%d:%d" % [kind, variant, cx, cz]
	if not _buckets.has(key):
		_buckets[key] = []
	_buckets[key].append(xform)


## 경사가 완만하고 물 밖인 곳
func _ground_ok(x: float, z: float, max_slope_y: float = 0.78) -> bool:
	if terrain.height_at(x, z) < FieldLayout.WATER_LEVEL + 0.3:
		return false
	return terrain.normal_at(x, z).y >= max_slope_y


func _place_trees(rng: RandomNumberGenerator) -> void:
	var step := 5.2
	var half := FieldLayout.HALF_SIZE
	var z := -half + step * 0.5
	while z < half:
		var x := -half + step * 0.5
		while x < half:
			var p := Vector2(x + rng.randf_range(-2.2, 2.2), z + rng.randf_range(-2.2, 2.2))
			var density := layout.tree_density(p)
			if rng.randf() < density and _ground_ok(p.x, p.y, 0.72):
				_place_tree(rng, p)
			x += step
		z += step


func _place_tree(rng: RandomNumberGenerator, p: Vector2) -> void:
	var shade := layout.shade_factor(p)
	var edge := FieldLayout.HALF_SIZE - maxf(absf(p.x), absf(p.y))
	var kind := Kind.BROADLEAF
	var roll := rng.randf()
	if shade > 0.5:
		kind = Kind.PINE if roll < 0.62 else (Kind.DEAD if roll < 0.8 else Kind.BROADLEAF)
	elif edge < 55.0 or terrain.height_at(p.x, p.y) > 22.0:
		kind = Kind.PINE if roll < 0.8 else Kind.BROADLEAF
	elif roll < 0.3:
		kind = Kind.PINE
	var variants: Array = _meshes[kind]
	var variant := rng.randi() % variants.size()
	var scale := rng.randf_range(0.85, 1.2) * lerpf(1.0, 1.35, shade)
	var y := terrain.height_at(p.x, p.y) - 0.12
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
	var origin := Vector3(p.x, y, p.y)
	_add(kind, variant, Transform3D(basis, origin))
	tree_positions.append(origin)
	# 밑동 충돌체
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.32 * scale
	shape.height = 5.0
	cs.shape = shape
	cs.position = origin + Vector3.UP * 2.3
	_body.add_child(cs)


func _place_rocks(rng: RandomNumberGenerator) -> void:
	var step := 11.0
	var half := FieldLayout.HALF_SIZE
	var z := -half + step * 0.5
	while z < half:
		var x := -half + step * 0.5
		while x < half:
			var p := Vector2(x + rng.randf_range(-4.5, 4.5), z + rng.randf_range(-4.5, 4.5))
			var slope := 1.0 - terrain.normal_at(p.x, p.y).y
			var chance := 0.08 + slope * 0.45 + (0.18 if layout.distance_to_river(p) < 16.0 else 0.0)
			if layout.road_factor(p) > 0.05 or layout.in_town(p, 6.0):
				chance = 0.0
			if rng.randf() < chance and terrain.height_at(p.x, p.y) > FieldLayout.WATER_LEVEL - 0.6:
				_place_rock(rng, p, rng.randf_range(0.35, 1.0) if rng.randf() < 0.7 else rng.randf_range(1.2, 2.6))
			x += step
		z += step


func _place_rock(rng: RandomNumberGenerator, p: Vector2, scale: float) -> void:
	var n := terrain.normal_at(p.x, p.y)
	var y := terrain.height_at(p.x, p.y) - 0.15 * scale
	var basis := Basis(Vector3.UP, rng.randf() * TAU)
	# 경사면에서는 지면을 따라 기울인다.
	var tilt_axis := Vector3.UP.cross(n)
	if tilt_axis.length() > 0.01:
		basis = Basis(tilt_axis.normalized(), Vector3.UP.angle_to(n) * 0.7) * basis
	basis = basis.scaled(Vector3.ONE * scale)
	var variant := rng.randi() % (_meshes[Kind.ROCK] as Array).size()
	var origin := Vector3(p.x, y, p.y)
	_add(Kind.ROCK, variant, Transform3D(basis, origin))
	if scale >= 0.8:
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.8 * scale
		cs.shape = shape
		cs.position = origin + Vector3.UP * 0.25 * scale
		_body.add_child(cs)


func _place_bushes(rng: RandomNumberGenerator) -> void:
	var step := 6.5
	var half := FieldLayout.HALF_SIZE
	var z := -half + step * 0.5
	while z < half:
		var x := -half + step * 0.5
		while x < half:
			var p := Vector2(x + rng.randf_range(-2.8, 2.8), z + rng.randf_range(-2.8, 2.8))
			var chance := 0.07 + layout.meadow_factor(p) * 0.12 + layout.tree_density(p) * 0.18
			if layout.is_clear_area(p):
				chance = 0.0
			if rng.randf() < chance and _ground_ok(p.x, p.y, 0.8):
				var scale := rng.randf_range(0.8, 1.35)
				var origin := Vector3(p.x, terrain.height_at(p.x, p.y) - 0.1, p.y)
				var variant := rng.randi() % (_meshes[Kind.BUSH] as Array).size()
				_add(Kind.BUSH, variant, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), origin))
				bush_positions.append(origin)
			x += step
		z += step


func _place_flowers(rng: RandomNumberGenerator) -> void:
	var step := 3.2
	var half := FieldLayout.HALF_SIZE
	var z := -half + step * 0.5
	while z < half:
		var x := -half + step * 0.5
		while x < half:
			var p := Vector2(x + rng.randf_range(-1.5, 1.5), z + rng.randf_range(-1.5, 1.5))
			var chance := layout.meadow_factor(p) * 0.3 + 0.025
			if layout.road_factor(p) > 0.1 or layout.in_town(p, 2.0) or layout.shade_factor(p) > 0.4:
				chance = 0.0
			if rng.randf() < chance and _ground_ok(p.x, p.y, 0.85):
				var origin := Vector3(p.x, terrain.height_at(p.x, p.y) - 0.02, p.y)
				var variant := rng.randi() % 3
				_add(Kind.FLOWER, variant, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), origin))
			x += step
		z += step


func _emit_multimeshes() -> void:
	for key: String in _buckets:
		var parts := key.split(":")
		var kind := int(parts[0])
		var variant := int(parts[1])
		var xforms: Array = _buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = (_meshes[kind] as Array)[variant]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_%s" % key.replace(":", "_")
		mmi.multimesh = mm
		match kind:
			Kind.ROCK:
				mmi.material_override = MeshKit.solid_material()
				mmi.visibility_range_end = 300.0
			Kind.BUSH:
				mmi.material_override = MeshKit.foliage_material()
				mmi.visibility_range_end = 190.0
			Kind.FLOWER:
				mmi.material_override = MeshKit.foliage_material()
				mmi.visibility_range_end = 70.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_:
				mmi.material_override = MeshKit.foliage_material()
		add_child(mmi)
	_buckets.clear()

class_name CombatFx
extends RefCounted
## 임시 전투 이펙트: 탄도선, 착탄, 폭발, 파동 고리. 스스로 사라진다.
## 정식 VFX가 준비되면 교체한다. 시야를 과도하게 가리지 않도록 작고 짧게 만든다(기획서 §23.4).

static var _materials: Dictionary = {}


## 발광 재질(색별로 공유)
static func glow_material(color: Color, energy: float = 2.5) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, color.a)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = m
	return m


static func _world_root(ctx: Node) -> Node:
	if ctx == null or not ctx.is_inside_tree():
		return null
	var tree := ctx.get_tree()
	return tree.current_scene if tree.current_scene else tree.root


static func _spawn(ctx: Node, node: Node3D, position: Vector3) -> bool:
	var root := _world_root(ctx)
	if root == null:
		node.free()
		return false
	root.add_child(node)
	node.global_position = position
	node.reset_physics_interpolation()
	return true


static func _orient(node: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	node.global_basis = Basis.looking_at(dir, up)


static func tracer(ctx: Node, from: Vector3, to: Vector3, color: Color, width: float = 0.012,
		life: float = 0.06) -> void:
	var length := from.distance_to(to)
	if length < 0.3:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, length)
	mi.mesh = mesh
	mi.material_override = glow_material(color, 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _spawn(ctx, mi, (from + to) * 0.5):
		return
	_orient(mi, from, to)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.05, 0.05, 1.0), life)
	tw.tween_callback(mi.queue_free)


static func impact(ctx: Node, position: Vector3, color: Color, size: float = 0.08, life: float = 0.15) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = glow_material(color, 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _spawn(ctx, mi, position):
		return
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 0.1, life)
	tw.tween_callback(mi.queue_free)


## 바닥에 퍼지는 고리(파동, 폭발 범위 표시)
static func ring(ctx: Node, center: Vector3, radius: float, color: Color, life: float = 0.4) -> void:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 6
	mi.mesh = mesh
	mi.material_override = glow_material(color, 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * maxf(radius * 0.15, 0.1)
	if not _spawn(ctx, mi, center):
		return
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi, "transparency", 1.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


static func explosion(ctx: Node, center: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = glow_material(color, 1.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.2
	if not _spawn(ctx, mi, center):
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = radius * 2.5
	mi.add_child(light)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 0.7, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "transparency", 1.0, 0.3).set_delay(0.05)
	tw.tween_property(light, "light_energy", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)
	ring(ctx, center + Vector3.UP * 0.05, radius, color, 0.35)

@tool
class_name GreyboxBlock
extends StaticBody3D
## 회색 상자 단계의 지형 블록. 크기와 색만 정하면 격자 재질 메시와 충돌체를 만든다.
## 편집기에서도 모양이 보이며, 내비게이션 굽기는 충돌체를 기준으로 한다.

const GREYBOX_SHADER := preload("res://assets/shaders/greybox.gdshader")

@export var size := Vector3(2, 2, 2):
	set(value):
		size = value
		_rebuild()
@export var color := Color(0.55, 0.57, 0.6):
	set(value):
		color = value
		_rebuild()

static var _materials: Dictionary = {}

var _mesh_instance: MeshInstance3D
var _shape_node: CollisionShape3D


func _ready() -> void:
	collision_layer = CombatLayers.WORLD
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_BACK)
		_shape_node = CollisionShape3D.new()
		add_child(_shape_node, false, Node.INTERNAL_MODE_BACK)
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material_for(color)
	var shape := BoxShape3D.new()
	shape.size = size
	_shape_node.shape = shape


static func material_for(c: Color) -> ShaderMaterial:
	var key := c.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = GREYBOX_SHADER
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("line_color", c.darkened(0.3))
	_materials[key] = m
	return m

@tool
class_name GrassPatch
extends Node3D
## 키 큰 풀숲(충돌 없음). 시야를 가려 매복하는 적이 숨을 수 있다(기획서 §14.6).
## 같은 시드로 항상 같은 모양을 만든다.

@export var size := Vector2(8, 8):
	set(value):
		size = value
		_rebuild()
## 1제곱미터당 풀 줄기 수
@export var density: float = 7.0:
	set(value):
		density = value
		_rebuild()
@export var height: float = 0.95:
	set(value):
		height = value
		_rebuild()
@export var seed_value: int = 1:
	set(value):
		seed_value = value
		_rebuild()

var _mmi: MultiMeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mmi == null:
		_mmi = MultiMeshInstance3D.new()
		_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mmi, false, Node.INTERNAL_MODE_BACK)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.05, 1.0, 0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.52, 0.26)
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	var count := int(size.x * size.y * density)
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var h := height * rng.randf_range(0.65, 1.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
		basis = basis.scaled(Vector3(rng.randf_range(0.8, 1.6), h, 1.0))
		var pos := Vector3(rng.randf_range(-0.5, 0.5) * size.x, h * 0.5, rng.randf_range(-0.5, 0.5) * size.y)
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var tint := rng.randf_range(0.8, 1.15)
		mm.set_instance_color(i, Color(tint, tint, tint * 0.9))
	mat.vertex_color_use_as_albedo = true
	_mmi.multimesh = mm

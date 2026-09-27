@tool
class_name Interactable
extends Area3D
## 상호작용 대상(기본 키 E). 플레이어 시선이 이 영역을 향하면 HUD에 안내 문구가 뜬다.
## 사용할 수 없는 상황이면 이유를 함께 보여 준다(기획서 §4.4: 잠긴 이유를 전달한다).
## 편집기에서도 모양이 보이도록 도구 스크립트로 둔다. 시각 요소는 저장되지 않는 내부 노드다.

signal interacted(player: Node)

@export var prompt: String = "상호작용"
@export var label_text: String = ""


func _ready() -> void:
	collision_layer = CombatLayers.INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true
	_build()


## 하위 클래스가 시각 요소와 판정 모양을 만든다.
func _build() -> void:
	pass


func get_prompt(_player: Node) -> String:
	return prompt


## 지금 사용할 수 없으면 이유를, 가능하면 빈 문자열을 돌려준다.
func get_block_reason(_player: Node) -> String:
	return ""


func interact(player: Node) -> void:
	interacted.emit(player)


# --- 시각 요소 도우미 ---

func _add_internal(node: Node) -> Node:
	add_child(node, false, Node.INTERNAL_MODE_BACK)
	return node


func _add_trigger_box(size: Vector3, center: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = center
	_add_internal(cs)


## 플레이어가 통과하지 못하는 단단한 몸체(내비게이션 굽기에도 쓰인다)
func _add_solid_box(size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CombatLayers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	_add_internal(body)


func _add_mesh(mesh: Mesh, position: Vector3, color: Color, emission: float = 0.0,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	mi.material_override = m
	mi.position = position
	mi.rotation_degrees = rot_deg
	_add_internal(mi)
	return mi


func _add_label(text: String, height: float) -> void:
	if text == "":
		return
	var l := Label3D.new()
	l.text = text
	l.position = Vector3(0, height, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.005
	l.outline_size = 12
	l.modulate = Color(0.92, 0.96, 0.95)
	l.no_depth_test = false
	_add_internal(l)


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	return m

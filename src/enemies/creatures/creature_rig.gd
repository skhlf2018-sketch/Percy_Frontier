class_name CreatureRig
extends Node3D
## 생물 모델 한 개체: 뼈대(Skeleton3D) + 피부 메시 + 뼈에 붙은 물건(무기, 판정 상자, 빛).
## 적의 "Visual" 노드로 쓰인다. 동작은 종별 스크립트가 뼈를 돌려 만든다(절차적 애니메이션).

const VISIBILITY_END := 220.0
## 털 껍질은 가까이서만 그린다(멀면 몸 표면의 결 재질만으로 충분하다).
const FUR_VISIBILITY_END := 40.0

var template: RigTemplate
var skeleton: Skeleton3D
var body: MeshInstance3D
var fur: MeshInstance3D
var _idx: Dictionary = {}
var _rest: Dictionary = {}


func setup(t: RigTemplate) -> void:
	template = t
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	for i in t.names.size():
		skeleton.add_bone(String(t.names[i]))
		_idx[t.names[i]] = i
	for i in t.names.size():
		var parent := t.parents[i]
		skeleton.set_bone_parent(i, parent)
		var local := t.positions[i] - (t.positions[parent] if parent >= 0 else Vector3.ZERO)
		skeleton.set_bone_rest(i, Transform3D(Basis(), local))
		_rest[i] = local
	skeleton.reset_bone_poses()
	add_child(skeleton)
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = t.mesh
	body.skin = t.skin
	body.skeleton = NodePath("..")
	body.custom_aabb = t.custom_aabb
	body.visibility_range_end = VISIBILITY_END
	body.visibility_range_end_margin = 20.0
	body.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	skeleton.add_child(body)
	if t.fur_mesh and Settings.creature_fur_enabled():
		fur = MeshInstance3D.new()
		fur.name = "Fur"
		fur.mesh = t.fur_mesh
		fur.skin = t.skin
		fur.skeleton = NodePath("..")
		fur.custom_aabb = t.custom_aabb
		fur.material_override = CreatureMaterials.fur_shells(t.fur_length, t.fur_density)
		fur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fur.visibility_range_end = FUR_VISIBILITY_END
		fur.visibility_range_end_margin = 8.0
		fur.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		skeleton.add_child(fur)


func has_bone(bone: StringName) -> bool:
	return _idx.has(bone)


func bone_idx(bone: StringName) -> int:
	return _idx.get(bone, -1)


## 뼈를 쉬는 자세에서 오일러 각(라디안, YXZ 순서)만큼 돌린다.
func rot(bone: StringName, euler: Vector3) -> void:
	var i: int = _idx.get(bone, -1)
	if i >= 0:
		skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(euler))


## 뼈를 쉬는 자세 위치에서 offset만큼 옮긴다.
func move(bone: StringName, offset: Vector3) -> void:
	var i: int = _idx.get(bone, -1)
	if i >= 0:
		skeleton.set_bone_pose_position(i, _rest[i] + offset)


## 뼈의 크기를 바꾼다(숨쉬기, 부풀기).
func scale_bone(bone: StringName, s: Vector3) -> void:
	var i: int = _idx.get(bone, -1)
	if i >= 0:
		skeleton.set_bone_pose_scale(i, s)


## 뼈에 물건을 붙인다. xf는 뼈 기준 변환.
func attach(bone: StringName, node: Node3D, xf := Transform3D.IDENTITY) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.name = "Attach_%s_%d" % [bone, get_child_count()]
	ba.bone_name = String(bone)
	skeleton.add_child(ba)
	node.transform = xf
	ba.add_child(node)
	return ba


## 부착점(RigBuilder.socket)에 붙인다.
func attach_socket(socket: StringName, node: Node3D, extra := Transform3D.IDENTITY) -> BoneAttachment3D:
	if not template.sockets.has(socket):
		return attach(template.names[0], node, extra)
	var s: Array = template.sockets[socket]
	return attach(s[0], node, (s[1] as Transform3D) * extra)


## 뼈의 현재 위치(전역)
func bone_global_position(bone: StringName) -> Vector3:
	var i: int = _idx.get(bone, -1)
	if i < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin

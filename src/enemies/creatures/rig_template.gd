class_name RigTemplate
extends RefCounted
## 한 종의 뼈대·피부 메시·부착점(RigBuilder가 만든다). 모든 개체가 메시와 피부를 나눠 쓰고,
## 개체마다 뼈대(Skeleton3D)만 따로 만든다.

var names: Array[StringName] = []
var parents := PackedInt32Array()
var positions := PackedVector3Array()
var sockets: Dictionary = {}
var mesh: ArrayMesh
## 털 표면만 모은 메시(털 껍질). 털이 없으면 null.
var fur_mesh: ArrayMesh
var fur_length: float = 0.025
var fur_density: float = 9.0
var skin: Skin
var custom_aabb := AABB()
var vertex_count: int = 0


func bone_index(name: StringName) -> int:
	return names.find(name)


func instantiate() -> CreatureRig:
	var rig := CreatureRig.new()
	rig.name = "Visual"
	rig.setup(self)
	return rig

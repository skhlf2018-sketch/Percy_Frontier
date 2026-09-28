class_name EncounterGroup
extends Node3D
## 야외 무리. 시작할 때 적을 배치하고 규칙에 따라 다시 배치한다(기획서 §19.1, §19.3).
## - 거점에서 휴식하면 모든 야외 무리가 다시 나타난다.
## - 플레이어가 쓰러지면 교전 중이던 무리만 처음 상태로 돌아간다.

signal engaged

@export var enemy_scene: PackedScene
## 종 id로 만들 때(EnemyBody). 비어 있으면 enemy_scene을 쓴다.
@export var species: StringName
## 섞어 넣을 종: [[종 id, 수], ...]. 지정하면 count·species 대신 이 목록대로 만든다.
@export var mix: Array = []
@export var count: int = 1
## 여러 마리일 때 원형 배치 반경
@export var spread: float = 2.5
@export var ambush: bool = false
## 적을 붙일 노드(비우면 부모)
@export var spawn_parent: NodePath

var members: Array[Enemy] = []


func _ready() -> void:
	spawn_all.call_deferred()


## 이번에 만들 종 목록(무리 구성)
func roster() -> Array[StringName]:
	var out: Array[StringName] = []
	if not mix.is_empty():
		for m: Array in mix:
			for i in int(m[1]):
				out.append(StringName(m[0]))
		return out
	for i in count:
		out.append(species)
	return out


func _make(id: StringName) -> Enemy:
	if id != &"":
		return EnemyBody.create(id)
	return enemy_scene.instantiate() if enemy_scene else null


func spawn_all() -> void:
	despawn_all()
	if enemy_scene == null and species == &"" and mix.is_empty():
		return
	var parent: Node3D = get_node_or_null(spawn_parent) if not spawn_parent.is_empty() else get_parent()
	var list := roster()
	var n := list.size()
	for i in n:
		var offset := Vector3.ZERO
		if n > 1:
			var angle := TAU * float(i) / float(n)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * spread
		var point := _ground(global_position + offset)
		var e: Enemy = _make(list[i])
		if e == null:
			continue
		e.position = parent.to_local(point)
		e.rotation.y = global_rotation.y + randf_range(-0.4, 0.4)
		e.ambush = ambush
		e.encounter = self
		parent.add_child(e)
		e.reset_physics_interpolation()
		members.append(e)


func despawn_all() -> void:
	for e in members:
		if is_instance_valid(e):
			e.queue_free()
	members.clear()


func reset() -> void:
	spawn_all()


func notify_engaged() -> void:
	engaged.emit()


## 살아 있는 구성원 중 하나라도 교전 중이면 true
func is_engaged() -> bool:
	for e in members:
		if is_instance_valid(e) and e.is_alive() and e.is_engaged():
			return true
	return false


func alive_count() -> int:
	var n := 0
	for e in members:
		if is_instance_valid(e) and e.is_alive():
			n += 1
	return n


func _ground(point: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 4.0, point + Vector3.DOWN * 10.0, CombatLayers.WORLD)
	var hit := space.intersect_ray(q)
	return hit.position if not hit.is_empty() else point

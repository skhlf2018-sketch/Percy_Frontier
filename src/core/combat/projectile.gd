class_name Projectile
extends Node3D
## 레이 스윕으로 충돌을 검사하는 투사체. 빠른 탄도가 얇은 대상을 건너뛰지 않는다.
## 명중 처리는 on_hit(hit: Dictionary)에 맡기고, 명중하거나 수명이 끝나면 사라진다.

signal expired

var velocity: Vector3 = Vector3.ZERO
var gravity: float = 0.0
var life: float = 4.0
var collision_mask: int = CombatLayers.PLAYER_ATTACK_MASK
var collide_with_areas: bool = true
var exclude: Array[RID] = []
## func(hit: Dictionary) -> void. hit에는 position, normal, collider가 들어 있다.
var on_hit: Callable
## 수명이 다했을 때(명중 없이) 호출. 곡사 포자처럼 공중에서 터지는 경우에 쓴다.
var on_expire: Callable

var _done: bool = false


static func create(color: Color, radius: float = 0.08, stretch: float = 3.0) -> Projectile:
	var p := Projectile.new()
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mi.mesh = mesh
	mi.scale = Vector3(1.0, 1.0, stretch)
	mi.material_override = CombatFx.glow_material(color, 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	return p


## 장면에 붙이고 발사한다.
func launch(parent: Node, origin: Vector3, p_velocity: Vector3) -> void:
	velocity = p_velocity
	parent.add_child(self)
	global_position = origin
	_face_velocity()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _done:
		return
	life -= delta
	if life <= 0.0:
		_finish(true)
		return
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, collision_mask, exclude)
	q.collide_with_areas = collide_with_areas
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		if on_hit.is_valid():
			on_hit.call(hit)
		_finish(false)
		return
	global_position = to
	_face_velocity()


func _face_velocity() -> void:
	if velocity.length_squared() < 0.0001:
		return
	var dir := velocity.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	global_basis = Basis.looking_at(dir, up)


func _finish(timed_out: bool) -> void:
	_done = true
	if timed_out and on_expire.is_valid():
		on_expire.call()
	expired.emit()
	queue_free()

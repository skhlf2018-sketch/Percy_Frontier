class_name TestWorld
extends RefCounted
## 통합 테스트용 작은 월드: 평평한 바닥, 벽, 내비게이션, 플레이어·적 배치.

const PLAYER_SCENE := preload("res://src/player/player.tscn")

var root: Node3D
var nav: NavigationRegion3D


static func create(runner: Node, size: float = 80.0) -> TestWorld:
	var w := TestWorld.new()
	w.root = Node3D.new()
	w.root.name = "TestWorld"
	w.nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = CombatLayers.WORLD
	nm.agent_radius = 0.5
	w.nav.navigation_mesh = nm
	w.root.add_child(w.nav)
	runner.add_child(w.root)
	w.add_box(Vector3(0, -0.5, 0), Vector3(size, 1.0, size))
	return w


func add_box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CombatLayers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	nav.add_child(body)
	body.global_position = center
	return body


func bake() -> void:
	nav.bake_navigation_mesh(false)


func spawn_player(position: Vector3, yaw: float = 0.0) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.position = position
	p.rotation.y = yaw
	root.add_child(p)
	p.yaw = yaw
	return p


func spawn(scene: PackedScene, position: Vector3, yaw: float = 0.0) -> Enemy:
	var e: Enemy = scene.instantiate()
	e.position = position
	e.rotation.y = yaw
	root.add_child(e)
	return e


## 플레이어가 point를 바라보게 한다.
static func aim_at(p: Player, point: Vector3) -> void:
	var dir := point - p.get_eye_position()
	p.yaw = atan2(-dir.x, -dir.z)
	p.pitch = atan2(dir.y, Vector2(dir.x, dir.z).length())

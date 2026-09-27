class_name Pickup
extends Node3D
## 떨어진 보상. 가까이 가면 끌려와 자동으로 회수된다(기획서 §11.1: 중요한 보상은 지형에 끼이거나 사라지지 않고 자동 회수).
## 가진 양이 가득 차 있으면 회수하지 않고 남겨 둔다.

enum Kind { AMMO, CONSUMABLE }

const MAGNET_RADIUS := 4.0
const COLLECT_RADIUS := 1.1
const LIFETIME := 120.0
const GRAVITY := 14.0
## 탄약 상자 하나가 채우는 양(종류별 시작 보유량 대비)
const AMMO_FRACTION := 0.35

var kind: int = Kind.AMMO
var consumable_id: StringName = &""

var _life: float = LIFETIME
var _time: float = 0.0
var _velocity := Vector3.ZERO
var _grounded: bool = false
var _mesh: Node3D
var _blocked_notice_cooldown: float = 0.0


static func spawn_ammo(ctx: Node, position: Vector3) -> Pickup:
	var p := Pickup.new()
	p.kind = Kind.AMMO
	return p._place(ctx, position)


static func spawn_consumable(ctx: Node, position: Vector3, id: StringName) -> Pickup:
	var p := Pickup.new()
	p.kind = Kind.CONSUMABLE
	p.consumable_id = id
	return p._place(ctx, position)


func _place(ctx: Node, position: Vector3) -> Pickup:
	if ctx == null or not ctx.is_inside_tree():
		free()
		return null
	var tree := ctx.get_tree()
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	root.add_child(self)
	global_position = position
	_velocity = Vector3(randf_range(-1.5, 1.5), 3.5, randf_range(-1.5, 1.5))
	reset_physics_interpolation()
	return self


func _ready() -> void:
	add_to_group(&"pickups")
	_mesh = Node3D.new()
	add_child(_mesh)
	if kind == Kind.AMMO:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.28, 0.16, 0.2)
		box.mesh = bm
		box.material_override = CombatFx.glow_material(Color(1.0, 0.78, 0.3), 1.2)
		_mesh.add_child(box)
	else:
		var c := GameDB.consumable(consumable_id)
		var color := c.color if c else Color(1, 0.3, 0.3)
		for size in [Vector3(0.28, 0.09, 0.09), Vector3(0.09, 0.28, 0.09)]:
			var mi := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = size
			mi.mesh = m
			mi.material_override = CombatFx.glow_material(color, 1.5)
			_mesh.add_child(mi)


func _physics_process(delta: float) -> void:
	_time += delta
	_life -= delta
	_blocked_notice_cooldown = maxf(0.0, _blocked_notice_cooldown - delta)
	if _life <= 0.0:
		queue_free()
		return
	var players := get_tree().get_nodes_in_group(&"player")
	var player: Player = players[0] if players.size() > 0 else null
	var to_player := Vector3.ZERO
	if player and player.alive:
		to_player = player.get_chest_position() - global_position
	if player and player.alive and to_player.length() < MAGNET_RADIUS and _can_accept(player):
		if to_player.length() < COLLECT_RADIUS:
			_give(player)
			queue_free()
			return
		_velocity = to_player.normalized() * lerpf(9.0, 4.0, to_player.length() / MAGNET_RADIUS)
		_grounded = false
		global_position += _velocity * delta
		return
	if not _grounded:
		_velocity.y -= GRAVITY * delta
		var from := global_position
		var to := from + _velocity * delta
		var q := PhysicsRayQueryParameters3D.create(from, to + Vector3.DOWN * 0.15, CombatLayers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and _velocity.y <= 0.0:
			global_position = hit.position + Vector3.UP * 0.15
			_grounded = true
			_velocity = Vector3.ZERO
		else:
			global_position = to
		if global_position.y < -50.0:
			queue_free()


func _process(_delta: float) -> void:
	if _mesh:
		_mesh.position.y = 0.12 + sin(_time * 3.0) * 0.06
		_mesh.rotation.y = _time * 1.6


func _can_accept(player: Player) -> bool:
	if kind == Kind.CONSUMABLE:
		var c := GameDB.consumable(consumable_id)
		return c != null and player.consumable_counts.get(consumable_id, 0) < c.max_carry
	for type in _ammo_types(player):
		if player.ammo.get_count(type) < player.ammo.get_max(type):
			return true
	return false


func _ammo_types(player: Player) -> Array[StringName]:
	var types: Array[StringName] = []
	for w in [player.weapons.primary, player.weapons.secondary]:
		if w and not w.uses_heat and not types.has(w.ammo_type):
			types.append(w.ammo_type)
	return types


func _give(player: Player) -> void:
	var parts: Array[String] = []
	if kind == Kind.CONSUMABLE:
		var c := GameDB.consumable(consumable_id)
		if player.add_consumable(consumable_id, 1) > 0:
			parts.append("%s +1" % c.display_name)
	else:
		var supply := float(Settings.difficulty_params().supply_mult)
		for type in _ammo_types(player):
			var amount := int(ceil(AmmoInventory.TYPES[type].start * AMMO_FRACTION * supply))
			var added := player.ammo.add(type, amount)
			if added > 0:
				parts.append("%s +%d" % [AmmoInventory.type_name(type), added])
	if parts.is_empty():
		return
	Sfx.play(&"pickup", -4.0)
	GameEvents.notify(", ".join(parts), GameEvents.NoticeKind.PICKUP)

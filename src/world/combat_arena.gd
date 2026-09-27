class_name CombatArena
extends Node3D
## 전투 시험장(기획서 §25.1 첫 단계: 회색 상자 전장, 총기·근접·스킬 최소 세트).
## 야외 무리, 사격장 표적, 보급 거점, 무기 거치대, 시험 단말기로 조작·타격감·전투 규칙을 검증한다.

signal rest_requested(player: Player, point: SupplyPoint)
signal rack_requested(player: Player)
signal terminal_requested(player: Player)

const RABBIT := preload("res://src/enemies/killer_rabbit.tscn")
const CHARGER := preload("res://src/enemies/rock_charger.tscn")
const SPITTER := preload("res://src/enemies/spore_spitter.tscn")

## 시험 단말기로 부를 수 있는 무리
const TEST_WAVES := {
	&"rabbits": "살인토끼 무리 (4)",
	&"charger": "바위등 돌격수 (1)",
	&"spitters": "포자 사수 (2)",
	&"mixed": "혼성 교전 (토끼 3 · 돌격수 1 · 포자 사수 1)",
}

@onready var navigation: NavigationRegion3D = $NavigationRegion3D
@onready var player_start: Marker3D = $PlayerStart
@onready var test_active: Node3D = $TestSpawns/Active

var supply_points: Array[SupplyPoint] = []
var encounters: Array[EncounterGroup] = []


func _ready() -> void:
	for n in find_children("*", "Interactable", true, false):
		var it: Interactable = n
		it.interacted.connect(_on_interacted.bind(it))
		if it is SupplyPoint:
			supply_points.append(it)
	for g in find_children("*", "EncounterGroup", true, false):
		encounters.append(g)
	# 회색 상자 지형은 작아서 시작할 때 한 번 동기로 굽는다.
	navigation.bake_navigation_mesh(false)


func _on_interacted(player: Node, node: Interactable) -> void:
	if not (player is Player):
		return
	if node is SupplyPoint:
		rest_requested.emit(player, node)
	elif node is WeaponRack:
		rack_requested.emit(player)
	elif node is TestTerminal:
		terminal_requested.emit(player)


func default_respawn() -> Transform3D:
	return player_start.global_transform


## 휴식: 모든 야외 무리를 다시 배치한다(기획서 §19.3).
func reset_all_encounters() -> void:
	for g in encounters:
		g.reset()


## 지금 교전 중인 야외 무리 목록
func engaged_encounters() -> Array[EncounterGroup]:
	var out: Array[EncounterGroup] = []
	for g in encounters:
		if g.is_engaged():
			out.append(g)
	return out


## 사망: 교전 중이던 야외 무리만 처음 상태로 되돌린다(기획서 §19.1). 되돌린 무리 수를 돌려준다.
## groups를 주면 그 무리들을(사망 순간에 기억해 둔 교전 무리), 비우면 지금 교전 중인 무리를 되돌린다.
func reset_engaged_encounters(groups: Array[EncounterGroup] = []) -> int:
	var targets := groups if not groups.is_empty() else engaged_encounters()
	for g in targets:
		if is_instance_valid(g):
			g.reset()
	return targets.size()


func clear_test_spawns() -> void:
	for c in test_active.get_children():
		c.queue_free()


func active_test_count() -> int:
	var n := 0
	for c in test_active.get_children():
		if c is Enemy and c.is_alive() and not c.is_queued_for_deletion():
			n += 1
	return n


## 시험 단말기: 중앙 광장에 무리를 부른다. 부른 수를 돌려준다.
func spawn_test_wave(kind: StringName) -> int:
	var a := _marker(&"A")
	var b := _marker(&"B")
	var c := _marker(&"C")
	var d := _marker(&"D")
	var spawned := 0
	match kind:
		&"rabbits":
			for i in 4:
				_spawn_test(RABBIT, a + _ring(i, 4, 2.5))
				spawned += 1
		&"charger":
			_spawn_test(CHARGER, b)
			spawned += 1
		&"spitters":
			_spawn_test(SPITTER, c)
			_spawn_test(SPITTER, d)
			spawned += 2
		&"mixed":
			for i in 3:
				_spawn_test(RABBIT, a + _ring(i, 3, 2.0))
			_spawn_test(CHARGER, b)
			_spawn_test(SPITTER, d)
			spawned += 5
	return spawned


func _marker(marker_name: StringName) -> Vector3:
	var m := get_node_or_null(NodePath("TestSpawns/" + String(marker_name))) as Node3D
	return m.global_position if m else Vector3.ZERO


static func _ring(i: int, count: int, radius: float) -> Vector3:
	var angle := TAU * float(i) / float(count)
	return Vector3(cos(angle), 0.0, sin(angle)) * radius


func _spawn_test(scene: PackedScene, point: Vector3) -> Enemy:
	var e: Enemy = scene.instantiate()
	# 거점 쪽(남쪽)을 바라보게 둔다.
	e.position = test_active.to_local(point)
	e.rotation.y = PI
	test_active.add_child(e)
	e.reset_physics_interpolation()
	return e

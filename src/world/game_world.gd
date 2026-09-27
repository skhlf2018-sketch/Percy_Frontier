class_name GameWorld
extends Node3D
## 플레이어가 돌아다니는 공간의 공통 동작: 안전 거점, 야외 무리의 재배치 규칙(기획서 §19),
## 상호작용 신호 연결. 전투 시험장(CombatArena)과 퍼시 외곽권 필드(FieldWorld)가 이어받는다.

signal rest_requested(player: Player, point: SupplyPoint)
signal rack_requested(player: Player)
signal terminal_requested(player: Player)
## 시설·주민 등 하위 클래스가 정의하는 상호작용(Game이 메뉴를 연다)
signal facility_requested(player: Player, node: Interactable)

var supply_points: Array[SupplyPoint] = []
var encounters: Array[EncounterGroup] = []


## 아래 노드의 상호작용 대상과 야외 무리를 등록한다. 하위 클래스가 배치를 끝낸 뒤 부른다.
func register_contents(root: Node = self) -> void:
	for n in root.find_children("*", "Interactable", true, false):
		var it: Interactable = n
		if it.interacted.is_connected(_on_interacted):
			continue
		it.interacted.connect(_on_interacted.bind(it))
		if it is SupplyPoint and not supply_points.has(it):
			supply_points.append(it)
	for g in root.find_children("*", "EncounterGroup", true, false):
		if not encounters.has(g):
			encounters.append(g)


func _on_interacted(player: Node, node: Interactable) -> void:
	if not (player is Player):
		return
	if node is SupplyPoint:
		rest_requested.emit(player, node)
	elif node is WeaponRack:
		rack_requested.emit(player)
	elif node is TestTerminal:
		terminal_requested.emit(player)
	else:
		facility_requested.emit(player, node)


## 새로 시작할 때의 위치
func default_respawn() -> Transform3D:
	return Transform3D.IDENTITY


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


## 시험 단말기로 부른 적(시험장 전용). 기본은 없음.
func clear_test_spawns() -> void:
	pass


func active_test_count() -> int:
	return 0


## 거점 이름으로 찾기(저장된 부활 지점 복원용)
func supply_point_by_name(point_name: String) -> SupplyPoint:
	for sp in supply_points:
		if sp.name == point_name:
			return sp
	return null


## 매 프레임 플레이어 위치를 알려 준다(풀밭·안개 같은 주변 연출용).
func track_player(_player: Player) -> void:
	pass

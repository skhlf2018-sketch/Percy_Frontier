class_name Hurtbox
extends Area3D
## 피격 부위 판정. 플레이어의 레이캐스트·형태 쿼리가 이 Area3D를 맞히면
## receive_hit(info, hurtbox)를 가진 상위 개체(적)에게 피해를 전달한다.

enum Zone { NORMAL, WEAK_POINT, ARMOR }

signal armor_broken(hurtbox: Hurtbox)

@export var zone: Zone = Zone.NORMAL
## 부위 피해 배율(약점은 보통 1.8~2.5)
@export var damage_multiplier: float = 1.0
## 도감·피드백에 표시할 부위 이름
@export var part_name: String = ""
## 시작 시 비활성(장갑 파괴 후 드러나는 약점 등)
@export var starts_disabled: bool = false

@export_group("장갑")
## 장갑 내구도. zone이 ARMOR일 때만 사용한다.
@export var armor_max: float = 0.0
## 장갑이 남아 있을 때 본체로 전달되는 피해 비율
@export_range(0.0, 1.0) var armor_pass_through: float = 0.2
## 장갑 파괴 후 이 부위가 바뀌는 판정
@export var broken_zone: Zone = Zone.NORMAL
@export var broken_multiplier: float = 1.0
## 파괴 시 숨길 장갑 시각 노드
@export var armor_visual: Node3D
## 파괴 시 드러낼 시각 노드(노출된 약점 등)
@export var exposed_visual: Node3D

var armor_current: float = 0.0
## receive_hit(info, hurtbox)를 가진 소유 개체
var entity: Node = null
var _enabled: bool = true


func _ready() -> void:
	collision_layer = CombatLayers.HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true
	armor_current = armor_max
	entity = _find_entity()
	if exposed_visual:
		exposed_visual.visible = false
	set_enabled(not starts_disabled)


func _find_entity() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("receive_hit"):
			return n
		n = n.get_parent()
	return null


func set_enabled(value: bool) -> void:
	_enabled = value
	collision_layer = CombatLayers.HURTBOX if value else 0


func is_enabled() -> bool:
	return _enabled


func is_armor_intact() -> bool:
	return zone == Zone.ARMOR and armor_current > 0.0


func effective_zone() -> Zone:
	if zone == Zone.ARMOR and armor_current <= 0.0:
		return broken_zone
	return zone


func effective_multiplier() -> float:
	if zone == Zone.ARMOR and armor_current <= 0.0:
		return broken_multiplier
	return damage_multiplier


## 장갑 내구 피해를 적용한다. 이번 피해로 파괴되었으면 true.
func apply_armor_damage(amount: float) -> bool:
	if not is_armor_intact():
		return false
	armor_current = maxf(0.0, armor_current - amount)
	if armor_current > 0.0:
		return false
	if armor_visual:
		armor_visual.visible = false
	if exposed_visual:
		exposed_visual.visible = true
	armor_broken.emit(self)
	return true


func restore_armor() -> void:
	armor_current = armor_max
	if armor_visual:
		armor_visual.visible = true
	if exposed_visual:
		exposed_visual.visible = false


## 이 부위에 피해를 준다. 소유 개체가 없거나 이미 죽었으면 null.
func hit(info: DamageInfo) -> HitResult:
	if entity == null or not is_instance_valid(entity) or not _enabled:
		return null
	return entity.receive_hit(info, self)

class_name DamageInfo
extends RefCounted
## 한 번의 공격이 전달하는 피해 정보.

enum Kind { GUN, MELEE, SKILL, STATUS, ENEMY_MELEE, ENEMY_PROJECTILE, EXPLOSION }

var amount: float = 0.0
var kind: Kind = Kind.GUN
var attacker: Node = null
## 경직 누적치(대상의 경직 저항을 깎는 양)
var stagger: float = 0.0
## 장갑 내구에 주는 피해 배율
var armor_damage_mult: float = 1.0
## 상태이상 축적치: StatusEffects.Type -> float
var status_buildup: Dictionary = {}
var hit_position: Vector3 = Vector3.ZERO
## 공격이 진행한 방향(넉백·피격 방향 표시용)
var direction: Vector3 = Vector3.FORWARD
## 강공격 여부(빙결 대상 추가 피해 등)
var heavy: bool = false
## 공명 획득 배율(산탄처럼 한 번의 사격이 여러 번 명중하는 경우 나눈다)
var resonance_mult: float = 1.0
## 적의 공격일 때 패링 가능 여부
var parryable: bool = true
## 넉백 속도(m/s)
var knockback: float = 0.0
## 부위 판정을 건너뛰는 피해(지속 피해 등)
var ignore_zones: bool = false
## 경직·기절한 대상에게 더하는 피해 비율(무기 특성 「무리 깨기」)
var bonus_vs_staggered: float = 0.0


static func create(p_amount: float, p_kind: Kind, p_attacker: Node = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.kind = p_kind
	info.attacker = p_attacker
	return info


func is_from_player() -> bool:
	return kind == Kind.GUN or kind == Kind.MELEE or kind == Kind.SKILL


func is_melee() -> bool:
	return kind == Kind.MELEE

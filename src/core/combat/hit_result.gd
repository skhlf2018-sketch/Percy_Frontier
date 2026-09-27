class_name HitResult
extends RefCounted
## 명중 결과. HUD 히트마커, 공명 획득, 분석도 계산에 쓰인다.

var target: Node = null
var zone: int = Hurtbox.Zone.NORMAL
var damage: float = 0.0
var armor_damage: float = 0.0
## 장갑이 남아 있는 부위를 맞혔는지
var hit_armor: bool = false
var armor_broken: bool = false
var killed: bool = false
var position: Vector3 = Vector3.ZERO
var kind: int = DamageInfo.Kind.GUN
## 이번 명중으로 발동한 상태이상(StatusEffects.Type)
var triggered_statuses: Array[int] = []
## 대상이 경직에 빠졌는지
var staggered: bool = false
## 공명 획득 배율(DamageInfo에서 복사)
var resonance_mult: float = 1.0


func is_weak_point() -> bool:
	return zone == Hurtbox.Zone.WEAK_POINT

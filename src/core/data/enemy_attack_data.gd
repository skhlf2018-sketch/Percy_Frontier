class_name EnemyAttackData
extends Resource
## 적 공격 패턴 하나. 전조(windup) → 판정(active) → 회복(recovery) 순서로 진행한다.
## 강한 공격은 충분한 전조를 가지며, 패링 가능 여부를 모양·색·소리로 구분해 알린다(기획서 §8.4, §8.7).

enum TokenGroup { NONE, MELEE, RANGED }

enum Kind {
	## 제자리 타격
	STRIKE,
	## 짧게 뛰어드는 공격
	LUNGE,
	## 직선 돌진. 벽에 부딪히면 스스로 기절할 수 있다.
	CHARGE,
	## 투사체
	PROJECTILE,
}

@export var id: StringName
@export var display_name: String = ""
@export var kind: Kind = Kind.STRIKE
@export var parryable: bool = true
@export var min_range: float = 0.0
@export var max_range: float = 2.5
@export var windup: float = 0.6
@export var active_time: float = 0.25
@export var recovery: float = 0.8
@export var cooldown: float = 2.0
@export var damage: float = 10.0
## 판정 거리(타격·돌진)
@export var reach: float = 1.6
@export var hit_angle_deg: float = 80.0
## 뛰어들기·돌진 속도
@export var move_speed: float = 0.0
@export var knockback: float = 4.0
## 선택 가중치
@export var weight: float = 1.0
## 동시 공격 수 제한(공격권) 그룹. 근접과 원거리는 따로 센다.
@export var token_group: TokenGroup = TokenGroup.MELEE
## 돌진이 벽에 부딪혔을 때 스스로 기절하는 시간(0이면 기절하지 않음)
@export var wall_stun: float = 0.0

@export_group("투사체")
@export var projectile_speed: float = 18.0
@export var projectile_gravity: float = 9.0
@export var projectile_blast_radius: float = 3.0

@export_group("상태이상 축적")
@export var burn_buildup: float = 0.0
@export var chill_buildup: float = 0.0
@export var shock_buildup: float = 0.0
@export var bleed_buildup: float = 0.0


func status_buildup() -> Dictionary:
	return StatusEffects.buildup_from(burn_buildup, chill_buildup, shock_buildup, bleed_buildup)

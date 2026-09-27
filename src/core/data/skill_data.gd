class_name SkillData
extends Resource
## 몬스터 스킬 정의(기획서 §8.5). 공명 장치가 몬스터의 법칙을 분석해 재현한 능력이다.
## 공명을 소모하고 짧은 재사용 시간을 가진다.

enum Kind { PULSE, DASH, SHIELD, PROJECTILE }
enum Role { DAMAGE, MOBILITY, CONTROL, DEFENSE }

const ROLE_NAMES := ["피해", "이동", "제어", "방어"]

@export var id: StringName
@export var display_name: String = ""
## HUD 슬롯에 표시할 짧은 이름
@export var short_name: String = ""
@export_multiline var description: String = ""
## 분석 대상 몬스터 id. 비어 있으면 공명 장치 기본 기록.
@export var source_enemy: StringName
@export var kind: Kind = Kind.PULSE
@export var role: Role = Role.DAMAGE
@export var resonance_cost: float = 30.0
@export var cooldown: float = 5.0
@export var color: Color = Color(0.6, 0.85, 1.0)

@export_group("효과")
@export var damage: float = 20.0
@export var radius: float = 6.0
## 돌진 거리
@export var distance: float = 8.0
## 돌진 시간 또는 보호막 지속 시간
@export var duration: float = 0.25
@export var speed: float = 30.0
@export var gravity: float = 12.0
@export var shield_amount: float = 60.0
@export var stagger: float = 20.0
@export var knockback: float = 5.0

@export_group("상태이상 축적")
@export var burn_buildup: float = 0.0
@export var chill_buildup: float = 0.0
@export var shock_buildup: float = 0.0
@export var bleed_buildup: float = 0.0


func role_label() -> String:
	return ROLE_NAMES[role]


func status_buildup() -> Dictionary:
	return StatusEffects.buildup_from(burn_buildup, chill_buildup, shock_buildup, bleed_buildup)

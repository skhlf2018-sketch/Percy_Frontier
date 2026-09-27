class_name EnemyData
extends Resource
## 몬스터 데이터(기획서 §14.4). 위협 등급은 장비 희귀도와 분리된 체계다(§14.3).

enum ThreatTier { NORMAL, ENHANCED, RARE, ELITE, BOSS, UNIQUE }

const TIER_NAMES := ["일반", "강화", "희귀", "정예", "보스", "유니크"]

@export var id: StringName
@export var display_name: String = ""
## 종족군
@export var family: String = ""
@export var threat_tier: ThreatTier = ThreatTier.NORMAL
## 전투 역할(돌격, 사격, 지원, 매복, 방어, 소환 등)
@export var combat_role: String = ""
@export_multiline var description: String = ""

@export_group("능력치")
@export var max_hp: float = 100.0
@export_range(0.0, 0.9) var defense: float = 0.0
@export var walk_speed: float = 2.5
@export var run_speed: float = 5.0
@export var turn_speed_deg: float = 360.0
## 경직 저항치. 누적 경직이 이 값을 넘으면 경직된다.
@export var poise: float = 30.0
@export var stagger_duration: float = 0.9
@export var mass_kg: float = 40.0

@export_group("감지")
@export var sight_range: float = 25.0
@export var sight_fov_deg: float = 120.0
## 이 거리 안에서는 시야각과 무관하게 알아챈다
@export var proximity_sense: float = 2.5
@export var hearing_mult: float = 1.0
## 거점(처음 위치)에서 이 거리를 넘어 추적하지 않는다
@export var leash_radius: float = 35.0
## 무리 경고 반경(0이면 무리 행동 없음)
@export var pack_alert_radius: float = 0.0

@export_group("공격")
@export var attacks: Array[EnemyAttackData] = []

@export_group("상태이상 저항")
## 축적 배율: 1.0 보통, 0.5 저항, 1.5 취약
@export var burn_mult: float = 1.0
@export var chill_mult: float = 1.0
@export var shock_mult: float = 1.0
@export var bleed_mult: float = 1.0
## 보스 규칙: 빙결 대신 강한 둔화(기획서 §8.6)
@export var boss_status_rules: bool = false

@export_group("보상")
## 적 레벨(지역 위험대 기준, 기획서 §5.1: 플레이어 레벨에 맞춰 바뀌지 않는다)
@export var level: int = 1
## 처치 경험치
@export var xp_reward: int = 10
@export var resonance_on_kill: float = 4.0
@export_range(0.0, 1.0) var ammo_drop_chance: float = 0.35
@export_range(0.0, 1.0) var heal_drop_chance: float = 0.05

@export_group("분석")
## 분석 완료 시 해금되는 스킬 id. 비어 있으면 분석 대상이 아니다.
@export var analysis_skill: StringName
## 처치 시 스킬 핵을 즉시 얻을 확률(기획서 §10.3)
@export_range(0.0, 1.0) var core_drop_chance: float = 0.05
@export var analysis_observe: float = 10.0
@export var analysis_kill: float = 12.0
@export var analysis_weak_kill: float = 16.0
@export var analysis_part_break: float = 18.0
@export var analysis_parry: float = 8.0
@export var analysis_evade: float = 6.0


func tier_label() -> String:
	return TIER_NAMES[threat_tier]


func status_resistance() -> Dictionary:
	return {
		StatusEffects.Type.BURN: burn_mult,
		StatusEffects.Type.CHILL: chill_mult,
		StatusEffects.Type.SHOCK: shock_mult,
		StatusEffects.Type.BLEED: bleed_mult,
	}


func is_analyzable() -> bool:
	return analysis_skill != &""

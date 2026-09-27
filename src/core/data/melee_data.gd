class_name MeleeData
extends Resource
## 근접 무기 정의(기획서 §8.4, §9.3). 약공격·강공격·방어/패링 중 무기 특성에 맞는 행동을 제공한다.

@export var id: StringName
@export var display_name: String = ""
@export var manufacturer: String = ""
@export var rarity: ItemRarity.Tier = ItemRarity.Tier.STANDARD
@export_multiline var description: String = ""
## 임시 1인칭 모델 형태(viewmodel_factory 참고)
@export var viewmodel_style: StringName = &"sword"
@export var body_color: Color = Color(0.7, 0.72, 0.75)
@export var accent_color: Color = Color(0.3, 0.22, 0.15)

@export_group("약공격")
@export var light_damage: float = 22.0
@export var light_windup: float = 0.1
@export var light_recovery: float = 0.3
@export var light_stagger: float = 12.0
@export var light_stamina: float = 6.0
## 세 번째 연속 약공격 배율
@export var combo_finisher_mult: float = 1.35

@export_group("강공격")
## 공격 버튼을 이 시간 이상 누르면 강공격
@export var heavy_charge_time: float = 0.4
@export var heavy_damage: float = 55.0
@export var heavy_windup: float = 0.16
@export var heavy_recovery: float = 0.6
@export var heavy_stagger: float = 40.0
@export var heavy_stamina: float = 22.0

@export_group("공통")
@export var reach: float = 2.6
@export var hit_radius: float = 0.9
## 근접은 장갑 파괴에 유리하다(기획서 §8.4)
@export var armor_damage_mult: float = 2.0
@export var bleed_buildup: float = 0.0
@export var heavy_bleed_buildup: float = 0.0

@export_group("방어")
@export var can_block: bool = true
## 방어 성공 시 피해 감소율
@export var block_reduction: float = 0.7
## 패링 불가 공격을 방어했을 때 피해 감소율
@export var unparryable_block_reduction: float = 0.25
@export var block_stamina_per_damage: float = 1.2
## 방어 시작 직후 패링이 성립하는 시간
@export var parry_window: float = 0.18
@export var block_move_mult: float = 0.55

@export_group("빠른 근접")
@export var quick_damage: float = 18.0
@export var quick_stagger: float = 14.0
@export var quick_time: float = 0.42

@export_group("특수")
## 쌍검: 두 손에 하나씩 쥐고 번갈아 벤다(1인칭 모델과 애니메이션이 달라진다).
@export var dual: bool = false
## 강공격이 앞쪽이 아니라 주위를 모두 베는 회전 베기다.
@export var spin_heavy: bool = false

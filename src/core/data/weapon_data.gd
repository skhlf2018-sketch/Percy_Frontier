class_name WeaponData
extends Resource
## 총기 정의(기획서 §8.3, §9.2). 무기군마다 반동, 유효 거리, 관통, 이동 중 정확도, 재장전 위험이 다르다.

enum WeaponClass { PISTOL, SMG, RIFLE, MACHINE_GUN, SNIPER, SHOTGUN, ENERGY, SPECIAL }
enum Slot { PRIMARY, SECONDARY }
enum FireMode { SEMI, AUTO }

const CLASS_NAMES := ["권총", "SMG", "소총", "기관총", "저격총", "산탄총", "에너지 라이플", "특수 총기"]

@export var id: StringName
@export var display_name: String = ""
## 가상의 제조사
@export var manufacturer: String = ""
@export var weapon_class: WeaponClass = WeaponClass.RIFLE
@export var slot: Slot = Slot.PRIMARY
@export var rarity: ItemRarity.Tier = ItemRarity.Tier.STANDARD
@export_multiline var description: String = ""

@export_group("사격")
@export var fire_mode: FireMode = FireMode.AUTO
@export var rounds_per_minute: float = 600.0
@export var damage: float = 14.0
## 한 번에 발사되는 탄 수(산탄총)
@export var pellets: int = 1
@export var falloff_start: float = 25.0
@export var falloff_end: float = 60.0
@export var falloff_min_mult: float = 0.6
@export var max_range: float = 150.0
## 관통 가능한 추가 대상 수
@export var pierce: int = 0
@export var stagger: float = 4.0
@export var armor_damage_mult: float = 1.0

@export_group("탄도")
## false면 히트스캔, true면 투사체
@export var projectile: bool = false
@export var projectile_speed: float = 80.0
@export var projectile_gravity: float = 0.0

@export_group("탄퍼짐·반동")
@export var hip_spread_deg: float = 2.5
@export var ads_spread_deg: float = 0.35
@export var bloom_per_shot_deg: float = 0.5
@export var max_bloom_deg: float = 3.5
@export var bloom_recovery_deg: float = 9.0
@export var move_spread_deg: float = 1.5
@export var air_spread_deg: float = 4.0
@export var recoil_pitch_deg: float = 1.0
@export var recoil_yaw_deg: float = 0.35
## 반동이 원래 조준점으로 돌아오는 속도(초당 비율)
@export var recoil_recovery: float = 7.0
## 반동 중 자동으로 되돌아오는 비율(0이면 전혀 복귀하지 않음)
@export_range(0.0, 1.0) var recoil_return_ratio: float = 0.6

@export_group("탄약")
## 공용 탄약 종류(총기군별 공유, 기획서 §11.4). 과열 무기는 비워 둔다.
@export var ammo_type: StringName = &"rifle"
@export var magazine_size: int = 30
@export var reload_time: float = 2.0
@export var empty_reload_time: float = 2.4

@export_group("과열")
@export var uses_heat: bool = false
@export var heat_per_shot: float = 0.06
@export var heat_cool_rate: float = 0.5
@export var heat_cool_delay: float = 0.25
@export var overheat_lockout: float = 1.6

@export_group("조준")
@export var ads_fov_mult: float = 0.8
@export var ads_time: float = 0.18
@export var ads_move_mult: float = 0.65
## 저격 조준경 표시
@export var scope: bool = false
@export var equip_time: float = 0.45

@export_group("상태이상 축적")
@export var burn_buildup: float = 0.0
@export var chill_buildup: float = 0.0
@export var shock_buildup: float = 0.0
@export var bleed_buildup: float = 0.0

@export_group("감각")
## 발사음이 적에게 들리는 반경(m)
@export var noise_radius: float = 45.0
@export var shake: float = 0.12
@export var sound: StringName = &"shot_rifle"
@export var tracer_color: Color = Color(1.0, 0.85, 0.55)
## 임시 1인칭 모델 형태(viewmodel_factory 참고)
@export var viewmodel_style: StringName = &"rifle"
@export var body_color: Color = Color(0.25, 0.27, 0.3)
@export var accent_color: Color = Color(0.8, 0.55, 0.2)


func class_label() -> String:
	return CLASS_NAMES[weapon_class]


func seconds_per_shot() -> float:
	return 60.0 / maxf(rounds_per_minute, 1.0)


func status_buildup() -> Dictionary:
	return StatusEffects.buildup_from(burn_buildup, chill_buildup, shock_buildup, bleed_buildup)

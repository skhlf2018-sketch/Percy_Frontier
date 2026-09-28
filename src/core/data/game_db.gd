class_name GameDB
extends RefCounted
## data/ 폴더의 정의 리소스를 id로 조회한다.
## 내보내기 빌드에서도 빠지지 않도록 preload로 명시한다.

const WEAPONS := [
	preload("res://data/weapons/rifle_bfa3.tres"),
	preload("res://data/weapons/shotgun_logger.tres"),
	preload("res://data/weapons/energy_re2.tres"),
	preload("res://data/weapons/sniper_l14.tres"),
	preload("res://data/weapons/pistol_bf9.tres"),
	preload("res://data/weapons/pipe_shotgun.tres"),
	preload("res://data/weapons/bolt_rifle.tres"),
	preload("res://data/weapons/scrap_smg.tres"),
]
const MELEE := [
	preload("res://data/melee/sword_survey.tres"),
	preload("res://data/melee/karambit_hook.tres"),
	preload("res://data/melee/twin_moon.tres"),
	preload("res://data/melee/goblin_cleaver.tres"),
	preload("res://data/melee/bone_spear.tres"),
	preload("res://data/melee/hand_axe.tres"),
	preload("res://data/melee/chief_greatblade.tres"),
]
const SKILLS := [
	preload("res://data/skills/frost_pulse.tres"),
	preload("res://data/skills/ambush_leap.tres"),
	preload("res://data/skills/carapace_guard.tres"),
	preload("res://data/skills/fire_spore.tres"),
]
const ENEMIES := [
	preload("res://data/enemies/killer_rabbit.tres"),
	preload("res://data/enemies/rock_charger.tres"),
	preload("res://data/enemies/spore_spitter.tres"),
	preload("res://data/enemies/training_dummy.tres"),
	preload("res://data/enemies/night_predator.tres"),
]
const CONSUMABLES := [
	preload("res://data/consumables/field_suture.tres"),
	preload("res://data/consumables/purge_ampoule.tres"),
]


static func _find(list: Array, id: StringName) -> Resource:
	for item in list:
		if item.id == id:
			return item
	return null


static func weapon(id: StringName) -> WeaponData:
	return _find(WEAPONS, id)


static func melee(id: StringName) -> MeleeData:
	return _find(MELEE, id)


static func skill(id: StringName) -> SkillData:
	return _find(SKILLS, id)


static func enemy(id: StringName) -> EnemyData:
	return _find(ENEMIES, id)


static func consumable(id: StringName) -> ConsumableData:
	return _find(CONSUMABLES, id)


static func weapons_for_slot(slot: WeaponData.Slot) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w: WeaponData in WEAPONS:
		if w.slot == slot:
			out.append(w)
	return out


static func all_melee() -> Array[MeleeData]:
	var out: Array[MeleeData] = []
	for m: MeleeData in MELEE:
		out.append(m)
	return out


static func unique_enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for e: EnemyData in ENEMIES:
		if e.threat_tier == EnemyData.ThreatTier.UNIQUE:
			out.append(e)
	return out


static func analyzable_enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for e: EnemyData in ENEMIES:
		if e.is_analyzable():
			out.append(e)
	return out

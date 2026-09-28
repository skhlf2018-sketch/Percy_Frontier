class_name WeaponItem
extends RefCounted
## 무기 한 자루(기획서 §9.4 희귀도, §9.5 강화). 같은 기본 무기라도 희귀도와 특성, 강화 단계가 다를 수 있다.
## 플레이어는 주무기·보조 총기·근접 무기를 한 자루씩만 든다(§11.5 슬롯 제한). 새 무기를 주우려면
## 같은 칸의 무기를 내려놓아야 한다.

enum Slot { PRIMARY, SECONDARY, MELEE }

const SLOT_NAMES := ["주무기", "보조 총기", "근접 무기"]
const UPGRADE_STEP := 0.08
## 되팔 때 값의 희귀도 배율
const RARITY_VALUE := [1.0, 1.6, 2.6, 4.0, 7.0, 10.0]

static var _next_uid: int = 1

var uid: int = 0
var base_id: StringName
var rarity: int = ItemRarity.Tier.STANDARD
var perks: Array[StringName] = []
var upgrade: int = 0
## 전설·유니크 같은 고유 이름. 비어 있으면 기본 이름을 쓴다.
var custom_name: String = ""


static func create(base: StringName, tier: int = ItemRarity.Tier.STANDARD, perk_ids: Array[StringName] = [],
		name_override: String = "") -> WeaponItem:
	var it := WeaponItem.new()
	it.uid = _next_uid
	_next_uid += 1
	it.base_id = base
	it.rarity = clampi(tier, 0, ItemRarity.Tier.UNIQUE)
	it.perks = perk_ids.duplicate()
	it.custom_name = name_override
	return it


## 희귀도에 맞춰 특성을 굴려 만든다(전설이면 고유 이름이 붙는다).
static func roll(base: StringName, tier: int, rng: RandomNumberGenerator) -> WeaponItem:
	var gun := GameDB.weapon(base)
	var perks_rolled := WeaponPerks.roll(tier, base, gun != null, gun != null and not gun.uses_heat, rng)
	var it := create(base, tier, perks_rolled)
	if tier == ItemRarity.Tier.LEGENDARY:
		var sig: Array = WeaponPerks.SIGNATURES.get(base, [])
		if not sig.is_empty():
			it.custom_name = String(sig[1])
	return it


func gun_data() -> WeaponData:
	return GameDB.weapon(base_id)


func melee_data() -> MeleeData:
	return GameDB.melee(base_id)


func is_gun() -> bool:
	return gun_data() != null


func is_valid() -> bool:
	return gun_data() != null or melee_data() != null


func slot() -> int:
	var g := gun_data()
	if g:
		return Slot.PRIMARY if g.slot == WeaponData.Slot.PRIMARY else Slot.SECONDARY
	return Slot.MELEE


func base_name() -> String:
	var g := gun_data()
	if g:
		return g.display_name
	var m := melee_data()
	return m.display_name if m else String(base_id)


func display_name() -> String:
	var n := custom_name if custom_name != "" else base_name()
	return "%s +%d" % [n, upgrade] if upgrade > 0 else n


func rarity_name() -> String:
	return ItemRarity.tier_name(rarity)


func color() -> Color:
	return ItemRarity.tier_color(rarity)


func class_label() -> String:
	var g := gun_data()
	return g.class_label() if g else "근접 무기"


func has_perk(id: StringName) -> bool:
	return perks.has(id)


func price() -> int:
	var g := gun_data()
	if g:
		return g.price
	var m := melee_data()
	return m.price if m else 50


## 공방에 되팔 때 받는 은화
func sell_value() -> int:
	return int(round(price() * 0.35 * RARITY_VALUE[rarity] * (1.0 + 0.25 * upgrade)))


# --- 효과 ---

## 피해 배율: 강화 단계 + 예리함
func damage_mult() -> float:
	var m := 1.0 + UPGRADE_STEP * upgrade
	if has_perk(&"keen"):
		m *= 1.1
	return m


func reload_mult() -> float:
	return 1.2 if has_perk(&"quick_hands") and is_gun() else 1.0


## 근접 공격 속도(전조·회복 시간을 나눈다)
func melee_speed_mult() -> float:
	return 1.12 if has_perk(&"quick_hands") and not is_gun() else 1.0


func mag_capacity() -> int:
	var g := gun_data()
	if g == null or g.uses_heat:
		return g.magazine_size if g else 0
	return int(round(g.magazine_size * (1.3 if has_perk(&"extended_mag") else 1.0)))


func recoil_mult() -> float:
	return 0.75 if has_perk(&"steady") else 1.0


func parry_bonus() -> float:
	return 0.05 if has_perk(&"balanced") else 0.0


func stagger_mult() -> float:
	return 1.35 if has_perk(&"heavy_blow") else 1.0


func counter_mult() -> float:
	return 1.6 if has_perk(&"counter_edge") else 1.0


## 명중마다 더하는 상태이상 누적
func extra_buildup() -> Dictionary:
	return StatusEffects.buildup_from(12.0 if has_perk(&"incendiary") else 0.0, 0.0, 0.0,
		15.0 if has_perk(&"serrated") else 0.0)


## 비교·툴팁에 쓰는 핵심 수치 한 줄
func stat_line() -> String:
	var g := gun_data()
	var mult := damage_mult()
	if g:
		var dmg := ("%d×%d" % [int(round(g.damage * mult)), g.pellets]) if g.pellets > 1 else "%d" % int(round(g.damage * mult))
		var feed := "과열식" if g.uses_heat else "탄창 %d" % mag_capacity()
		return "피해 %s · 분당 %d발 · %s" % [dmg, int(g.rounds_per_minute), feed]
	var m := melee_data()
	if m:
		return "약공격 %d · 강공격 %d · 패링 %.2f초" % [int(round(m.light_damage * mult)), int(round(m.heavy_damage * mult)),
			m.parry_window + parry_bonus()]
	return ""


## 특성 설명 목록
func perk_lines() -> Array[String]:
	var out: Array[String] = []
	for p in perks:
		out.append("%s — %s" % [WeaponPerks.name_of(p), WeaponPerks.desc_of(p)])
	return out


# --- 저장 ---

func to_dict() -> Dictionary:
	var ps: Array[String] = []
	for p in perks:
		ps.append(String(p))
	return {"base": String(base_id), "rarity": rarity, "perks": ps, "upgrade": upgrade, "name": custom_name}


## 저장 문서에서 되살린다. 알 수 없는 무기면 null.
static func from_dict(d: Dictionary) -> WeaponItem:
	var base := StringName(d.get("base", ""))
	if GameDB.weapon(base) == null and GameDB.melee(base) == null:
		return null
	var ps: Array[StringName] = []
	for p in d.get("perks", []):
		if WeaponPerks.has(StringName(p)):
			ps.append(StringName(p))
	var it := create(base, int(d.get("rarity", 0)), ps, String(d.get("name", "")))
	it.upgrade = clampi(int(d.get("upgrade", 0)), 0, 3)
	return it

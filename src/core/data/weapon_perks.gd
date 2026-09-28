class_name WeaponPerks
extends RefCounted
## 무기 특성(기획서 §9.4). 희귀도가 오를수록 특성이 하나씩 붙는다(최대 셋).
## 소수점 비교를 강요하지 않도록 효과는 몇 가지 뚜렷한 종류로 한정한다.
##  - 개량: 작은 특성 1
##  - 희귀: 작은 특성 1 + 빌드 특성 1
##  - 에픽: 작은 특성 1 + 빌드 특성 1 + 특수 작동 1
##  - 전설: 무기마다 정해진 고유 특성 + 작은 특성 1 + 빌드 특성 1
##  - 유니크: 정해진 경로로만 얻는 고유 장비(특성을 굴리지 않는다)

enum Kind { MINOR, BUILD, SPECIAL, SIGNATURE }

## for: gun(총기만) · mag(탄창을 쓰는 총기만) · melee(근접만) · any
const PERKS := {
	&"keen": {"name": "예리함", "kind": Kind.MINOR, "for": "any", "desc": "피해 +10%"},
	&"quick_hands": {"name": "재빠른 손", "kind": Kind.MINOR, "for": "any", "desc": "총: 재장전 +20% · 근접: 공격 속도 +12%"},
	&"extended_mag": {"name": "확장 탄창", "kind": Kind.MINOR, "for": "mag", "desc": "탄창 +30%"},
	&"steady": {"name": "안정된 총열", "kind": Kind.MINOR, "for": "gun", "desc": "반동 -25%"},
	&"balanced": {"name": "균형 잡힌 날", "kind": Kind.MINOR, "for": "melee", "desc": "패링 판정 +0.05초"},
	&"resonant": {"name": "공명 각인", "kind": Kind.BUILD, "for": "any", "desc": "약점을 맞히면 공명 +3"},
	&"serrated": {"name": "톱니", "kind": Kind.BUILD, "for": "any", "desc": "명중마다 출혈 누적 +15"},
	&"incendiary": {"name": "발화", "kind": Kind.BUILD, "for": "any", "desc": "명중마다 화상 누적 +12"},
	&"heavy_blow": {"name": "묵직함", "kind": Kind.BUILD, "for": "any", "desc": "경직 +35%"},
	&"scavenger": {"name": "알뜰한 사냥꾼", "kind": Kind.BUILD, "for": "mag", "desc": "처치하면 이 총의 탄약을 탄창의 15%만큼 회수"},
	&"last_rounds": {"name": "마지막 탄", "kind": Kind.SPECIAL, "for": "mag", "desc": "탄창의 마지막 30%는 피해 +40%"},
	&"counter_edge": {"name": "반격의 날", "kind": Kind.SPECIAL, "for": "melee", "desc": "반격 피해 +60%"},
	&"chain_weak": {"name": "연쇄 약점", "kind": Kind.SPECIAL, "for": "any", "desc": "약점을 세 번 이어 맞히면 그 자리에 공명 폭발"},
	&"butcher": {"name": "도살자", "kind": Kind.SIGNATURE, "for": "melee", "desc": "처치하면 HP 8 회복"},
	&"one_eye": {"name": "외눈의 시선", "kind": Kind.SIGNATURE, "for": "gun", "desc": "정조준 중 피해 +30%"},
	&"pack_breaker": {"name": "무리 깨기", "kind": Kind.SIGNATURE, "for": "gun", "desc": "경직된 적에게 피해 +35%"},
}

## 전설 무기의 고유 특성과 이름(기본 무기 id → [특성, 전설 이름])
const SIGNATURES := {
	&"chief_greatblade": [&"butcher", "도살자의 대도"],
	&"goblin_cleaver": [&"butcher", "피 맛을 본 식칼"],
	&"bolt_rifle": [&"one_eye", "외눈의 조준총"],
	&"sniper_l14": [&"one_eye", "L-14 「외눈」"],
	&"pipe_shotgun": [&"pack_breaker", "무리 깨는 파이프"],
	&"shotgun_logger": [&"pack_breaker", "벌목꾼 「무리 깨기」"],
}


static func has(id: StringName) -> bool:
	return PERKS.has(id)


static func name_of(id: StringName) -> String:
	return String(PERKS[id].name) if PERKS.has(id) else String(id)


static func desc_of(id: StringName) -> String:
	return String(PERKS[id].desc) if PERKS.has(id) else ""


## 무기에 붙을 수 있는 특성인지(for 조건)
static func fits(id: StringName, is_gun: bool, uses_mag: bool) -> bool:
	match String(PERKS[id]["for"]):
		"gun":
			return is_gun
		"mag":
			return is_gun and uses_mag
		"melee":
			return not is_gun
	return true


static func _pick(kind: int, is_gun: bool, uses_mag: bool, rng: RandomNumberGenerator, taken: Array[StringName]) -> StringName:
	var pool: Array[StringName] = []
	for id: StringName in PERKS:
		if int(PERKS[id].kind) == kind and fits(id, is_gun, uses_mag) and not taken.has(id):
			pool.append(id)
	if pool.is_empty():
		return &""
	return pool[rng.randi() % pool.size()]


## 희귀도에 맞춰 특성을 굴린다.
static func roll(rarity: int, base_id: StringName, is_gun: bool, uses_mag: bool, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	var plan: Array[int] = []
	match rarity:
		ItemRarity.Tier.IMPROVED:
			plan = [Kind.MINOR]
		ItemRarity.Tier.RARE:
			plan = [Kind.MINOR, Kind.BUILD]
		ItemRarity.Tier.EPIC:
			plan = [Kind.MINOR, Kind.BUILD, Kind.SPECIAL]
		ItemRarity.Tier.LEGENDARY:
			var sig: Array = SIGNATURES.get(base_id, [])
			if not sig.is_empty():
				out.append(sig[0])
			plan = [Kind.MINOR, Kind.BUILD]
	for kind in plan:
		var id := _pick(kind, is_gun, uses_mag, rng, out)
		if id != &"":
			out.append(id)
	return out

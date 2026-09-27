class_name ItemDB
extends RefCounted
## 재료·의뢰 물품(기획서 §11.2: 일반 화폐 1종과 지역 재료). 재료는 무게 제한 없는 별도 보관함에 들어간다(§11.5).
## 몬스터별 드롭 표와 은화 범위도 여기서 정한다. 수치는 시험 후 조정한다.

const ITEMS := {
	&"rabbit_fur": {"name": "살인토끼 털", "value": 6, "color": Color(0.92, 0.9, 0.84),
		"desc": "부드럽지만 질긴 털. 잡화점에서 사 간다."},
	&"rabbit_fang": {"name": "날카로운 앞니", "value": 14, "color": Color(0.95, 0.95, 0.9),
		"desc": "살인토끼의 앞니. 무기 공방에서 날붙이 강화에 쓴다."},
	&"stone_scale": {"name": "돌비늘 조각", "value": 20, "color": Color(0.55, 0.52, 0.48),
		"desc": "바위등 돌격수의 등껍질 조각. 단단해서 장비 강화와 설비 수리에 쓰인다."},
	&"charger_horn": {"name": "돌격수 뿔", "value": 60, "color": Color(0.72, 0.62, 0.45),
		"desc": "좀처럼 온전히 얻기 힘든 뿔. 공방에서 총기 강화에 쓴다."},
	&"fire_spore": {"name": "발화 포자", "value": 10, "color": Color(1.0, 0.55, 0.2),
		"desc": "문지르면 불꽃이 튀는 포자. 조심해서 다뤄야 한다."},
	&"spore_sac": {"name": "포자 주머니", "value": 24, "color": Color(0.95, 0.4, 0.3),
		"desc": "포자 사수의 발화 주머니. 공명 연구소가 연구용으로 산다."},
	&"herb_basket": {"name": "약초 바구니", "value": 0, "color": Color(0.6, 0.8, 0.4), "quest": true,
		"desc": "여관 주인 마르타가 늪 연못가에서 잃어버린 바구니."},
}

## 몬스터별 재료 드롭: [아이템, 확률, 최소, 최대]
const DROPS := {
	&"killer_rabbit": [[&"rabbit_fur", 0.7, 1, 2], [&"rabbit_fang", 0.25, 1, 1]],
	&"rock_charger": [[&"stone_scale", 1.0, 2, 3], [&"charger_horn", 0.3, 1, 1]],
	&"spore_spitter": [[&"fire_spore", 0.8, 1, 2], [&"spore_sac", 0.3, 1, 1]],
}
## 몬스터별 은화 범위
const SILVER := {
	&"killer_rabbit": [2, 5],
	&"rock_charger": [15, 25],
	&"spore_spitter": [4, 8],
}


static func has_item(id: StringName) -> bool:
	return ITEMS.has(id)


static func name_of(id: StringName) -> String:
	return ITEMS[id].name if ITEMS.has(id) else String(id)


static func value_of(id: StringName) -> int:
	return int(ITEMS[id].value) if ITEMS.has(id) else 0


static func color_of(id: StringName) -> Color:
	return ITEMS[id].color if ITEMS.has(id) else Color(1, 1, 1)


static func is_quest_item(id: StringName) -> bool:
	return ITEMS.has(id) and bool(ITEMS[id].get("quest", false))


## 처치 드롭을 굴린다: [[아이템, 개수], ...]
static func roll_drops(enemy_id: StringName, luck_mult: float, rng: RandomNumberGenerator) -> Array:
	var out := []
	for entry in DROPS.get(enemy_id, []):
		if rng.randf() < minf(float(entry[1]) * luck_mult, 1.0):
			out.append([entry[0], rng.randi_range(int(entry[2]), int(entry[3]))])
	return out


static func roll_silver(enemy_id: StringName, rng: RandomNumberGenerator) -> int:
	var r: Array = SILVER.get(enemy_id, [0, 0])
	return rng.randi_range(int(r[0]), int(r[1]))

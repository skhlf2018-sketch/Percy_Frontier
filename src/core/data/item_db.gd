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
	# --- 1지역 새 종의 재료 ---
	&"rabbit_horn": {"name": "뿔토끼 뿔", "value": 12, "color": Color(0.82, 0.76, 0.62),
		"desc": "짧고 단단한 뿔. 갈아서 화살촉이나 장식에 쓴다."},
	&"wolf_pelt": {"name": "잿빛 늑대 가죽", "value": 14, "color": Color(0.55, 0.53, 0.5),
		"desc": "두껍고 따뜻한 가죽. 잡화점에서 사 간다."},
	&"wolf_fang": {"name": "늑대 송곳니", "value": 18, "color": Color(0.94, 0.92, 0.85),
		"desc": "날카로운 송곳니. 무기 공방에서 날붙이 강화에 쓴다."},
	&"alpha_mane": {"name": "우두머리의 갈기", "value": 60, "color": Color(0.25, 0.23, 0.22),
		"desc": "늑대 우두머리의 검은 갈기. 사냥꾼들이 높이 쳐 준다."},
	&"goblin_trinket": {"name": "고블린 장신구", "value": 10, "color": Color(0.7, 0.55, 0.3),
		"desc": "뼈와 쇳조각을 엮은 장신구. 잡동사니지만 값은 쳐 준다."},
	&"scrap_parts": {"name": "녹슨 부품", "value": 12, "color": Color(0.55, 0.45, 0.38),
		"desc": "고블린 총에서 떼어 낸 부품. 무기 공방에서 총기 손질에 쓴다."},
	&"hex_bead": {"name": "주술 구슬", "value": 30, "color": Color(0.35, 0.9, 0.55),
		"desc": "고블린 주술사의 구슬. 희미하게 빛난다. 공명 연구소가 산다."},
	&"chief_seal": {"name": "두목의 인장", "value": 80, "color": Color(0.85, 0.7, 0.3),
		"desc": "고블린 두목이 목에 걸던 인장. 퍼시 경비대에 가져가면 좋아한다."},
	&"moss_hide": {"name": "이끼등 가죽", "value": 16, "color": Color(0.4, 0.48, 0.3),
		"desc": "이끼가 낀 두꺼운 가죽 조각."},
	&"boar_tusk": {"name": "멧돼지 엄니", "value": 16, "color": Color(0.92, 0.88, 0.76),
		"desc": "휘어진 엄니. 손잡이나 장식으로 쓴다."},
	&"thorn_bristle": {"name": "가시 갈기", "value": 10, "color": Color(0.5, 0.42, 0.3),
		"desc": "멧돼지 등의 억센 가시털. 솔을 만든다."},
	&"toad_gland": {"name": "두꺼비 독샘", "value": 18, "color": Color(0.7, 0.75, 0.3),
		"desc": "쓸개즙이 든 샘. 조심해서 다루면 약재가 된다."},
	&"mantis_blade": {"name": "사마귀 낫", "value": 30, "color": Color(0.46, 0.4, 0.3),
		"desc": "나무껍질 사마귀의 앞다리 낫. 가볍고 날카롭다."},
	&"spider_silk": {"name": "거미줄 뭉치", "value": 14, "color": Color(0.9, 0.9, 0.92),
		"desc": "끈적한 거미줄. 말리면 질긴 실이 된다."},
	&"venom_sac": {"name": "독주머니", "value": 22, "color": Color(0.5, 0.2, 0.5),
		"desc": "동굴 거미의 독주머니."},
	&"bat_wing": {"name": "박쥐 날개막", "value": 8, "color": Color(0.25, 0.2, 0.2),
		"desc": "얇고 질긴 막."},
	&"mother_core": {"name": "포자 모체의 핵", "value": 90, "color": Color(1.0, 0.45, 0.3),
		"desc": "아직 따뜻한 붉은 핵. 공명 연구소가 탐내는 표본."},
	# 희귀 전리품: 무기 공방에서 전용 무기를 만드는 재료
	&"serial_fang": {"name": "연쇄살인범의 앞니", "value": 90, "color": Color(0.8, 0.15, 0.15), "trophy": true,
		"desc": "검은 토끼의 붉게 물든 앞니. 무기 공방에서 특별한 칼을 벼리는 재료."},
	&"silver_mane": {"name": "은갈기", "value": 120, "color": Color(0.8, 0.88, 1.0), "trophy": true,
		"desc": "서리가 맺힌 은빛 갈기. 무기 공방에서 특별한 쌍검을 벼리는 재료."},
	&"oneeye_lens": {"name": "외눈의 조준경", "value": 110, "color": Color(0.45, 0.75, 1.0), "trophy": true,
		"desc": "외눈 저격수가 아끼던 조준경. 무기 공방에서 특별한 소총을 만드는 재료."},
	&"gold_horn": {"name": "황금뿔", "value": 150, "color": Color(1.0, 0.8, 0.3), "trophy": true,
		"desc": "황금뿔 돌격수의 뿔. 무기 공방에서 특별한 산탄총을 만드는 재료."},
	# 보스 재료(기획서 §11.2: 보스·유니크 핵은 전용 장비와 스킬 해금에 쓴다)
	&"maw_scale": {"name": "늪턱 비늘판", "value": 45, "color": Color(0.36, 0.42, 0.26),
		"desc": "늪턱 구렁의 등에서 떨어진 두꺼운 비늘판. 무기 공방에서 상위 강화에 쓴다."},
	&"maw_core": {"name": "늪턱 구렁의 핵", "value": 260, "color": Color(0.95, 0.35, 0.3), "trophy": true, "core": true,
		"desc": "늪턱 구렁의 목 아래에서 꺼낸 붉은 핵. 아직도 느리게 뛴다. 무기 공방에서 특별한 무기를 벼리는 재료."},
}

## 몬스터별 재료 드롭: [아이템, 확률, 최소, 최대]
const DROPS := {
	&"killer_rabbit": [[&"rabbit_fur", 0.7, 1, 2], [&"rabbit_fang", 0.25, 1, 1]],
	&"rock_charger": [[&"stone_scale", 1.0, 2, 3], [&"charger_horn", 0.3, 1, 1]],
	&"spore_spitter": [[&"fire_spore", 0.8, 1, 2], [&"spore_sac", 0.3, 1, 1]],
	&"horn_rabbit": [[&"rabbit_fur", 0.7, 1, 2], [&"rabbit_horn", 0.5, 1, 1]],
	&"serial_rabbit": [[&"serial_fang", 1.0, 1, 1], [&"rabbit_fang", 1.0, 2, 3], [&"rabbit_fur", 1.0, 2, 3]],
	&"ash_wolf": [[&"wolf_pelt", 0.6, 1, 1], [&"wolf_fang", 0.3, 1, 1]],
	&"wolf_alpha": [[&"alpha_mane", 1.0, 1, 1], [&"wolf_pelt", 1.0, 1, 2], [&"wolf_fang", 0.7, 1, 2]],
	&"silvermane": [[&"silver_mane", 1.0, 1, 1], [&"wolf_fang", 1.0, 1, 2]],
	&"goblin_scout": [[&"goblin_trinket", 0.5, 1, 1]],
	&"goblin_brute": [[&"goblin_trinket", 0.5, 1, 2]],
	&"goblin_gunner": [[&"scrap_parts", 0.6, 1, 2], [&"goblin_trinket", 0.3, 1, 1]],
	&"goblin_thrower": [[&"goblin_trinket", 0.5, 1, 1], [&"rabbit_fang", 0.2, 1, 1]],
	&"goblin_shaman": [[&"hex_bead", 0.8, 1, 2], [&"goblin_trinket", 0.4, 1, 1]],
	&"goblin_chief": [[&"chief_seal", 1.0, 1, 1], [&"goblin_trinket", 1.0, 2, 3], [&"scrap_parts", 0.6, 1, 2]],
	&"oneeye_sniper": [[&"oneeye_lens", 1.0, 1, 1], [&"scrap_parts", 1.0, 2, 3]],
	&"mossback_calf": [[&"moss_hide", 0.7, 1, 1], [&"stone_scale", 0.3, 1, 1]],
	&"goldhorn_charger": [[&"gold_horn", 1.0, 1, 1], [&"stone_scale", 1.0, 3, 5], [&"charger_horn", 0.6, 1, 1]],
	&"thorn_boar": [[&"boar_tusk", 0.5, 1, 2], [&"thorn_bristle", 0.6, 1, 2]],
	&"bog_toad": [[&"toad_gland", 0.6, 1, 1]],
	&"bark_mantis": [[&"mantis_blade", 0.5, 1, 1]],
	&"cave_spider": [[&"spider_silk", 0.7, 1, 2], [&"venom_sac", 0.3, 1, 1]],
	&"cave_bat": [[&"bat_wing", 0.5, 1, 1]],
	&"bloat_pod": [[&"fire_spore", 0.5, 1, 2]],
	&"spore_mother": [[&"mother_core", 1.0, 1, 1], [&"spore_sac", 1.0, 2, 3], [&"fire_spore", 1.0, 3, 5]],
	&"mire_maw": [[&"maw_scale", 1.0, 3, 4]],
}
## 몬스터별 은화 범위
const SILVER := {
	&"killer_rabbit": [2, 5],
	&"rock_charger": [15, 25],
	&"spore_spitter": [4, 8],
	&"horn_rabbit": [3, 6],
	&"serial_rabbit": [40, 60],
	&"ash_wolf": [4, 8],
	&"wolf_alpha": [30, 45],
	&"silvermane": [50, 70],
	&"goblin_scout": [5, 10],
	&"goblin_brute": [6, 12],
	&"goblin_gunner": [7, 13],
	&"goblin_thrower": [6, 12],
	&"goblin_shaman": [10, 18],
	&"goblin_chief": [45, 70],
	&"oneeye_sniper": [55, 80],
	&"mossback_calf": [2, 5],
	&"goldhorn_charger": [70, 100],
	&"thorn_boar": [4, 8],
	&"bog_toad": [3, 7],
	&"bark_mantis": [6, 12],
	&"cave_spider": [5, 9],
	&"cave_bat": [1, 3],
	&"bloat_pod": [0, 2],
	&"spore_mother": [40, 60],
	&"mire_maw": [180, 240],
}


static func has_item(id: StringName) -> bool:
	return ITEMS.has(id)


static func name_of(id: StringName) -> String:
	return ITEMS[id].name if ITEMS.has(id) else String(id)


static func value_of(id: StringName) -> int:
	return int(ITEMS[id].value) if ITEMS.has(id) else 0


static func color_of(id: StringName) -> Color:
	return ITEMS[id].color if ITEMS.has(id) else Color(1, 1, 1)


## 희귀 전리품(공방에서 전용 무기를 만드는 재료)
static func is_trophy(id: StringName) -> bool:
	return ITEMS.has(id) and bool(ITEMS[id].get("trophy", false))


## 보스·유니크 핵
static func is_core(id: StringName) -> bool:
	return ITEMS.has(id) and bool(ITEMS[id].get("core", false))


## "모두 판다"에서 빼는 물건(의뢰 물품, 전용 무기 재료, 핵)
static func is_keepsake(id: StringName) -> bool:
	return is_quest_item(id) or is_trophy(id) or is_core(id)


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

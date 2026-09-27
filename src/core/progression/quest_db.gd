class_name QuestDB
extends RefCounted
## 이 개발 빌드의 의뢰(기획서 §17): 메인 1, 지역 1, 인물 1, 발견·추적 1.
## 단계 종류: area(지역 도착), talk(주민과 대화), kill(몬스터 처치 수), item(아이템 보유 수),
## clue(유니크 단서 수), unique(유니크 사건에서 살아남기).
## hint는 지도와 추적 표시에 쓰는 대략적인 목표 지점(정확한 표식이 아니라 방향과 거리만 알려 준다).

const QUESTS := {
	&"main_signal": {
		"title": "구조 신호", "type": "메인",
		"steps": [
			{"text": "구조 신호를 따라 동쪽의 정착지를 찾는다", "type": &"area", "target": &"percy", "need": 1,
				"hint": Vector2(104, 136)},
			{"text": "퍼시 광장의 의뢰 게시판 옆, 의뢰 담당자 카일과 이야기한다", "type": &"talk", "target": &"clerk", "need": 1,
				"hint": Vector2(137, 141)},
			{"text": "통신탑을 고칠 돌비늘 조각 3개를 모은다 — 북동 초원의 바위등 돌격수", "type": &"item",
				"target": &"stone_scale", "need": 3, "hint": Vector2(150, -104)},
			{"text": "무기 공방의 대장장이 도르가에게 돌비늘 조각을 건넨다", "type": &"talk", "target": &"smith", "need": 1,
				"consume": {&"stone_scale": 3}, "hint": Vector2(169, 151)},
		],
		"reward": {"xp": 200, "silver": 120},
		"done_text": "통신탑이 다시 신호를 보내기 시작했다. 이 개발 빌드의 메인 이야기는 여기까지다.",
	},
	&"rabbit_trouble": {
		"title": "길목의 토끼 소동", "type": "지역", "giver": &"clerk",
		"steps": [
			{"text": "살인토끼 6마리를 처치한다 — 강하 지점과 다리 사이 풀숲", "type": &"kill", "target": &"killer_rabbit",
				"need": 6, "hint": Vector2(-84, 30)},
			{"text": "의뢰 담당자 카일에게 보고한다", "type": &"talk", "target": &"clerk", "need": 1, "hint": Vector2(137, 141)},
		],
		"reward": {"xp": 90, "silver": 80},
		"done_text": "길이 조금은 안전해졌다.",
	},
	&"herb_basket": {
		"title": "잃어버린 약초 바구니", "type": "인물", "giver": &"innkeeper",
		"steps": [
			{"text": "남서쪽 늪 연못가에서 약초 바구니를 찾는다 — 포자 사수를 조심할 것", "type": &"item",
				"target": &"herb_basket", "need": 1, "hint": Vector2(-150, 172)},
			{"text": "여관 주인 마르타에게 바구니를 돌려준다", "type": &"talk", "target": &"innkeeper", "need": 1,
				"consume": {&"herb_basket": 1}, "hint": Vector2(135, 126)},
		],
		"reward": {"xp": 70, "silver": 30, "consumables": {&"field_suture": 2}},
		"done_text": "마르타가 약초로 만든 봉합제를 나눠 주었다.",
	},
	&"night_silence": {
		"title": "밤에 조용해지는 숲", "type": "추적", "giver": &"hunter",
		"steps": [
			{"text": "그늘 숲 주변에서 이상한 흔적(단서)을 찾는다 — 숲 가장자리, 북쪽 야영지, 밤의 숲", "type": &"clue",
				"target": &"night_predator", "need": 2, "hint": Vector2(-40, -110), "radius": 60.0},
			{"text": "밤에 그늘 숲 깊은 곳으로 들어가 살아남는다 — 회복약을 챙길 것", "type": &"unique",
				"target": &"night_predator", "need": 1, "hint": Vector2(-72, -140), "radius": 55.0},
			{"text": "사냥꾼 노라에게 본 것을 이야기한다", "type": &"talk", "target": &"hunter", "need": 1,
				"hint": Vector2(114, 128)},
		],
		"reward": {"xp": 250, "silver": 60},
		"done_text": "노라는 오래 말이 없었다. 그 짐승은 아직 숲 어딘가에 있다.",
	},
}


static func has(id: StringName) -> bool:
	return QUESTS.has(id)


static func get_quest(id: StringName) -> Dictionary:
	return QUESTS.get(id, {})


static func title(id: StringName) -> String:
	return String(QUESTS[id].title) if QUESTS.has(id) else String(id)


static func steps(id: StringName) -> Array:
	return QUESTS[id].steps if QUESTS.has(id) else []

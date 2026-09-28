class_name MonsterCatalog
extends RefCounted
## 몬스터 카탈로그 목표(기획서 §14.1: 일반 250 · 희귀 50, §16.1: 지역 보스 12, §15.3: 유니크 8).
## 도감의 수집 현황과 문서(docs/design/몬스터_카탈로그.md)가 같은 목표를 쓴다.

const CATEGORIES: Array[StringName] = [&"normal", &"rare", &"boss", &"unique"]
const TARGETS := {&"normal": 250, &"rare": 50, &"boss": 12, &"unique": 8}
const NAMES := {&"normal": "일반", &"rare": "희귀", &"boss": "보스", &"unique": "유니크"}


## 위협 등급으로 카탈로그 구분을 정한다(일반·강화·정예는 일반 카탈로그).
static func category_of(data: EnemyData) -> StringName:
	match data.threat_tier:
		EnemyData.ThreatTier.RARE:
			return &"rare"
		EnemyData.ThreatTier.BOSS:
			return &"boss"
		EnemyData.ThreatTier.UNIQUE:
			return &"unique"
	return &"normal"


## 구분별 {"target": 목표, "made": 이 빌드에 있는 종 수, "found": 도감에 오른 종 수}
static func progress() -> Dictionary:
	var out := {}
	for c in CATEGORIES:
		out[c] = {"target": TARGETS[c], "made": 0, "found": 0}
	for data: EnemyData in GameDB.ENEMIES:
		if not data.in_catalog:
			continue
		var c := category_of(data)
		out[c].made += 1
		if is_found(data):
			out[c].found += 1
	return out


static func is_found(data: EnemyData) -> bool:
	if data.threat_tier == EnemyData.ThreatTier.UNIQUE:
		return bool(GameState.unique_record(data.id).sighted)
	return GameState.bestiary.is_discovered(data.id)

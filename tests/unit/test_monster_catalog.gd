extends TestCase
## 몬스터 카탈로그 목표(일반 250 · 희귀 50 · 보스 12 · 유니크 8)와 수집 현황.


func after_each() -> void:
	GameState.reset_session()


func test_targets_match_design() -> void:
	assert_eq(MonsterCatalog.TARGETS[&"normal"], 250)
	assert_eq(MonsterCatalog.TARGETS[&"rare"], 50)
	assert_eq(MonsterCatalog.TARGETS[&"boss"], 12)
	assert_eq(MonsterCatalog.TARGETS[&"unique"], 8)


func test_training_dummy_is_not_counted() -> void:
	var dummy := GameDB.enemy(&"training_dummy")
	assert_false(dummy.in_catalog)
	var made := 0
	for c in MonsterCatalog.CATEGORIES:
		made += int(MonsterCatalog.progress()[c].made)
	var catalog := GameDB.ENEMIES.filter(func(e: EnemyData) -> bool: return e.in_catalog)
	assert_eq(made, catalog.size(), "카탈로그 대상만 센다")


func test_found_counts_follow_bestiary_and_unique_log() -> void:
	var before: int = MonsterCatalog.progress()[&"normal"].found
	GameState.bestiary.record(GameDB.enemy(&"killer_rabbit"), Bestiary.Event.OBSERVE)
	assert_eq(int(MonsterCatalog.progress()[&"normal"].found), before + 1, "도감에 오르면 센다")
	assert_eq(int(MonsterCatalog.progress()[&"unique"].found), 0)
	GameState.record_unique(&"night_predator", "sighted")
	assert_eq(int(MonsterCatalog.progress()[&"unique"].found), 1, "유니크는 최초 발견으로 센다")


func test_every_catalog_species_has_distinct_identity() -> void:
	# 같은 이름이나 같은 id의 종이 둘 있으면 안 된다.
	var ids := {}
	var names := {}
	for e: EnemyData in GameDB.ENEMIES:
		assert_false(ids.has(e.id), "id 중복: %s" % e.id)
		assert_false(names.has(e.display_name), "이름 중복: %s" % e.display_name)
		ids[e.id] = true
		names[e.display_name] = true

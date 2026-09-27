extends Node
## 한 번의 플레이 동안 유지되는 진행 상태: 성장(레벨·능력치), 도감·분석도, 스킬 해금과 장착, 장비 선택,
## 발견한 지역.

signal skills_changed
signal loadout_changed

## 공명 장치 기본 기록에 들어 있는 시작 스킬
const STARTER_SKILL := &"frost_pulse"
const SKILL_SLOT_COUNT := 4

var bestiary: Bestiary
var progress: PlayerProgress
## 발견한 지역 id(처음 들어가면 경험치와 알림)
var discovered_areas: Array[StringName] = []
var unlocked_skills: Array[StringName] = []
## 장착 슬롯(키 4~7). 빈 슬롯은 &""
var skill_slots: Array[StringName] = []
var primary_weapon: StringName = &"rifle_bfa3"
var secondary_weapon: StringName = &"pistol_bf9"
var melee_weapon: StringName = &"sword_survey"


func _ready() -> void:
	reset_session()


func reset_session() -> void:
	progress = PlayerProgress.new()
	progress.leveled_up.connect(_on_leveled_up)
	discovered_areas = []
	bestiary = Bestiary.new()
	bestiary.skill_unlocked.connect(_on_skill_unlocked)
	bestiary.analysis_changed.connect(_on_analysis_changed)
	bestiary.entry_discovered.connect(_on_entry_discovered)
	unlocked_skills = [STARTER_SKILL]
	skill_slots = [STARTER_SKILL, &"", &"", &""]
	primary_weapon = &"rifle_bfa3"
	secondary_weapon = &"pistol_bf9"
	melee_weapon = &"sword_survey"
	skills_changed.emit()
	loadout_changed.emit()


## 경험치를 준다(처치, 발견, 의뢰).
func grant_xp(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	progress.add_xp(amount)
	GameEvents.xp_gained.emit(amount, reason)


## 지역에 처음 들어가면 기록하고 경험치를 준다. 처음이면 true.
func discover_area(area_id: StringName, area_name: String, xp: int = 20) -> bool:
	if discovered_areas.has(area_id):
		return false
	discovered_areas.append(area_id)
	GameEvents.announce("지역 발견 · %s" % area_name, "퍼시 외곽권", GameEvents.AnnounceKind.DISCOVERY)
	grant_xp(xp, "지역 발견")
	return true


func _on_leveled_up(new_level: int, points: int) -> void:
	GameEvents.announce("레벨 업 · Lv %d" % new_level,
		"최대 HP·스태미나 증가 · 능력 포인트 +%d (Tab: 상태창)" % points, GameEvents.AnnounceKind.LEVEL_UP)


func is_skill_unlocked(skill_id: StringName) -> bool:
	return unlocked_skills.has(skill_id)


## 스킬을 해금하고 첫 빈 슬롯에 장착한다. 장착한 슬롯 번호(없으면 -1)를 돌려준다.
func unlock_skill(skill_id: StringName) -> int:
	if GameDB.skill(skill_id) == null:
		push_error("알 수 없는 스킬: %s" % skill_id)
		return -1
	if unlocked_skills.has(skill_id):
		return skill_slots.find(skill_id)
	unlocked_skills.append(skill_id)
	var slot := skill_slots.find(&"")
	if slot >= 0:
		skill_slots[slot] = skill_id
	skills_changed.emit()
	return slot


## 해금한 스킬을 슬롯에 넣는다. 다른 슬롯에 있던 스킬이면 두 슬롯을 맞바꾼다.
func assign_skill(skill_id: StringName, slot: int) -> bool:
	if slot < 0 or slot >= SKILL_SLOT_COUNT or not unlocked_skills.has(skill_id):
		return false
	var from := skill_slots.find(skill_id)
	if from == slot:
		return true
	var previous := skill_slots[slot]
	skill_slots[slot] = skill_id
	if from >= 0:
		skill_slots[from] = previous
	skills_changed.emit()
	return true


func set_primary_weapon(id: StringName) -> void:
	if GameDB.weapon(id) == null or primary_weapon == id:
		return
	primary_weapon = id
	loadout_changed.emit()


func set_melee_weapon(id: StringName) -> void:
	if GameDB.melee(id) == null or melee_weapon == id:
		return
	melee_weapon = id
	loadout_changed.emit()


## 시험장 전용: 모든 분석 대상의 분석을 완료한다.
func complete_all_analysis() -> void:
	for data in GameDB.analyzable_enemies():
		bestiary.complete(data)


func _on_skill_unlocked(skill_id: StringName, enemy_id: StringName, via_core: bool) -> void:
	var slot := unlock_skill(skill_id)
	var skill := GameDB.skill(skill_id)
	var enemy := GameDB.enemy(enemy_id)
	if skill == null or enemy == null:
		return
	var how := "스킬 핵 획득" if via_core else "분석 완료"
	var text := "%s %s — 스킬 해금: %s" % [enemy.display_name, how, skill.display_name]
	if slot >= 0:
		text += " (스킬 슬롯 %d)" % (slot + 1)
	GameEvents.notify(text, GameEvents.NoticeKind.UNLOCK)
	GameEvents.announce("스킬 습득 · %s" % skill.display_name,
		"%s %s%s" % [enemy.display_name, how, " · 슬롯 %d에 장착" % (slot + 1) if slot >= 0 else ""],
		GameEvents.AnnounceKind.SKILL)


func _on_analysis_changed(enemy_id: StringName, analysis: float, gained: float) -> void:
	if gained <= 0.0:
		return
	var enemy := GameDB.enemy(enemy_id)
	if enemy == null:
		return
	GameEvents.notify("%s 분석도 %d%%" % [enemy.display_name, int(floor(analysis))],
		GameEvents.NoticeKind.ANALYSIS)


func _on_entry_discovered(enemy_id: StringName) -> void:
	var enemy := GameDB.enemy(enemy_id)
	if enemy:
		GameEvents.notify("도감 등록: %s (%s)" % [enemy.display_name, enemy.tier_label()],
			GameEvents.NoticeKind.ANALYSIS)

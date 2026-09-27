class_name Bestiary
extends RefCounted
## 몬스터 도감과 분석도(기획서 §10.3).
## 1. 처음 관찰하거나 처치하면 도감이 열린다.
## 2. 약점 처치, 부위 파괴, 패링, 공격 회피 등 다양한 행동으로 분석도를 얻는다.
## 3. 처치 시 낮은 확률로 스킬 핵을 즉시 얻는다.
## 4. 운이 나빠도 분석도가 100에 도달하면 스킬을 확정 해금한다.
## 같은 행동을 반복하면 얻는 양이 줄어들어, 같은 몬스터 반복 사냥만이 최선이 되지 않게 한다.

enum Event { OBSERVE, KILL, WEAK_POINT_KILL, PART_BREAK, PARRY, EVADE }

signal entry_discovered(enemy_id: StringName)
signal analysis_changed(enemy_id: StringName, analysis: float, gained: float)
signal skill_unlocked(skill_id: StringName, enemy_id: StringName, via_core: bool)

const MAX_ANALYSIS := 100.0
## 같은 행동을 반복할 때마다 곱해지는 감소율
const REPEAT_DECAY := 0.8
## 반복 감소의 하한(기본값 대비 비율)
const REPEAT_FLOOR := 0.25


class Entry:
	var enemy_id: StringName
	var display_name: String = ""
	var discovered: bool = false
	var kills: int = 0
	var analysis: float = 0.0
	var skill_unlocked: bool = false
	var event_counts: Dictionary = {}


var entries: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func get_entry(enemy_id: StringName) -> Entry:
	return entries.get(enemy_id)


func _ensure(data: EnemyData) -> Entry:
	var e: Entry = entries.get(data.id)
	if e == null:
		e = Entry.new()
		e.enemy_id = data.id
		e.display_name = data.display_name
		entries[data.id] = e
	return e


func base_points(data: EnemyData, event: Event) -> float:
	match event:
		Event.OBSERVE:
			return data.analysis_observe
		Event.KILL:
			return data.analysis_kill
		Event.WEAK_POINT_KILL:
			return data.analysis_weak_kill
		Event.PART_BREAK:
			return data.analysis_part_break
		Event.PARRY:
			return data.analysis_parry
		Event.EVADE:
			return data.analysis_evade
	return 0.0


## 행동을 기록하고 얻은 분석도를 돌려준다.
func record(data: EnemyData, event: Event) -> float:
	if data == null:
		return 0.0
	var e := _ensure(data)
	if not e.discovered:
		e.discovered = true
		entry_discovered.emit(data.id)
	if event == Event.KILL or event == Event.WEAK_POINT_KILL:
		e.kills += 1
	var count: int = e.event_counts.get(event, 0)
	e.event_counts[event] = count + 1
	if event == Event.OBSERVE and count > 0:
		return 0.0
	if not data.is_analyzable() or e.skill_unlocked:
		return 0.0
	var base := base_points(data, event)
	var gained := maxf(base * pow(REPEAT_DECAY, count), base * REPEAT_FLOOR)
	gained = minf(gained, MAX_ANALYSIS - e.analysis)
	if gained <= 0.0:
		return 0.0
	e.analysis += gained
	analysis_changed.emit(data.id, e.analysis, gained)
	if e.analysis >= MAX_ANALYSIS:
		_unlock(data, e, false)
	return gained


## 처치 시 스킬 핵 드롭 판정. 얻었으면 true(즉시 해금).
## 스킬 핵 드롭 판정. bonus는 행운 능력치로 더해지는 확률.
func roll_core_drop(data: EnemyData, bonus: float = 0.0) -> bool:
	if data == null or not data.is_analyzable():
		return false
	var e := _ensure(data)
	if e.skill_unlocked:
		return false
	if rng.randf() < data.core_drop_chance + bonus:
		_unlock(data, e, true)
		return true
	return false


## 시험장 전용: 분석을 즉시 완료한다.
func complete(data: EnemyData) -> void:
	if data == null or not data.is_analyzable():
		return
	var e := _ensure(data)
	if not e.discovered:
		e.discovered = true
		entry_discovered.emit(data.id)
	if e.skill_unlocked:
		return
	e.analysis = MAX_ANALYSIS
	analysis_changed.emit(data.id, e.analysis, 0.0)
	_unlock(data, e, false)


func _unlock(data: EnemyData, e: Entry, via_core: bool) -> void:
	if e.skill_unlocked:
		return
	e.skill_unlocked = true
	if via_core:
		e.analysis = MAX_ANALYSIS
		analysis_changed.emit(data.id, e.analysis, 0.0)
	skill_unlocked.emit(data.analysis_skill, data.id, via_core)


func analysis_of(enemy_id: StringName) -> float:
	var e: Entry = entries.get(enemy_id)
	return e.analysis if e else 0.0


func is_discovered(enemy_id: StringName) -> bool:
	var e: Entry = entries.get(enemy_id)
	return e != null and e.discovered

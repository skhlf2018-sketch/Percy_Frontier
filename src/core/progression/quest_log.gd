class_name QuestLog
extends RefCounted
## 의뢰 진행(기획서 §17). 게임 속 사건(지역 도착, 대화, 처치, 아이템, 단서, 유니크 조우)을 받아 단계를 넘긴다.
## 이미 목적을 이룬 플레이어의 행동을 인정한다(§17.2): 아이템 단계는 받는 순간 이미 가진 수를 센다.

signal changed
signal step_advanced(quest_id: StringName, step: int)
signal completed(quest_id: StringName)

enum State { INACTIVE, ACTIVE, DONE }

## id → {"state", "step", "count"}
var quests: Dictionary = {}
## HUD에 보여 줄 의뢰
var tracked: StringName = &""
## 아이템 수를 셀 때 부르는 함수(아이템 id → 개수)
var item_counter: Callable
## 단서 수를 셀 때 부르는 함수(유니크 id 또는 &"any" → 개수)
var clue_counter: Callable
## 유니크 사건에서 살아남았는지 셀 때 부르는 함수(유니크 id → 0 또는 1)
var unique_counter: Callable


func state_of(id: StringName) -> int:
	return int(quests.get(id, {}).get("state", State.INACTIVE))


func is_active(id: StringName) -> bool:
	return state_of(id) == State.ACTIVE


func is_done(id: StringName) -> bool:
	return state_of(id) == State.DONE


func step_of(id: StringName) -> int:
	return int(quests.get(id, {}).get("step", 0))


func count_of(id: StringName) -> int:
	return int(quests.get(id, {}).get("count", 0))


func current_step(id: StringName) -> Dictionary:
	var steps := QuestDB.steps(id)
	var s := step_of(id)
	return steps[s] if s < steps.size() else {}


## 의뢰를 받는다. 새로 받았으면 true.
func start(id: StringName) -> bool:
	if not QuestDB.has(id) or state_of(id) != State.INACTIVE:
		return false
	quests[id] = {"state": State.ACTIVE, "step": 0, "count": 0}
	tracked = id
	GameEvents.announce("의뢰 수락 · %s" % QuestDB.title(id), String(current_step(id).get("text", "")),
		GameEvents.AnnounceKind.QUEST)
	_check_counts(id)
	changed.emit()
	return true


## 사건을 알린다. kind: area/talk/kill/item/clue/unique, target: 대상 id
func notify(kind: StringName, target: StringName, amount: int = 1) -> void:
	for id: StringName in quests.keys():
		if not is_active(id):
			continue
		var step := current_step(id)
		if step.is_empty() or step.type != kind:
			continue
		if step.target != &"any" and step.target != target:
			continue
		if kind == &"item" or kind == &"clue" or kind == &"unique":
			_check_counts(id)
			continue
		quests[id].count = count_of(id) + amount
		if count_of(id) >= int(step.need):
			_advance(id)
		else:
			changed.emit()


## 대화 단계는 주민과 이야기할 때 이 함수로 넘긴다. 넘겼으면 true.
func try_talk_step(id: StringName, npc_id: StringName) -> bool:
	if not is_active(id):
		return false
	var step := current_step(id)
	if step.is_empty() or step.type != &"talk" or step.target != npc_id:
		return false
	var consume: Dictionary = step.get("consume", {})
	for item in consume:
		if item_counter.is_valid() and int(item_counter.call(item)) < int(consume[item]):
			return false
	for item in consume:
		GameState.remove_item(item, int(consume[item]))
	_advance(id)
	return true


## 가진 아이템·찾은 단서처럼 "지금 가진 수"로 판정하는 단계를 센다(이미 이룬 것은 받자마자 인정, 기획서 §17.2).
func _check_counts(id: StringName) -> void:
	var step := current_step(id)
	if step.is_empty():
		return
	var counter: Callable
	if step.type == &"item":
		counter = item_counter
	elif step.type == &"clue":
		counter = clue_counter
	elif step.type == &"unique":
		counter = unique_counter
	if not counter.is_valid():
		return
	var have := int(counter.call(step.target))
	quests[id].count = mini(have, int(step.need))
	if have >= int(step.need):
		_advance(id)
	else:
		changed.emit()


func _advance(id: StringName) -> void:
	var steps := QuestDB.steps(id)
	var next := step_of(id) + 1
	if next >= steps.size():
		quests[id].state = State.DONE
		quests[id].step = steps.size()
		if tracked == id:
			tracked = _next_tracked()
		changed.emit()
		completed.emit(id)
		return
	quests[id].step = next
	quests[id].count = 0
	GameEvents.announce("의뢰 갱신 · %s" % QuestDB.title(id), String(steps[next].text), GameEvents.AnnounceKind.QUEST)
	step_advanced.emit(id, next)
	changed.emit()
	# 다음 단계가 아이템·단서면 이미 가진 것을 바로 센다.
	_check_counts(id)


func _next_tracked() -> StringName:
	for id: StringName in quests:
		if is_active(id):
			return id
	return &""


func active_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in quests:
		if is_active(id):
			out.append(id)
	return out


func done_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in quests:
		if is_done(id):
			out.append(id)
	return out


## 추적 중인 의뢰의 목표 지점(없으면 Vector2.INF)
func tracked_hint() -> Vector2:
	if tracked == &"" or not is_active(tracked):
		return Vector2.INF
	var step := current_step(tracked)
	return step.get("hint", Vector2.INF)


func step_progress_text(id: StringName) -> String:
	var step := current_step(id)
	if step.is_empty():
		return ""
	var need := int(step.need)
	if need > 1:
		return "%s (%d/%d)" % [step.text, count_of(id), need]
	return String(step.text)


# --- 저장 ---

func to_dict() -> Dictionary:
	var out := {}
	for id: StringName in quests:
		out[String(id)] = quests[id].duplicate()
	return {"quests": out, "tracked": String(tracked)}


func from_dict(d: Dictionary) -> void:
	quests = {}
	var q: Dictionary = d.get("quests", {})
	for k in q:
		var id := StringName(k)
		if not QuestDB.has(id):
			continue
		var v: Dictionary = q[k]
		quests[id] = {"state": clampi(int(v.get("state", 0)), 0, 2), "step": maxi(int(v.get("step", 0)), 0),
			"count": maxi(int(v.get("count", 0)), 0)}
	tracked = StringName(d.get("tracked", ""))
	if tracked != &"" and not is_active(tracked):
		tracked = _next_tracked()
	changed.emit()

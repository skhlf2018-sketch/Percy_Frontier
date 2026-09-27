class_name AmmoInventory
extends RefCounted
## 총기군별 공용 탄약(기획서 §8.2, §11.4). 종류 수를 늘리지 않고 무기군끼리 공유한다.

signal changed

## 종류별 이름, 최대 보유량, 시작 보유량, 거점 비상 보급 최소량
const TYPES := {
	&"pistol": {"name": "권총탄", "max": 180, "start": 96, "emergency": 36},
	&"rifle": {"name": "소총탄", "max": 300, "start": 180, "emergency": 60},
	&"shell": {"name": "산탄", "max": 48, "start": 24, "emergency": 12},
	&"sniper": {"name": "저격탄", "max": 40, "start": 20, "emergency": 10},
}

var counts: Dictionary = {}


func _init() -> void:
	reset_to_start()


static func type_name(type: StringName) -> String:
	if TYPES.has(type):
		return TYPES[type].name
	return ""


func get_count(type: StringName) -> int:
	return counts.get(type, 0)


func get_max(type: StringName) -> int:
	if TYPES.has(type):
		return TYPES[type].max
	return 0


## 탄약을 더한다. 실제로 더해진 양을 돌려준다.
func add(type: StringName, amount: int) -> int:
	if not TYPES.has(type) or amount <= 0:
		return 0
	var before := get_count(type)
	counts[type] = mini(get_max(type), before + amount)
	var added: int = counts[type] - before
	if added > 0:
		changed.emit()
	return added


## 탄약을 꺼낸다. 실제로 꺼낸 양을 돌려준다.
func take(type: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var have := get_count(type)
	var taken := mini(have, amount)
	if taken > 0:
		counts[type] = have - taken
		changed.emit()
	return taken


## 비상 탄약: 최소량보다 적으면 최소량까지 채운다(기획서 §11.4, §19.1).
func ensure_emergency(multiplier: float = 1.0) -> void:
	var dirty := false
	for type in TYPES:
		var minimum := int(ceil(TYPES[type].emergency * multiplier))
		if get_count(type) < minimum:
			counts[type] = minimum
			dirty = true
	if dirty:
		changed.emit()


## 시작 보유량까지 채운다(시험장 보급).
func refill_to_start(multiplier: float = 1.0) -> void:
	var dirty := false
	for type in TYPES:
		var target := mini(get_max(type), int(ceil(TYPES[type].start * multiplier)))
		if get_count(type) < target:
			counts[type] = target
			dirty = true
	if dirty:
		changed.emit()


func reset_to_start() -> void:
	for type in TYPES:
		counts[type] = TYPES[type].start
	changed.emit()

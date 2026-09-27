class_name StatusEffects
extends RefCounted
## 상태이상 축적·발동·지속 관리(기획서 §8.6).
## 공격이 축적치를 쌓고, 100에 도달하면 효과가 발동한다. 소유자가 매 물리 프레임 tick()을 호출한다.
##
## - 화상: 지속 피해, 회복 효율 감소
## - 냉각·빙결: 축적 50 이상이면 둔화, 100이면 빙결(행동 정지). 보스 규칙이면 빙결 대신 강한 둔화
## - 감전: 발동 순간 추가 피해와 짧은 행동 중단, 지속 중 장갑 피해 증가, 주변 전이는 소유자가 처리
## - 출혈: 이동하거나 공격할 때 추가 피해

enum Type { BURN, CHILL, SHOCK, BLEED }

signal triggered(type: int)
signal ended(type: int)

const NAMES := {
	Type.BURN: "화상",
	Type.CHILL: "빙결",
	Type.SHOCK: "감전",
	Type.BLEED: "출혈",
}
const THRESHOLD := 100.0
## 이 축적치 이상이면 냉각(둔화) 상태
const CHILL_SLOW_THRESHOLD := 50.0

const BURN_DURATION := 5.0
const BURN_DPS := 6.0
## 화상 중 회복 효율
const BURN_HEAL_MULT := 0.5
const FREEZE_DURATION := 2.5
const CHILL_SLOW := 0.4
## 보스 규칙: 빙결 대신 적용되는 이동 감소율
const BOSS_FREEZE_SLOW := 0.65
## 빙결 대상이 근접·강공격에 받는 추가 피해
const FROZEN_SHATTER_MULT := 1.3
const SHOCK_DURATION := 3.0
const SHOCK_BURST := 14.0
const SHOCK_ARMOR_MULT := 1.5
const BLEED_DURATION := 6.0
const BLEED_MOVE_DPS := 7.0
const BLEED_ACTION_DAMAGE := 5.0
## 효과가 끝난 뒤 같은 상태 축적이 절반만 쌓이는 시간(반복 행동 불능 방지)
const TOLERANCE_TIME := 6.0
const TOLERANCE_MULT := 0.5
const DECAY_DELAY := 1.5
const DECAY_PER_SEC := 14.0

## 상태별 발동 지속 시간(보스 규칙에서는 빙결 지속이 절반)
const DURATIONS := {
	Type.BURN: BURN_DURATION,
	Type.CHILL: FREEZE_DURATION,
	Type.SHOCK: SHOCK_DURATION,
	Type.BLEED: BLEED_DURATION,
}

var buildup: Dictionary = {}
var remaining: Dictionary = {}
## 상태별 축적 배율(1.0 = 보통, 0.5 = 저항)
var resistance: Dictionary = {}
## 보스 규칙: 면역 대신 효과 감소(기획서 §8.6)
var boss_rules: bool = false
## 정화 등으로 모든 축적을 막는 남은 시간
var immunity_time: float = 0.0

var _since_buildup: Dictionary = {}
var _tolerance: Dictionary = {}


func _init() -> void:
	for t in Type.values():
		buildup[t] = 0.0
		remaining[t] = 0.0
		resistance[t] = 1.0
		_since_buildup[t] = 999.0
		_tolerance[t] = 0.0


## 네 가지 축적치를 사전 형태로 묶는다(데이터 리소스에서 사용).
static func buildup_from(burn: float, chill: float, shock: float, bleed: float) -> Dictionary:
	var d := {}
	if burn > 0.0:
		d[Type.BURN] = burn
	if chill > 0.0:
		d[Type.CHILL] = chill
	if shock > 0.0:
		d[Type.SHOCK] = shock
	if bleed > 0.0:
		d[Type.BLEED] = bleed
	return d


static func type_name(type: int) -> String:
	return NAMES.get(type, "?")


## 축적치를 더한다. 이번에 효과가 발동했으면 true.
func add_buildup(type: int, amount: float) -> bool:
	if amount <= 0.0 or immunity_time > 0.0:
		return false
	if is_active(type):
		return false
	var mult: float = resistance.get(type, 1.0)
	if _tolerance[type] > 0.0:
		mult *= TOLERANCE_MULT
	buildup[type] = minf(THRESHOLD, buildup[type] + amount * mult)
	_since_buildup[type] = 0.0
	if buildup[type] >= THRESHOLD:
		_trigger(type)
		return true
	return false


## 사전 형태의 축적치를 한꺼번에 적용하고 발동한 상태 목록을 돌려준다.
func apply_buildup(amounts: Dictionary) -> Array[int]:
	var fired: Array[int] = []
	for type in amounts:
		if add_buildup(type, amounts[type]):
			fired.append(type)
	return fired


func _trigger(type: int) -> void:
	buildup[type] = 0.0
	var duration: float = DURATIONS[type]
	if boss_rules and type == Type.CHILL:
		duration *= 0.5
	remaining[type] = duration
	triggered.emit(type)


## 매 프레임 호출. 이번 프레임에 받아야 할 지속 피해를 돌려준다.
func tick(delta: float, moving: bool) -> float:
	var damage := 0.0
	immunity_time = maxf(0.0, immunity_time - delta)
	for type in Type.values():
		_tolerance[type] = maxf(0.0, _tolerance[type] - delta)
		if remaining[type] > 0.0:
			match type:
				Type.BURN:
					damage += BURN_DPS * delta
				Type.BLEED:
					if moving:
						damage += BLEED_MOVE_DPS * delta
			remaining[type] -= delta
			if remaining[type] <= 0.0:
				remaining[type] = 0.0
				_tolerance[type] = TOLERANCE_TIME
				ended.emit(type)
		else:
			_since_buildup[type] += delta
			if _since_buildup[type] > DECAY_DELAY and buildup[type] > 0.0:
				buildup[type] = maxf(0.0, buildup[type] - DECAY_PER_SEC * delta)
	return damage


## 공격·회피 같은 행동을 할 때 호출한다. 출혈 중이면 추가 피해를 돌려준다.
func on_action() -> float:
	return BLEED_ACTION_DAMAGE if is_active(Type.BLEED) else 0.0


func is_active(type: int) -> bool:
	return remaining.get(type, 0.0) > 0.0


func is_frozen() -> bool:
	return is_active(Type.CHILL) and not boss_rules


func is_chilled() -> bool:
	return buildup[Type.CHILL] >= CHILL_SLOW_THRESHOLD or (boss_rules and is_active(Type.CHILL))


## 이동 속도 배율
func move_multiplier() -> float:
	if is_active(Type.CHILL):
		return 0.0 if not boss_rules else 1.0 - BOSS_FREEZE_SLOW
	if buildup[Type.CHILL] >= CHILL_SLOW_THRESHOLD:
		return 1.0 - CHILL_SLOW
	return 1.0


## 받는 피해 배율
func damage_taken_multiplier(info: DamageInfo) -> float:
	if is_frozen() and (info.is_melee() or info.heavy):
		return FROZEN_SHATTER_MULT
	return 1.0


## 장갑 내구 피해 배율(감전 중 증가)
func armor_damage_multiplier() -> float:
	return SHOCK_ARMOR_MULT if is_active(Type.SHOCK) else 1.0


## 회복량 배율(화상 중 감소)
func heal_multiplier() -> float:
	return BURN_HEAL_MULT if is_active(Type.BURN) else 1.0


func get_buildup(type: int) -> float:
	return buildup.get(type, 0.0)


func get_remaining(type: int) -> float:
	return remaining.get(type, 0.0)


## HUD 표시용: 발동 중이거나 축적 중인 상태 목록
## 항목: { "type", "active", "remaining", "buildup" }
func describe() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for type in Type.values():
		var active: bool = remaining[type] > 0.0
		if active or buildup[type] > 0.0:
			list.append({
				"type": type,
				"active": active,
				"remaining": remaining[type],
				"buildup": buildup[type],
			})
	return list


func has_any() -> bool:
	for type in Type.values():
		if remaining[type] > 0.0 or buildup[type] > 0.0:
			return true
	return false


## 모든 상태를 해제한다. 끝나는 효과마다 ended 신호를 보낸다.
func clear_all() -> void:
	for type in Type.values():
		var was_active: bool = remaining[type] > 0.0
		buildup[type] = 0.0
		remaining[type] = 0.0
		_tolerance[type] = 0.0
		if was_active:
			ended.emit(type)

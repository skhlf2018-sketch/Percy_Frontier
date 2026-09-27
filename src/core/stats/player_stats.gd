class_name PlayerStats
extends RefCounted
## 플레이어 자원(기획서 §8.2): HP, 스태미나, 공명, 보호막.
## HP는 전투 밖에서도 자동으로 완전히 회복되지 않는다.

signal changed
signal died

var max_hp: float = 100.0
var hp: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var max_resonance: float = 100.0
var resonance: float = 0.0
## 보호막(스킬 등). HP보다 먼저 피해를 흡수한다.
var shield: float = 0.0
var shield_time: float = 0.0

const BASE_STAMINA_REGEN := 32.0

var stamina_regen_rate: float = BASE_STAMINA_REGEN
var stamina_regen_delay: float = 0.9
## 스태미나를 모두 쓰면 일정 비율까지 회복하기 전에는 달리기·회피를 쓸 수 없다.
var exhausted: bool = false
const EXHAUST_RECOVER_RATIO := 0.3

var _regen_delay_left: float = 0.0


func is_dead() -> bool:
	return hp <= 0.0


## 피해를 받는다. 보호막이 먼저 흡수하고 실제로 줄어든 HP를 돌려준다.
func take_damage(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return 0.0
	var left := amount
	if shield > 0.0:
		var absorbed := minf(shield, left)
		shield -= absorbed
		left -= absorbed
	var before := hp
	hp = maxf(0.0, hp - left)
	changed.emit()
	if hp <= 0.0 and before > 0.0:
		died.emit()
	return before - hp


## 회복한다. 실제 회복량을 돌려준다.
func heal(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	changed.emit()
	return hp - before


## 스태미나를 한 번에 소모한다(회피, 강공격). 부족하면 false.
func use_stamina(amount: float) -> bool:
	if exhausted or stamina < amount:
		return false
	stamina -= amount
	_regen_delay_left = stamina_regen_delay
	changed.emit()
	return true


## 스태미나를 지속 소모한다(달리기, 방어). 0이 되면 탈진한다.
func drain_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = maxf(0.0, stamina - amount)
	_regen_delay_left = stamina_regen_delay
	if stamina <= 0.0:
		exhausted = true
	changed.emit()


func add_resonance(amount: float) -> void:
	if amount <= 0.0:
		return
	resonance = minf(max_resonance, resonance + amount)
	changed.emit()


func spend_resonance(amount: float) -> bool:
	if resonance < amount:
		return false
	resonance -= amount
	changed.emit()
	return true


func add_shield(amount: float, duration: float) -> void:
	shield = maxf(shield, amount)
	shield_time = maxf(shield_time, duration)
	changed.emit()


func has_shield() -> bool:
	return shield > 0.0 and shield_time > 0.0


func tick(delta: float) -> void:
	var dirty := false
	if shield_time > 0.0:
		shield_time -= delta
		if shield_time <= 0.0:
			shield_time = 0.0
			shield = 0.0
			dirty = true
	# 회복 지연이 이번 프레임 중간에 끝나면 남은 시간만큼은 회복한다.
	var regen_time := delta
	if _regen_delay_left > 0.0:
		_regen_delay_left -= delta
		if _regen_delay_left > 0.0:
			regen_time = 0.0
		else:
			regen_time = -_regen_delay_left
			_regen_delay_left = 0.0
	if regen_time > 0.0 and stamina < max_stamina:
		stamina = minf(max_stamina, stamina + stamina_regen_rate * regen_time)
		if exhausted and stamina >= max_stamina * EXHAUST_RECOVER_RATIO:
			exhausted = false
		dirty = true
	if dirty:
		changed.emit()


## 거점 휴식·부활 시 호출. 공명은 전투 자원이므로 비운다.
func restore_full() -> void:
	hp = max_hp
	stamina = max_stamina
	exhausted = false
	resonance = 0.0
	shield = 0.0
	shield_time = 0.0
	_regen_delay_left = 0.0
	changed.emit()

class_name GunState
extends RefCounted
## 총기 한 자루의 런타임 상태: 탄창, 과열, 발사 간격, 탄퍼짐, 재장전.
## 장면(노드)과 분리된 순수 로직이라 테스트로 검증한다.

var data: WeaponData
var mag: int = 0
## 탄창 크기(무기 특성 「확장 탄창」으로 늘어날 수 있다)
var capacity: int = 0
## 0..1
var heat: float = 0.0
var overheated: bool = false
var cooldown: float = 0.0
## 연사로 누적되는 추가 탄퍼짐(도)
var bloom: float = 0.0
var reloading: bool = false
var reload_left: float = 0.0
var reload_total: float = 0.0
## 재장전 속도 배율(기교 능력치). 재장전을 시작할 때 적용한다.
var reload_speed: float = 1.0

var _overheat_left: float = 0.0
var _heat_delay_left: float = 0.0


func _init(p_data: WeaponData) -> void:
	data = p_data
	capacity = data.magazine_size
	mag = capacity


func can_fire() -> bool:
	if cooldown > 0.0 or reloading:
		return false
	if data.uses_heat:
		return not overheated
	return mag > 0


func is_empty() -> bool:
	return not data.uses_heat and mag <= 0


## 발사한다. 발사했으면 true.
func fire() -> bool:
	if not can_fire():
		return false
	cooldown = data.seconds_per_shot()
	bloom = minf(data.max_bloom_deg, bloom + data.bloom_per_shot_deg)
	if data.uses_heat:
		heat = minf(1.0, heat + data.heat_per_shot)
		_heat_delay_left = data.heat_cool_delay
		if heat >= 1.0:
			overheated = true
			_overheat_left = data.overheat_lockout
	else:
		mag -= 1
	return true


func can_reload(inv: AmmoInventory) -> bool:
	if data.uses_heat or reloading or mag >= capacity:
		return false
	return inv.get_count(data.ammo_type) > 0


func start_reload(inv: AmmoInventory) -> bool:
	if not can_reload(inv):
		return false
	reloading = true
	reload_total = (data.empty_reload_time if mag <= 0 else data.reload_time) / maxf(reload_speed, 0.1)
	reload_left = reload_total
	return true


func cancel_reload() -> void:
	reloading = false
	reload_left = 0.0


func reload_progress() -> float:
	if not reloading or reload_total <= 0.0:
		return 0.0
	return 1.0 - reload_left / reload_total


## 매 프레임 호출. 이번 프레임에 재장전이 끝났으면 true.
func tick(delta: float, inv: AmmoInventory) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	bloom = maxf(0.0, bloom - data.bloom_recovery_deg * delta)
	if data.uses_heat:
		_tick_heat(delta)
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			reloading = false
			reload_left = 0.0
			var need := capacity - mag
			mag += inv.take(data.ammo_type, need)
			return true
	return false


func _tick_heat(delta: float) -> void:
	if overheated:
		_overheat_left -= delta
		heat = maxf(0.0, heat - data.heat_cool_rate * delta)
		if _overheat_left <= 0.0:
			overheated = false
		return
	if _heat_delay_left > 0.0:
		_heat_delay_left -= delta
		return
	heat = maxf(0.0, heat - data.heat_cool_rate * delta)


## 현재 탄퍼짐(도). ads_blend: 0 지향 사격 ~ 1 정조준, move_ratio: 0 정지 ~ 1 최고 속도.
func spread_deg(ads_blend: float, move_ratio: float, airborne: bool) -> float:
	var s := lerpf(data.hip_spread_deg, data.ads_spread_deg, ads_blend)
	s += bloom * lerpf(1.0, 0.5, ads_blend)
	s += data.move_spread_deg * clampf(move_ratio, 0.0, 1.0) * lerpf(1.0, 0.4, ads_blend)
	if airborne:
		s += data.air_spread_deg
	return s

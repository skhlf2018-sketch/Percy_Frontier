class_name WeaponManager
extends Node3D
## 무기 3슬롯(주무기·보조 총기·근접) 관리(기획서 §7, §8.3, §8.4, §9.1).
## 사격(히트스캔·투사체·관통·산탄), 정조준, 반동, 재장전, 교체,
## 근접 약·강공격과 연속 공격, 방어·패링, 빠른 근접 공격을 처리한다.

signal weapon_changed(slot: int)
signal ammo_changed
signal fired(data: WeaponData)
signal reload_started(duration: float)
signal reload_finished
signal overheated
signal guard_broken
## 상황에 따라 나가는 근접 기술(돌진 베기·낙하 베기·질주 찌르기)과 반격
signal technique_used(technique_name: String)

enum Slot { PRIMARY, SECONDARY, MELEE }
enum MeleePhase { NONE, CHARGING, WINDUP, RECOVERY }
## 근접 무기를 든 채 상황에 맞춰 공격하면 나가는 기술
enum Technique { NONE, DASH, PLUNGE, THRUST }

const TECHNIQUE_NAMES := {
	Technique.DASH: "돌진 베기",
	Technique.PLUNGE: "낙하 베기",
	Technique.THRUST: "질주 찌르기",
}
const TECHNIQUE_COSTS := {Technique.DASH: 12.0, Technique.PLUNGE: 15.0, Technique.THRUST: 10.0}
## 회피가 끝난 뒤에도 돌진 베기로 이어 줄 수 있는 시간
const DASH_INPUT_GRACE := 0.3
const PLUNGE_MIN_HEIGHT := 1.6
const PLUNGE_RADIUS := 3.3
const COUNTER_DAMAGE_MULT := 1.5
## 쌍검: 두 손의 기본 자세
const TWIN_POSITION := Vector3(0.0, -0.3, -0.48)

const HIP_POSITION := Vector3(0.23, -0.25, -0.55)
const MELEE_POSITION := Vector3(0.3, -0.36, -0.52)
const MELEE_EQUIP_TIME := 0.35
const QUICK_MELEE_HIT_TIME := 0.13
const COMBO_RESET := 0.8
const GUARD_BREAK_TIME := 1.0
## 총기 사격이 출혈 행동 피해를 일으키는 최소 간격(연사로 과도하게 누적되지 않게 한다)
const BLEED_SHOT_INTERVAL := 0.5
const FLASH_TIME := 0.05

var player: Player
var primary: WeaponData
var secondary: WeaponData
var melee: MeleeData
## 든 무기 한 자루씩(희귀도·특성·강화 단계를 가진다)
var primary_item: WeaponItem
var secondary_item: WeaponItem
var melee_item: WeaponItem
var current_slot: int = Slot.PRIMARY
var ads_blend: float = 0.0

var _states: Dictionary = {}
var _views: Dictionary = {}
## 1인칭 모델을 만들 때의 희귀도(희귀도가 바뀌면 다시 만든다)
var _view_rarity: Dictionary = {}
## 「연쇄 약점」: 이어서 약점을 맞힌 횟수
var _weak_chain: int = 0
var _equip_left: float = 0.0
var _lowered_left: float = 0.0
var _guard_broken_left: float = 0.0
var _trigger_held: bool = false
var _trigger_fresh: bool = false
var _aim_held: bool = false
var _aim_toggled: bool = false
var _clock: float = 0.0
var _last_bleed_shot: float = -10.0
## 자동화 입력(테스트·스크린샷)에서는 실제 버튼이 눌려 있지 않으므로 유지 상태를 따로 둔다.
var _simulated_hold: bool = false
var _simulated_aim: bool = false

var _melee_phase: int = MeleePhase.NONE
var _melee_timer: float = 0.0
var _melee_hold: float = 0.0
var _melee_heavy: bool = false
var _combo: int = 0
var _combo_timer: float = 0.0
var _block_started: float = -1.0
var _quick_left: float = 0.0
var _quick_hit_done: bool = true
var _technique: int = Technique.NONE
var _tech_elapsed: float = 0.0
var _tech_left: float = 0.0
var _tech_hit_done: bool = true

var _vm_root: Node3D
var _flash: Node3D
var _flash_light: OmniLight3D
var _flash_left: float = 0.0
var _kick: float = 0.0
var _sway := Vector2.ZERO
var _anim_time: float = 0.0


func setup(p: Player) -> void:
	player = p
	p.landed.connect(_on_player_landed)
	_vm_root = Node3D.new()
	_vm_root.name = "ViewmodelRoot"
	add_child(_vm_root)
	_flash = ViewmodelFactory.build_muzzle_flash(Color(1.0, 0.8, 0.45))
	_flash_light = OmniLight3D.new()
	_flash_light.name = "MuzzleLight"
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 6.0
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	GameState.loadout_changed.connect(load_loadout)
	player.ammo.changed.connect(func() -> void: ammo_changed.emit())
	load_loadout()


## GameState의 든 무기를 반영한다. 총기별 탄창 상태는 교체해도 유지된다.
func load_loadout() -> void:
	primary_item = GameState.equipped_item(WeaponItem.Slot.PRIMARY)
	secondary_item = GameState.equipped_item(WeaponItem.Slot.SECONDARY)
	melee_item = GameState.equipped_item(WeaponItem.Slot.MELEE)
	primary = primary_item.gun_data()
	secondary = secondary_item.gun_data()
	melee = melee_item.melee_data()
	for it: WeaponItem in [primary_item, secondary_item]:
		var w := it.gun_data()
		if not _states.has(w.id):
			_states[w.id] = GunState.new(w)
		var st: GunState = _states[w.id]
		st.capacity = it.mag_capacity()
		st.mag = mini(st.mag, st.capacity)
	var keep := {primary.id: primary_item.rarity, secondary.id: secondary_item.rarity, melee.id: melee_item.rarity}
	for key in _views.keys():
		if not keep.has(key) or int(_view_rarity.get(key, -1)) != int(keep[key]):
			_views[key].root.queue_free()
			_views.erase(key)
	for it: WeaponItem in [primary_item, secondary_item]:
		var w := it.gun_data()
		if not _views.has(w.id):
			var v := ViewmodelFactory.build_gun(w, it.rarity)
			_vm_root.add_child(v.root)
			_views[w.id] = v
			_view_rarity[w.id] = it.rarity
	if not _views.has(melee.id):
		var mv := ViewmodelFactory.build_melee(melee, melee_item.rarity)
		_vm_root.add_child(mv.root)
		_views[melee.id] = mv
		_view_rarity[melee.id] = melee_item.rarity
	_cancel_actions()
	_equip_left = _equip_time_for(current_slot)
	_refresh_views()
	weapon_changed.emit(current_slot)
	ammo_changed.emit()


# --- 조회 ---

## 지금 든 칸의 무기 한 자루
func current_item() -> WeaponItem:
	match current_slot:
		Slot.PRIMARY:
			return primary_item
		Slot.SECONDARY:
			return secondary_item
	return melee_item


## 총기 데이터에 해당하는 든 무기
func item_for_gun(data: WeaponData) -> WeaponItem:
	if primary_item and primary_item.base_id == data.id:
		return primary_item
	if secondary_item and secondary_item.base_id == data.id:
		return secondary_item
	return null


func current_gun() -> GunState:
	match current_slot:
		Slot.PRIMARY:
			return _states.get(primary.id)
		Slot.SECONDARY:
			return _states.get(secondary.id)
	return null


func gun_state_for(id: StringName) -> GunState:
	return _states.get(id)


func is_melee_equipped() -> bool:
	return current_slot == Slot.MELEE


func is_aiming() -> bool:
	return current_slot != Slot.MELEE and ads_blend > 0.5


func is_blocking() -> bool:
	return _block_started >= 0.0


func is_scoped() -> bool:
	var gun := current_gun()
	return gun != null and gun.data.scope and ads_blend > 0.9


func is_quick_meleeing() -> bool:
	return _quick_left > 0.0


func is_ready() -> bool:
	return _equip_left <= 0.0 and _lowered_left <= 0.0 and _quick_left <= 0.0


func blocks_sprint() -> bool:
	return ads_blend > 0.15 or is_blocking() or _melee_phase != MeleePhase.NONE or _quick_left > 0.0


func move_speed_multiplier() -> float:
	if current_slot == Slot.MELEE:
		if is_blocking():
			return melee.block_move_mult
		if _melee_phase == MeleePhase.WINDUP or _melee_phase == MeleePhase.RECOVERY:
			return 0.75
		return 1.0
	var gun := current_gun()
	return lerpf(1.0, gun.data.ads_move_mult, ads_blend)


func fov_multiplier() -> float:
	var gun := current_gun()
	if gun == null:
		return 1.0
	return lerpf(1.0, gun.data.ads_fov_mult, ads_blend)


## 현재 탄퍼짐(도). HUD 조준선이 쓴다.
func current_spread_deg() -> float:
	var gun := current_gun()
	if gun == null:
		return 0.0
	return gun.spread_deg(ads_blend, player.move_ratio(), not player.is_on_floor())


# --- 입력 ---

func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.can_act():
		return
	if event.is_action_pressed(&"fire"):
		_trigger_held = true
		_trigger_fresh = true
	elif event.is_action_pressed(&"aim"):
		_aim_held = true
		if Settings.get_value(&"aim_toggle"):
			_aim_toggled = not _aim_toggled
	elif event.is_action_pressed(&"reload"):
		try_reload()
	elif event.is_action_pressed(&"weapon_1"):
		select_slot(Slot.PRIMARY)
	elif event.is_action_pressed(&"weapon_2"):
		select_slot(Slot.SECONDARY)
	elif event.is_action_pressed(&"weapon_3"):
		select_slot(Slot.MELEE)
	elif event.is_action_pressed(&"weapon_next"):
		cycle(1)
	elif event.is_action_pressed(&"weapon_prev"):
		cycle(-1)
	elif event.is_action_pressed(&"melee_quick"):
		try_quick_melee()


## 테스트·자동화용: 방아쇠를 당긴 것처럼 처리한다.
func press_trigger() -> void:
	_trigger_held = true
	_trigger_fresh = true


func release_trigger() -> void:
	_trigger_held = false


func set_aim_held(value: bool) -> void:
	_aim_held = value


func add_sway(relative: Vector2) -> void:
	_sway += relative


# --- 물리 프레임 ---

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_clock += delta
	for state: GunState in _states.values():
		if state.tick(delta, player.ammo):
			_on_reload_done(state)
	_equip_left = maxf(0.0, _equip_left - delta)
	_lowered_left = maxf(0.0, _lowered_left - delta)
	_guard_broken_left = maxf(0.0, _guard_broken_left - delta)
	_update_aim(delta)
	if current_slot == Slot.MELEE:
		_update_melee(delta)
	else:
		_update_gun()
	_update_quick_melee(delta)
	_trigger_fresh = false
	# 버튼 해제는 처리 뒤에 확인한다. 한 프레임 안에 누르고 뗀 짧은 클릭도 한 번은 쏘게 된다.
	if _trigger_held and not Input.is_action_pressed(&"fire") and not _simulated_hold:
		_trigger_held = false
	if _aim_held and not Input.is_action_pressed(&"aim") and not _simulated_aim:
		_aim_held = false


## 자동화(테스트·스크린샷)용: 실제 버튼 없이 방아쇠를 누르고 있는 상태를 만든다.
func simulate_hold(value: bool) -> void:
	_simulated_hold = value
	if value:
		press_trigger()
	else:
		release_trigger()


func simulate_aim(value: bool) -> void:
	_simulated_aim = value
	_aim_held = value


func _update_aim(delta: float) -> void:
	var want := _aim_toggled if Settings.get_value(&"aim_toggle") else _aim_held
	# 조준·방어 입력은 달리기를 끊는다(서로 막아 둘 다 안 되는 상황 방지).
	if want and player.sprinting:
		player.cancel_sprint()
	var can := player.can_act() and is_ready() and not player.sprinting and _guard_broken_left <= 0.0
	if current_slot == Slot.MELEE:
		var block := want and can and melee.can_block and _melee_phase == MeleePhase.NONE
		if block and _block_started < 0.0:
			_block_started = _clock
		elif not block:
			_block_started = -1.0
		ads_blend = 0.0
		return
	var gun := current_gun()
	var aiming := want and can
	ads_blend = move_toward(ads_blend, 1.0 if aiming else 0.0, delta / maxf(gun.data.ads_time, 0.01))


# --- 총기 ---

func _update_gun() -> void:
	var gun := current_gun()
	if gun == null or not player.can_act() or not is_ready() or player.is_busy_with_consumable():
		return
	var data := gun.data
	var wants := _trigger_held and (data.fire_mode == WeaponData.FireMode.AUTO or _trigger_fresh)
	if not wants:
		return
	if gun.reloading:
		if gun.mag > 0 and _trigger_fresh:
			gun.cancel_reload()
		else:
			return
	if gun.can_fire():
		_fire(gun)
	elif _trigger_fresh:
		if gun.is_empty():
			Sfx.play(&"dry_fire")
			try_reload()
		elif gun.overheated:
			Sfx.play(&"dry_fire", -6.0)


func _fire(gun: GunState) -> void:
	var data := gun.data
	var spread := gun.spread_deg(ads_blend, player.move_ratio(), not player.is_on_floor())
	if not gun.fire():
		return
	player.cancel_sprint()
	var aim := player.get_aim_transform()
	var forward := -aim.basis.z
	var muzzle_pos := _muzzle_position(aim)
	for i in data.pellets:
		var dir := CombatQuery.spread_direction(forward, aim.basis, spread)
		if data.projectile:
			_fire_projectile(data, aim.origin, dir)
		else:
			_hitscan(data, aim.origin, dir, muzzle_pos)
	var item := item_for_gun(data)
	var recoil_mult := lerpf(1.0, 0.75, ads_blend) * GameState.progress.recoil_mult() * (item.recoil_mult() if item else 1.0)
	player.add_recoil(data.recoil_pitch_deg * recoil_mult,
		randf_range(-1.0, 1.0) * data.recoil_yaw_deg * recoil_mult,
		data.recoil_return_ratio, data.recoil_recovery)
	_kick = minf(_kick + 1.0, 1.6)
	_show_flash(data)
	Sfx.play(data.sound, -2.0)
	player.camera_rig.add_trauma(data.shake)
	Hearing.emit(get_tree(), aim.origin, data.noise_radius, player, Hearing.Kind.GUNSHOT)
	if _clock - _last_bleed_shot >= BLEED_SHOT_INTERVAL:
		_last_bleed_shot = _clock
		player.apply_action_bleed()
	if gun.overheated:
		Sfx.play(&"overheat", -4.0)
		overheated.emit()
	ammo_changed.emit()
	fired.emit(data)
	if gun.is_empty():
		try_reload()


func _muzzle_position(aim: Transform3D) -> Vector3:
	var gun := current_gun()
	if gun and _views.has(gun.data.id):
		var m: Marker3D = _views[gun.data.id].muzzle
		if m.is_inside_tree():
			return m.global_position
	return aim.origin + (-aim.basis.z) * 0.6 + aim.basis.x * 0.15 - aim.basis.y * 0.1


func _gun_damage(data: WeaponData, distance: float, position: Vector3, dir: Vector3) -> DamageInfo:
	var mult := DamageMath.falloff(distance, data.falloff_start, data.falloff_end, data.falloff_min_mult)
	var item := item_for_gun(data)
	if item:
		mult *= item.damage_mult()
		var st: GunState = _states.get(data.id)
		# 「마지막 탄」: 탄창의 마지막 30%(방금 쏜 탄 포함)
		if item.has_perk(&"last_rounds") and st and not data.uses_heat and st.mag < int(ceil(st.capacity * 0.3)):
			mult *= 1.4
		if item.has_perk(&"one_eye") and ads_blend > 0.9:
			mult *= 1.3
	var info := DamageInfo.create(data.damage * mult, DamageInfo.Kind.GUN, player)
	info.stagger = data.stagger * (item.stagger_mult() if item else 1.0)
	info.armor_damage_mult = data.armor_damage_mult
	info.status_buildup = data.status_buildup()
	if item:
		_add_buildup(info, item.extra_buildup(), 1.0 / float(maxi(data.pellets, 1)))
		if item.has_perk(&"pack_breaker"):
			info.bonus_vs_staggered = 0.35
	info.hit_position = position
	info.direction = dir
	info.resonance_mult = 1.0 / float(maxi(data.pellets, 1))
	info.knockback = 0.0
	return info


func _hitscan(data: WeaponData, origin: Vector3, dir: Vector3, muzzle_pos: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var to := origin + dir * data.max_range
	var exclude: Array[RID] = [player.get_rid()]
	var seen := {}
	var pierce_left := data.pierce
	var end_point := to
	for i in 8:
		var q := PhysicsRayQueryParameters3D.create(origin, to, CombatLayers.PLAYER_ATTACK_MASK, exclude)
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var hb := hit.collider as Hurtbox
		if hb == null:
			end_point = hit.position
			CombatFx.impact(self, hit.position, Color(0.85, 0.8, 0.7), 0.045, 0.12)
			break
		exclude.append(hit.rid)
		if seen.has(hb.entity):
			continue
		seen[hb.entity] = true
		var result := hb.hit(_gun_damage(data, origin.distance_to(hit.position), hit.position, dir))
		handle_hit_result(result, item_for_gun(data))
		if pierce_left <= 0:
			end_point = hit.position
			break
		pierce_left -= 1
	CombatFx.tracer(self, muzzle_pos, end_point, data.tracer_color)


func _fire_projectile(data: WeaponData, origin: Vector3, dir: Vector3) -> void:
	var p := Projectile.create(data.tracer_color, 0.055, 4.0)
	p.collision_mask = CombatLayers.PLAYER_ATTACK_MASK
	p.exclude = [player.get_rid()]
	p.gravity = data.projectile_gravity
	p.life = data.max_range / maxf(data.projectile_speed, 1.0)
	p.on_hit = func(hit: Dictionary) -> void: _on_projectile_hit(data, origin, dir, hit)
	p.launch(_world_root(), origin + dir * 0.5, dir * data.projectile_speed)


func _on_projectile_hit(data: WeaponData, origin: Vector3, dir: Vector3, hit: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var hb := hit.collider as Hurtbox
	if hb:
		handle_hit_result(hb.hit(_gun_damage(data, origin.distance_to(hit.position), hit.position, dir)), item_for_gun(data))
		CombatFx.impact(self, hit.position, data.tracer_color, 0.1, 0.15)
	else:
		CombatFx.impact(self, hit.position, data.tracer_color, 0.07, 0.15)


## 명중 결과를 공명·교전 상태·HUD 피드백에 반영한다. 스킬과 투사체도 이 함수를 쓴다.
## source는 맞힌 무기(스킬이면 null). 무기 특성(공명 각인·연쇄 약점·알뜰한 사냥꾼·도살자)을 여기서 적용한다.
func handle_hit_result(result: HitResult, source: WeaponItem = null) -> void:
	if result == null:
		return
	player.stats.add_resonance(DamageMath.resonance_for_hit(result) * GameState.progress.resonance_gain_mult())
	player.mark_combat()
	GameEvents.hit_confirmed.emit(result)
	if source:
		_apply_perks(result, source)


func _apply_perks(result: HitResult, item: WeaponItem) -> void:
	var weak := result.zone == Hurtbox.Zone.WEAK_POINT
	if weak and item.has_perk(&"resonant"):
		player.stats.add_resonance(3.0)
	if item.has_perk(&"chain_weak"):
		_weak_chain = _weak_chain + 1 if weak else 0
		if _weak_chain >= 3:
			_weak_chain = 0
			_resonance_burst(result.position, item)
	if result.killed:
		if item.has_perk(&"scavenger") and item.is_gun():
			var g := item.gun_data()
			player.ammo.add(g.ammo_type, maxi(1, int(ceil(item.mag_capacity() * 0.15))))
		if item.has_perk(&"butcher"):
			player.stats.heal(8.0)


## 「연쇄 약점」 공명 폭발: 맞힌 자리 둘레 3m
func _resonance_burst(center: Vector3, item: WeaponItem) -> void:
	CombatFx.impact(self, center, Color(0.45, 0.9, 1.0), 0.8, 0.35)
	Sfx.play_at(&"shock", center, 2.0)
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 3.0
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = shape
	sq.transform = Transform3D(Basis(), center)
	sq.collision_mask = CombatLayers.HURTBOX
	sq.collide_with_areas = true
	sq.collide_with_bodies = false
	var seen := {}
	for r in space.intersect_shape(sq, 32):
		var hb := r.collider as Hurtbox
		if hb == null or hb.entity == null or seen.has(hb.entity):
			continue
		seen[hb.entity] = true
		var info := DamageInfo.create(30.0 * item.damage_mult(), DamageInfo.Kind.EXPLOSION, player)
		info.ignore_zones = true
		info.stagger = 20.0
		info.hit_position = hb.global_position
		info.direction = (hb.global_position - center).normalized()
		handle_hit_result(hb.hit(info))


static func _add_buildup(info: DamageInfo, extra: Dictionary, scale: float) -> void:
	for k in extra:
		if float(extra[k]) > 0.0:
			info.status_buildup[k] = float(info.status_buildup.get(k, 0.0)) + float(extra[k]) * scale


func try_reload() -> bool:
	var gun := current_gun()
	if gun == null or not player.can_act() or not is_ready():
		return false
	var gi := item_for_gun(gun.data)
	gun.reload_speed = GameState.progress.reload_speed_mult() * (gi.reload_mult() if gi else 1.0)
	if not gun.start_reload(player.ammo):
		if not gun.data.uses_heat and gun.mag < gun.capacity \
				and player.ammo.get_count(gun.data.ammo_type) <= 0:
			GameEvents.notify("%s이(가) 없습니다." % AmmoInventory.type_name(gun.data.ammo_type),
				GameEvents.NoticeKind.WARNING)
		return false
	Sfx.play(&"reload_out", -4.0)
	reload_started.emit(gun.reload_total)
	return true


func _on_reload_done(gun: GunState) -> void:
	if gun == current_gun():
		Sfx.play(&"reload_in", -4.0)
	reload_finished.emit()
	ammo_changed.emit()


# --- 교체 ---

func select_slot(slot: int) -> void:
	if slot == current_slot or player == null or not player.can_act():
		return
	if _melee_phase != MeleePhase.NONE or _quick_left > 0.0:
		return
	_switch_to(slot)


func cycle(direction: int) -> void:
	select_slot(posmod(current_slot + direction, 3))


func _switch_to(slot: int) -> void:
	_cancel_actions()
	current_slot = slot
	_equip_left = _equip_time_for(slot)
	_refresh_views()
	Sfx.play(&"reload_out", -10.0)
	weapon_changed.emit(slot)
	ammo_changed.emit()


func _equip_time_for(slot: int) -> float:
	match slot:
		Slot.PRIMARY:
			return primary.equip_time
		Slot.SECONDARY:
			return secondary.equip_time
	return MELEE_EQUIP_TIME


func _cancel_actions() -> void:
	var gun := current_gun()
	if gun and gun.reloading:
		gun.cancel_reload()
	_block_started = -1.0
	_aim_toggled = false
	ads_blend = 0.0
	_melee_phase = MeleePhase.NONE
	_combo = 0
	_quick_left = 0.0
	_quick_hit_done = true
	_technique = Technique.NONE


# --- 근접 ---

func _update_melee(delta: float) -> void:
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _technique != Technique.NONE:
		_update_technique(delta)
		return
	if _combo_timer <= 0.0 and _melee_phase == MeleePhase.NONE:
		_combo = 0
	match _melee_phase:
		MeleePhase.NONE:
			if not player.can_act() or not is_ready() or _guard_broken_left > 0.0 \
					or player.is_busy_with_consumable():
				return
			if _trigger_fresh and not is_blocking():
				if _try_technique():
					return
				_melee_phase = MeleePhase.CHARGING
				_melee_hold = 0.0
		MeleePhase.CHARGING:
			_melee_hold += delta
			if not _trigger_held:
				_start_melee_attack(false)
			elif _melee_hold >= melee.heavy_charge_time:
				_start_melee_attack(true)
		MeleePhase.WINDUP:
			_melee_timer -= delta
			if _melee_timer <= 0.0:
				_perform_melee_hit()
				_melee_phase = MeleePhase.RECOVERY
				_melee_timer = _recovery_time(_melee_heavy)
		MeleePhase.RECOVERY:
			_melee_timer -= delta
			if _melee_timer <= 0.0:
				_melee_phase = MeleePhase.NONE
				_combo_timer = COMBO_RESET


func _start_melee_attack(heavy: bool) -> void:
	if heavy and not player.stats.use_stamina(melee.heavy_stamina):
		heavy = false
	if not heavy:
		player.stats.drain_stamina(melee.light_stamina)
		_combo += 1
	_melee_heavy = heavy
	_melee_phase = MeleePhase.WINDUP
	_melee_timer = _windup_time(heavy)
	_anim_time = 0.0
	player.cancel_sprint()
	player.apply_action_bleed()
	Sfx.play(&"melee_swing", 0.0 if heavy else -3.0, 0.85 if heavy else 1.0)


func _perform_melee_hit() -> void:
	var finisher := not _melee_heavy and _combo >= 3
	var damage := melee.heavy_damage if _melee_heavy else melee.light_damage
	var stagger := melee.heavy_stagger if _melee_heavy else melee.light_stagger
	if finisher:
		damage *= melee.combo_finisher_mult
		stagger *= 1.5
		_combo = 0
	var bleed := melee.heavy_bleed_buildup if _melee_heavy else melee.bleed_buildup
	if _melee_heavy and melee.spin_heavy:
		# 쌍검 강공격: 몸을 돌려 주위를 모두 벤다.
		var center := player.global_position + Vector3.UP * 1.0
		CombatFx.ring(self, player.global_position + Vector3.UP * 0.6, melee.reach + 0.3, Color(0.75, 0.9, 1.0), 0.3)
		Sfx.play(&"spin_slash", -2.0)
		melee_area(center, melee.reach + 0.3, damage, stagger, bleed, true)
		return
	melee_strike(damage, stagger, bleed, _melee_heavy, melee.reach, melee.hit_radius)


## 근접 판정. 조준선이 향한 부위를 우선하고, 전방을 휩쓸어 여러 적을 맞힐 수 있다. 맞힌 수를 돌려준다.
func melee_strike(damage: float, stagger: float, bleed: float, heavy: bool, reach: float, radius: float) -> int:
	var aim := player.get_aim_transform()
	var origin := aim.origin
	var fwd := -aim.basis.z
	var space := get_world_3d().direct_space_state
	var targets := {}
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * reach,
		CombatLayers.PLAYER_ATTACK_MASK, [player.get_rid()])
	q.collide_with_areas = true
	var ray_hit := space.intersect_ray(q)
	if not ray_hit.is_empty() and ray_hit.collider is Hurtbox:
		var hb: Hurtbox = ray_hit.collider
		if hb.entity:
			targets[hb.entity] = hb
	var shape := SphereShape3D.new()
	shape.radius = radius + reach * 0.25
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = shape
	sq.transform = Transform3D(Basis(), origin + fwd * (reach * 0.55))
	sq.collision_mask = CombatLayers.HURTBOX
	sq.collide_with_areas = true
	sq.collide_with_bodies = false
	var candidates := {}
	for r in space.intersect_shape(sq, 32):
		var hb := r.collider as Hurtbox
		if hb == null or hb.entity == null or targets.has(hb.entity):
			continue
		if not CombatQuery.has_line_of_sight(get_world_3d(), origin, hb.global_position):
			continue
		# 휩쓸기로는 약점을 고르지 않는다. 약점은 조준해서 맞혀야 한다.
		var prev: Hurtbox = candidates.get(hb.entity)
		if prev == null or (prev.zone == Hurtbox.Zone.WEAK_POINT and hb.zone != Hurtbox.Zone.WEAK_POINT):
			candidates[hb.entity] = hb
	for e in candidates:
		targets[e] = candidates[e]
	var hits := 0
	var status_buildup := StatusEffects.buildup_from(0.0, 0.0, 0.0, bleed)
	if not targets.is_empty() and player.consume_counter():
		damage *= COUNTER_DAMAGE_MULT * (melee_item.counter_mult() if melee_item else 1.0)
		stagger *= 2.0
		heavy = true
		technique_used.emit("반격")
	for entity in targets:
		var hb: Hurtbox = targets[entity]
		var info := DamageInfo.create(damage * GameState.progress.melee_damage_mult() * _melee_damage_mult(),
			DamageInfo.Kind.MELEE, player)
		info.stagger = stagger * (melee_item.stagger_mult() if melee_item else 1.0)
		info.armor_damage_mult = melee.armor_damage_mult
		info.status_buildup = status_buildup.duplicate()
		if melee_item:
			_add_buildup(info, melee_item.extra_buildup(), 1.0)
		info.heavy = heavy
		info.hit_position = hb.global_position
		info.direction = fwd
		info.knockback = 4.0 if heavy else 1.5
		var result := hb.hit(info)
		if result:
			hits += 1
			handle_hit_result(result, melee_item)
	if hits > 0:
		Sfx.play(&"melee_hit", 0.0 if heavy else -2.0)
		player.camera_rig.add_trauma(0.3 if heavy else 0.12)
		Hearing.emit(get_tree(), origin, 10.0, player, Hearing.Kind.IMPACT)
		if heavy:
			_hitstop(0.06)
	return hits


func _melee_damage_mult() -> float:
	return melee_item.damage_mult() if melee_item else 1.0


func _melee_speed() -> float:
	return melee_item.melee_speed_mult() if melee_item else 1.0


func _windup_time(heavy: bool) -> float:
	return (melee.heavy_windup if heavy else melee.light_windup) / _melee_speed()


func _recovery_time(heavy: bool) -> float:
	return (melee.heavy_recovery if heavy else melee.light_recovery) / _melee_speed()


func _hitstop(duration: float) -> void:
	TimeFx.request(get_tree(), 0.08, duration)


## 한 점을 중심으로 둘레를 모두 치는 근접 판정(회전 베기, 낙하 베기). 맞힌 수를 돌려준다.
func melee_area(center: Vector3, radius: float, damage: float, stagger: float, bleed: float, heavy: bool) -> int:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = shape
	sq.transform = Transform3D(Basis(), center)
	sq.collision_mask = CombatLayers.HURTBOX
	sq.collide_with_areas = true
	sq.collide_with_bodies = false
	var targets := {}
	for r in space.intersect_shape(sq, 48):
		var hb := r.collider as Hurtbox
		if hb == null or hb.entity == null:
			continue
		if not CombatQuery.has_line_of_sight(get_world_3d(), center, hb.global_position):
			continue
		var prev: Hurtbox = targets.get(hb.entity)
		if prev == null or (prev.zone == Hurtbox.Zone.WEAK_POINT and hb.zone != Hurtbox.Zone.WEAK_POINT):
			targets[hb.entity] = hb
	if not targets.is_empty() and player.consume_counter():
		damage *= COUNTER_DAMAGE_MULT * (melee_item.counter_mult() if melee_item else 1.0)
		stagger *= 2.0
		technique_used.emit("반격")
	var hits := 0
	var status_buildup := StatusEffects.buildup_from(0.0, 0.0, 0.0, bleed)
	for entity in targets:
		var hb: Hurtbox = targets[entity]
		var dir := hb.global_position - center
		dir.y = 0.0
		var info := DamageInfo.create(damage * GameState.progress.melee_damage_mult() * _melee_damage_mult(),
			DamageInfo.Kind.MELEE, player)
		info.stagger = stagger * (melee_item.stagger_mult() if melee_item else 1.0)
		info.armor_damage_mult = melee.armor_damage_mult
		info.status_buildup = status_buildup.duplicate()
		if melee_item:
			_add_buildup(info, melee_item.extra_buildup(), 1.0)
		info.heavy = heavy
		info.hit_position = hb.global_position
		info.direction = dir.normalized() if dir.length_squared() > 0.001 else -player.look_basis().z
		info.knockback = 5.0 if heavy else 2.0
		var result := hb.hit(info)
		if result:
			hits += 1
			handle_hit_result(result, melee_item)
	if hits > 0:
		Sfx.play(&"melee_hit", 0.0)
		player.camera_rig.add_trauma(0.3)
		Hearing.emit(get_tree(), center, 12.0, player, Hearing.Kind.IMPACT)
		if heavy:
			_hitstop(0.05)
	return hits


# --- 근접 기술 ---

## 상황에 맞는 기술을 쓴다: 회피 중·직후 → 돌진 베기, 높은 곳에서 떨어지는 중 → 낙하 베기, 달리기·미끄러지기 중 → 질주 찌르기.
func _try_technique() -> bool:
	if current_slot != Slot.MELEE:
		return false
	var p := player
	if p.time_since_dodge() <= Player.DODGE_TIME + DASH_INPUT_GRACE:
		return _start_technique(Technique.DASH)
	if not p.is_on_floor() and p.velocity.y < 2.0 and p.height_above_ground() > PLUNGE_MIN_HEIGHT:
		return _start_technique(Technique.PLUNGE)
	if p.sprinting or p.is_sliding():
		return _start_technique(Technique.THRUST)
	return false


func _start_technique(t: int) -> bool:
	if not player.stats.use_stamina(TECHNIQUE_COSTS[t]):
		return false
	_technique = t
	_tech_elapsed = 0.0
	_tech_hit_done = false
	_anim_time = 0.0
	var fwd := -player.look_basis().z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
	match t:
		Technique.DASH:
			player.start_forced_motion(fwd * 15.0, 0.2, 0.12)
			_tech_left = 0.55
		Technique.PLUNGE:
			player.velocity = Vector3(player.velocity.x * 0.3, -24.0, player.velocity.z * 0.3)
			_tech_left = 3.0
		Technique.THRUST:
			player.start_forced_motion(fwd * 9.5, 0.18, 0.0)
			_tech_left = 0.5
	player.cancel_sprint(0.4)
	player.apply_action_bleed()
	Sfx.play(&"technique", -3.0)
	Sfx.play(&"melee_swing", 0.0, 0.9)
	technique_used.emit(TECHNIQUE_NAMES[t])
	return true


func _update_technique(delta: float) -> void:
	_tech_elapsed += delta
	_tech_left -= delta
	match _technique:
		Technique.DASH:
			if not _tech_hit_done and _tech_elapsed >= 0.12:
				_tech_hit_done = true
				melee_strike(melee.light_damage * 1.8 + melee.heavy_damage * 0.3, melee.heavy_stagger * 0.8,
					melee.bleed_buildup, true, melee.reach + 0.9, melee.hit_radius + 0.35)
		Technique.THRUST:
			if not _tech_hit_done and _tech_elapsed >= 0.08:
				_tech_hit_done = true
				melee_strike(melee.light_damage * 1.5, melee.light_stagger * 2.0, melee.bleed_buildup * 1.5,
					false, melee.reach + 1.4, melee.hit_radius * 0.7)
	if _tech_left <= 0.0:
		_technique = Technique.NONE
		_melee_phase = MeleePhase.NONE
		_combo_timer = COMBO_RESET


func _on_player_landed(fall_speed: float) -> void:
	if _technique != Technique.PLUNGE or _tech_hit_done:
		return
	_tech_hit_done = true
	_tech_left = 0.35
	var center := player.global_position + Vector3.UP * 0.6
	CombatFx.ring(self, player.global_position + Vector3.UP * 0.05, PLUNGE_RADIUS, Color(0.95, 0.85, 0.5), 0.4)
	Sfx.play(&"plunge_impact", 0.0)
	player.camera_rig.add_trauma(0.45)
	melee_area(center, PLUNGE_RADIUS, melee.heavy_damage * 1.1 + fall_speed * 1.5, melee.heavy_stagger * 1.2,
		melee.heavy_bleed_buildup * 0.5, true)


func is_using_technique() -> bool:
	return _technique != Technique.NONE


## 적 공격을 막거나 흘린다. 결과: {} 또는 { parried } 또는 { blocked, reduction, stamina_per_damage }
func try_block(info: DamageInfo, source_position: Vector3) -> Dictionary:
	if current_slot != Slot.MELEE or not is_blocking() or not melee.can_block:
		return {}
	var fwd := -player.look_basis().z
	fwd.y = 0.0
	var to_source := source_position - player.global_position
	to_source.y = 0.0
	if fwd.length_squared() > 0.0001 and to_source.length_squared() > 0.0001:
		if fwd.normalized().dot(to_source.normalized()) < cos(deg_to_rad(70.0)):
			return {}
	if info.parryable and _clock - _block_started <= melee.parry_window + (melee_item.parry_bonus() if melee_item else 0.0):
		return {"parried": true}
	var reduction := melee.block_reduction if info.parryable else melee.unparryable_block_reduction
	return {"blocked": true, "reduction": reduction,
		"stamina_per_damage": melee.block_stamina_per_damage * GameState.progress.guard_cost_mult()}


func guard_break() -> void:
	_guard_broken_left = GUARD_BREAK_TIME
	_block_started = -1.0
	GameEvents.notify("방어가 무너졌습니다.", GameEvents.NoticeKind.WARNING)
	guard_broken.emit()


func try_quick_melee() -> void:
	if player == null or not player.can_act() or _quick_left > 0.0 or not is_ready() \
			or _melee_phase != MeleePhase.NONE or player.is_busy_with_consumable():
		return
	if current_slot == Slot.MELEE:
		_start_melee_attack(false)
		return
	var gun := current_gun()
	if gun and gun.reloading:
		gun.cancel_reload()
	_quick_left = melee.quick_time
	_quick_hit_done = false
	_anim_time = 0.0
	ads_blend = 0.0
	player.cancel_sprint()
	player.apply_action_bleed()
	Sfx.play(&"melee_swing", -3.0)
	_refresh_views()


func _update_quick_melee(delta: float) -> void:
	if _quick_left <= 0.0:
		return
	_quick_left -= delta
	if not _quick_hit_done and melee.quick_time - _quick_left >= QUICK_MELEE_HIT_TIME:
		_quick_hit_done = true
		melee_strike(melee.quick_damage, melee.quick_stagger, melee.bleed_buildup * 0.5, false,
			melee.reach * 0.9, melee.hit_radius)
	if _quick_left <= 0.0:
		_quick_left = 0.0
		_refresh_views()


# --- 외부 사건 ---

func on_consumable_used(duration: float) -> void:
	var gun := current_gun()
	if gun and gun.reloading:
		gun.cancel_reload()
	_lowered_left = maxf(_lowered_left, duration)
	ads_blend = 0.0
	_block_started = -1.0


func on_owner_died() -> void:
	_cancel_actions()
	if _vm_root:
		_vm_root.visible = false
	_trigger_held = false
	_aim_held = false
	_simulated_hold = false
	_simulated_aim = false


func on_respawn() -> void:
	_cancel_actions()
	if _vm_root:
		_vm_root.visible = true
	for state: GunState in _states.values():
		state.heat = 0.0
		state.overheated = false
		state.bloom = 0.0
	_equip_left = _equip_time_for(current_slot)
	ammo_changed.emit()


## 거점 휴식: 모든 총기의 탄창을 채우고 과열을 식힌다.
func on_rest() -> void:
	for state: GunState in _states.values():
		state.cancel_reload()
		state.heat = 0.0
		state.overheated = false
		if not state.data.uses_heat:
			state.mag = state.capacity
	ammo_changed.emit()


# --- 화면 표시 ---

func _world_root() -> Node:
	var tree := get_tree()
	return tree.current_scene if tree.current_scene else tree.root


func _refresh_views() -> void:
	var show_key: StringName = melee.id
	if current_slot == Slot.PRIMARY:
		show_key = primary.id
	elif current_slot == Slot.SECONDARY:
		show_key = secondary.id
	if _quick_left > 0.0:
		show_key = melee.id
	for key in _views:
		_views[key].root.visible = key == show_key
	var gun := current_gun()
	if gun and _views.has(gun.data.id):
		var muzzle: Marker3D = _views[gun.data.id].muzzle
		if _flash.get_parent() != muzzle:
			if _flash.get_parent():
				_flash.get_parent().remove_child(_flash)
			muzzle.add_child(_flash)
	_flash.visible = false


func _show_flash(data: WeaponData) -> void:
	var strength := float(Settings.get_value(&"muzzle_flash"))
	if strength <= 0.01:
		return
	_flash_left = FLASH_TIME
	_flash.visible = true
	_flash.scale = Vector3.ONE * lerpf(0.6, 1.2, strength) * (1.4 if data.pellets > 1 else 1.0)
	_flash.rotation.z = randf() * TAU
	for child in _flash.get_children():
		var mat: ShaderMaterial = child.material_override
		mat.set_shader_parameter("color", data.tracer_color)
		mat.set_shader_parameter("intensity", strength)
	_flash_light.global_position = _flash.global_position
	_flash_light.light_color = data.tracer_color
	_flash_light.light_energy = 2.5 * strength


func _process(delta: float) -> void:
	if player == null or _vm_root == null:
		return
	_anim_time += delta
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
			_flash_light.light_energy = 0.0
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-12.0 * delta))
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	var pos := HIP_POSITION
	var rot := Vector3.ZERO
	var gun := current_gun()
	if _quick_left > 0.0:
		var t := 1.0 - _quick_left / maxf(melee.quick_time, 0.01)
		pos = MELEE_POSITION + Vector3(-0.1 * sin(t * PI), 0.08 * sin(t * PI), -0.1 * sin(t * PI))
		rot = Vector3(-60.0, lerpf(30.0, -40.0, t), lerpf(-40.0, 60.0, t))
	elif current_slot == Slot.MELEE and melee.dual:
		pos = TWIN_POSITION
		_animate_twin(delta)
	elif current_slot == Slot.MELEE and _technique != Technique.NONE:
		pos = MELEE_POSITION
		var t := clampf(_tech_elapsed / 0.2, 0.0, 1.0)
		match _technique:
			Technique.PLUNGE:
				rot = Vector3(lerpf(30.0, -95.0, 1.0 if _tech_hit_done else t * 0.4), 5.0, -10.0)
			_:
				rot = Vector3(lerpf(-40.0, -88.0, t), 0.0, -10.0)
				pos += Vector3(-0.12, 0.08, -0.12 * t)
	elif current_slot == Slot.MELEE:
		pos = MELEE_POSITION
		rot = Vector3(-35.0, 12.0, -18.0)
		if is_blocking():
			pos = Vector3(0.12, -0.14, -0.5)
			rot = Vector3(-10.0, 10.0, 75.0)
		match _melee_phase:
			MeleePhase.CHARGING:
				var c := clampf(_melee_hold / maxf(melee.heavy_charge_time, 0.01), 0.0, 1.0)
				rot += Vector3(25.0 * c, 0.0, -20.0 * c)
				pos += Vector3(0.05 * c, 0.05 * c, 0.05 * c)
			MeleePhase.WINDUP:
				var w := 1.0 - _melee_timer / maxf(_windup_time(_melee_heavy), 0.01)
				if _melee_heavy:
					rot += Vector3(lerpf(30.0, -70.0, w), 0.0, 0.0)
				else:
					rot += Vector3(0.0, lerpf(25.0, -35.0, w), lerpf(-30.0, 55.0, w))
					if _combo % 2 == 0:
						rot.y = -rot.y
						rot.z = -rot.z + 40.0
			MeleePhase.RECOVERY:
				var r := _melee_timer / maxf(_recovery_time(_melee_heavy), 0.01)
				rot += Vector3(-40.0 * r if _melee_heavy else 0.0, -30.0 * r, 50.0 * r)
	elif gun:
		var view: Dictionary = _views.get(gun.data.id, {})
		var ads_pos: Vector3 = view.get("ads_offset", HIP_POSITION)
		pos = HIP_POSITION.lerp(ads_pos, ads_blend)
		if player.sprinting:
			pos += Vector3(-0.05, -0.05, 0.03)
			rot += Vector3(-12.0, 28.0, 8.0)
		if gun.reloading:
			var p := gun.reload_progress()
			var dip := sin(p * PI)
			pos += Vector3(0.0, -0.08 * dip, 0.0)
			rot += Vector3(-15.0 * dip, 0.0, 25.0 * dip)
		if gun.overheated:
			rot += Vector3(-10.0, 0.0, 10.0)
		if is_scoped():
			pos = Vector3(0.0, -0.6, -0.3)
	if _equip_left > 0.0 or _lowered_left > 0.0 or _guard_broken_left > 0.0:
		pos += Vector3(0.0, -0.25, 0.0)
		rot += Vector3(-30.0, 0.0, 0.0)
	var sway_scale := lerpf(1.0, 0.25, ads_blend)
	pos += Vector3(-_sway.x, _sway.y, 0.0) * 0.0004 * sway_scale
	rot += Vector3(_sway.y * 0.02, _sway.x * 0.02, 0.0) * sway_scale
	pos.z += 0.04 * _kick
	rot.x += 4.0 * _kick * lerpf(1.0, 0.4, ads_blend)
	var target := Transform3D(Basis.from_euler(rot * (PI / 180.0)), pos)
	_vm_root.transform = _vm_root.transform.interpolate_with(target, 1.0 - exp(-22.0 * delta))


## 쌍검 양손 동작: 약공격은 좌우를 번갈아, 강공격은 두 손을 크게 돌려 벤다.
func _animate_twin(delta: float) -> void:
	var view: Dictionary = _views.get(melee.id, {})
	var right: Node3D = view.get("right")
	var left: Node3D = view.get("left")
	if right == null or left == null:
		return
	# 기본 자세: 칼끝이 앞쪽 위를 향하고 바깥으로 조금 벌어진다.
	var r_rot := Vector3(-64.0, 10.0, -24.0)
	var l_rot := Vector3(-64.0, -10.0, 24.0)
	var r_pos := Vector3(0.2, 0.0, 0.0)
	var l_pos := Vector3(-0.2, 0.0, 0.0)
	if is_blocking():
		# 방어: 두 칼을 가슴 앞에서 낮게 엇갈린다.
		r_rot = Vector3(-24.0, 22.0, 46.0)
		l_rot = Vector3(-24.0, -22.0, -46.0)
		r_pos = Vector3(0.13, 0.0, -0.02)
		l_pos = Vector3(-0.13, 0.0, -0.02)
	var swing_right := _combo % 2 == 1
	match _melee_phase:
		MeleePhase.CHARGING:
			var c := clampf(_melee_hold / maxf(melee.heavy_charge_time, 0.01), 0.0, 1.0)
			r_rot += Vector3(28.0 * c, 20.0 * c, 0.0)
			l_rot += Vector3(28.0 * c, -20.0 * c, 0.0)
		MeleePhase.WINDUP:
			var w := 1.0 - _melee_timer / maxf(_windup_time(_melee_heavy), 0.01)
			if _melee_heavy:
				r_rot += Vector3(-10.0, lerpf(40.0, -120.0, w), lerpf(-20.0, 70.0, w))
				l_rot += Vector3(-10.0, lerpf(-40.0, 120.0, w), lerpf(20.0, -70.0, w))
			elif swing_right:
				r_rot += Vector3(0.0, lerpf(30.0, -45.0, w), lerpf(-40.0, 65.0, w))
				r_pos += Vector3(-0.08 * w, 0.05 * w, -0.08 * w)
			else:
				l_rot += Vector3(0.0, lerpf(-30.0, 45.0, w), lerpf(40.0, -65.0, w))
				l_pos += Vector3(0.08 * w, 0.05 * w, -0.08 * w)
		MeleePhase.RECOVERY:
			var r := _melee_timer / maxf(_recovery_time(_melee_heavy), 0.01)
			if _melee_heavy:
				r_rot += Vector3(0.0, -60.0 * r, 40.0 * r)
				l_rot += Vector3(0.0, 60.0 * r, -40.0 * r)
			elif swing_right:
				r_rot += Vector3(0.0, -35.0 * r, 55.0 * r)
			else:
				l_rot += Vector3(0.0, 35.0 * r, -55.0 * r)
	if _technique != Technique.NONE:
		var t := clampf(_tech_elapsed / 0.2, 0.0, 1.0)
		match _technique:
			Technique.PLUNGE:
				var down := 1.0 if _tech_hit_done else t * 0.3
				r_rot = Vector3(lerpf(35.0, -100.0, down), 10.0, -10.0)
				l_rot = Vector3(lerpf(35.0, -100.0, down), -10.0, 10.0)
			Technique.THRUST:
				r_rot = Vector3(lerpf(-40.0, -88.0, t), 0.0, 0.0)
				r_pos = Vector3(0.12, 0.05, -0.16 * t)
			_:
				r_rot = Vector3(lerpf(-40.0, -85.0, t), -25.0 * t, 0.0)
				l_rot = Vector3(lerpf(-40.0, -85.0, t), 25.0 * t, 0.0)
				r_pos = Vector3(0.16, 0.04, -0.1 * t)
				l_pos = Vector3(-0.16, 0.04, -0.1 * t)
	var k := 1.0 - exp(-26.0 * delta)
	right.transform = right.transform.interpolate_with(Transform3D(Basis.from_euler(r_rot * (PI / 180.0)), r_pos), k)
	left.transform = left.transform.interpolate_with(Transform3D(Basis.from_euler(l_rot * (PI / 180.0)), l_pos), k)

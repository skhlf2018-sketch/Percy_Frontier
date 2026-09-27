extends TestCase
## 플레이어·무기·적의 실제 장면 동작을 검증한다.

const DUMMY := preload("res://src/enemies/training_dummy.tscn")
const RABBIT := preload("res://src/enemies/killer_rabbit.tscn")
const CHARGER := preload("res://src/enemies/rock_charger.tscn")
const SPITTER := preload("res://src/enemies/spore_spitter.tscn")

var world: TestWorld
var hits: Array[HitResult] = []


func before_each() -> void:
	GameState.reset_session()
	Settings.load_settings("user://test_integration_settings.cfg")
	world = TestWorld.create(runner)
	hits.clear()
	GameEvents.hit_confirmed.connect(_on_hit)


func after_each() -> void:
	GameEvents.hit_confirmed.disconnect(_on_hit)
	TimeFx.reset()
	GameState.reset_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_integration_settings.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)


func _on_hit(result: HitResult) -> void:
	hits.append(result)


func _fire_once(p: Player) -> void:
	p.weapons.press_trigger()
	await wait_physics_frames(1)
	p.weapons.release_trigger()
	await wait_physics_frames(1)


func test_rifle_headshot_is_weak_point() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -10), PI)
	await wait_physics_frames(3)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.8)
	p.weapons.simulate_aim(true)
	await wait_seconds(0.6)
	assert_true(p.weapons.is_aiming(), "정조준")
	var before := dummy.hp
	await _fire_once(p)
	assert_eq(hits.size(), 1, "명중 1회")
	if hits.size() > 0:
		assert_eq(hits[0].zone, Hurtbox.Zone.WEAK_POINT, "머리는 약점")
		assert_near(hits[0].damage, 14.0 * 2.0, 0.01)
	assert_near(dummy.hp, before - 28.0, 0.01)
	assert_gt(p.stats.resonance, 0.0, "약점 명중으로 공명을 얻는다")
	assert_eq(p.weapons.current_gun().mag, 29)


func test_chest_plate_absorbs_then_breaks() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -6), PI)
	await wait_physics_frames(3)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.3)
	p.weapons.simulate_aim(true)
	await wait_seconds(0.6)
	await _fire_once(p)
	assert_eq(hits.size(), 1)
	if hits.size() > 0:
		assert_true(hits[0].hit_armor, "장갑판 명중")
		assert_near(hits[0].damage, 14.0 * 0.2, 0.01, "장갑이 대부분 흡수")
	# 연사로 장갑 파괴(반동으로 올라간 조준을 매번 되돌린다)
	var broke := false
	for i in 12:
		await wait_seconds(0.12)
		TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.3)
		await _fire_once(p)
		for h in hits:
			if h.armor_broken:
				broke = true
		if broke:
			break
	assert_true(broke, "장갑 내구 80은 소총으로 부술 수 있다")


func test_hitscan_is_blocked_by_walls() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -10), PI)
	world.add_box(Vector3(0, 1.5, -5), Vector3(4, 3, 0.5))
	await wait_physics_frames(3)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.3)
	await wait_seconds(0.6)
	await _fire_once(p)
	assert_eq(hits.size(), 0, "벽 너머 적은 맞지 않는다")


func test_reload_refills_magazine() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(2)
	var gun := p.weapons.current_gun()
	gun.mag = 3
	await wait_seconds(0.6)
	assert_true(p.weapons.try_reload())
	await wait_seconds(gun.data.reload_time + 0.2)
	assert_eq(gun.mag, gun.data.magazine_size)


func test_weapon_switch_and_melee_hit() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -2.0), PI)
	await wait_physics_frames(3)
	p.weapons.select_slot(WeaponManager.Slot.MELEE)
	assert_true(p.weapons.is_melee_equipped())
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.1)
	await wait_seconds(0.5)
	var before := dummy.hp
	p.weapons.press_trigger()
	await wait_physics_frames(2)
	p.weapons.release_trigger()
	await wait_seconds(0.5)
	assert_lt(dummy.hp, before, "약공격 명중")
	assert_true(hits.size() >= 1)
	if hits.size() > 0:
		assert_eq(hits[0].kind, DamageInfo.Kind.MELEE)


func test_heavy_melee_breaks_armor_faster() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -2.0), PI)
	await wait_physics_frames(3)
	p.weapons.select_slot(WeaponManager.Slot.MELEE)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.3)
	await wait_seconds(0.5)
	p.weapons.simulate_hold(true)
	await wait_seconds(0.7)
	p.weapons.simulate_hold(false)
	await wait_seconds(0.3)
	assert_true(hits.size() >= 1, "강공격 명중")
	if hits.size() > 0:
		assert_true(hits[0].armor_broken, "검 강공격(60 x 장갑 배율 2.2)은 장갑 80을 한 번에 부순다")


func test_quick_melee_while_holding_gun() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -1.8), PI)
	await wait_physics_frames(3)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.1)
	await wait_seconds(0.6)
	p.weapons.try_quick_melee()
	await wait_seconds(0.5)
	assert_false(p.weapons.is_melee_equipped(), "총을 든 상태 유지")
	assert_true(hits.size() >= 1, "빠른 근접 명중")


func test_energy_rifle_projectile_and_heat() -> void:
	GameState.set_primary_weapon(&"energy_re2")
	var p := world.spawn_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -12), PI)
	await wait_physics_frames(3)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.0)
	# 허리 사격 탄퍼짐으로 12m에서 가끔 빗나가지 않도록 정조준해서 쏜다.
	p.weapons.simulate_aim(true)
	await wait_seconds(0.7)
	await _fire_once(p)
	var gun := p.weapons.current_gun()
	assert_gt(gun.heat, 0.0, "탄약 대신 열이 쌓인다")
	assert_eq(hits.size(), 0, "투사체는 즉시 맞지 않는다")
	await wait_seconds(0.4)
	assert_eq(hits.size(), 1, "투사체가 날아가 명중")
	assert_gt(dummy.status.get_buildup(StatusEffects.Type.SHOCK), 0.0, "감전 축적")


func test_shotgun_pellets_share_one_shot() -> void:
	GameState.set_primary_weapon(&"shotgun_logger")
	var p := world.spawn_player(Vector3(0, 0, 0))
	var dummy := world.spawn(DUMMY, Vector3(0, 0, -4), PI)
	await wait_physics_frames(3)
	TestWorld.aim_at(p, dummy.global_position + Vector3.UP * 1.0)
	await wait_seconds(0.7)
	await _fire_once(p)
	assert_gt(hits.size(), 3, "가까운 거리에서 여러 펠릿이 맞는다")
	assert_eq(p.weapons.current_gun().mag, 5, "한 번 쏘면 탄 1발 소모")


func test_frost_pulse_freezes_nearby_rabbit() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -3), PI)
	world.bake()
	await wait_physics_frames(3)
	p.stats.add_resonance(100.0)
	assert_true(p.skills.cast_slot(0), "서리 파동 시전")
	await wait_physics_frames(2)
	assert_true(rabbit.status.is_frozen(), "일반 적은 빙결")
	assert_near(p.stats.resonance, 65.0, 0.5, "공명 35 소모")
	assert_false(p.skills.cast_slot(0), "재사용 대기")


func test_skill_fails_without_resonance() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(2)
	var reasons: Array[String] = []
	p.skills.cast_failed.connect(func(_slot: int, reason: String) -> void: reasons.append(reason))
	assert_false(p.skills.cast_slot(0))
	assert_false(p.skills.cast_slot(1), "빈 슬롯")
	assert_eq(reasons.size(), 2)


func test_rabbit_detects_and_bites_player() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -8), 0.0)
	rabbit.rotation.y = 0.0
	world.bake()
	await wait_physics_frames(3)
	# 토끼가 플레이어를 보도록(토끼 정면 -Z에서 플레이어는 +Z 방향이므로 뒤돌려 둔다)
	rabbit.rotation.y = PI
	var start_hp := p.stats.hp
	await wait_seconds(5.0)
	assert_true(rabbit.target == p, "시야 안의 플레이어를 발견한다")
	assert_lt(p.stats.hp, start_hp, "도약 물기로 피해를 준다")


func test_enemy_does_not_see_through_walls() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	world.add_box(Vector3(0, 2, -4), Vector3(8, 4, 0.5))
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -8), PI)
	await wait_physics_frames(3)
	assert_false(rabbit.can_see(p), "벽에 가리면 볼 수 없다")
	await wait_seconds(1.0)
	assert_eq(rabbit.state, Enemy.State.IDLE)


func test_gunshot_draws_investigation() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -15), 0.0)
	world.bake()
	await wait_physics_frames(3)
	assert_false(rabbit.can_see(p), "등을 돌리고 있다")
	await wait_seconds(0.6)
	await _fire_once(p)
	await wait_physics_frames(2)
	assert_eq(rabbit.state, Enemy.State.INVESTIGATE, "총소리 위치를 조사하러 간다")
	assert_null(rabbit.target, "소리만으로는 플레이어를 확정하지 않는다")


func test_pack_alert_spreads_to_nearby_rabbits() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var a := world.spawn(RABBIT, Vector3(0, 0, -8), PI)
	var b := world.spawn(RABBIT, Vector3(6, 0, -14), 0.0)
	world.bake()
	await wait_physics_frames(3)
	assert_false(b.can_see(p))
	await wait_seconds(1.5)
	assert_eq(a.target, p)
	assert_eq(b.target, p, "경고 울음으로 무리가 합류한다")


func test_parry_staggers_attacker() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(2)
	p.weapons.select_slot(WeaponManager.Slot.MELEE)
	await wait_seconds(0.5)
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -2), PI)
	await wait_physics_frames(2)
	TestWorld.aim_at(p, rabbit.global_position + Vector3.UP * 0.4)
	rabbit.alert(p)
	p.weapons.simulate_aim(true)
	await wait_physics_frames(1)
	var info := DamageInfo.create(10.0, DamageInfo.Kind.ENEMY_MELEE, rabbit)
	info.parryable = true
	info.hit_position = rabbit.global_position
	var result := p.receive_enemy_attack(info)
	assert_true(result.parried, "막기 시작 직후에는 패링")
	assert_eq(rabbit.state, Enemy.State.STAGGER)
	assert_near(p.stats.resonance, 20.0, 0.01)
	await wait_seconds(0.5)
	var blocked := p.receive_enemy_attack(info)
	assert_true(blocked.blocked, "패링 시간이 지나면 방어")
	assert_lt(blocked.damage, 10.0)


func test_unparryable_attack_is_not_parried() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(2)
	p.weapons.select_slot(WeaponManager.Slot.MELEE)
	await wait_seconds(0.5)
	var charger := world.spawn(CHARGER, Vector3(0, 0, -4), PI)
	await wait_physics_frames(2)
	TestWorld.aim_at(p, charger.global_position + Vector3.UP)
	p.weapons.simulate_aim(true)
	await wait_physics_frames(1)
	var info := DamageInfo.create(26.0, DamageInfo.Kind.ENEMY_MELEE, charger)
	info.parryable = false
	info.hit_position = charger.global_position
	var result := p.receive_enemy_attack(info)
	assert_false(result.parried)
	assert_true(result.blocked)
	assert_gt(result.damage, 26.0 * 0.5, "패링 불가 공격은 방어해도 대부분 들어온다")


func test_dodge_grants_invulnerability() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -3), PI)
	await wait_physics_frames(3)
	assert_true(p.try_dodge())
	var info := DamageInfo.create(10.0, DamageInfo.Kind.ENEMY_MELEE, rabbit)
	var result := p.receive_enemy_attack(info)
	assert_true(result.evaded)
	assert_near(p.stats.hp, p.stats.max_hp)
	assert_near(p.stats.stamina, p.stats.max_stamina - Player.DODGE_COST, 1.0)


func test_charger_armor_break_enrages() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var charger: RockCharger = world.spawn(CHARGER, Vector3(0, 0, -8), 0.0)
	await wait_physics_frames(3)
	var plate: Hurtbox = charger.get_node("FrontPlateHurtbox")
	var info := DamageInfo.create(200.0, DamageInfo.Kind.MELEE, p)
	info.armor_damage_mult = 1.0
	var result := plate.hit(info)
	assert_true(result.armor_broken)
	assert_true(charger.enraged, "장갑이 깨지면 분노")
	assert_eq(plate.effective_zone(), Hurtbox.Zone.WEAK_POINT, "드러난 핵이 약점이 된다")
	assert_eq(charger.state, Enemy.State.STAGGER, "파괴 순간 경직")
	var analysis := GameState.bestiary.analysis_of(&"rock_charger")
	assert_gt(analysis, 0.0, "부위 파괴는 분석도를 준다")


func test_stagger_resistance_grows() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var charger: RockCharger = world.spawn(CHARGER, Vector3(0, 0, -8), 0.0)
	await wait_physics_frames(3)
	var body: Hurtbox = charger.get_node("BodyHurtbox")
	var info := DamageInfo.create(1.0, DamageInfo.Kind.MELEE, p)
	info.stagger = charger.data.poise + 1.0
	body.hit(info)
	assert_eq(charger.state, Enemy.State.STAGGER)
	await wait_seconds(charger.data.stagger_duration + 0.2)
	var second := body.hit(info)
	assert_false(second.staggered, "직후 같은 경직치로는 다시 경직되지 않는다")


func test_spitter_sac_burst_interrupts_attack() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var spitter: SporeSpitter = world.spawn(SPITTER, Vector3(0, 0, -14), PI)
	world.bake()
	await wait_physics_frames(3)
	spitter.alert(p)
	var waited := 0.0
	while spitter.telegraph_info().is_empty() and waited < 6.0:
		await wait_physics_frames(1)
		waited += 1.0 / 60.0
	assert_false(spitter.telegraph_info().is_empty(), "전조를 시작한다")
	var sac: Hurtbox = spitter.get_node("SacHurtbox")
	var info := DamageInfo.create(10.0, DamageInfo.Kind.GUN, p)
	sac.hit(info)
	assert_true(spitter.sac_depleted, "전조 중 주머니를 맞히면 터진다")
	assert_true(spitter.telegraph_info().is_empty(), "공격이 끊긴다")
	assert_true(spitter.status.is_active(StatusEffects.Type.BURN), "자신이 화상을 입는다")


func test_spitter_projectile_hurts_player() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var spitter := world.spawn(SPITTER, Vector3(0, 0, -12), PI)
	world.bake()
	await wait_physics_frames(3)
	spitter.alert(p)
	var start_hp := p.stats.hp
	await wait_seconds(5.0)
	assert_lt(p.stats.hp, start_hp, "곡사 포자가 명중한다")


func test_kill_records_bestiary_and_resonance() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var rabbit := world.spawn(RABBIT, Vector3(0, 0, -6), 0.0)
	await wait_physics_frames(3)
	var head: Hurtbox = rabbit.get_node("HeadHurtbox")
	var info := DamageInfo.create(200.0, DamageInfo.Kind.GUN, p)
	var result := head.hit(info)
	assert_true(result.killed)
	assert_false(rabbit.is_alive())
	var entry := GameState.bestiary.get_entry(&"killer_rabbit")
	assert_not_null(entry)
	if entry:
		assert_eq(entry.kills, 1)
		assert_gt(entry.analysis, 0.0)
	assert_ge(p.stats.resonance, rabbit.data.resonance_on_kill)
	await wait_seconds(Enemy.CORPSE_TIME + 0.2)
	assert_false(is_instance_valid(rabbit), "사체는 잠시 뒤 사라진다")


func test_player_death_and_respawn_keeps_progress() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(2)
	GameState.unlock_skill(&"fire_spore")
	p.consumable_counts[&"field_suture"] = 0
	p.ammo.counts[&"rifle"] = 0
	p.stats.take_damage(500.0)
	assert_false(p.alive)
	p.respawn_at(Transform3D(Basis(), Vector3(5, 0, 5)))
	await wait_physics_frames(2)
	assert_true(p.alive)
	assert_near(p.stats.hp, p.stats.max_hp)
	assert_true(GameState.is_skill_unlocked(&"fire_spore"), "스킬은 잃지 않는다")
	assert_eq(p.consumable_counts[&"field_suture"], 1, "기본 회복 수단 보장")
	assert_ge(p.ammo.get_count(&"rifle"), AmmoInventory.TYPES[&"rifle"].emergency, "비상 탄약 보장")


func test_consumable_heals_over_time() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(2)
	p.stats.take_damage(60.0)
	var count: int = p.consumable_counts[&"field_suture"]
	assert_true(p.use_consumable(0))
	await wait_seconds(2.0)
	assert_near(p.stats.hp, 85.0, 0.5, "40 + 45")
	assert_eq(p.consumable_counts[&"field_suture"], count - 1)


func test_mantle_onto_low_ledge() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	world.add_box(Vector3(0, 0.5, -1.5), Vector3(3, 1.0, 1.5))
	await wait_physics_frames(5)
	p.yaw = 0.0
	assert_true(p.try_mantle(), "1m 높이 난간은 넘을 수 있다")
	await wait_seconds(0.6)
	assert_gt(p.global_position.y, 0.9, "난간 위로 올라섰다")


func test_hidden_rabbit_waits_until_close() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var rabbit: KillerRabbit = world.spawn(RABBIT, Vector3(0, 0, -15), PI)
	rabbit.hidden = true
	rabbit.ambush = true
	world.bake()
	await wait_seconds(1.5)
	assert_true(rabbit.can_see(p), "시야 안에 있다")
	assert_eq(rabbit.state, Enemy.State.IDLE, "숨어 있으면 멀리서 보고 튀어나오지 않는다")
	assert_true(rabbit.hidden)
	p.global_position = Vector3(0, 0, -10)
	await wait_seconds(0.5)
	assert_false(rabbit.hidden, "가까이 오면 튀어나온다")
	assert_eq(rabbit.target, p)


func test_aim_input_cancels_sprint() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(3)
	var ev := InputEventAction.new()
	ev.action = &"sprint"
	ev.pressed = true
	Input.parse_input_event(ev)
	var fwd := InputEventAction.new()
	fwd.action = &"move_forward"
	fwd.pressed = true
	fwd.strength = 1.0
	Input.parse_input_event(fwd)
	await wait_seconds(0.5)
	assert_true(p.sprinting, "달리는 중")
	p.weapons.simulate_aim(true)
	await wait_seconds(0.5)
	assert_false(p.sprinting, "조준 입력은 달리기를 끊는다")
	assert_true(p.weapons.is_aiming(), "정조준이 시작된다")
	p.weapons.simulate_aim(false)
	for action in [&"sprint", &"move_forward"]:
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event(up)
	await wait_physics_frames(2)


func test_firing_stops_sprint_briefly() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	await wait_physics_frames(3)
	var ev := InputEventAction.new()
	ev.action = &"sprint"
	ev.pressed = true
	Input.parse_input_event(ev)
	var fwd := InputEventAction.new()
	fwd.action = &"move_forward"
	fwd.pressed = true
	fwd.strength = 1.0
	Input.parse_input_event(fwd)
	await wait_seconds(0.8)
	assert_true(p.sprinting)
	p.weapons.simulate_hold(true)
	var sprint_frames := 0
	for i in 20:
		await wait_physics_frames(1)
		if p.sprinting:
			sprint_frames += 1
	p.weapons.simulate_hold(false)
	assert_eq(sprint_frames, 0, "쏘는 동안은 달리지 않는다")
	for action in [&"sprint", &"move_forward"]:
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event(up)
	await wait_physics_frames(2)

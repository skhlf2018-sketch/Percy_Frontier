extends TestCase
## 1지역 보스 늪턱 구렁: 잠든 채 숨어 있다가 깨어나 포효하고, 단계마다 패턴이 늘고, 돌진이 벽에 부딪히면 기절해
## 목 아래 약점이 드러나며, 잠수해 발밑에서 솟구친다. 싸움터 밖의 상대는 쫓지 않고 숨어서 회복한다.
## 최초 처치 보상과 보스 기록, 의뢰 단계, 저장도 확인한다.

var world: TestWorld


func before_each() -> void:
	GameState.reset_session()
	Settings.load_settings("user://test_maw_settings.cfg")
	world = TestWorld.create(runner, 120.0)


func after_each() -> void:
	if world and is_instance_valid(world.root):
		world.root.queue_free()
	await wait_frames(2)
	GameState.reset_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_maw_settings.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)


func _spawn_boss(at := Vector3.ZERO) -> MireMaw:
	var e := world.spawn_species(&"mire_maw", at, 0.0) as MireMaw
	return e


func _attack(boss: MireMaw, id: StringName) -> EnemyAttackData:
	for a in boss.data.attacks:
		if a.id == id:
			return a
	return null


## 보스가 이 공격을 끝낼 때까지(또는 limit 프레임) 기다린다.
func _wait_attack_done(boss: MireMaw, id: StringName, limit: int) -> void:
	for i in limit:
		await wait_physics_frames(1)
		if not (boss.state == Enemy.State.ATTACK and boss._attack and boss._attack.id == id):
			return


func test_boss_sleeps_hidden_until_awakened() -> void:
	var boss := _spawn_boss()
	await wait_physics_frames(3)
	assert_not_null(boss.rig(), "절차적 모델")
	assert_true(boss.dormant, "처음에는 진흙 속에 잠들어 있다")
	assert_true(boss.is_hidden())
	assert_eq(boss.collision_layer, 0, "잠든 동안은 부딪히지 않는다")
	for hb: Hurtbox in boss.find_children("*", "Hurtbox", true, false):
		assert_false(hb.is_enabled(), "잠든 동안은 맞힐 수 없다: %s" % hb.name)
	var info := DamageInfo.create(50.0, DamageInfo.Kind.GUN, null)
	assert_null(boss.receive_hit(info, null), "범위 피해도 받지 않는다")
	assert_eq(boss.hp, boss.data.max_hp)
	# 가까이 있어도 저절로 깨지 않는다(싸움터가 깨운다).
	var p := world.spawn_player(Vector3(0, 0, -8))
	await wait_physics_frames(30)
	assert_true(boss.dormant, "싸움터가 깨우기 전에는 잠들어 있다")
	p.queue_free()


func test_awakening_roar_exposes_throat() -> void:
	var boss := _spawn_boss()
	var p := world.spawn_player(Vector3(0, 0, -9))
	world.bake()
	await wait_physics_frames(3)
	var woke := [false]
	boss.awakened.connect(func() -> void: woke[0] = true)
	boss.awaken(p)
	assert_true(woke[0], "깨어남 신호")
	assert_false(boss.dormant)
	assert_eq(boss.collision_layer, CombatLayers.ENEMY, "몸이 드러난다")
	var roared := false
	var exposed_during_roar := false
	for i in 150:
		await wait_physics_frames(1)
		p.stats.hp = p.stats.max_hp
		if boss.state == Enemy.State.ATTACK and boss._attack and boss._attack.id == &"roar":
			roared = true
			if boss.throat_exposed():
				exposed_during_roar = true
	assert_true(roared, "깨어나면 먼저 포효한다")
	assert_true(exposed_during_roar, "포효하는 동안 목 아래 턱살이 드러난다")
	assert_true(boss.telegraph_info().is_empty() or boss._attack == null or boss._attack.id != &"roar", "포효는 공격 전조로 표시하지 않는다")


func test_phases_unlock_patterns() -> void:
	var boss := _spawn_boss()
	var p := world.spawn_player(Vector3(0, 0, -9))
	await wait_physics_frames(3)
	boss.awaken(p)
	boss.target = p
	var phases: Array[int] = []
	boss.phase_changed.connect(func(ph: int) -> void: phases.append(ph))
	assert_false(boss._attack_allowed(_attack(boss, &"mud_spit")), "1단계에는 진흙 뱉기가 없다")
	assert_false(boss._attack_allowed(_attack(boss, &"submerge")), "1단계에는 잠수가 없다")
	boss._apply_damage(boss.data.max_hp * 0.4, null, Hurtbox.Zone.NORMAL)
	assert_eq(boss.phase, 2, "HP 65% 미만이면 2단계")
	assert_true(boss._pending_roar, "단계가 바뀌면 포효한다")
	assert_true(boss._attack_allowed(_attack(boss, &"submerge")), "2단계: 잠수")
	assert_false(boss._attack_allowed(_attack(boss, &"death_roll")), "2단계에는 몸 굴리기가 없다")
	boss._apply_damage(boss.data.max_hp * 0.32, null, Hurtbox.Zone.NORMAL)
	assert_eq(boss.phase, 3, "HP 30% 미만이면 3단계")
	assert_eq(phases, [2, 3] as Array[int])
	boss.rotation.y = 0.0
	assert_true(boss._attack_allowed(_attack(boss, &"death_roll")), "3단계: 몸 굴리기 돌진")
	assert_false(boss._attack_allowed(_attack(boss, &"roar")), "포효는 무작위로 고르지 않는다")


func test_charge_into_wall_stuns_and_exposes_throat() -> void:
	var boss := _spawn_boss()
	# 보스 앞 7m에 벽, 그 너머에 플레이어
	world.add_box(Vector3(0, 2.0, -10.0), Vector3(12, 4, 1))
	var p := world.spawn_player(Vector3(0, 0, -16))
	await wait_physics_frames(3)
	boss.awaken(p)
	boss._pending_roar = false
	await wait_physics_frames(40)
	if boss._attack:
		boss._end_attack(false)
	boss._set_state(Enemy.State.CHASE)
	boss.rotation.y = 0.0
	boss._force_attack(&"lunge_bite")
	var stunned := false
	for i in 200:
		await wait_physics_frames(1)
		p.stats.hp = p.stats.max_hp
		if boss.state == Enemy.State.STUNNED:
			stunned = true
			break
	assert_true(stunned, "뛰어들어 물기가 벽에 부딪히면 정신을 잃는다")
	await wait_physics_frames(2)
	assert_true(boss.throat_exposed(), "기절하면 목 아래 턱살이 드러난다")
	var throat: Hurtbox = boss.find_children("ThroatHurtbox", "Hurtbox", true, false)[0]
	var hp_before := boss.hp
	var info := DamageInfo.create(40.0, DamageInfo.Kind.GUN, p)
	info.hit_position = throat.global_position
	var r := throat.hit(info)
	assert_not_null(r)
	assert_eq(r.zone, Hurtbox.Zone.WEAK_POINT, "턱살은 약점")
	assert_gt(hp_before - boss.hp, 40.0 * 1.5, "약점 배율이 크다")


func test_submerge_travels_underground_and_bursts_under_player() -> void:
	var boss := _spawn_boss()
	var p := world.spawn_player(Vector3(3, 0, -10))
	await wait_physics_frames(3)
	boss.awaken(p)
	boss._pending_roar = false
	boss.phase = 2
	await wait_physics_frames(40)
	if boss._attack:
		boss._end_attack(false)
	boss._set_state(Enemy.State.CHASE)
	p.stats.hp = p.stats.max_hp
	var hp0 := p.stats.hp
	boss._force_attack(&"submerge")
	var went_under := false
	var ring_seen := false
	var stuck := false
	for i in 400:
		await wait_physics_frames(1)
		if boss._underground:
			went_under = true
			assert_eq(boss.collision_layer, 0)
			var hb: Hurtbox = boss.find_children("HeadHurtbox", "Hurtbox", true, false)[0]
			assert_false(hb.is_enabled(), "땅속에서는 맞힐 수 없다")
		if boss._burst_ring and is_instance_valid(boss._burst_ring):
			ring_seen = true
		if boss.state == Enemy.State.STUNNED and boss._stuck:
			stuck = true
			break
	assert_true(went_under, "진흙 속으로 들어간다")
	assert_true(ring_seen, "솟구치기 전에 붉은 고리로 자리를 알린다")
	assert_true(stuck, "솟구친 뒤 박혀 움직이지 못한다")
	assert_lt(p.stats.hp, hp0, "가만히 서 있던 플레이어는 솟구치기에 맞는다")
	var flat := Vector2(boss.global_position.x - p.global_position.x, boss.global_position.z - p.global_position.z)
	assert_lt(flat.length(), 6.0, "플레이어 가까이에서 솟구친다")
	await wait_physics_frames(2)
	assert_true(boss.throat_exposed(), "박혀 있는 동안 턱살이 드러난다")


func test_tail_sweep_spares_the_head_side() -> void:
	var boss := _spawn_boss()
	var p := world.spawn_player(Vector3(0, 0, -4))
	await wait_physics_frames(3)
	boss.awaken(p)
	boss.target = p
	boss.rotation.y = 0.0
	boss._attack_dir = -boss.global_basis.z
	var sweep := _attack(boss, &"tail_sweep")
	assert_false(boss._try_hit_target(sweep), "머리 쪽 앞은 꼬리에 맞지 않는다")
	p.global_position = Vector3(0, 0, 5.0)
	boss._attack_hit_done = false
	assert_true(boss._try_hit_target(sweep), "뒤쪽은 꼬리에 맞는다")
	assert_false(boss._attack_allowed(_attack(boss, &"jaw_snap")), "뒤에 있으면 턱 내리꽂기를 하지 않는다")
	assert_true(boss._attack_allowed(sweep), "뒤에 있으면 꼬리를 휘두를 수 있다")


func test_player_outside_arena_makes_boss_hide_and_heal() -> void:
	var boss := _spawn_boss()
	var p := world.spawn_player(Vector3(0, 0, -10))
	await wait_physics_frames(3)
	boss.awaken(p)
	boss._pending_roar = false
	boss._apply_damage(boss.data.max_hp * 0.2, null, Hurtbox.Zone.NORMAL)
	var hp_hurt := boss.hp
	p.global_position = Vector3(0, 0, -(boss.fight_radius + 8.0))
	p.reset_physics_interpolation()
	var hid := false
	for i in 400:
		await wait_physics_frames(1)
		p.stats.hp = p.stats.max_hp
		if boss._hiding:
			hid = true
			break
	assert_true(hid, "싸움터 밖에 머무르면 진흙 속에 숨는다")
	var info := DamageInfo.create(30.0, DamageInfo.Kind.GUN, p)
	assert_null(boss.receive_hit(info, null), "숨어 있는 동안은 맞지 않는다")
	await wait_physics_frames(60)
	assert_gt(boss.hp, hp_hurt, "숨어 있는 동안 상처가 아문다")
	p.global_position = Vector3(0, 0, -8)
	p.reset_physics_interpolation()
	for i in 60:
		await wait_physics_frames(1)
		if not boss._hiding:
			break
	assert_false(boss._hiding, "싸움터로 돌아오면 다시 솟아오른다")


func test_reset_fight_returns_to_sleep() -> void:
	var boss := _spawn_boss()
	var p := world.spawn_player(Vector3(0, 0, -10))
	await wait_physics_frames(3)
	boss.awaken(p)
	boss._apply_damage(boss.data.max_hp * 0.5, null, Hurtbox.Zone.NORMAL)
	var back: Hurtbox = boss.find_children("BackHurtbox", "Hurtbox", true, false)[0]
	back.apply_armor_damage(9999.0)
	await wait_physics_frames(5)
	boss.reset_fight()
	assert_true(boss.dormant)
	assert_eq(boss.hp, boss.data.max_hp, "체력이 모두 돌아온다")
	assert_eq(boss.phase, 1)
	assert_true(back.is_armor_intact(), "부서진 등 골판도 돌아온다")
	assert_true(boss.is_hidden())


func test_first_kill_rewards_once_and_records() -> void:
	var arena := MireArena.new()
	arena._on_boss_died(null)
	assert_true(GameState.boss_defeated(&"mire_maw"), "처치 기록")
	var fang: WeaponItem = null
	for it in GameState.warehouse:
		if it.base_id == &"maw_fang":
			fang = it
	assert_not_null(fang, "유니크 대검이 창고에 들어온다")
	if fang:
		assert_eq(fang.rarity, ItemRarity.Tier.UNIQUE)
		assert_true(fang.has_perk(&"serrated"))
	assert_eq(GameState.item_count(&"maw_core"), 1, "보스 핵")
	assert_true(GameState.titles.has(&"maw_hunter"), "칭호")
	var silver := GameState.silver
	arena._on_boss_died(null)
	assert_eq(GameState.item_count(&"maw_core"), 1, "두 번 받지 않는다")
	assert_eq(GameState.silver, silver)
	arena.free()


func test_reward_goes_in_even_when_warehouse_is_full_and_survives_save() -> void:
	while not GameState.warehouse_full():
		GameState.store_item(WeaponItem.create(&"pistol_bf9"))
	GameState.store_reward(WeaponItem.create(&"maw_fang", ItemRarity.Tier.UNIQUE, [], "늪턱 이빨"))
	assert_eq(GameState.warehouse.size(), GameState.WAREHOUSE_SIZE + 1, "가득 찬 창고에도 확정 보상은 들어간다")
	var doc := GameState.to_dict()
	GameState.reset_session()
	GameState.from_dict(doc)
	var found := false
	for it in GameState.warehouse:
		if it.base_id == &"maw_fang":
			found = true
	assert_true(found, "불러와도 보상이 남아 있다")


func test_boss_record_saves_and_quest_counts_prior_defeat() -> void:
	GameState.record_boss(&"mire_maw", "seen")
	GameState.record_boss(&"mire_maw", "attempts")
	GameState.record_boss(&"mire_maw", "defeated")
	var doc := GameState.to_dict()
	GameState.reset_session()
	GameState.from_dict(doc)
	assert_true(GameState.boss_defeated(&"mire_maw"), "보스 처치 기록이 저장된다")
	assert_eq(int(GameState.boss_record(&"mire_maw").attempts), 1)
	# 먼저 쓰러뜨렸어도 의뢰의 보스 단계는 인정된다(기획서 §17.2).
	var q := GameState.quests
	q.start(&"mire_maw_hunt")
	assert_true(q.try_talk_step(&"mire_maw_hunt", &"hunter"))
	assert_eq(q.step_of(&"mire_maw_hunt"), 2, "보스 단계를 건너뛰고 보고 단계로")


func test_quest_boss_step_completes_on_defeat() -> void:
	var q := GameState.quests
	q.start(&"mire_maw_hunt")
	q.try_talk_step(&"mire_maw_hunt", &"hunter")
	assert_eq(q.step_of(&"mire_maw_hunt"), 1)
	GameState.record_boss(&"mire_maw", "defeated")
	assert_eq(q.step_of(&"mire_maw_hunt"), 2, "보스를 쓰러뜨리면 단계가 넘어간다")
	assert_true(q.try_talk_step(&"mire_maw_hunt", &"clerk"))
	assert_true(q.is_done(&"mire_maw_hunt"))

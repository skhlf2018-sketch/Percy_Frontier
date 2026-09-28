extends TestCase
## 새 종(뿔토끼·연쇄살인범토끼·늑대 셋·고블린 일곱): 절차적 모델과 동작, 뼈를 따라가는 피격 부위, 역할별 행동,
## 고블린 무기 드롭과 조준선이 있는 총격.

const SPECIES: Array[StringName] = [
	&"horn_rabbit", &"serial_rabbit", &"ash_wolf", &"wolf_alpha", &"silvermane",
	&"goblin_scout", &"goblin_brute", &"goblin_gunner", &"goblin_thrower", &"goblin_shaman", &"goblin_chief", &"oneeye_sniper",
]

var world: TestWorld


func before_each() -> void:
	GameState.reset_session()
	Settings.load_settings("user://test_species_settings.cfg")
	world = TestWorld.create(runner)


func after_each() -> void:
	if world and is_instance_valid(world.root):
		world.root.queue_free()
	await wait_frames(2)
	GameState.reset_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_species_settings.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)


func test_every_species_builds_body() -> void:
	for id in SPECIES:
		var e := world.spawn_species(id, Vector3(0, 0, -6), 0.0)
		await wait_physics_frames(2)
		assert_not_null(e.rig(), "%s: 절차적 모델" % id)
		assert_not_null(e.animator(), "%s: 동작기" % id)
		var head: Hurtbox = null
		for hb in e.find_children("*", "Hurtbox", true, false):
			if (hb as Hurtbox).zone == Hurtbox.Zone.WEAK_POINT:
				head = hb
		assert_not_null(head, "%s: 약점 부위" % id)
		assert_true(e.get_node_or_null(^"CollisionShape3D") != null, "%s: 이동 충돌체" % id)
		assert_true(GameDB.enemy(id) != null, "%s: 도감 데이터" % id)
		e.queue_free()
		await wait_frames(1)


func test_head_hurtbox_follows_head_bone() -> void:
	var wolf := world.spawn_species(&"ash_wolf", Vector3(0, 0, -6), 0.0)
	await wait_physics_frames(3)
	var head: Hurtbox = wolf.find_children("HeadHurtbox", "Hurtbox", true, false)[0]
	var before := head.global_position
	wolf.rig().rot(&"neck", Vector3(-0.8, 0.0, 0.0))
	await wait_frames(3)
	assert_gt(before.distance_to(head.global_position), 0.05, "목을 숙이면 머리 판정도 따라 내려간다")


func test_species_fight_without_errors() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	world.bake()
	await wait_physics_frames(3)
	for id in SPECIES:
		var e := world.spawn_species(id, Vector3(4, 0, -7), 0.0)
		await wait_physics_frames(2)
		e.alert(p)
		for i in 90:
			await wait_physics_frames(1)
			p.stats.hp = p.stats.max_hp
		assert_true(e.is_alive() or e.state == Enemy.State.DEAD)
		e.queue_free()
		await wait_frames(2)


func test_goblins_hold_role_weapons() -> void:
	var expect := {
		&"goblin_scout": [&"goblin_cleaver"], &"goblin_brute": [&"hand_axe"], &"goblin_gunner": [&"pipe_shotgun", &"scrap_smg"],
		&"goblin_thrower": [&"bone_spear"], &"goblin_chief": [&"chief_greatblade"], &"oneeye_sniper": [&"bolt_rifle", &"sniper_l14"],
	}
	for id: StringName in expect:
		var g: Goblin = world.spawn_species(id, Vector3(0, 0, -5), 0.0)
		await wait_physics_frames(1)
		assert_not_null(g.weapon, "%s: 무기를 든다" % id)
		assert_true((expect[id] as Array).has(g.weapon.base_id), "%s: 역할 무기" % id)
		g.queue_free()
	var shaman: Goblin = world.spawn_species(&"goblin_shaman", Vector3(0, 0, -5), 0.0)
	await wait_physics_frames(1)
	assert_null(shaman.weapon, "주술사는 무기가 없다")


func test_elite_and_rare_goblins_always_drop_rare_weapons() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 30:
		var chief := Goblin.roll_weapon(Goblin.Role.CHIEF, rng)
		assert_ge(chief.rarity, ItemRarity.Tier.RARE, "두목 대도는 희귀 이상")
		var sniper := Goblin.roll_weapon(Goblin.Role.SNIPER, rng)
		assert_ge(sniper.rarity, ItemRarity.Tier.RARE, "저격수 무기는 희귀 이상")
	var p := world.spawn_player(Vector3(0, 0, 0))
	var chief: Goblin = world.spawn_species(&"goblin_chief", Vector3(0, 0, -5), 0.0)
	await wait_physics_frames(2)
	var held := chief.weapon
	var info := DamageInfo.create(99999.0, DamageInfo.Kind.GUN, p)
	chief.receive_hit(info, null)
	await wait_physics_frames(2)
	var found: WeaponPickup = null
	for n in world.root.get_parent().get_children() + world.root.get_children():
		if n is WeaponPickup:
			found = n
	if found == null:
		for n in runner.get_tree().root.find_children("*", "WeaponPickup", true, false):
			found = n
	assert_not_null(found, "두목은 대도를 반드시 떨어뜨린다")
	if found:
		assert_true(found.item == held, "들고 있던 바로 그 무기")


func test_gunner_shot_follows_locked_aim_line() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var g: Goblin = world.spawn_species(&"goblin_gunner", Vector3(0, 0, -12), 0.0)
	await wait_physics_frames(2)
	var shot: EnemyAttackData = null
	for a in g.data.attacks:
		if a.id == &"crude_shot":
			shot = a
	g.alert(p)
	g.target = p
	g._sees_target = true
	# 가만히 서 있으면 맞는다.
	var hp := p.stats.hp
	g._start_attack(shot)
	for i in 120:
		await wait_physics_frames(1)
		if g.state != Enemy.State.ATTACK:
			break
	assert_lt(p.stats.hp, hp, "고정된 조준선 위에 서 있으면 맞는다")
	# 조준이 고정된 뒤 옆으로 비키면 빗나간다.
	p.stats.hp = p.stats.max_hp
	g._cooldowns.clear()
	g._start_attack(shot)
	var moved := false
	for i in 120:
		await wait_physics_frames(1)
		if g._aim_locked and not moved:
			p.global_position += Vector3(2.5, 0, 0)
			moved = true
		if g.state != Enemy.State.ATTACK:
			break
	assert_true(moved, "조준이 고정된다")
	assert_eq(p.stats.hp, p.stats.max_hp, "고정된 선에서 비키면 빗나간다")


func test_shaman_heals_wounded_ally() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var brute: Goblin = world.spawn_species(&"goblin_brute", Vector3(2, 0, -8), 0.0)
	var shaman: Goblin = world.spawn_species(&"goblin_shaman", Vector3(-2, 0, -12), 0.0)
	await wait_physics_frames(2)
	brute.hp = brute.data.max_hp * 0.3
	var chant: EnemyAttackData = null
	for a in shaman.data.attacks:
		if a.id == &"heal_chant":
			chant = a
	shaman.target = p
	assert_true(shaman._attack_allowed(chant), "다친 동료가 있으면 주문을 왼다")
	var before := brute.hp
	shaman._start_attack(chant)
	for i in 180:
		await wait_physics_frames(1)
		if shaman.state != Enemy.State.ATTACK:
			break
	assert_gt(brute.hp, before + brute.data.max_hp * 0.3, "동료를 치유한다")


func test_brute_shield_blocks_front_shots() -> void:
	var brute: Goblin = world.spawn_species(&"goblin_brute", Vector3(0, 0, -6), 0.0)
	await wait_physics_frames(3)
	var shield: Hurtbox = brute.find_children("ShieldHurtbox", "Hurtbox", true, false)[0]
	assert_eq(shield.zone, Hurtbox.Zone.ARMOR, "방패는 장갑 판정")
	assert_gt(shield.armor_max, 0.0)


func test_wolf_alpha_howl_buffs_pack() -> void:
	var p := world.spawn_player(Vector3(0, 0, 0))
	var alpha: WolfAlpha = world.spawn_species(&"wolf_alpha", Vector3(0, 0, -10), 0.0)
	var w1: Wolf = world.spawn_species(&"ash_wolf", Vector3(3, 0, -10), 0.0)
	var w2: Wolf = world.spawn_species(&"ash_wolf", Vector3(-3, 0, -10), 0.0)
	await wait_physics_frames(2)
	var howl: EnemyAttackData = null
	for a in alpha.data.attacks:
		if a.id == &"howl":
			howl = a
	alpha.target = p
	assert_true(alpha._attack_allowed(howl), "무리가 있으면 운다")
	alpha._start_attack(howl)
	for i in 120:
		await wait_physics_frames(1)
		if alpha.state != Enemy.State.ATTACK:
			break
	assert_true(w1.is_buffed() and w2.is_buffed(), "울음을 들은 늑대들이 사나워진다")

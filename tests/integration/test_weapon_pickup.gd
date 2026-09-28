extends TestCase
## 바닥의 무기: 희귀도 표시, 같은 칸 무기를 버려야 줍기, 줍기 전 비교.

const GAME := preload("res://src/main/game.tscn")

var game: Game


func before_each() -> void:
	Settings.load_settings("user://test_pickup.cfg")
	game = GAME.instantiate()
	game.mode = Game.Mode.FIELD
	runner.add_child(game)
	await wait_physics_frames(4)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await wait_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pickup.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()


func _pickups() -> Array[WeaponPickup]:
	var out: Array[WeaponPickup] = []
	for n in tree().current_scene.get_children() if tree().current_scene else runner.get_children():
		if n is WeaponPickup and not n.is_queued_for_deletion():
			out.append(n)
	for n in game.get_children():
		if n is WeaponPickup and not n.is_queued_for_deletion() and not out.has(n):
			out.append(n)
	return out


func _drop_ahead(it: WeaponItem, dist: float = 1.8) -> WeaponPickup:
	var p := game.player
	var at := p.global_position + p.look_basis() * Vector3(0, 0, -dist)
	return WeaponPickup.drop(p, it, at)


func test_pickup_swaps_and_drops_current_weapon() -> void:
	var old_melee := GameState.equipped_item(WeaponItem.Slot.MELEE)
	var cleaver := WeaponItem.create(&"goblin_cleaver", ItemRarity.Tier.RARE, [&"keen", &"serrated"] as Array[StringName])
	var pickup := _drop_ahead(cleaver)
	await wait_physics_frames(2)
	assert_not_null(pickup)
	assert_true(pickup.get_prompt(game.player).contains("내려놓는다"), "주우면 지금 무기를 버린다고 알려 준다")
	assert_true(pickup.get_prompt(game.player).contains(old_melee.display_name()))
	pickup.interact(game.player)
	await wait_physics_frames(3)
	assert_true(GameState.equipped_item(WeaponItem.Slot.MELEE) == cleaver, "주운 무기를 든다")
	assert_true(game.player.weapons.melee_item == cleaver, "무기 관리자가 새 무기를 쓴다")
	assert_false(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "주운 무기는 바닥에서 사라진다")
	var dropped: WeaponPickup = null
	for p in _pickups():
		if p.item == old_melee:
			dropped = p
	assert_not_null(dropped, "들던 무기는 그 자리에 떨어진다")
	assert_lt(dropped.global_position.distance_to(game.player.global_position), 3.0)
	assert_true(GameState.warehouse.is_empty(), "창고로 가지 않는다")


func test_gun_pickup_uses_item_magazine() -> void:
	var smg := WeaponItem.create(&"scrap_smg", ItemRarity.Tier.IMPROVED, [&"extended_mag"] as Array[StringName])
	var pickup := _drop_ahead(smg)
	await wait_physics_frames(2)
	pickup.interact(game.player)
	await wait_physics_frames(3)
	assert_eq(GameState.primary_weapon, &"scrap_smg")
	game.player.weapons.select_slot(WeaponManager.Slot.PRIMARY)
	await wait_physics_frames(2)
	assert_eq(game.player.weapons.current_gun().capacity, smg.mag_capacity(), "확장 탄창이 탄창 크기를 늘린다")
	var rifle_drop: WeaponPickup = null
	for p in _pickups():
		if p.item and p.item.base_id == &"rifle_bfa3":
			rifle_drop = p
	assert_not_null(rifle_drop, "들던 소총이 떨어진다")


func test_player_can_target_pickup_on_ground() -> void:
	var p := game.player
	var pickup := _drop_ahead(WeaponItem.create(&"hand_axe"), 1.6)
	p.pitch = deg_to_rad(-35.0)
	await wait_physics_frames(4)
	assert_true(p.interaction_target == pickup, "내려다보면 바닥의 무기를 가리킨다")
	var hud_text := Hud.compare_text(pickup.item, GameState.equipped_item(WeaponItem.Slot.MELEE))
	assert_true(hud_text.contains("바닥의 무기") and hud_text.contains("지금 든 무기"), "비교 창에 두 무기가 나온다")
	assert_true(game.hud._compare.visible, "비교 창이 뜬다")


func test_rarity_beam_and_label_show_tier() -> void:
	var legend := WeaponItem.roll(&"chief_greatblade", ItemRarity.Tier.LEGENDARY, RandomNumberGenerator.new())
	var pickup := _drop_ahead(legend)
	await wait_physics_frames(2)
	assert_true(pickup._label.text.contains("도살자의 대도"))
	assert_true(pickup._label.text.contains("전설"))
	var common := _drop_ahead(WeaponItem.create(&"hand_axe"), 2.6)
	await wait_physics_frames(2)
	assert_gt(pickup._light.light_energy, common._light.light_energy, "희귀할수록 빛이 강하다")
	assert_ne(pickup._beam_mat.albedo_color.to_rgba32() & 0xFFFFFF00, common._beam_mat.albedo_color.to_rgba32() & 0xFFFFFF00,
		"희귀도마다 빛 색이 다르다")

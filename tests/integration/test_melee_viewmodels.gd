extends TestCase
## 근접 무기 1인칭 모델: 쌍월 단검의 초승달 한 쌍, 카람빗(손가락 고리·굽은 날), 살펴보기와 고리 돌리기.

var world: TestWorld


func before_each() -> void:
	GameState.reset_session()
	Settings.load_settings("user://test_melee_vm.cfg")
	world = TestWorld.create(runner)


func after_each() -> void:
	if world and is_instance_valid(world.root):
		world.root.queue_free()
	await wait_frames(2)
	GameState.reset_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_melee_vm.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)


func _free_view(view: Dictionary) -> void:
	(view.root as Node).free()


func test_twin_moon_is_a_mirrored_pair_of_crescents() -> void:
	var view := ViewmodelFactory.build_melee(GameDB.melee(&"twin_moon"), 0)
	assert_true(view.has("right") and view.has("left"), "두 손")
	var r_knife := (view.right as Node).find_child("MoonKnife", true, false) as Node3D
	var l_knife := (view.left as Node).find_child("MoonKnife", true, false) as Node3D
	assert_not_null(r_knife, "오른손 초승달 칼")
	assert_not_null(l_knife, "왼손 초승달 칼")
	if r_knife and l_knife:
		assert_near(r_knife.scale.x, 1.0, 0.001)
		assert_near(l_knife.scale.x, -1.0, 0.001, "왼손 칼은 거울에 비춘 모양(초승달이 서로 마주 본다)")
		# 초승달 날: 볼록한 쪽이 바깥(+X)으로 부푼다.
		var blade_x := 0.0
		for mi: MeshInstance3D in r_knife.find_children("*", "MeshInstance3D", false, false):
			if mi.mesh is ArrayMesh:
				blade_x = maxf(blade_x, mi.mesh.get_aabb().end.x)
		assert_gt(blade_x, 0.03, "날이 바깥으로 부푼 초승달")
	_free_view(view)


func test_karambit_has_ring_spin_and_its_own_poses() -> void:
	var view := ViewmodelFactory.build_melee(GameDB.melee(&"karambit_hook"), 0)
	for key in ["spin", "rest_pos", "rest_rot", "block_pos", "block_rot"]:
		assert_true(view.has(key), "카람빗 모델 정보: %s" % key)
	var spin: Node3D = view.get("spin")
	assert_not_null(spin)
	if spin:
		assert_near(spin.position.x, ViewmodelFactory.KARAMBIT_RING.x, 0.0001, "고리 가운데를 축으로 돈다")
		assert_not_null(spin.get_node_or_null("Karambit"))
		# 날은 주먹 위로 솟아 안쪽(-X)으로 휜다.
		var top := -INF
		var left := INF
		for mi: MeshInstance3D in spin.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh is ArrayMesh:
				var box: AABB = mi.mesh.get_aabb()
				top = maxf(top, box.end.y)
				left = minf(left, box.position.x)
		assert_gt(top, 0.09, "날이 주먹 위로 솟는다")
		assert_lt(left, -0.06, "날끝이 화면 가운데 쪽으로 휜다")
	_free_view(view)


func test_world_models_build_without_hands() -> void:
	for id: StringName in [&"twin_moon", &"karambit_hook"]:
		var root := ViewmodelFactory.build_world(id, ItemRarity.Tier.RARE)
		assert_gt(root.find_children("*", "MeshInstance3D", true, false).size(), 3, "%s 바닥 모델" % id)
		assert_null(root.find_child("Hand", true, false), "바닥의 무기에는 손이 없다")
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			assert_true(mi.material_override is StandardMaterial3D, "세계 속 무기는 일반 재질")
		root.free()


func _player_with(id: StringName) -> Player:
	var p := world.spawn_player(Vector3.ZERO)
	await wait_physics_frames(3)
	GameState.equip_item(WeaponItem.create(id))
	await wait_physics_frames(2)
	p.weapons.select_slot(WeaponManager.Slot.MELEE)
	return p


func test_inspect_needs_idle_melee_and_stops_on_attack() -> void:
	var p: Player = await _player_with(&"twin_moon")
	await wait_seconds(WeaponManager.MELEE_EQUIP_TIME + 0.1)
	assert_true(p.weapons.try_inspect(), "근접 무기를 들고 가만히 있으면 살펴본다")
	assert_true(p.weapons.is_inspecting())
	p.weapons.press_trigger()
	await wait_physics_frames(3)
	assert_false(p.weapons.is_inspecting(), "공격하면 살펴보기를 멈춘다")
	await wait_seconds(0.8)
	p.weapons.select_slot(WeaponManager.Slot.PRIMARY)
	await wait_seconds(0.8)
	assert_false(p.weapons.try_inspect(), "총을 들고는 살펴보지 않는다(재장전 키는 재장전)")


func test_reload_key_inspects_melee() -> void:
	var p: Player = await _player_with(&"karambit_hook")
	await wait_seconds(WeaponManager.MELEE_EQUIP_TIME + 0.1)
	var ev := InputEventAction.new()
	ev.action = &"reload"
	ev.pressed = true
	p.weapons._unhandled_input(ev)
	assert_true(p.weapons.is_inspecting(), "근접 무기를 들고 재장전 키를 누르면 살펴본다")
	await wait_seconds(WeaponManager.INSPECT_TIME + 0.1)
	assert_false(p.weapons.is_inspecting())


func test_karambit_spins_on_draw_and_settles() -> void:
	var p: Player = await _player_with(&"karambit_hook")
	var view: Dictionary = p.weapons._views.get(&"karambit_hook", {})
	var spin: Node3D = view.get("spin")
	assert_not_null(spin)
	if spin == null:
		return
	var turned := false
	for i in 20:
		await wait_frames(1)
		if absf(spin.rotation.z) > 0.5:
			turned = true
	assert_true(turned, "꺼낼 때 고리를 축으로 돈다")
	await wait_seconds(WeaponManager.MELEE_EQUIP_TIME + 0.1)
	await wait_frames(2)
	assert_near(spin.rotation.z, 0.0, 0.0001, "다 꺼내면 제자리")

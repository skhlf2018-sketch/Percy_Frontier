extends Node
## 화면 확인용 스크린샷 도구. 게임을 띄우고 여러 상황을 자동으로 연출해 PNG로 저장한다.
##   xvfb-run -a godot --path . --resolution 1600x900 res://tools/screenshot_tour.tscn -- --out=/절대/경로
## 테스트가 아니라 사람이 화면 배치·가독성을 눈으로 확인하기 위한 도구다.

const GAME := preload("res://src/main/game.tscn")
const TITLE := preload("res://src/ui/menus/title_screen.tscn")

var out_dir := "user://screenshots"
var game: Game


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir if out_dir.is_absolute_path() else ProjectSettings.globalize_path(out_dir))
	Settings.load_settings("user://screenshot_settings.cfg")
	await _run()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("저장: ", path)


func _aim(p: Player, point: Vector3) -> void:
	var dir := point - p.get_eye_position()
	p.yaw = atan2(-dir.x, -dir.z)
	p.pitch = atan2(dir.y, Vector2(dir.x, dir.z).length())


func _place(p: Player, pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _run() -> void:
	# 1. 타이틀
	var title := TITLE.instantiate()
	add_child(title)
	await _frames(20)
	await _shot("01_title")
	title.queue_free()
	await _frames(2)

	# 2. 게임 시작(보급 기지)
	game = GAME.instantiate()
	game.mode = Game.Mode.TRAINING
	add_child(game)
	await _frames(45)
	game.menus.close_all()
	await _frames(5)
	await _shot("02_camp")
	var p := game.player

	# 3. 사격장: 정조준 후 10m 표적 머리 사격
	_place(p, Vector3(-40, 0, 45))
	var dummy: Enemy = game.arena.get_node("Targets/Dummy10")
	_aim(p, dummy.global_position + Vector3.UP * 1.8)
	p.weapons.simulate_aim(true)
	await _frames(30)
	await _shot("03a_rifle_ads")
	for i in 3:
		_aim(p, dummy.global_position + Vector3.UP * 1.8)
		p.weapons.press_trigger()
		await _frames(1)
		p.weapons.release_trigger()
		await _frames(7)
	await _frames(2)
	await _shot("03_range_headshots")
	p.weapons.simulate_aim(false)

	# 4. 장갑판 사격(장갑 표시)과 피해 수치
	_aim(p, dummy.global_position + Vector3.UP * 1.3)
	await _frames(15)
	for i in 2:
		_aim(p, dummy.global_position + Vector3.UP * 1.3)
		p.weapons.press_trigger()
		await _frames(1)
		p.weapons.release_trigger()
		await _frames(6)
	await _shot("04_range_armor")

	# 5. 저격총 조준경
	GameState.set_primary_weapon(&"sniper_l14")
	await _frames(50)
	var far_dummy: Enemy = game.arena.get_node("Targets/Dummy45")
	_aim(p, far_dummy.global_position + Vector3.UP * 1.8)
	p.weapons.simulate_aim(true)
	await _frames(40)
	await _shot("05_sniper_scope")
	p.weapons.simulate_aim(false)
	GameState.set_primary_weapon(&"rifle_bfa3")
	await _frames(40)

	# 6. 살인토끼 무리: 패링 가능 전조(◇)
	_place(p, Vector3(0, 0, 24))
	p.yaw = 0.0
	p.pitch = -0.1
	game.arena.spawn_test_wave(&"rabbits")
	await _frames(20)
	var rabbit_shot := false
	for i in 400:
		await _frames(1)
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e is KillerRabbit and not e.telegraph_info().is_empty():
				_aim(p, e.global_position + Vector3.UP * 0.5)
				await _frames(2)
				await _shot("06_rabbit_telegraph")
				rabbit_shot = true
				break
		if rabbit_shot:
			break
		p.stats.heal(100.0)
	game.arena.clear_test_spawns()
	await _frames(5)

	# 7. 돌격수: 패링 불가 전조(▲)와 체력바
	_place(p, Vector3(0, 0, 22))
	p.yaw = 0.0
	p.pitch = -0.05
	game.arena.spawn_test_wave(&"charger")
	await _frames(10)
	var charger: Enemy = null
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is RockCharger and e.get_parent() == game.arena.test_active:
			charger = e
	if charger:
		charger.receive_hit(DamageInfo.create(40.0, DamageInfo.Kind.GUN, p), null)
		for i in 400:
			await _frames(1)
			p.stats.heal(100.0)
			if not charger.telegraph_info().is_empty():
				_aim(p, charger.global_position + Vector3.UP * 1.0)
				await _frames(8)
				await _shot("07_charger_telegraph")
				break
	game.arena.clear_test_spawns()
	await _frames(5)

	# 8. 서리 파동 시전
	_place(p, Vector3(0, 0, 24))
	game.arena.spawn_test_wave(&"rabbits")
	await _frames(30)
	p.stats.add_resonance(100.0)
	p.yaw = 0.0
	p.pitch = -0.25
	p.skills.cast_slot(0)
	await _frames(8)
	await _shot("08_frost_pulse")
	game.arena.clear_test_spawns()
	await _frames(5)

	# 9. 근접 무기 대기·방어 자세와 상태이상 표시
	_place(p, Vector3(-4, 0, 37))
	p.weapons.select_slot(WeaponManager.Slot.MELEE)
	await _frames(30)
	var idle_dummy: Enemy = game.arena.get_node("Targets/DummyPlaza")
	_aim(p, idle_dummy.global_position + Vector3.UP * 1.2)
	await _frames(10)
	await _shot("09a_melee_idle")
	p.status.add_buildup(StatusEffects.Type.BURN, 100.0)
	p.status.add_buildup(StatusEffects.Type.BLEED, 60.0)
	p.stats.take_damage(70.0)
	var plaza_dummy: Enemy = game.arena.get_node("Targets/DummyPlaza")
	_aim(p, plaza_dummy.global_position + Vector3.UP * 1.2)
	p.weapons.simulate_aim(true)
	await _frames(20)
	await _shot("09_melee_block_status")
	p.weapons.simulate_aim(false)
	p.status.clear_all()
	p.stats.restore_full()
	p.weapons.select_slot(WeaponManager.Slot.PRIMARY)
	await _frames(30)

	# 10. 포자 능선 원경
	_place(p, Vector3(30, 0, 20))
	_aim(p, Vector3(55, 3.5, 10))
	await _frames(20)
	await _shot("10_ridge_view")

	# 11. 시험 단말기 메뉴
	game._open_test_terminal(p)
	await _frames(10)
	await _shot("11_terminal_menu")
	game.menus.close_all()
	await _frames(3)

	# 12. 일시정지 메뉴와 설정(키 설정 탭)
	game.menus.open_pause()
	await _frames(8)
	await _shot("12_pause_menu")
	game.menus.pause_menu.settings_requested.emit()
	await _frames(6)
	game.menus.settings_menu._tabs.current_tab = 5
	await _frames(6)
	await _shot("13_settings_keys")
	game.menus.settings_menu._tabs.current_tab = 1
	await _frames(6)
	await _shot("14_settings_display")
	game.menus.close_all()
	await _frames(3)

	# 13. 사망 화면
	p.stats.take_damage(999.0)
	await _frames(30)
	await _shot("15_death")
	Settings.load_settings(Settings.DEFAULT_PATH)

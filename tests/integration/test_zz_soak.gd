extends TestCase
## 장시간 실전 테스트: 자동 조작 봇이 실제 게임에서 교전을 반복한다.
## 무기 교체·재장전·스킬·근접·소모품·피격·사망·부활·휴식이 섞여도 엔진 에러가 나지 않는지,
## 프레임당 CPU 시간이 예산 안인지 확인한다. (파일 이름의 zz는 가장 마지막에 실행하려는 것)

const GAME := preload("res://src/main/game.tscn")
const SIM_SECONDS := 75.0

var game: Game


func before_each() -> void:
	Settings.load_settings("user://test_soak.cfg")
	game = GAME.instantiate()
	game.mode = Game.Mode.TRAINING
	runner.add_child(game)
	await wait_physics_frames(6)


func after_each() -> void:
	runner.get_tree().paused = false
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_soak.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)
	GameState.reset_session()


func _nearest_enemy(p: Player) -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e in runner.get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e is Enemy and e.is_alive() and not (e is TrainingDummy):
			var d := p.global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func test_bot_fights_for_a_while() -> void:
	var p := game.player
	GameState.complete_all_analysis()
	p.global_position = Vector3(0, 0, 26)
	p.reset_physics_interpolation()
	var frames := int(SIM_SECONDS * 60.0)
	var deaths := 0
	var kills := [0]
	GameEvents.enemy_killed.connect(func(_e: Node) -> void: kills[0] += 1)
	p.died.connect(func() -> void: deaths += 1)
	var peak_enemies := 0
	# 고정 프레임 모드에서는 성능 모니터 값이 실제 처리 시간과 달라 실제 경과 시간으로 잰다.
	var start_usec := Time.get_ticks_usec()
	for f in frames:
		# 3초마다 교전이 없으면 혼성 무리를 부른다.
		if f % 180 == 0 and game.arena.active_test_count() < 3:
			game.arena.spawn_test_wave(&"mixed")
		if p.alive:
			var target := _nearest_enemy(p)
			if target:
				TestWorld.aim_at(p, target.global_position + Vector3.UP * target.eye_height * 0.8)
				var dist := p.global_position.distance_to(target.global_position)
				if dist < 2.5 and f % 40 == 0:
					p.weapons.try_quick_melee()
				elif f % 5 == 0:
					p.weapons.press_trigger()
			if f % 17 == 0:
				p.weapons.release_trigger()
			if f % 300 == 150:
				p.weapons.cycle(1)
			if f % 240 == 120:
				p.stats.add_resonance(40.0)
				p.skills.cast_slot((f / 240) % 4)
			if f % 400 == 200 and p.stats.hp < 60.0:
				p.use_consumable(0)
			if f % 350 == 30:
				p.try_dodge()
		await runner.get_tree().physics_frame
		peak_enemies = maxi(peak_enemies, runner.get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP).size())
	var ms_per_frame := float(Time.get_ticks_usec() - start_usec) / 1000.0 / float(frames)
	print("    봇 %d초: 처치 %d, 사망 %d, 최대 적 수 %d, 프레임당 CPU %.2fms(렌더링 제외)" % [
		int(SIM_SECONDS), kills[0], deaths, peak_enemies, ms_per_frame])
	assert_gt(kills[0], 3, "봇이 적을 처치한다")
	# 렌더링을 뺀 스크립트·물리 비용이 60fps 예산(16.6ms)의 절반을 넘지 않아야 한다.
	assert_lt(ms_per_frame, 8.0, "CPU 시간 예산")

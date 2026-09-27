extends Node
## 내보낸 빌드 점검. 배포용 엔진으로 모든 스크립트·장면·리소스를 불러오고, 실제 게임을 잠깐 자동으로 돌린다.
##   tools/export.sh 가 Linux 빌드를 만든 뒤 실행한다:
##   build/linux/PercyFrontier.x86_64 --headless --fixed-fps 60 res://tools/export_smoke.tscn
## 편집기·테스트에서는 통과해도 배포용 엔진에서만 실패하는 코드를 잡기 위한 것이다.
## (예: 노드가 자기 자신을 free()로 지우는 코드는 배포용 엔진에서 컴파일 에러가 난다)
## Linux 점검 빌드에만 포함되고 Windows 배포본에는 들어가지 않는다.
## 불러오기 점검 전에 컴파일되지 않도록 게임 클래스를 이름으로 직접 참조하지 않는다.

const SIM_FRAMES := 60 * 25
const LOAD_ROOTS := ["res://src", "res://data", "res://assets"]


class ErrorCatcher extends Logger:
	var _mutex := Mutex.new()
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if rationale != "" else code
		_mutex.lock()
		errors.append("%s (%s:%d %s)" % [text, file, line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catcher := ErrorCatcher.new()
var _failures: Array[String] = []


func _ready() -> void:
	OS.add_logger(_catcher)
	_run.call_deferred()


func _run() -> void:
	var counts := {"scripts": 0, "resources": 0}
	for root_dir in LOAD_ROOTS:
		_load_all(root_dir, counts)
	print("불러오기: 스크립트 %d개, 리소스 %d개" % [counts.scripts, counts.resources])

	var title: Node = (load("res://src/ui/menus/title_screen.tscn") as PackedScene).instantiate()
	add_child(title)
	await _frames(10)
	title.queue_free()
	await _frames(2)

	var stats := await _play_game()
	print("자동 플레이 %d초: 처치 %d, 사망 %d" % [SIM_FRAMES / 60, stats.kills, stats.deaths])
	if stats.kills == 0:
		_failures.append("자동 플레이에서 적을 한 마리도 처치하지 못했습니다")

	for e in _catcher.errors:
		_failures.append("엔진·스크립트 에러: " + e)
	if _failures.is_empty():
		print("내보낸 빌드 점검 통과")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("실패: ", f)
		get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _load_all(dir: String, counts: Dictionary) -> void:
	for entry in ResourceLoader.list_directory(dir):
		var path := dir.path_join(entry)
		if entry.ends_with("/"):
			_load_all(path.trim_suffix("/"), counts)
			continue
		var ext := entry.get_extension()
		if ext == "gd":
			var script := load(path) as GDScript
			if script == null or not script.can_instantiate() and not script.is_abstract():
				_failures.append("스크립트를 불러오지 못함: " + path)
			counts.scripts += 1
		elif ext in ["tscn", "tres", "gdshader", "woff2", "svg"]:
			if load(path) == null:
				_failures.append("리소스를 불러오지 못함: " + path)
			counts.resources += 1


## 실제 게임 장면을 띄우고 무기·스킬·근접·소모품·회피·메뉴를 섞어 쓰는 간단한 자동 조작.
func _play_game() -> Dictionary:
	var game: Node = (load("res://src/main/game.tscn") as PackedScene).instantiate()
	game.mode = 1  # 훈련장(자동 교전에 시험 단말기의 무리 부르기를 쓴다)
	add_child(game)
	await _frames(6)
	var p: Node3D = game.player
	var game_state: Node = get_node("/root/GameState")
	var events: Node = get_node("/root/GameEvents")
	game_state.complete_all_analysis()
	var stats := {"kills": 0, "deaths": 0}
	events.enemy_killed.connect(func(_e: Node) -> void: stats.kills += 1)
	p.died.connect(func() -> void: stats.deaths += 1)
	p.global_position = Vector3(0, 0, 26)
	p.reset_physics_interpolation()
	var waves: Array[StringName] = [&"rabbits", &"charger", &"spitters", &"mixed"]
	for f in SIM_FRAMES:
		if f % 240 == 0 and game.arena.active_test_count() < 3:
			game.arena.spawn_test_wave(waves[(f / 240) % waves.size()])
		if p.alive:
			var target := _nearest_enemy(p)
			if target:
				var aim_point: Vector3 = target.global_position + Vector3.UP * float(target.eye_height) * 0.8
				var dir: Vector3 = aim_point - (p.get_eye_position() as Vector3)
				p.yaw = atan2(-dir.x, -dir.z)
				p.pitch = atan2(dir.y, Vector2(dir.x, dir.z).length())
				if p.global_position.distance_to(target.global_position) < 2.5 and f % 40 == 0:
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
			if f % 400 == 200:
				p.use_consumable(0)
			if f % 350 == 30:
				p.try_dodge()
		if f == SIM_FRAMES / 2:
			game.menus.open_pause()
			game.menus.pause_menu.settings_requested.emit()
			await _frames(3)
			game.menus.close_all()
			game._open_test_terminal(p)
			await _frames(3)
			game.menus.close_all()
		await get_tree().physics_frame
	game.queue_free()
	await _frames(2)
	return stats


func _nearest_enemy(p: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		if e.has_method("is_alive") and e.is_alive() and e.get_script().get_global_name() != &"TrainingDummy":
			var d := p.global_position.distance_to((e as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

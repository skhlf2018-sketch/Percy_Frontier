extends Node
## 헤드리스 테스트 실행기.
##   godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
## 특정 테스트만 실행: 뒤에 `-- --filter=이름일부` 를 붙인다.
## 테스트 중 발생한 엔진·스크립트 에러는 해당 테스트의 실패로 기록한다.

const TEST_DIRS := ["res://tests/unit", "res://tests/integration"]


class ErrorCatcher extends Logger:
	var _mutex := Mutex.new()
	var _errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if rationale != "" else code
		_mutex.lock()
		_errors.append("%s (%s:%d %s)" % [text, file, line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_mutex.lock()
		var copy := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return copy


var _catcher := ErrorCatcher.new()


func _ready() -> void:
	# 테스트가 실제 저장 파일을 건드리지 않게 따로 둔다.
	SaveSystem.directory = "user://test_saves_runner"
	OS.add_logger(_catcher)
	await get_tree().process_frame
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr(9)
	var passed := 0
	var failed_names: Array[String] = []
	for dir in TEST_DIRS:
		for file in _list_tests(dir):
			var path: String = dir + "/" + file
			var script: GDScript = load(path)
			if script == null:
				failed_names.append(path)
				print("FAIL  %s (불러오기 실패)" % path)
				continue
			for method in script.get_script_method_list():
				var name: String = method.name
				if not name.begins_with("test_"):
					continue
				var full := "%s::%s" % [file.get_basename(), name]
				if filter != "" and not _matches(full, filter):
					continue
				var ok := await _run_one(script, name, full)
				if ok:
					passed += 1
				else:
					failed_names.append(full)
	print("")
	print("통과 %d, 실패 %d" % [passed, failed_names.size()])
	for n in failed_names:
		print("  실패: %s" % n)
	OS.remove_logger(_catcher)
	get_tree().quit(1 if failed_names.size() > 0 else 0)


## 쉼표로 여러 이름 일부를 줄 수 있다(예: test_scripts,test_arena).
static func _matches(full: String, filter: String) -> bool:
	for part in filter.split(",", false):
		if full.contains(part.strip_edges()):
			return true
	return false


func _run_one(script: GDScript, method: String, full_name: String) -> bool:
	var inst: TestCase = script.new()
	inst.runner = self
	# 앞 테스트의 슬로 모션·타격 정지가 남지 않게 한다.
	TimeFx.reset()
	_catcher.take()
	await inst.before_each()
	await inst.call(method)
	await inst.after_each()
	# 테스트가 남긴 노드를 정리하고 한 프레임 넘겨 해제를 끝낸다.
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	var errors := _catcher.take()
	var failures := inst._failures
	if errors.size() > inst.expected_errors:
		for e in errors:
			failures.append("엔진 에러: " + e)
	elif errors.size() < inst.expected_errors:
		failures.append("에러 %d개를 기대했지만 %d개 발생" % [inst.expected_errors, errors.size()])
	if failures.is_empty():
		print("PASS  %s" % full_name)
		return true
	print("FAIL  %s" % full_name)
	for f in failures:
		print("        %s" % f)
	return false


func _list_tests(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out

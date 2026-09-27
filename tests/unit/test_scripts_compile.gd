extends TestCase
## src 아래 모든 스크립트와 씬이 에러 없이 불러와지는지 확인한다(파싱·컴파일 에러 조기 발견).


func test_all_scripts_compile() -> void:
	var paths := _collect("res://src", ".gd")
	assert_gt(paths.size(), 30)
	for path in paths:
		var s: Script = load(path)
		assert_not_null(s, path)
		if s:
			assert_true(s.can_instantiate(), path)


func test_all_scenes_load() -> void:
	for path in _collect("res://src", ".tscn"):
		var scene: PackedScene = load(path)
		assert_not_null(scene, path)
		if scene:
			assert_true(scene.can_instantiate(), path)


func _collect(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_collect(dir.path_join(d), ext))
	return out

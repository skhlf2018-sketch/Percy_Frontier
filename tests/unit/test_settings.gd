extends TestCase

const TEST_PATH := "user://test_settings.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_settings(TEST_PATH)


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_settings(Settings.DEFAULT_PATH)


func test_defaults_are_loaded() -> void:
	assert_near(Settings.get_value(&"fov"), 90.0)
	assert_eq(Settings.get_value(&"aim_toggle"), false)
	assert_eq(Settings.binding_text(&"reload"), "R")


func test_values_persist() -> void:
	Settings.set_value(&"fov", 100.0)
	Settings.set_value(&"crouch_toggle", true)
	Settings.set_value(&"difficulty", 2)
	Settings.load_settings(TEST_PATH)
	assert_near(Settings.get_value(&"fov"), 100.0)
	assert_eq(Settings.get_value(&"crouch_toggle"), true)
	assert_eq(Settings.get_value(&"difficulty"), 2)


func test_values_are_coerced_to_default_type() -> void:
	Settings.set_value(&"fov", 95)
	assert_eq(typeof(Settings.get_value(&"fov")), TYPE_FLOAT)


func test_unknown_key_is_rejected() -> void:
	expect_error()
	Settings.set_value(&"no_such_option", 1)
	assert_null(Settings.values.get(&"no_such_option"))


func test_rebind_and_persist() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_T
	var conflict := Settings.rebind(&"reload", ev)
	assert_eq(conflict, &"")
	assert_eq(Settings.binding_text(&"reload"), "T")
	Settings.load_settings(TEST_PATH)
	assert_eq(Settings.binding_text(&"reload"), "T", "재시작 후에도 유지")


func test_rebind_swaps_conflicting_action() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	var conflict := Settings.rebind(&"reload", ev)
	assert_eq(conflict, &"interact")
	assert_eq(Settings.binding_text(&"reload"), "E")
	assert_eq(Settings.binding_text(&"interact"), "R", "기존 입력과 서로 바뀐다")


func test_rebind_mouse_button() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_XBUTTON1
	Settings.rebind(&"melee_quick", ev)
	assert_eq(Settings.binding_text(&"melee_quick"), "마우스 4")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_XBUTTON1
	press.pressed = true
	assert_true(press.is_action_pressed(&"melee_quick"))


func test_restore_default_bindings() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_T
	Settings.rebind(&"reload", ev)
	Settings.restore_default_bindings()
	assert_eq(Settings.binding_text(&"reload"), "R")


func test_event_dict_roundtrip() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	var back := Settings.dict_to_event(Settings.event_to_dict(key))
	assert_true(Settings.same_input(key, back))
	assert_null(Settings.dict_to_event({"type": "key", "code": 0}))
	assert_null(Settings.dict_to_event("garbage"))


func test_every_rebindable_action_exists() -> void:
	for entry in Settings.REBINDABLE:
		assert_true(InputMap.has_action(entry[0]), String(entry[0]))
		assert_false(InputMap.action_get_events(entry[0]).is_empty(), "기본 입력: %s" % entry[0])


func test_vertical_fov_conversion() -> void:
	assert_near(Settings.vertical_fov_from_horizontal(90.0), 58.7155, 0.01)


func test_look_sensitivity_uses_ads_multiplier() -> void:
	Settings.set_value(&"ads_sensitivity", 0.5)
	assert_near(Settings.look_rad_per_pixel(true), Settings.look_rad_per_pixel(false) * 0.5)


func test_difficulty_never_removes_telegraphs() -> void:
	for p in Settings.DIFFICULTY_PARAMS:
		assert_gt(p.telegraph_mult, 0.8, "도전 난이도에서도 전조는 남는다")

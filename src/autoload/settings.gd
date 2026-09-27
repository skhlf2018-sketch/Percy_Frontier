extends Node
## 옵션과 키 설정(기획서 §7, §21, §24). user://settings.cfg에 저장한다.
## 여기 있는 모든 항목은 실제로 게임에 반영된다. 동작하지 않는 옵션은 두지 않는다(기획서 §0).

signal changed(key: StringName)
signal bindings_changed

const DEFAULT_PATH := "user://settings.cfg"

## 재설정할 수 있는 입력(표시 순서). 전투 시험 단계에서 실제로 동작하는 기능만 둔다.
const REBINDABLE := [
	[&"move_forward", "앞으로 이동"],
	[&"move_back", "뒤로 이동"],
	[&"move_left", "왼쪽 이동"],
	[&"move_right", "오른쪽 이동"],
	[&"sprint", "달리기"],
	[&"jump", "점프·넘기"],
	[&"crouch", "앉기"],
	[&"dodge", "회피"],
	[&"fire", "발사·근접 공격"],
	[&"aim", "조준·방어"],
	[&"reload", "재장전"],
	[&"melee_quick", "빠른 근접 공격"],
	[&"interact", "상호작용"],
	[&"weapon_next", "다음 무기"],
	[&"weapon_prev", "이전 무기"],
	[&"weapon_1", "주무기"],
	[&"weapon_2", "보조 총기"],
	[&"weapon_3", "근접 무기"],
	[&"skill_quick", "마지막 스킬 다시 사용"],
	[&"skill_1", "스킬 슬롯 1"],
	[&"skill_2", "스킬 슬롯 2"],
	[&"skill_3", "스킬 슬롯 3"],
	[&"skill_4", "스킬 슬롯 4"],
	[&"consumable_1", "소모품 1"],
	[&"consumable_2", "소모품 2"],
]

enum Difficulty { STORY, STANDARD, CHALLENGE }
const DIFFICULTY_NAMES := ["이야기", "표준", "도전"]
## 난이도는 적 HP 대신 받는 피해, 전조 시간, 동시 공격 수, 공격 빈도, 보급량을 조정한다(기획서 §21.1).
## 도전 난이도에서도 공격 전조를 없애지 않는다.
const DIFFICULTY_PARAMS := [
	{"damage_taken": 0.6, "telegraph_mult": 1.3, "max_attackers": 1, "attack_cooldown_mult": 1.35, "supply_mult": 1.5},
	{"damage_taken": 1.0, "telegraph_mult": 1.0, "max_attackers": 2, "attack_cooldown_mult": 1.0, "supply_mult": 1.0},
	{"damage_taken": 1.3, "telegraph_mult": 0.9, "max_attackers": 3, "attack_cooldown_mult": 0.75, "supply_mult": 0.75},
]

const WINDOW_MODE_NAMES := ["창 모드", "전체 화면", "독점 전체 화면"]
const MAX_FPS_OPTIONS := [0, 60, 120, 144, 240]

const DEFAULTS := {
	# 조작
	&"mouse_sensitivity": 1.0,
	&"ads_sensitivity": 0.75,
	&"invert_y": false,
	&"aim_toggle": false,
	&"crouch_toggle": false,
	&"sprint_toggle": false,
	# 화면
	&"fov": 90.0,
	&"camera_shake": 1.0,
	&"muzzle_flash": 1.0,
	&"head_bob": true,
	&"damage_numbers": true,
	&"telegraph_boost": false,
	# 게임플레이
	&"difficulty": Difficulty.STANDARD,
	# 소리
	&"master_volume": 0.8,
	&"sfx_volume": 1.0,
	&"ui_volume": 0.8,
	# 그래픽
	&"window_mode": 0,
	&"vsync": true,
	&"max_fps": 0,
	&"render_scale": 1.0,
}

## 마우스 1픽셀당 회전(라디안), 감도 1.0 기준
const BASE_LOOK_RAD_PER_PIXEL := 0.0022

var values: Dictionary = {}
var config_path: String = DEFAULT_PATH
var _default_bindings: Dictionary = {}


func _ready() -> void:
	_capture_default_bindings()
	load_settings()


func _capture_default_bindings() -> void:
	for entry in REBINDABLE:
		var action: StringName = entry[0]
		var events: Array[InputEvent] = []
		for ev in InputMap.action_get_events(action):
			events.append(ev.duplicate())
		_default_bindings[action] = events


func get_value(key: StringName) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: StringName, value: Variant, persist: bool = true) -> void:
	if not DEFAULTS.has(key):
		push_error("알 수 없는 설정 키: %s" % key)
		return
	values[key] = _coerce(key, value)
	_apply(key)
	changed.emit(key)
	if persist:
		save_settings()


func _coerce(key: StringName, value: Variant) -> Variant:
	match typeof(DEFAULTS[key]):
		TYPE_FLOAT:
			return float(value)
		TYPE_INT:
			return int(value)
		TYPE_BOOL:
			return bool(value)
	return value


# --- 저장·불러오기 ---

func load_settings(path: String = "") -> void:
	if path != "":
		config_path = path
	values = DEFAULTS.duplicate()
	_restore_bindings_silently()
	var cfg := ConfigFile.new()
	if cfg.load(config_path) == OK:
		if cfg.has_section("options"):
			for key_string in cfg.get_section_keys("options"):
				var key := StringName(key_string)
				if DEFAULTS.has(key):
					values[key] = _coerce(key, cfg.get_value("options", key_string))
		if cfg.has_section("bindings"):
			for action_string in cfg.get_section_keys("bindings"):
				var action := StringName(action_string)
				if not _default_bindings.has(action):
					continue
				var events: Array[InputEvent] = []
				for d in cfg.get_value("bindings", action_string, []):
					var ev := dict_to_event(d)
					if ev:
						events.append(ev)
				if not events.is_empty():
					_set_action_events(action, events)
	apply_all()
	bindings_changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("options", String(key), values[key])
	for action in _default_bindings:
		var list: Array = []
		for ev in InputMap.action_get_events(action):
			var d := event_to_dict(ev)
			if not d.is_empty():
				list.append(d)
		cfg.set_value("bindings", String(action), list)
	var err := cfg.save(config_path)
	if err != OK:
		push_warning("설정을 저장하지 못했습니다: %s (%d)" % [config_path, err])


func reset_options_to_default() -> void:
	values = DEFAULTS.duplicate()
	apply_all()
	for key in DEFAULTS:
		changed.emit(key)
	save_settings()


# --- 적용 ---

func apply_all() -> void:
	for key in DEFAULTS:
		_apply(key)


func _apply(key: StringName) -> void:
	match key:
		&"master_volume", &"sfx_volume", &"ui_volume":
			_apply_audio()
		&"window_mode":
			_apply_window_mode()
		&"vsync":
			_apply_vsync()
		&"max_fps":
			Engine.max_fps = int(get_value(&"max_fps"))
		&"render_scale":
			_apply_render_scale()


func _apply_audio() -> void:
	_set_bus_volume("Master", float(get_value(&"master_volume")))
	_set_bus_volume("SFX", float(get_value(&"sfx_volume")))
	_set_bus_volume("UI", float(get_value(&"ui_volume")))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _apply_window_mode() -> void:
	if _is_headless():
		return
	match int(get_value(&"window_mode")):
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_vsync() -> void:
	if _is_headless():
		return
	var mode := DisplayServer.VSYNC_ENABLED if get_value(&"vsync") else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func _apply_render_scale() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var s := clampf(float(get_value(&"render_scale")), 0.5, 1.0)
	vp.scaling_3d_scale = s
	var supports_fsr := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if s < 0.999 and supports_fsr:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


# --- 게임 코드에서 쓰는 도우미 ---

## 마우스 1픽셀당 회전량(라디안). 정조준 중이면 ADS 감도를 곱한다.
func look_rad_per_pixel(aiming: bool) -> float:
	var s := BASE_LOOK_RAD_PER_PIXEL * float(get_value(&"mouse_sensitivity"))
	if aiming:
		s *= float(get_value(&"ads_sensitivity"))
	return s


## 설정의 FOV는 16:9 기준 수평 시야각이다. Camera3D(세로 기준)에 넣을 세로 시야각을 돌려준다.
static func vertical_fov_from_horizontal(horizontal_deg: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_deg) * 0.5) * 9.0 / 16.0))


func difficulty_params() -> Dictionary:
	var idx := clampi(int(get_value(&"difficulty")), 0, DIFFICULTY_PARAMS.size() - 1)
	return DIFFICULTY_PARAMS[idx]


# --- 키 설정 ---

## 동작에 새 입력을 지정한다. 같은 입력을 쓰던 동작이 있으면 기존 입력과 서로 바꾸고 그 동작을 돌려준다.
func rebind(action: StringName, event: InputEvent) -> StringName:
	if not _default_bindings.has(action):
		return &""
	var normalized := normalize_event(event)
	if normalized == null:
		return &""
	var conflict := find_action_for_event(normalized, action)
	var previous := InputMap.action_get_events(action)
	_set_action_events(action, [normalized])
	if conflict != &"":
		_set_action_events(conflict, previous)
	save_settings()
	bindings_changed.emit()
	return conflict


func find_action_for_event(event: InputEvent, exclude: StringName = &"") -> StringName:
	for entry in REBINDABLE:
		var action: StringName = entry[0]
		if action == exclude:
			continue
		for ev in InputMap.action_get_events(action):
			if same_input(ev, event):
				return action
	return &""


func restore_default_bindings() -> void:
	_restore_bindings_silently()
	save_settings()
	bindings_changed.emit()


func _restore_bindings_silently() -> void:
	for action in _default_bindings:
		var events: Array[InputEvent] = []
		for ev in _default_bindings[action]:
			events.append(ev.duplicate())
		_set_action_events(action, events)


func _set_action_events(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for ev in events:
		InputMap.action_add_event(action, ev)


func binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "지정 안 됨"
	return event_text(events[0])


func action_label(action: StringName) -> String:
	for entry in REBINDABLE:
		if entry[0] == action:
			return entry[1]
	return String(action)


static func normalize_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var k := InputEventKey.new()
		k.device = -1
		k.physical_keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return k
	if event is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.device = -1
		m.button_index = event.button_index
		return m
	return null


static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ca: int = a.physical_keycode if a.physical_keycode != KEY_NONE else a.keycode
		var cb: int = b.physical_keycode if b.physical_keycode != KEY_NONE else b.keycode
		return ca == cb
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


static func event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		return {"type": "key", "code": code}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "button": ev.button_index}
	return {}


static func dict_to_event(d: Variant) -> InputEvent:
	if typeof(d) != TYPE_DICTIONARY:
		return null
	match d.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.device = -1
			k.physical_keycode = int(d.get("code", 0))
			return k if k.physical_keycode != KEY_NONE else null
		"mouse":
			var m := InputEventMouseButton.new()
			m.device = -1
			m.button_index = int(d.get("button", 0))
			return m if m.button_index != MOUSE_BUTTON_NONE else null
	return null


static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		match code:
			KEY_ESCAPE:
				return "Esc"
			KEY_SPACE:
				return "Space"
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				return "마우스 왼쪽"
			MOUSE_BUTTON_RIGHT:
				return "마우스 오른쪽"
			MOUSE_BUTTON_MIDDLE:
				return "마우스 가운데"
			MOUSE_BUTTON_WHEEL_UP:
				return "휠 위"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "휠 아래"
			MOUSE_BUTTON_XBUTTON1:
				return "마우스 4"
			MOUSE_BUTTON_XBUTTON2:
				return "마우스 5"
		return "마우스 %d" % ev.button_index
	return "?"

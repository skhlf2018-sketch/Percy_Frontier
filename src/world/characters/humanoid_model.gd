class_name HumanoidModel
extends Node3D
## 절차적 저다각형 인물 모델(캐릭터 생성 미리보기, 퍼시 주민). 정식 모델이 들어오기 전의 임시 모델이다.
## 외형은 사전(appearance)으로 정한다. 숨쉬기·팔 흔들기·고개 돌리기·말하기 몸짓을 코드로 움직인다.

const SKIN_TONES: Array[Color] = [
	Color(0.96, 0.8, 0.68), Color(0.9, 0.7, 0.55), Color(0.76, 0.55, 0.4), Color(0.55, 0.38, 0.27), Color(0.99, 0.88, 0.8),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.1, 0.09, 0.08), Color(0.33, 0.21, 0.12), Color(0.72, 0.56, 0.3), Color(0.86, 0.86, 0.9),
	Color(0.58, 0.16, 0.12), Color(0.22, 0.32, 0.58),
]
const OUTFIT_COLORS: Array[Color] = [
	Color(0.3, 0.38, 0.3), Color(0.24, 0.3, 0.42), Color(0.48, 0.34, 0.22), Color(0.55, 0.2, 0.18),
	Color(0.34, 0.34, 0.36), Color(0.72, 0.68, 0.58), Color(0.2, 0.44, 0.46), Color(0.42, 0.28, 0.46),
]
const ACCENT_COLORS: Array[Color] = [
	Color(0.92, 0.55, 0.2), Color(0.3, 0.8, 0.85), Color(0.85, 0.82, 0.3), Color(0.9, 0.3, 0.35), Color(0.9, 0.9, 0.92),
]
const HAIR_STYLES: Array[String] = ["짧은 머리", "묶은 머리", "긴 머리", "짧게 민 머리", "탐사 모자"]
const GEAR_NAMES: Array[String] = ["없음", "탐사 고글", "두건", "반가면"]
const BUILD_NAMES: Array[String] = ["표준", "호리호리", "다부진"]

## 선택지 이름과 개수(캐릭터 생성 화면에서 쓴다)
const OPTIONS := [
	["build", "체형", 3],
	["skin", "피부색", 5],
	["hair_style", "머리 모양", 5],
	["hair_color", "머리 색", 6],
	["outfit", "옷 색", 8],
	["accent", "포인트 색", 5],
	["gear", "장비", 4],
]

var appearance: Dictionary = {}
var look_target: Node3D
var talking: bool = false

var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _time: float = 0.0
var _phase: float = 0.0


static func default_appearance() -> Dictionary:
	return {"build": 0, "skin": 1, "hair_style": 0, "hair_color": 1, "outfit": 0, "accent": 0, "gear": 1}


static func random_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var a := {}
	for opt in OPTIONS:
		a[opt[0]] = rng.randi() % int(opt[2])
	return a


static func option_label(key: String, index: int) -> String:
	match key:
		"build":
			return BUILD_NAMES[index]
		"hair_style":
			return HAIR_STYLES[index]
		"gear":
			return GEAR_NAMES[index]
	return "%d" % (index + 1)


func _init(look: Dictionary = {}) -> void:
	appearance = default_appearance()
	appearance.merge(look, true)
	_phase = randf() * TAU


func _ready() -> void:
	rebuild()


func set_appearance(look: Dictionary) -> void:
	appearance.merge(look, true)
	rebuild()


func _get_idx(key: String, count: int) -> int:
	return clampi(int(appearance.get(key, 0)), 0, count - 1)


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var skin := SKIN_TONES[_get_idx("skin", SKIN_TONES.size())]
	var hair := HAIR_COLORS[_get_idx("hair_color", HAIR_COLORS.size())]
	var outfit := OUTFIT_COLORS[_get_idx("outfit", OUTFIT_COLORS.size())]
	var accent := ACCENT_COLORS[_get_idx("accent", ACCENT_COLORS.size())]
	var build := _get_idx("build", 3)
	var width: float = [1.0, 0.88, 1.16][build]
	var pants := outfit.darkened(0.45)
	var boots := Color(0.2, 0.16, 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	# 다리
	var legs := MeshKit.Builder.new()
	for side in [-1.0, 1.0]:
		var hip := Vector3(side * 0.11 * width, 0.92, 0.0)
		var knee := Vector3(side * 0.115 * width, 0.5, 0.02)
		var ankle := Vector3(side * 0.115 * width, 0.1, 0.0)
		legs.frustum(knee, hip, 0.075 * width, 0.095 * width, 7, pants)
		legs.frustum(ankle, knee, 0.06 * width, 0.075 * width, 7, pants)
		legs.box(Vector3(side * 0.115 * width, 0.06, 0.04), Vector3(0.12 * width, 0.12, 0.26), boots)
	_add_part(legs, Vector3.ZERO)

	# 몸통(외투), 허리띠, 가방끈
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.92, 0)
	add_child(_torso)
	var torso := MeshKit.Builder.new()
	torso.frustum(Vector3(0, 0.0, 0), Vector3(0, 0.56, 0), 0.19 * width, 0.23 * width, 8, outfit)
	torso.frustum(Vector3(0, 0.56, 0), Vector3(0, 0.64, 0), 0.23 * width, 0.1, 8, outfit.darkened(0.1))
	torso.frustum(Vector3(0, -0.05, 0), Vector3(0, 0.06, 0), 0.2 * width, 0.2 * width, 8, Color(0.25, 0.18, 0.12))
	torso.box(Vector3(0.0, 0.0, 0.2 * width), Vector3(0.1, 0.07, 0.04), accent)
	torso.box(Vector3(0.0, 0.32, 0.0), Vector3(0.05, 0.62, 0.43 * width), Color(0.3, 0.22, 0.15), Basis(Vector3.FORWARD, 0.6))
	# 공명 장치(가슴의 작은 빛나는 판)
	torso.box(Vector3(-0.1 * width, 0.42, 0.21 * width), Vector3(0.1, 0.07, 0.03), accent.lightened(0.3))
	_add_part(torso, Vector3.ZERO, _torso)

	# 팔
	_arm_l = _make_arm(-1.0, width, outfit, skin, accent)
	_arm_r = _make_arm(1.0, width, outfit, skin, accent)

	# 머리
	_head = Node3D.new()
	_head.position = Vector3(0, 0.62, 0)
	_torso.add_child(_head)
	var head := MeshKit.Builder.new()
	head.frustum(Vector3(0, 0.0, 0), Vector3(0, 0.08, 0), 0.055, 0.05, 6, skin)
	head.blob(Vector3(0, 0.2, 0.01), 0.12, Color(skin, 0.0), 0.0, rng, 0.04, Vector3(0.92, 1.08, 0.98), -2.0, 0.03, 0.12)
	# 눈
	for side in [-1.0, 1.0]:
		head.box(Vector3(side * 0.045, 0.22, 0.11), Vector3(0.028, 0.02, 0.01), Color(0.08, 0.08, 0.1))
	_hair(head, _get_idx("hair_style", HAIR_STYLES.size()), hair, rng)
	_gear(head, _get_idx("gear", GEAR_NAMES.size()), accent, outfit, rng)
	_add_part(head, Vector3.ZERO, _head)


func _make_arm(side: float, width: float, outfit: Color, skin: Color, accent: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.26 * width, 0.56, 0)
	_torso.add_child(pivot)
	var arm := MeshKit.Builder.new()
	arm.frustum(Vector3(side * 0.02, -0.3, 0.0), Vector3(0, 0.0, 0), 0.055 * width, 0.07 * width, 6, outfit)
	arm.frustum(Vector3(side * 0.03, -0.56, 0.04), Vector3(side * 0.02, -0.3, 0.0), 0.045 * width, 0.055 * width, 6, outfit.darkened(0.08))
	arm.box(Vector3(side * 0.03, -0.53, 0.04), Vector3(0.1 * width, 0.05, 0.1 * width), accent.darkened(0.2))
	arm.blob(Vector3(side * 0.035, -0.62, 0.05), 0.05, Color(Color(0.22, 0.18, 0.14), 0.0), 0.0, RandomNumberGenerator.new(), 0.1)
	_add_part(arm, Vector3.ZERO, pivot)
	return pivot


func _hair(b: MeshKit.Builder, style: int, col: Color, rng: RandomNumberGenerator) -> void:
	match style:
		0:
			b.blob(Vector3(0, 0.27, -0.01), 0.125, Color(col, 0.0), 0.0, rng, 0.12, Vector3(1.0, 0.65, 1.02), -0.1)
		1:
			b.blob(Vector3(0, 0.27, -0.01), 0.125, Color(col, 0.0), 0.0, rng, 0.1, Vector3(1.0, 0.62, 1.02), -0.1)
			b.blob(Vector3(0, 0.22, -0.14), 0.055, Color(col, 0.0), 0.0, rng, 0.1)
			b.frustum(Vector3(0, 0.05, -0.17), Vector3(0, 0.2, -0.15), 0.025, 0.04, 5, col)
		2:
			b.blob(Vector3(0, 0.26, -0.02), 0.13, Color(col, 0.0), 0.0, rng, 0.1, Vector3(1.02, 0.7, 1.02), -0.2)
			b.box(Vector3(0, 0.12, -0.08), Vector3(0.24, 0.26, 0.1), col)
		3:
			b.blob(Vector3(0, 0.26, -0.01), 0.123, Color(col.darkened(0.3), 0.0), 0.0, rng, 0.02, Vector3(0.98, 0.6, 1.0), 0.0)
		4:
			b.frustum(Vector3(0, 0.29, 0), Vector3(0, 0.4, 0), 0.13, 0.11, 8, Color(0.42, 0.33, 0.22))
			b.frustum(Vector3(0, 0.285, 0), Vector3(0, 0.3, 0), 0.22, 0.22, 10, Color(0.36, 0.28, 0.19))


func _gear(b: MeshKit.Builder, gear: int, accent: Color, outfit: Color, rng: RandomNumberGenerator) -> void:
	match gear:
		1:
			# 탐사 고글: 이마에 걸친 두 개의 렌즈
			b.frustum(Vector3(-0.05, 0.3, 0.1), Vector3(-0.05, 0.3, 0.14), 0.035, 0.035, 8, Color(0.2, 0.2, 0.22))
			b.frustum(Vector3(0.05, 0.3, 0.1), Vector3(0.05, 0.3, 0.14), 0.035, 0.035, 8, Color(0.2, 0.2, 0.22))
			b.disc(Vector3(-0.05, 0.3, 0.141), 0.028, 8, Color(accent.lightened(0.2), 0.0), Vector3.BACK)
			b.disc(Vector3(0.05, 0.3, 0.141), 0.028, 8, Color(accent.lightened(0.2), 0.0), Vector3.BACK)
			b.frustum(Vector3(0, 0.29, -0.01), Vector3(0, 0.31, -0.01), 0.128, 0.128, 10, Color(0.18, 0.16, 0.14), 0.0, 0.0, false)
		2:
			b.blob(Vector3(0, 0.27, -0.01), 0.135, Color(outfit.lightened(0.15), 0.0), 0.0, rng, 0.08, Vector3(1.0, 0.72, 1.04), -0.15)
			b.frustum(Vector3(0, 0.1, -0.12), Vector3(0, 0.22, -0.13), 0.06, 0.03, 5, outfit.lightened(0.1))
		3:
			# 반가면: 코와 입을 가리는 판
			b.box(Vector3(0, 0.15, 0.1), Vector3(0.2, 0.1, 0.06), Color(0.85, 0.83, 0.78))
			b.box(Vector3(0, 0.15, 0.13), Vector3(0.06, 0.05, 0.02), accent)


func _add_part(b: MeshKit.Builder, offset: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = MeshKit.solid_material()
	mi.position = offset
	(parent if parent else self).add_child(mi)
	return mi


func _process(delta: float) -> void:
	if _torso == null:
		return
	_time += delta
	var t := _time + _phase
	# 숨쉬기와 팔 흔들림
	_torso.scale = Vector3(1.0, 1.0 + sin(t * 1.8) * 0.008, 1.0)
	var swing := sin(t * 1.1) * 0.04
	_arm_l.rotation = Vector3(swing, 0.0, -0.08)
	_arm_r.rotation = Vector3(-swing, 0.0, 0.08)
	if talking:
		_arm_r.rotation = Vector3(-0.9 + sin(t * 4.0) * 0.25, 0.1, 0.25)
	# 말 거는 사람이 있으면 그쪽으로 고개를 돌린다.
	var yaw_target := 0.0
	if look_target and is_instance_valid(look_target):
		var local := to_local(look_target.global_position)
		yaw_target = clampf(atan2(local.x, local.z), -1.0, 1.0)
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw_target, 1.0 - exp(-5.0 * delta))

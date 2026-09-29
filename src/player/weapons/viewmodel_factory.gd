class_name ViewmodelFactory
extends RefCounted
## 1인칭 무기 모델(기획서 §23.4): 모서리를 깎은 부품을 조합해 무기군마다 다른 실루엣을 만들고,
## 금속·수지·나무 결(표면 결 텍스처)과 레일·가늠쇠·총구 제퇴기·방아쇠울 같은 세부를 붙인다.
## 1인칭에서는 장갑 낀 손과 소매가 무기를 쥔다(세계 속 무기에는 손이 없다).
##
## 좌표: -Z가 총구 방향, +Y가 위. 근접 무기는 +Y 방향으로 날을 세운다.
## 반환: { "root": Node3D, "muzzle": Marker3D(총기), "ads_offset": Vector3(총기) }

const SHADER := preload("res://assets/shaders/viewmodel.gdshader")
## 소매가 뻗는 방향(무기 기준, 화면 밖 아래쪽)
const RIGHT_SLEEVE := Vector3(0.35, -0.55, 0.75)
const LEFT_SLEEVE := Vector3(-0.42, -0.52, 0.74)

## 카람빗: 손가락 고리 가운데(손 가운데 기준, 새끼손가락이 지나는 자리), 날이 휘는 원의 중심과 등 반지름
const KARAMBIT_RING := Vector2(0.026, -0.034)
const KARAMBIT_CURVE_CENTER := Vector2(-0.0338, 0.056)
const KARAMBIT_SPINE_R := 0.04
## 카람빗을 든 기본 자세(카메라 기준): 주먹은 화면 오른쪽 아래, 칼 옆면이 보여 날의 곡선이 화면 가운데 쪽으로 휜다.
const KARAMBIT_REST_POS := Vector3(0.15, -0.11, -0.3)
const KARAMBIT_REST_ROT := Vector3(-5.0, -20.0, 20.0)
## 카람빗 방어: 날을 가슴 앞으로 내밀어 화면 가운데 쪽을 겨눈다.
const KARAMBIT_BLOCK_POS := Vector3(0.1, -0.1, -0.3)
const KARAMBIT_BLOCK_ROT := Vector3(0.0, -35.0, 45.0)

## true면 1인칭 전용 셰이더 대신 일반 재질과 그림자를 쓴다(바닥에 떨어진 무기, 적이 든 무기).
static var _world_mode: bool = false
static var _bevel_cache: Dictionary = {}


static func clear_cache() -> void:
	_bevel_cache.clear()
	BladeMesh.clear_cache()


## 같은 모양을 세계 속 물체로 만든다(바닥에 떨어진 무기, 고블린이 든 무기).
static func build_world(base_id: StringName, rarity: int = 0) -> Node3D:
	_world_mode = true
	var root: Node3D
	var g := GameDB.weapon(base_id)
	if g:
		root = build_gun(g, rarity).root
	else:
		var m := GameDB.melee(base_id)
		root = build_melee(m, rarity).root if m else Node3D.new()
	_world_mode = false
	return root


## 희귀도가 개량 이상이면 포인트 부품을 희귀도 색으로 칠하고 은은하게 빛나게 한다(한눈에 구분).
static func _accent(color: Color, rarity: int, roughness: float, metallic: float, surface: StringName = &"polymer") -> Material:
	if rarity <= ItemRarity.Tier.STANDARD:
		return _mat(color, roughness, metallic, Color.BLACK, 0.0, surface)
	var rc := ItemRarity.tier_color(rarity)
	return _mat(color.lerp(rc, 0.7), roughness * 0.8, metallic, rc, 0.35 + 0.15 * rarity, surface)


## 장갑·소매 색(캐릭터 외형을 따른다)
static func _hand_colors() -> Array[Color]:
	var look: Dictionary = GameState.appearance
	var sleeve: Color = HumanoidModel.OUTFIT_COLORS[clampi(int(look.get("outfit", 0)), 0, HumanoidModel.OUTFIT_COLORS.size() - 1)]
	# 장갑: 외형의 포인트 색을 아주 짙게 낮춘 전술 장갑
	var accent: Color = HumanoidModel.ACCENT_COLORS[clampi(int(look.get("accent", 0)), 0, HumanoidModel.ACCENT_COLORS.size() - 1)]
	var glove := accent.lerp(Color(0.2, 0.19, 0.17), 0.7).darkened(0.35)
	return [glove, sleeve]


static func build_gun(data: WeaponData, rarity: int = 0) -> Dictionary:
	var root := Node3D.new()
	root.name = "VM_%s" % data.id
	var metal := _mat(data.body_color.darkened(0.25), 0.42, 0.75, Color.BLACK, 0.0, &"metal")
	var body := _mat(data.body_color, 0.55, 0.3, Color.BLACK, 0.0, &"polymer")
	var accent := _accent(data.accent_color, rarity, 0.6, 0.1)
	var dark := _mat(data.body_color.darkened(0.55), 0.5, 0.6, Color.BLACK, 0.0, &"metal")
	var wood := _mat(data.body_color.lerp(Color(0.42, 0.27, 0.15), 0.6), 0.62, 0.0, Color.BLACK, 0.0, &"wood")
	var muzzle_pos := Vector3(0, 0.02, -0.5)
	var ads := Vector3(0, -0.094, -0.4)
	# 손 자리: 손잡이(가운데, 기울기, 반지름)와 받치는 손(가운데, 반지름). 받치는 손이 없으면 반지름 0.
	var grip_pos := Vector3(0, -0.095, 0.085)
	var grip_tilt := -18.0
	var grip_r := 0.02
	var support_pos := Vector3(0, 0.012, -0.3)
	var support_r := 0.034
	match data.viewmodel_style:
		&"pistol":
			# 권총: 슬라이드(톱니 홈), 몸통, 방아쇠울, 손잡이, 가늠자·가늠쇠
			_bbox(root, Vector3(0.036, 0.034, 0.2), Vector3(0, 0.032, 0.0), metal)
			for i in 6:
				_bbox(root, Vector3(0.038, 0.024, 0.004), Vector3(0, 0.032, 0.07 + i * 0.007), dark, Vector3.ZERO, 0.0005)
			_bbox(root, Vector3(0.034, 0.03, 0.16), Vector3(0, 0.002, -0.012), body)
			_bbox(root, Vector3(0.034, 0.12, 0.05), Vector3(0, -0.058, 0.058), accent, Vector3(-14, 0, 0))
			_bbox(root, Vector3(0.006, 0.006, 0.05), Vector3(0, -0.03, -0.012), body)
			_bbox(root, Vector3(0.005, 0.02, 0.006), Vector3(0, -0.02, 0.0), dark, Vector3(12, 0, 0))
			_bbox(root, Vector3(0.008, 0.01, 0.008), Vector3(0, 0.054, -0.088), dark)
			_bbox(root, Vector3(0.024, 0.01, 0.008), Vector3(0, 0.054, 0.09), dark)
			_cyl(root, 0.007, 0.012, Vector3(0, 0.03, -0.103), dark)
			muzzle_pos = Vector3(0, 0.03, -0.11)
			ads = Vector3(0, -0.07, -0.36)
			grip_pos = Vector3(0, -0.06, 0.06)
			grip_tilt = -14.0
			grip_r = 0.018
			support_r = 0.0
		&"shotgun":
			# 펌프 산탄총: 몸통, 긴 총열과 탄창관, 나무 펌프 손잡이, 나무 개머리
			_bbox(root, Vector3(0.062, 0.078, 0.3), Vector3(0, 0.0, 0.0), metal)
			_cyl(root, 0.018, 0.56, Vector3(0, 0.028, -0.42), dark)
			_cyl(root, 0.014, 0.44, Vector3(0, -0.012, -0.36), dark)
			_bbox(root, Vector3(0.06, 0.05, 0.17), Vector3(0, -0.012, -0.32), wood)
			for i in 6:
				_bbox(root, Vector3(0.062, 0.004, 0.006), Vector3(0, -0.012, -0.39 + i * 0.024), dark, Vector3.ZERO, 0.0005)
			_bbox(root, Vector3(0.05, 0.1, 0.27), Vector3(0, -0.035, 0.27), wood, Vector3(8, 0, 0))
			_bbox(root, Vector3(0.036, 0.1, 0.045), Vector3(0, -0.08, 0.1), wood, Vector3(-16, 0, 0))
			_bbox(root, Vector3(0.006, 0.006, 0.05), Vector3(0, -0.045, 0.04), dark)
			_sphere(root, 0.005, Vector3(0, 0.05, -0.69), metal)
			muzzle_pos = Vector3(0, 0.028, -0.7)
			ads = Vector3(0, -0.07, -0.38)
			grip_pos = Vector3(0, -0.08, 0.1)
			grip_tilt = -16.0
			support_pos = Vector3(0, -0.012, -0.32)
			support_r = 0.03
		&"energy":
			var glow := _mat(data.accent_color, 0.3, 0.1, data.accent_color, 3.0)
			_bbox(root, Vector3(0.09, 0.11, 0.42), Vector3(0, 0, 0), body)
			_bbox(root, Vector3(0.07, 0.03, 0.3), Vector3(0, 0.07, -0.02), metal)
			_cyl(root, 0.022, 0.34, Vector3(0, 0.02, -0.34), dark)
			for i in 3:
				_torus(root, 0.03, 0.044, Vector3(0, 0.02, -0.22 - i * 0.07), glow)
			_bbox(root, Vector3(0.012, 0.06, 0.16), Vector3(0.05, -0.01, 0.04), glow, Vector3.ZERO, 0.002)
			_bbox(root, Vector3(0.012, 0.06, 0.16), Vector3(-0.05, -0.01, 0.04), glow, Vector3.ZERO, 0.002)
			_bbox(root, Vector3(0.04, 0.11, 0.05), Vector3(0, -0.1, 0.1), accent, Vector3(-12, 0, 0))
			_bbox(root, Vector3(0.05, 0.03, 0.09), Vector3(0, 0.1, 0.0), dark)
			muzzle_pos = Vector3(0, 0.02, -0.52)
			ads = Vector3(0, -0.125, -0.38)
			grip_pos = Vector3(0, -0.1, 0.1)
			grip_tilt = -12.0
			support_pos = Vector3(0, 0.0, -0.18)
			support_r = 0.05
		&"sniper":
			# 볼트식 저격총: 긴 총열, 조준경(앞뒤 렌즈 경통), 나무 개머리, 양각대 접힘
			_bbox(root, Vector3(0.056, 0.06, 0.32), Vector3(0, 0.005, -0.02), metal)
			_cyl(root, 0.014, 0.6, Vector3(0, 0.02, -0.5), dark)
			_cyl(root, 0.02, 0.05, Vector3(0, 0.02, -0.82), dark)
			_cyl(root, 0.024, 0.26, Vector3(0, 0.082, -0.02), dark)
			_cyl(root, 0.03, 0.06, Vector3(0, 0.082, -0.15), dark)
			_cyl(root, 0.028, 0.05, Vector3(0, 0.082, 0.11), dark)
			for zz: float in [-0.08, 0.05]:
				_bbox(root, Vector3(0.02, 0.028, 0.018), Vector3(0, 0.052, zz), metal)
			var lens := _mat(Color(0.2, 0.35, 0.45), 0.05, 0.3, Color(0.2, 0.5, 0.7), 0.5)
			_cyl(root, 0.026, 0.004, Vector3(0, 0.082, -0.182), lens)
			_bbox(root, Vector3(0.052, 0.07, 0.36), Vector3(0, -0.02, -0.26), wood)
			_bbox(root, Vector3(0.05, 0.12, 0.28), Vector3(0, -0.035, 0.37), wood, Vector3(6, 0, 0))
			_bbox(root, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.09, 0.12), wood, Vector3(-12, 0, 0))
			_cyl(root, 0.008, 0.06, Vector3(0.04, 0.03, 0.1), dark, Vector3(0, 0, 90))
			_bbox(root, Vector3(0.036, 0.1, 0.05), Vector3(0, -0.09, -0.06), dark)
			muzzle_pos = Vector3(0, 0.02, -0.85)
			ads = Vector3(0, -0.12, -0.3)
			grip_pos = Vector3(0, -0.085, 0.13)
			grip_tilt = -12.0
			support_pos = Vector3(0, -0.02, -0.3)
			support_r = 0.036
		&"pipe_shotgun":
			# 쇠파이프 두 개를 철사로 묶은 산탄총
			for sx: float in [-0.024, 0.024]:
				_cyl(root, 0.022, 0.5, Vector3(sx, 0.025, -0.3), dark)
			_bbox(root, Vector3(0.075, 0.08, 0.2), Vector3(0, 0, 0.02), wood)
			for i in 3:
				_torus(root, 0.047, 0.052, Vector3(0, 0.025, -0.14 - i * 0.14), accent)
			_bbox(root, Vector3(0.045, 0.12, 0.05), Vector3(0, -0.09, 0.07), wood, Vector3(-18, 0, 0))
			_bbox(root, Vector3(0.05, 0.07, 0.24), Vector3(0, -0.02, 0.24), wood, Vector3(6, 0, 0))
			muzzle_pos = Vector3(0, 0.025, -0.56)
			ads = Vector3(0, -0.075, -0.36)
			grip_pos = Vector3(0, -0.09, 0.075)
			support_pos = Vector3(0, 0.025, -0.3)
			support_r = 0.048
		&"bolt_rifle":
			# 긴 나무 개머리와 노리쇠 손잡이
			_bbox(root, Vector3(0.055, 0.075, 0.72), Vector3(0, -0.01, 0.02), wood)
			_cyl(root, 0.013, 0.46, Vector3(0, 0.022, -0.55), dark)
			_bbox(root, Vector3(0.048, 0.05, 0.18), Vector3(0, 0.03, -0.02), metal)
			_cyl(root, 0.008, 0.07, Vector3(0.045, 0.03, 0.04), metal, Vector3(0, 0, 90))
			_sphere(root, 0.012, Vector3(0.08, 0.03, 0.04), metal)
			_bbox(root, Vector3(0.05, 0.12, 0.2), Vector3(0, -0.05, 0.3), wood, Vector3(8, 0, 0))
			_bbox(root, Vector3(0.008, 0.03, 0.01), Vector3(0, 0.05, -0.75), dark)
			_bbox(root, Vector3(0.024, 0.02, 0.012), Vector3(0, 0.06, 0.06), dark)
			muzzle_pos = Vector3(0, 0.022, -0.79)
			ads = Vector3(0, -0.1, -0.33)
			grip_pos = Vector3(0, -0.07, 0.13)
			grip_tilt = -8.0
			grip_r = 0.024
			support_pos = Vector3(0, -0.01, -0.28)
			support_r = 0.036
		&"smg":
			# 짧은 총열과 아래로 꽂는 상자 탄창
			_bbox(root, Vector3(0.056, 0.085, 0.3), Vector3(0, 0, 0), metal)
			_cyl(root, 0.016, 0.14, Vector3(0, 0.02, -0.21), dark)
			_cyl(root, 0.021, 0.05, Vector3(0, 0.02, -0.28), dark)
			_bbox(root, Vector3(0.032, 0.15, 0.048), Vector3(0, -0.1, -0.07), accent, Vector3(6, 0, 0))
			_bbox(root, Vector3(0.036, 0.1, 0.045), Vector3(0, -0.08, 0.08), body, Vector3(-14, 0, 0))
			_bbox(root, Vector3(0.012, 0.012, 0.22), Vector3(0.022, -0.01, 0.24), dark)
			_bbox(root, Vector3(0.012, 0.012, 0.22), Vector3(-0.022, -0.01, 0.24), dark)
			_bbox(root, Vector3(0.05, 0.05, 0.012), Vector3(0, -0.01, 0.35), dark)
			_bbox(root, Vector3(0.014, 0.02, 0.03), Vector3(0, 0.055, 0.0), dark)
			_bbox(root, Vector3(0.006, 0.022, 0.008), Vector3(0, 0.052, -0.13), dark)
			muzzle_pos = Vector3(0, 0.02, -0.3)
			ads = Vector3(0, -0.085, -0.36)
			grip_pos = Vector3(0, -0.08, 0.085)
			grip_tilt = -14.0
			support_pos = Vector3(0, -0.1, -0.07)
			support_r = 0.0
		_:
			_rifle(root, metal, body, accent, dark)
			muzzle_pos = Vector3(0, 0.02, -0.64)
			# 정조준 시 가늠쇠 끝이 조준점 바로 아래에 오도록 둔다(표적을 가리지 않게).
			ads = Vector3(0, -0.096, -0.4)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = muzzle_pos
	root.add_child(muzzle)
	if not _world_mode:
		var cols := _hand_colors()
		_hand(root, HandModel.grip(grip_r, cols[0], cols[1], RIGHT_SLEEVE.rotated(Vector3.RIGHT, deg_to_rad(-grip_tilt)), true),
			grip_pos, Vector3(grip_tilt, 0, 0))
		if support_r > 0.0:
			_hand(root, HandModel.support(support_r, cols[0], cols[1], LEFT_SLEEVE), support_pos, Vector3.ZERO)
	return {"root": root, "muzzle": muzzle, "ads_offset": ads}


## 기본 소총(BF-A3 탐사 소총): 위아래 몸통, 통풍구 난 총열 덮개, 위쪽 레일과 가늠자·가늠쇠, 제퇴기,
## 살짝 휜 탄창, 권총 손잡이와 방아쇠울, 장전 손잡이, 탄피 배출구, 접이식 개머리
static func _rifle(root: Node3D, metal: Material, body: Material, accent: Material, dark: Material) -> void:
	_bbox(root, Vector3(0.056, 0.052, 0.34), Vector3(0, 0.02, -0.02), metal)
	_bbox(root, Vector3(0.052, 0.046, 0.2), Vector3(0, -0.026, 0.0), metal)
	_bbox(root, Vector3(0.004, 0.022, 0.05), Vector3(0.029, 0.022, 0.02), dark, Vector3.ZERO, 0.001)
	_bbox(root, Vector3(0.018, 0.012, 0.032), Vector3(0, 0.05, 0.16), dark)
	# 총열 덮개(통풍구)
	_bbox(root, Vector3(0.064, 0.062, 0.26), Vector3(0, 0.014, -0.3), accent)
	for side: float in [-1.0, 1.0]:
		for i in 4:
			_bbox(root, Vector3(0.004, 0.016, 0.034), Vector3(side * 0.032, 0.014, -0.39 + i * 0.058), dark, Vector3.ZERO, 0.001)
	# 레일: 받침과 톱니
	_bbox(root, Vector3(0.026, 0.009, 0.52), Vector3(0, 0.05, -0.12), dark, Vector3.ZERO, 0.002)
	for i in 15:
		_bbox(root, Vector3(0.03, 0.006, 0.012), Vector3(0, 0.056, -0.36 + i * 0.033), dark, Vector3.ZERO, 0.001)
	# 가늠자(구멍 고리)와 가늠쇠(보호 고리 안의 기둥)
	_bbox(root, Vector3(0.026, 0.022, 0.026), Vector3(0, 0.068, 0.1), metal)
	_torus(root, 0.006, 0.011, Vector3(0, 0.086, 0.1), dark, Vector3(90, 0, 0))
	_bbox(root, Vector3(0.024, 0.02, 0.02), Vector3(0, 0.066, -0.36), metal)
	_torus(root, 0.012, 0.015, Vector3(0, 0.084, -0.36), dark, Vector3(90, 0, 0))
	_bbox(root, Vector3(0.004, 0.02, 0.004), Vector3(0, 0.084, -0.36), dark, Vector3.ZERO, 0.0008)
	# 총열과 제퇴기
	_cyl(root, 0.011, 0.2, Vector3(0, 0.02, -0.52), dark)
	_cyl(root, 0.017, 0.07, Vector3(0, 0.02, -0.61), metal)
	for i in 2:
		_bbox(root, Vector3(0.036, 0.006, 0.008), Vector3(0, 0.02, -0.6 + i * 0.022), dark, Vector3.ZERO, 0.001)
	# 탄창(살짝 휜 두 토막)과 바닥판
	_bbox(root, Vector3(0.028, 0.08, 0.056), Vector3(0, -0.085, -0.06), body, Vector3(8, 0, 0))
	_bbox(root, Vector3(0.028, 0.07, 0.056), Vector3(0, -0.15, -0.072), body, Vector3(16, 0, 0))
	_bbox(root, Vector3(0.032, 0.01, 0.062), Vector3(0, -0.186, -0.084), dark, Vector3(16, 0, 0))
	# 권총 손잡이, 방아쇠울, 방아쇠
	_bbox(root, Vector3(0.034, 0.11, 0.044), Vector3(0, -0.095, 0.085), body, Vector3(-18, 0, 0))
	_bbox(root, Vector3(0.01, 0.006, 0.07), Vector3(0, -0.07, 0.03), metal, Vector3.ZERO, 0.001)
	_bbox(root, Vector3(0.01, 0.026, 0.006), Vector3(0, -0.058, -0.004), metal, Vector3.ZERO, 0.001)
	_bbox(root, Vector3(0.005, 0.022, 0.006), Vector3(0, -0.058, 0.032), dark, Vector3(12, 0, 0), 0.0008)
	# 개머리: 관 두 개와 개머리판, 뺨 받침
	for sy: float in [0.016, -0.02]:
		_cyl(root, 0.007, 0.2, Vector3(0, sy, 0.24), dark)
	_bbox(root, Vector3(0.04, 0.11, 0.05), Vector3(0, -0.02, 0.35), body)
	_bbox(root, Vector3(0.042, 0.115, 0.012), Vector3(0, -0.02, 0.38), dark)
	_bbox(root, Vector3(0.036, 0.022, 0.1), Vector3(0, 0.03, 0.3), body)


static func build_melee(data: MeleeData, rarity: int = 0) -> Dictionary:
	var root := Node3D.new()
	root.name = "VM_%s" % data.id
	var blade := _mat(data.body_color, 0.22, 0.88, Color.BLACK, 0.0, &"metal")
	var grip := _mat(data.accent_color, 0.75, 0.05, Color.BLACK, 0.0, &"leather")
	var guard := _accent(data.accent_color.lightened(0.25), rarity, 0.45, 0.65, &"metal")
	var cols := _hand_colors()
	var handle_r := 0.017
	var hand_pos := Vector3(0, -0.005, 0)
	var extra := {}
	match data.viewmodel_style:
		&"twin":
			# 쌍월: 초승달 날 한 쌍. 오른손은 흰 달, 왼손은 거울에 비춘 검은 달. 볼록한 날이 바깥을 보고,
			# 오목한 안쪽이 서로 마주 봐서 두 날을 맞대면 둥근 달 모양이 된다.
			var right := Node3D.new()
			right.name = "Right"
			right.position = Vector3(0.2, 0, 0)
			root.add_child(right)
			var left := Node3D.new()
			left.name = "Left"
			left.position = Vector3(-0.2, 0, 0)
			root.add_child(left)
			for hand: Node3D in [right, left]:
				var dark := hand == left
				if not _world_mode:
					var h := _hand(hand, HandModel.grip(0.0145, cols[0], cols[1], RIGHT_SLEEVE, false), Vector3(0, 0.04, 0), Vector3.ZERO)
					if dark:
						h.scale = Vector3(-1, 1, 1)
				var knife := _moon_knife(data, rarity, dark)
				knife.position = Vector3(0, 0.045, 0)
				if dark:
					knife.scale = Vector3(-1, 1, 1)
				hand.add_child(knife)
			return {"root": root, "left": left, "right": right}
		&"cleaver":
			# 넓적한 네모 날의 식칼
			_cyl(root, 0.018, 0.13, Vector3(0, 0, 0), grip, Vector3.ZERO)
			_bbox(root, Vector3(0.05, 0.02, 0.03), Vector3(0, 0.075, 0), guard)
			_bbox(root, Vector3(0.12, 0.3, 0.008), Vector3(0.035, 0.235, 0), blade, Vector3.ZERO, 0.002)
			_bbox(root, Vector3(0.03, 0.3, 0.01), Vector3(-0.022, 0.235, 0), guard)
			handle_r = 0.018
		&"spear":
			# 긴 자루 끝의 뼈 촉
			var wood := _mat(data.accent_color, 0.7, 0.0, Color.BLACK, 0.0, &"wood")
			_cyl(root, 0.016, 1.15, Vector3(0, 0.35, 0), wood, Vector3.ZERO)
			for i in 3:
				_bbox(root, Vector3(0.036, 0.018, 0.036), Vector3(0, 0.72 + i * 0.03, 0), guard)
			_blade(root, Vector3(0, 1.02, 0), 0.05, 0.22, 0.012, blade)
			handle_r = 0.016
		&"axe":
			# 짧은 자루와 쐐기 모양 도끼머리
			var wood := _mat(data.accent_color, 0.7, 0.0, Color.BLACK, 0.0, &"wood")
			_cyl(root, 0.019, 0.56, Vector3(0, 0.17, 0), wood, Vector3.ZERO)
			_bbox(root, Vector3(0.06, 0.09, 0.03), Vector3(0, 0.42, 0), guard)
			_bbox(root, Vector3(0.14, 0.13, 0.014), Vector3(0.08, 0.42, 0), blade, Vector3.ZERO, 0.003)
			_bbox(root, Vector3(0.02, 0.17, 0.016), Vector3(0.155, 0.42, 0), blade, Vector3.ZERO, 0.003)
			handle_r = 0.019
		&"greatblade":
			# 양손 대도
			_cyl(root, 0.022, 0.3, Vector3(0, -0.02, 0), grip, Vector3.ZERO)
			_bbox(root, Vector3(0.24, 0.045, 0.05), Vector3(0, 0.15, 0), guard)
			_blade(root, Vector3(0, 0.7, 0), 0.11, 1.05, 0.013, blade)
			for i in 4:
				_bbox(root, Vector3(0.02, 0.03, 0.014), Vector3(0.05, 0.35 + i * 0.2, 0), guard)
			handle_r = 0.022
		&"karambit":
			# 카람빗(바로 쥐기): 새끼손가락을 끼운 고리가 주먹 아래에 걸리고, 새 발톱처럼 굽은 날이 주먹 위로 솟아
			# 화면 가운데 쪽으로 휘어 내려온다. 고리를 축으로 칼만 돌릴 수 있게 "spin" 마디에 단다.
			var parts := _karambit(data, rarity)
			root.add_child(parts.spin)
			extra["spin"] = parts.spin
			extra["rest_pos"] = KARAMBIT_REST_POS
			extra["rest_rot"] = KARAMBIT_REST_ROT
			extra["block_pos"] = KARAMBIT_BLOCK_POS
			extra["block_rot"] = KARAMBIT_BLOCK_ROT
			handle_r = 0.0125
			hand_pos = Vector3.ZERO
		_:
			_cyl(root, 0.018, 0.17, Vector3(0, 0, 0), grip, Vector3.ZERO)
			_bbox(root, Vector3(0.15, 0.024, 0.035), Vector3(0, 0.095, 0), guard)
			_blade(root, Vector3(0, 0.47, 0), 0.038, 0.72, 0.008, blade)
			_cyl(root, 0.024, 0.03, Vector3(0, -0.095, 0), guard, Vector3.ZERO)
	if not _world_mode:
		_hand(root, HandModel.grip(handle_r, cols[0], cols[1], RIGHT_SLEEVE, false), hand_pos, Vector3.ZERO)
	extra["root"] = root
	return extra


## 쌍월의 초승달 칼 한 자루. 손잡이 가운데가 원점이고 날은 +Y로 선다. dark면 검은 달(검게 그을린 강철, 보랏빛 날).
static func _moon_knife(data: MeleeData, rarity: int, dark: bool) -> Node3D:
	var knife := Node3D.new()
	knife.name = "MoonKnife"
	var steel_col := Color(0.14, 0.14, 0.18) if dark else data.body_color.lerp(Color(0.95, 0.97, 1.0), 0.55)
	var glow := Color(0.62, 0.42, 1.0) if dark else Color(0.6, 0.8, 1.0)
	var body := _mat(steel_col, 0.26 if dark else 0.2, 0.88, glow, 0.0 if dark else 0.05, &"metal")
	var edge := _mat(Color(0.34, 0.3, 0.5) if dark else Color(0.94, 0.97, 1.0), 0.1, 1.0, glow, 0.9, &"metal")
	var grip := _mat(Color(0.07, 0.06, 0.09) if dark else data.accent_color, 0.8, 0.05, Color.BLACK, 0.0, &"leather")
	var fitting := _accent(Color(0.2, 0.19, 0.25) if dark else Color(0.76, 0.79, 0.86), rarity, 0.35, 0.85, &"metal")
	var stone := _mat(glow.lerp(Color.WHITE, 0.35), 0.1, 0.0, glow, 1.8)
	# 손잡이(가죽 감기와 금속 띠), 둥근 달 테 코등이, 달돌을 박은 자루 끝
	_cyl(knife, 0.0145, 0.1, Vector3.ZERO, grip, Vector3.ZERO)
	for y: float in [-0.047, 0.047]:
		_cyl(knife, 0.0158, 0.007, Vector3(0, y, 0), fitting, Vector3.ZERO)
	_cyl(knife, 0.021, 0.008, Vector3(0, 0.055, 0), fitting, Vector3.ZERO)
	_torus(knife, 0.017, 0.024, Vector3(0, 0.055, 0), fitting, Vector3.ZERO)
	_sphere(knife, 0.0155, Vector3(0, -0.058, 0), fitting)
	_sphere(knife, 0.0082, Vector3(0, -0.07, 0), stone)
	var m := _crescent_meshes()
	var at := Vector3(0, 0.058, 0)
	_add(knife, m[&"body"], at, body, Vector3.ZERO)
	_add(knife, m[&"edge"], at, edge, Vector3.ZERO)
	return knife


## 초승달 날(양날). 두 원이 만나는 뿔 사이의 볼록한 쪽이 날이고, 아래 뿔 가까이를 잘라 코등이에 꽂는다.
## 잘린 밑동의 가운데가 원점이고, 날은 +Y로 서서 바깥(+X)으로 부풀었다가 끝이 손잡이 위로 돌아온다.
static func _crescent_meshes() -> Dictionary:
	var chord := 0.25
	var bulge_out := 0.088
	var bulge_in := 0.038
	var ro := (chord * chord * 0.25 + bulge_out * bulge_out) / (2.0 * bulge_out)
	var ri := (chord * chord * 0.25 + bulge_in * bulge_in) / (2.0 * bulge_in)
	var co := Vector2(-(ro - bulge_out), chord * 0.5)
	var ci := Vector2(-(ri - bulge_in), chord * 0.5)
	var sides := BladeMesh.crescent(co, ro, ci, ri, 28, 0.1, 1.0)
	var inner := sides[0]
	var outer := sides[1]
	var base := (inner[0] + outer[0]) * 0.5
	var tilt := deg_to_rad(-14.0)
	var half_t := PackedFloat32Array()
	for i in inner.size():
		inner[i] = (inner[i] - base).rotated(tilt)
		outer[i] = (outer[i] - base).rotated(tilt)
		half_t.append(lerpf(0.0029, 0.0009, float(i) / float(inner.size() - 1)))
	return BladeMesh.band(inner, outer, half_t, BladeMesh.Profile.DOUBLE_EDGE, false, "moon_crescent")


## 카람빗 조각들. 손 가운데가 원점. 고리 가운데를 축으로 도는 "spin" 마디 아래에 칼을 단다.
static func _karambit(data: MeleeData, rarity: int) -> Dictionary:
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(KARAMBIT_RING.x, KARAMBIT_RING.y, 0.0)
	var knife := Node3D.new()
	knife.name = "Karambit"
	knife.position = -spin.position
	spin.add_child(knife)
	var steel := _mat(data.body_color.lightened(0.25), 0.24, 0.9, Color.BLACK, 0.0, &"metal")
	var edge := _mat(data.body_color.lerp(Color(0.97, 0.98, 1.0), 0.65), 0.1, 1.0, Color.BLACK, 0.0, &"metal")
	var scales := _mat(data.accent_color, 0.6, 0.05, Color.BLACK, 0.0, &"polymer")
	var liner := _accent(data.body_color.darkened(0.15), rarity, 0.35, 0.85, &"metal")
	var screw := _mat(data.body_color.darkened(0.4), 0.35, 0.9, Color.BLACK, 0.0, &"metal")
	var m := _karambit_meshes()
	for part: StringName in [&"blade", &"handle", &"liner", &"ring", &"ring_liner"]:
		var parts: Dictionary = m[part]
		var mat: Material = scales
		match part:
			&"blade":
				mat = steel
			&"liner", &"ring_liner":
				mat = liner
		_add(knife, parts[&"body"], Vector3.ZERO, mat, Vector3.ZERO)
		if parts[&"edge"] != null:
			_add(knife, parts[&"edge"], Vector3.ZERO, edge, Vector3.ZERO)
	# 손잡이 판을 조인 나사
	for p: Vector2 in [Vector2(0.005, -0.004), Vector2(-0.001, 0.034)]:
		for side: float in [-1.0, 1.0]:
			_cyl(knife, 0.0031, 0.0012, Vector3(p.x, p.y, side * 0.0064), screw, Vector3(90, 0, 0))
	return {"spin": spin, "knife": knife}


## 카람빗 메시(한 번만 만든다): 날, 손잡이 판, 판 사이의 금속 라이너, 손가락 고리.
static func _karambit_meshes() -> Dictionary:
	# 날: 등(볼록)은 원호를 따라 위로 솟았다가 안쪽(-X)으로 돌아 내려오고, 날(오목)은 그 안쪽에 선다.
	var spine := PackedVector2Array()
	var edge := PackedVector2Array()
	var blade_t := PackedFloat32Array()
	var steps := 30
	for s in steps:
		var t := float(s) / float(steps - 1)
		var a := deg_to_rad(lerpf(0.0, 138.0, t))
		var w := 0.025 * (1.0 + 0.08 * sin(t * PI * 0.8)) * (1.0 - pow(smoothstep(0.26, 1.0, t), 1.15))
		var dir := Vector2(cos(a), sin(a))
		spine.append(KARAMBIT_CURVE_CENTER + dir * KARAMBIT_SPINE_R)
		edge.append(KARAMBIT_CURVE_CENTER + dir * (KARAMBIT_SPINE_R - w))
		blade_t.append(lerpf(0.0023, 0.0004, pow(t, 1.3)))
	var blade := BladeMesh.band(spine, edge, blade_t, BladeMesh.Profile.SINGLE_EDGE, false, "karambit_blade")
	# 손잡이: 고리 위에서 주먹 속을 지나 날 밑동까지 살짝 굽는다.
	# 안쪽(-X, 손가락 끝 쪽)에 손가락 홈 셋(검지·가운뎃손가락·약손가락)과 날 가까이의 손가락 받이.
	var line := BladeMesh.bezier(Vector2(0.014, -0.021), Vector2(0.004, -0.004), Vector2(-0.002, 0.026), Vector2(-0.005, 0.059), 22)
	var inner_w := PackedFloat32Array()
	var outer_w := PackedFloat32Array()
	var inner_l := PackedFloat32Array()
	var outer_l := PackedFloat32Array()
	var scale_t := PackedFloat32Array()
	var liner_t := PackedFloat32Array()
	for p in line:
		var ow := 0.0112 + 0.0009 * exp(-pow((p.y - 0.012) / 0.02, 2.0))
		var iw := 0.0112
		for fy: float in [0.034, 0.012, -0.01]:
			iw -= 0.0021 * exp(-pow((p.y - fy) / 0.0062, 2.0))
		iw += 0.0062 * exp(-pow((p.y - 0.049) / 0.0045, 2.0))
		inner_w.append(iw)
		outer_w.append(ow)
		inner_l.append(iw + 0.0007)
		outer_l.append(ow + 0.0007)
		scale_t.append(0.0062)
		liner_t.append(0.0019)
	# 선이 아래에서 위로 가므로 진행 방향의 왼쪽이 -X(안쪽)다.
	var sides := BladeMesh.offset_sides(line, inner_w, outer_w)
	var handle := BladeMesh.band(sides[0], sides[1], scale_t, BladeMesh.Profile.ROUNDED, false, "karambit_handle")
	var lsides := BladeMesh.offset_sides(line, inner_l, outer_l)
	var liner := BladeMesh.band(lsides[0], lsides[1], liner_t, BladeMesh.Profile.ROUNDED, false, "karambit_liner")
	# 손가락 고리
	var ring_steps := 32
	var ring_t := PackedFloat32Array()
	var ring_lt := PackedFloat32Array()
	for i in ring_steps:
		ring_t.append(0.0058)
		ring_lt.append(0.0019)
	var ring := BladeMesh.band(BladeMesh.circle(KARAMBIT_RING, 0.0118, ring_steps), BladeMesh.circle(KARAMBIT_RING, 0.0192, ring_steps),
		ring_t, BladeMesh.Profile.ROUNDED, true, "karambit_ring")
	var ring_liner := BladeMesh.band(BladeMesh.circle(KARAMBIT_RING, 0.0111, ring_steps), BladeMesh.circle(KARAMBIT_RING, 0.0199, ring_steps),
		ring_lt, BladeMesh.Profile.ROUNDED, true, "karambit_ring_liner")
	return {&"blade": blade, &"handle": handle, &"liner": liner, &"ring": ring, &"ring_liner": ring_liner}


## 날: 가운데가 두툼하고 가장자리가 얇은 날(끝은 뾰족하다). center는 날 가운데, 폭 w, 길이 l, 두께 t.
static func _blade(root: Node3D, center: Vector3, w: float, l: float, t: float, mat: Material) -> void:
	_bbox(root, Vector3(w, l, t), center, mat, Vector3.ZERO, minf(t * 0.45, w * 0.3))
	_bbox(root, Vector3(w * 0.7, w * 0.7, t * 0.9), center + Vector3(0, l * 0.5, 0), mat, Vector3(0, 0, 45), t * 0.3)


static func _mat(color: Color, roughness: float, metallic: float,
		emission: Color = Color.BLACK, emission_energy: float = 0.0, surface: StringName = &"") -> Material:
	if _world_mode:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = color
		sm.roughness = roughness
		sm.metallic = metallic
		if emission_energy > 0.0:
			sm.emission_enabled = true
			sm.emission = emission
			sm.emission_energy_multiplier = emission_energy
		return sm
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", roughness)
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("emission_energy", emission_energy)
	if surface != &"":
		m.set_shader_parameter("detail_tex", GearTextures.get_texture(surface))
		var params: Array = _surface_params(surface)
		m.set_shader_parameter("detail_scale", params[0])
		m.set_shader_parameter("detail_strength", params[1])
		m.set_shader_parameter("detail_rough", params[2])
		m.set_shader_parameter("detail_albedo", params[3])
	return m


## 표면 결: [반복(1m당), 법선 세기, 거칠기 흔들림, 밝기 흔들림]
static func _surface_params(surface: StringName) -> Array:
	match surface:
		&"metal":
			return [9.0, 0.35, 0.3, 0.18]
		&"polymer":
			return [22.0, 0.45, 0.12, 0.08]
		&"wood":
			return [6.0, 0.6, 0.15, 0.4]
		&"leather":
			return [18.0, 0.55, 0.15, 0.15]
		&"cloth":
			return [30.0, 0.6, 0.1, 0.15]
	return [10.0, 0.0, 0.0, 0.0]


## 손·소매 재질(정점 색을 쓴다)
static func _hand_mat(surface: StringName) -> Material:
	var m := _mat(Color.WHITE, 0.72 if surface == &"leather" else 0.92, 0.0, Color.BLACK, 0.0, surface) as ShaderMaterial
	m.set_shader_parameter("use_vertex_color", true)
	return m


## 손: 장갑(가죽)과 소매(천)를 따로 된 메시 두 개로 나눠 각자 1인칭 재질을 입힌다
## (면별 재질 덮어쓰기는 쓰지 않는다: 무기를 바꿔 모델을 지울 때 렌더링 서버가 지워진 재질을 찾는 문제가 있다).
static func _hand(root: Node3D, parts: Dictionary, pos: Vector3, rot_deg: Vector3) -> Node3D:
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = pos
	hand.rotation_degrees = rot_deg
	for surface: StringName in parts:
		var mi := MeshInstance3D.new()
		mi.name = String(surface)
		mi.mesh = parts[surface]
		mi.material_override = _hand_mat(surface)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(mi)
	root.add_child(hand)
	return hand


static func _add(root: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _world_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## 모서리를 깎은 상자. bevel < 0이면 크기에 맞춰 정한다.
static func _bbox(root: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO, bevel: float = -1.0) -> MeshInstance3D:
	if bevel < 0.0:
		bevel = clampf(minf(size.x, minf(size.y, size.z)) * 0.16, 0.0008, 0.006)
	return _add(root, bevel_box(size, bevel), pos, mat, rot_deg)


## 모서리를 깎은 상자 메시: 면 여섯, 모서리 띠 열둘, 꼭짓점 세모 여덟. 모서리 띠가 빛을 받아 윤곽이 산다.
static func bevel_box(size: Vector3, bevel: float) -> ArrayMesh:
	var key := "%.4f_%.4f_%.4f_%.4f" % [size.x, size.y, size.z, bevel]
	if _bevel_cache.has(key):
		return _bevel_cache[key]
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 한 면의 네 꼭짓점(안쪽으로 b만큼 들인 사각형)
	var face := func(n: Vector3) -> Array[Vector3]:
		var out: Array[Vector3] = []
		var u := Vector3(n.y, n.z, n.x).abs()
		var v := n.cross(u).abs()
		var c := n * Vector3(h.x, h.y, h.z)
		var hu := (u * h).length() - b
		var hv := (v * h).length() - b
		for sv: Array in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
			out.append(c + u * hu * float(sv[0]) + v * hv * float(sv[1]))
		return out
	var tri := func(a: Vector3, bb: Vector3, c: Vector3, n: Vector3) -> void:
		var fn := (c - a).cross(bb - a)
		if fn.dot(n) < 0.0:
			var t := bb
			bb = c
			c = t
		for p: Vector3 in [a, bb, c]:
			st.set_normal(n)
			st.set_uv(Vector2(p.x + p.z, p.y + p.z))
			st.add_vertex(p)
	var normals: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var faces := {}
	for n in normals:
		var q: Array[Vector3] = face.call(n)
		faces[n] = q
		tri.call(q[0], q[1], q[2], n)
		tri.call(q[0], q[2], q[3], n)
	# 모서리 띠와 꼭짓점: 이웃한 면의 가장 가까운 꼭짓점끼리 잇는다.
	for i in normals.size():
		for j in range(i + 1, normals.size()):
			var na := normals[i]
			var nb := normals[j]
			if absf(na.dot(nb)) > 0.5:
				continue
			var qa: Array[Vector3] = faces[na]
			var qb: Array[Vector3] = faces[nb]
			# 두 면이 맞닿는 쪽의 꼭짓점 둘씩
			var ea: Array[Vector3] = []
			var eb: Array[Vector3] = []
			for p in qa:
				if p.dot(nb) > 0.0:
					ea.append(p)
			for p in qb:
				if p.dot(na) > 0.0:
					eb.append(p)
			if ea.size() != 2 or eb.size() != 2:
				continue
			# 짝 맞추기: ea[0]에 가까운 eb를 앞에
			if ea[0].distance_squared_to(eb[0]) > ea[0].distance_squared_to(eb[1]):
				eb.reverse()
			var n2 := (na + nb).normalized()
			tri.call(ea[0], ea[1], eb[1], n2)
			tri.call(ea[0], eb[1], eb[0], n2)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var pts: Array[Vector3] = []
				for n in [Vector3(sx, 0, 0), Vector3(0, sy, 0), Vector3(0, 0, sz)]:
					var q: Array[Vector3] = faces[n]
					var best := q[0]
					var corner := Vector3(sx * h.x, sy * h.y, sz * h.z)
					for p in q:
						if p.distance_squared_to(corner) < best.distance_squared_to(corner):
							best = p
					pts.append(best)
				tri.call(pts[0], pts[1], pts[2], Vector3(sx, sy, sz).normalized())
	var mesh := st.commit()
	_bevel_cache[key] = mesh
	return mesh


## 원기둥. 기본은 -Z 방향(총열)으로 눕힌다.
static func _cyl(root: Node3D, radius: float, length: float, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3(90, 0, 0)) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	mesh.rings = 1
	return _add(root, mesh, pos, mat, rot_deg)


static func _sphere(root: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _add(root, mesh, pos, mat, Vector3.ZERO)


static func _torus(root: Node3D, inner: float, outer: float, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3(90, 0, 0)) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 8
	return _add(root, mesh, pos, mat, rot_deg)


## 총구 섬광(교차한 두 사각형)
static func build_muzzle_flash(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "MuzzleFlash"
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/viewmodel_flash.gdshader")
	m.set_shader_parameter("color", color)
	for rot in [Vector3(0, 0, 0), Vector3(0, 90, 0), Vector3(90, 0, 0)]:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.14, 0.14) if rot.x == 0.0 else Vector2(0.1, 0.1)
		mi.mesh = q
		mi.material_override = m
		mi.rotation_degrees = rot
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	root.visible = false
	return root

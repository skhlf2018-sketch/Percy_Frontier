class_name CreatureMaterials
extends RefCounted
## 생물 재질(기획서 §23.1 "사실적 재질과 조명의 스타일화된 리얼리즘").
## 색은 모델의 정점 색(등은 짙고 배는 옅은 보호색, 얼룩·무늬)으로 칠하고, 재질은 표면 결만 맡는다.
## 표면 결(털 뭉치, 비늘, 피부 주름, 껍질)은 이음매 없는 잡음으로 만든 법선 지도를 물체 공간 삼면 투영으로 입힌다.
## 외부 텍스처 없이 실행할 때 한 번 만들어 모든 개체가 나눠 쓴다.

enum Kind { FUR, FUR_THIN, SKIN, SKIN_THIN, WET_SKIN, SCALE, CHITIN, HORN, EYE, CLOTH, LEATHER, METAL, WOOD, GLOW, SPORE, TEETH, STONE, HIDE }

const TEX_SIZE := 256
const FUR_SHADER := preload("res://assets/shaders/fur_shell.gdshader")
## 털 껍질 겹 수. 많을수록 촘촘하고 부드럽다.
const FUR_SHELLS := 8

static var _materials: Dictionary = {}
static var _normals: Dictionary = {}
static var _fur_chain: Dictionary = {}
static var _strands: Texture2D


## 캐시를 비운다(종료할 때 서버가 내려가기 전에 자원을 놓는다).
static func clear_cache() -> void:
	_materials.clear()
	_normals.clear()
	_fur_chain.clear()
	_strands = null


static func get_material(kind: int) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m := _make(kind)
	_materials[kind] = m
	return m


static func _base(roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = Color.WHITE
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _detail(m: StandardMaterial3D, tex: Texture2D, scale: float, strength: float) -> void:
	m.normal_enabled = true
	m.normal_texture = tex
	m.normal_scale = strength
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_triplanar_sharpness = 3.0
	m.uv1_scale = Vector3(scale, scale, scale)


static func _make(kind: int) -> Material:
	match kind:
		Kind.FUR, Kind.FUR_THIN:
			var m := _base(1.0)
			_detail(m, normal_texture(&"fur"), 4.0, 0.35)
			# 털: 비스듬히 볼 때 옅게 빛나는 결(rim)로 부드러운 윤곽을 낸다. 반짝이지 않게 반사는 낮춘다.
			m.rim_enabled = true
			m.rim = 0.22
			m.rim_tint = 0.8
			m.metallic_specular = 0.15
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			if kind == Kind.FUR_THIN:
				# 얇은 귀·막은 뒤에서 빛이 비친다.
				m.backlight_enabled = true
				m.backlight = Color(0.55, 0.25, 0.2)
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		Kind.SKIN, Kind.SKIN_THIN:
			var m := _base(0.72)
			_detail(m, normal_texture(&"skin"), 3.5, 0.3)
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.3
			m.metallic_specular = 0.35
			m.rim_enabled = true
			m.rim = 0.1
			m.rim_tint = 0.4
			if kind == Kind.SKIN_THIN:
				m.backlight_enabled = true
				m.backlight = Color(0.5, 0.3, 0.2)
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		Kind.WET_SKIN:
			var m := _base(0.32)
			_detail(m, normal_texture(&"skin"), 5.0, 0.7)
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
			m.clearcoat_roughness = 0.2
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.25
			return m
		Kind.SCALE:
			var m := _base(0.42)
			_detail(m, normal_texture(&"scale"), 9.0, 1.3)
			m.clearcoat_enabled = true
			m.clearcoat = 0.35
			m.clearcoat_roughness = 0.35
			return m
		Kind.CHITIN:
			var m := _base(0.28)
			_detail(m, normal_texture(&"chitin"), 3.0, 0.8)
			m.clearcoat_enabled = true
			m.clearcoat = 0.8
			m.clearcoat_roughness = 0.15
			return m
		Kind.HORN:
			var m := _base(0.48)
			_detail(m, normal_texture(&"horn"), 6.0, 0.9)
			return m
		Kind.TEETH:
			var m := _base(0.35)
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.2
			return m
		Kind.EYE:
			var m := _base(0.04)
			m.metallic_specular = 0.9
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.02
			m.emission_enabled = true
			m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			m.emission = Color(0.35, 0.35, 0.35)
			m.emission_energy_multiplier = 1.0
			return m
		Kind.CLOTH:
			var m := _base(0.95)
			_detail(m, normal_texture(&"cloth"), 14.0, 0.8)
			# 천은 얇다: 트인 망토 안쪽도 보이게
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		Kind.LEATHER:
			var m := _base(0.7)
			_detail(m, normal_texture(&"skin"), 5.0, 0.8)
			return m
		Kind.METAL:
			var m := _base(0.45)
			m.metallic = 0.85
			_detail(m, normal_texture(&"rust"), 4.0, 0.6)
			return m
		Kind.WOOD:
			var m := _base(0.8)
			_detail(m, normal_texture(&"wood"), 6.0, 0.9)
			return m
		Kind.GLOW:
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			return m
		Kind.STONE:
			var m := _base(0.88)
			_detail(m, normal_texture(&"stone"), 2.5, 1.2)
			return m
		Kind.HIDE:
			# 두꺼운 가죽: 깊은 주름, 반사가 거의 없다.
			var m := _base(0.86)
			_detail(m, normal_texture(&"hide"), 2.2, 1.1)
			m.metallic_specular = 0.25
			return m
		Kind.SPORE:
			var m := _base(0.55)
			_detail(m, normal_texture(&"spore"), 4.0, 1.0)
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.6
			m.rim_enabled = true
			m.rim = 0.3
			m.rim_tint = 0.8
			return m
	return _base(0.8)


## 털 껍질 재질 사슬(첫 겹의 next_pass로 다음 겹을 잇는다). length는 가장 긴 털(미터).
static func fur_shells(length: float = 0.025, density: float = 9.0) -> Material:
	var key := "%.3f_%.1f" % [length, density]
	if _fur_chain.has(key):
		return _fur_chain[key]
	var first: ShaderMaterial = null
	var prev: ShaderMaterial = null
	for i in FUR_SHELLS:
		var m := ShaderMaterial.new()
		m.shader = FUR_SHADER
		m.set_shader_parameter(&"shell_t", float(i + 1) / float(FUR_SHELLS))
		m.set_shader_parameter(&"fur_length", length)
		m.set_shader_parameter(&"density", density)
		m.set_shader_parameter(&"strands", strand_texture())
		m.render_priority = i
		if prev:
			prev.next_pass = m
		else:
			first = m
		prev = m
	_fur_chain[key] = first
	return first


## 털 가닥 무늬: r = 가닥 중심에서 1(가장자리 0), g = 가닥마다 다른 길이
static func strand_texture() -> Texture2D:
	if _strands:
		return _strands
	var dist := FastNoiseLite.new()
	dist.noise_type = FastNoiseLite.TYPE_CELLULAR
	dist.frequency = 0.16
	dist.cellular_jitter = 0.9
	dist.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	dist.fractal_type = FastNoiseLite.FRACTAL_NONE
	dist.seed = 31
	var val: FastNoiseLite = dist.duplicate()
	val.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var a := dist.get_seamless_image(TEX_SIZE, TEX_SIZE, true, false, 0.0, true)
	var b := val.get_seamless_image(TEX_SIZE, TEX_SIZE, false, false, 0.0, true)
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var r := a.get_pixel(x, y).r
			var g := b.get_pixel(x, y).r
			img.set_pixel(x, y, Color(r, 0.35 + 0.65 * g, 0.0, 1.0))
	img.generate_mipmaps()
	_strands = ImageTexture.create_from_image(img)
	return _strands


## 이음매 없는 결 법선 지도(종류별로 한 번 만든다)
static func normal_texture(kind: StringName) -> Texture2D:
	if _normals.has(kind):
		return _normals[kind]
	var img := height_image(kind)
	img.bump_map_to_normal_map(_bump_scale(kind))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_normals[kind] = tex
	return tex


static func _bump_scale(kind: StringName) -> float:
	match kind:
		&"fur":
			return 6.0
		&"scale":
			return 7.0
		&"chitin":
			return 3.0
		&"cloth":
			return 4.0
		&"wood":
			return 5.0
	return 4.0


## 결의 높이 지도(밝을수록 높다). 테스트와 환경 재질도 쓴다.
static func height_image(kind: StringName) -> Image:
	var n := FastNoiseLite.new()
	n.seed = hash(String(kind)) & 0xFFFF
	var w := TEX_SIZE
	var h := TEX_SIZE
	match kind:
		&"fur":
			# 털 뭉치: 한쪽으로 늘인 잡음(결 방향으로 길쭉한 줄)
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.06
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 4
			h = TEX_SIZE / 4
		&"scale":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.05
			n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
		&"chitin":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.02
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 2
		&"horn":
			# 뿔·뼈: 가로 줄무늬(자란 층)
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.05
			n.fractal_octaves = 3
			w = TEX_SIZE / 8
		&"cloth":
			n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
			n.frequency = 0.25
			n.fractal_octaves = 2
		&"wood":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.04
			n.fractal_octaves = 4
			w = TEX_SIZE / 8
		&"rust":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.03
			n.fractal_octaves = 5
		&"hide":
			# 코끼리 가죽 같은 굵은 주름(세포 잡음의 경계)
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.04
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 3
		&"stone":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.03
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_ADD
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 4
		&"spore":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.035
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			n.fractal_octaves = 3
		_:
			# 피부: 잔주름과 모공
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.045
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 5
			n.fractal_gain = 0.55
	var img := n.get_seamless_image(w, h, false, false, 0.12, true)
	img.convert(Image.FORMAT_RGBA8)
	if w != TEX_SIZE or h != TEX_SIZE:
		img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_CUBIC)
	return img

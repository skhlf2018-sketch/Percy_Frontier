class_name TerrainTextures
extends RefCounted
## 지표 결 텍스처(기획서 §23.1 사실적 재질): 풀밭, 흙길, 바위, 진흙, 낙엽 바닥, 자갈의 결을 잡음으로 한 번 만든다.
## 텍스처 하나에 법선(RGB)과 높이(A)를 함께 담는다. 지형 셰이더가 높이로 섞고 색을 입힌다.
## 외부 텍스처 없이 실행할 때 한 번 만들어 모두가 나눠 쓴다.

const SIZE := 512
const KINDS: Array[StringName] = [&"grass", &"dirt", &"rock", &"mud", &"litter", &"sand"]

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## 미리 만들어 둔 텍스처(tools/gen_terrain_textures.gd)를 쓰고, 없으면 그 자리에서 만든다.
static func get_texture(kind: StringName) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var tex: Texture2D = null
	var path := path_of(kind)
	if ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		tex = ImageTexture.create_from_image(make_image(kind))
	_cache[kind] = tex
	return tex


static func path_of(kind: StringName) -> String:
	return "res://assets/textures/terrain/%s.png" % kind


## 법선(RGB) + 높이(A) 이미지. 이음매 없이 반복된다.
static func make_image(kind: StringName) -> Image:
	return pack(_height(kind), _bump(kind))


## 높이 지도(RGBA8 회색)로 법선(RGB) + 높이(A) 이미지를 만든다(다른 결 텍스처도 쓴다).
static func pack(height: Image, bump: float) -> Image:
	var w := height.get_width()
	var normal := height.duplicate() as Image
	normal.bump_map_to_normal_map(bump)
	var nb := normal.get_data()
	var hb := height.get_data()
	for i in w * height.get_height():
		nb[i * 4 + 3] = hb[i * 4]
	var img := Image.create_from_data(w, height.get_height(), false, Image.FORMAT_RGBA8, nb)
	img.generate_mipmaps()
	return img


static func _bump(kind: StringName) -> float:
	match kind:
		&"rock":
			return 9.0
		&"dirt", &"sand":
			return 6.0
		&"mud":
			return 3.0
	return 5.0


static func noise(seed_value: int, type: FastNoiseLite.NoiseType, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	return n


static func noise_image(n: FastNoiseLite, size: int = SIZE) -> Image:
	var img := n.get_seamless_image(size, size, false, false, 0.1, true)
	img.convert(Image.FORMAT_RGBA8)
	return img


## 두 높이 지도를 섞는다(a*wa + b*wb). 결과는 RGBA8 회색.
static func mix(a: Image, b: Image, wa: float, wb: float, shape: Callable = Callable()) -> Image:
	var size := a.get_width()
	var ab := a.get_data()
	var bb := b.get_data()
	var out := PackedByteArray()
	out.resize(ab.size())
	var n := size * size
	for i in n:
		var v := (float(ab[i * 4]) * wa + float(bb[i * 4]) * wb) / 255.0
		if shape.is_valid():
			v = float(shape.call(v))
		var byte := clampi(int(v * 255.0), 0, 255)
		out[i * 4] = byte
		out[i * 4 + 1] = byte
		out[i * 4 + 2] = byte
		out[i * 4 + 3] = 255
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, out)


static func _height(kind: StringName) -> Image:
	match kind:
		&"grass":
			# 풀뿌리 덩이와 잔 풀잎 결
			var clumps := noise(11, FastNoiseLite.TYPE_CELLULAR, 0.03, 1)
			clumps.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			var blades := noise(12, FastNoiseLite.TYPE_SIMPLEX, 0.16, 3)
			return mix(noise_image(clumps), noise_image(blades), 0.45, 0.55, func(v: float) -> float: return 1.0 - v * 0.85)
		&"dirt":
			# 다져진 흙과 박힌 잔돌
			var pebbles := noise(21, FastNoiseLite.TYPE_CELLULAR, 0.045, 1)
			pebbles.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			var soil := noise(22, FastNoiseLite.TYPE_SIMPLEX, 0.03, 5)
			return mix(noise_image(pebbles), noise_image(soil), 0.5, 0.5, func(v: float) -> float: return smoothstep(0.15, 0.95, 1.0 - v))
		&"rock":
			# 금 간 바위 면과 결
			var cracks := noise(31, FastNoiseLite.TYPE_CELLULAR, 0.018, 3)
			cracks.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			var grain := noise(32, FastNoiseLite.TYPE_SIMPLEX, 0.06, 4)
			return mix(noise_image(cracks), noise_image(grain), 0.7, 0.3, func(v: float) -> float: return smoothstep(0.02, 0.6, v))
		&"mud":
			# 매끈한 진흙과 고인 물웅덩이(낮은 곳)
			var puddles := noise(41, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 3)
			var ripples := noise(42, FastNoiseLite.TYPE_SIMPLEX, 0.07, 2)
			return mix(noise_image(puddles), noise_image(ripples), 0.8, 0.2)
		&"litter":
			# 떨어진 잎(세포마다 잎 한 장)과 솔잎
			var leaves := noise(51, FastNoiseLite.TYPE_CELLULAR, 0.05, 1)
			leaves.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
			var needles := noise(52, FastNoiseLite.TYPE_SIMPLEX, 0.2, 2)
			return mix(noise_image(leaves), noise_image(needles), 0.7, 0.3, func(v: float) -> float: return smoothstep(0.1, 0.9, v))
		&"sand":
			# 자갈과 모래알
			var gravel := noise(61, FastNoiseLite.TYPE_CELLULAR, 0.09, 1)
			gravel.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			var grains := noise(62, FastNoiseLite.TYPE_VALUE, 0.5, 1)
			return mix(noise_image(gravel), noise_image(grains), 0.7, 0.3, func(v: float) -> float: return 1.0 - v * 0.9)
	return noise_image(noise(1, FastNoiseLite.TYPE_SIMPLEX, 0.05, 3))

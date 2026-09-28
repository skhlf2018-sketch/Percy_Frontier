class_name GearTextures
extends RefCounted
## 1인칭 무기·장비 표면 결(기획서 §23.4): 금속(잔 흠과 얼룩), 수지(오톨도톨한 결), 나무(결), 가죽(주름과 땀구멍), 천(짜임).
## 법선(RGB) + 높이(A). tools/gen_gear_textures.gd로 미리 만들어 assets/textures/gear/에 두고, 없으면 그 자리에서 만든다.

const SIZE := 256
const KINDS: Array[StringName] = [&"metal", &"polymer", &"wood", &"leather", &"cloth"]

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func path_of(kind: StringName) -> String:
	return "res://assets/textures/gear/%s.png" % kind


static func get_texture(kind: StringName) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var tex: Texture2D = null
	if ResourceLoader.exists(path_of(kind)):
		tex = load(path_of(kind))
	if tex == null:
		tex = ImageTexture.create_from_image(make_image(kind))
	_cache[kind] = tex
	return tex


static func make_image(kind: StringName) -> Image:
	var T := TerrainTextures
	match kind:
		&"metal":
			# 잔 흠(가늘고 긴 결)과 넓은 얼룩
			var scratch := T.noise(801, FastNoiseLite.TYPE_SIMPLEX, 0.35, 2)
			var stretch := _stretched(scratch, SIZE / 8, SIZE)
			var blotch := T.noise_image(T.noise(802, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 4), SIZE)
			return T.pack(T.mix(stretch, blotch, 0.35, 0.65), 2.0)
		&"polymer":
			var stipple := T.noise(811, FastNoiseLite.TYPE_CELLULAR, 0.25, 1)
			stipple.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			var soft := T.noise(812, FastNoiseLite.TYPE_SIMPLEX, 0.05, 3)
			return T.pack(T.mix(T.noise_image(stipple, SIZE), T.noise_image(soft, SIZE), 0.7, 0.3), 3.0)
		&"wood":
			# 나뭇결: 가로(U)로 길게 늘인 결
			var grain := T.noise(821, FastNoiseLite.TYPE_SIMPLEX, 0.06, 4)
			var img := T.noise_image(grain, SIZE)
			var long := _stretched(grain, SIZE / 8, SIZE)
			return T.pack(T.mix(long, img, 0.8, 0.2), 4.0)
		&"leather":
			var wrinkle := T.noise(831, FastNoiseLite.TYPE_CELLULAR, 0.06, 2)
			wrinkle.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			var pores := T.noise(832, FastNoiseLite.TYPE_VALUE, 0.7, 1)
			return T.pack(T.mix(T.noise_image(wrinkle, SIZE), T.noise_image(pores, SIZE), 0.75, 0.25), 3.5)
		&"cloth":
			# 짜임: 가로·세로 줄이 엇갈린다
			var bytes := PackedByteArray()
			bytes.resize(SIZE * SIZE * 4)
			var rough := T.noise_image(T.noise(841, FastNoiseLite.TYPE_SIMPLEX, 0.2, 2), SIZE).get_data()
			for y in SIZE:
				for x in SIZE:
					var u := float(x) / 4.0
					var v := float(y) / 4.0
					var over := (int(u) + int(v)) % 2 == 0
					var thread := sin(fposmod(v if over else u, 1.0) * PI)
					var h := clampf(thread * 0.8 + float(rough[(y * SIZE + x) * 4]) / 255.0 * 0.2, 0.0, 1.0)
					var i := (y * SIZE + x) * 4
					var byte := int(h * 255.0)
					bytes[i] = byte
					bytes[i + 1] = byte
					bytes[i + 2] = byte
					bytes[i + 3] = 255
			return T.pack(Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, bytes), 3.0)
	return T.pack(T.noise_image(T.noise(1, FastNoiseLite.TYPE_SIMPLEX, 0.05, 3), SIZE), 3.0)


## w×h 크기로 만든 잡음을 SIZE×SIZE로 늘인다(좁은 쪽 방향으로 결이 길어진다).
static func _stretched(n: FastNoiseLite, w: int, h: int) -> Image:
	var img := n.get_seamless_image(w, h, false, false, 0.1, true)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	return img

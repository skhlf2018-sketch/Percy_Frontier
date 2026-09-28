class_name FoliageTextures
extends RefCounted
## 나무 텍스처(기획서 §23.1 고품질 숲): 잎가지(잎 여럿이 달린 잔가지), 솔잎 가지, 나무껍질 결.
## 잎가지·솔잎은 알파로 모양을 오려 내는 카드에 쓰고, 나무껍질은 법선(RGB)과 높이(A)를 담는다.
## tools/gen_foliage_textures.gd로 미리 만들어 assets/textures/foliage/에 두고, 없으면 그 자리에서 만든다.

const SIZE := 512
const KINDS: Array[StringName] = [&"leaves", &"needles", &"bark"]

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func path_of(kind: StringName) -> String:
	return "res://assets/textures/foliage/%s.png" % kind


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
	match kind:
		&"leaves":
			return _leaves()
		&"needles":
			return _needles()
	return _bark()


## 칠하기 버퍼: 알파와 색을 겹쳐 칠한 뒤 이미지로 만든다.
class Canvas:
	var a := PackedFloat32Array()
	var r := PackedFloat32Array()
	var g := PackedFloat32Array()
	var b := PackedFloat32Array()
	var size: int

	func _init(s: int) -> void:
		size = s
		a.resize(s * s)
		r.resize(s * s)
		g.resize(s * s)
		b.resize(s * s)

	func put(x: int, y: int, cov: float, col: Color) -> void:
		if x < 0 or y < 0 or x >= size or y >= size or cov <= 0.0:
			return
		var i := y * size + x
		var k := clampf(cov, 0.0, 1.0)
		# 위에 칠한 것이 덮는다(알파 합성)
		r[i] = lerpf(r[i], col.r, k)
		g[i] = lerpf(g[i], col.g, k)
		b[i] = lerpf(b[i], col.b, k)
		a[i] = maxf(a[i], k)

	## 둥근 붓으로 선분을 칠한다.
	func line(p0: Vector2, p1: Vector2, radius: float, col0: Color, col1: Color) -> void:
		var steps := int(ceil(p0.distance_to(p1) / maxf(radius * 0.5, 0.5))) + 1
		for s in steps + 1:
			var t := float(s) / float(maxi(steps, 1))
			var p := p0.lerp(p1, t)
			var col := col0.lerp(col1, t)
			var rr := int(ceil(radius + 1.0))
			for dy in range(-rr, rr + 1):
				for dx in range(-rr, rr + 1):
					var d := Vector2(dx, dy).length()
					put(int(p.x) + dx, int(p.y) + dy, clampf(radius + 0.5 - d, 0.0, 1.0), col)

	func to_image() -> Image:
		var bytes := PackedByteArray()
		bytes.resize(size * size * 4)
		for i in size * size:
			# 가장자리 색이 검게 번지지 않도록 칠하지 않은 곳에도 둘레 색을 남겨 둔다(밉맵용).
			bytes[i * 4] = int(clampf(r[i], 0.0, 1.0) * 255.0)
			bytes[i * 4 + 1] = int(clampf(g[i], 0.0, 1.0) * 255.0)
			bytes[i * 4 + 2] = int(clampf(b[i], 0.0, 1.0) * 255.0)
			bytes[i * 4 + 3] = int(clampf(a[i], 0.0, 1.0) * 255.0)
		var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
		img.fix_alpha_edges()
		img.generate_mipmaps()
		return img


## 잎가지 뭉치: 밑에서 부챗살처럼 뻗은 잔가지 다섯 개에 작은 잎이 빽빽이 달렸다(카드 넓이의 절반 가까이를 덮는다).
## 뒤쪽 잎은 짙게 먼저 칠하고, 앞쪽 잎은 밝게 나중에 칠한다. 잎마다 밝기와 누런 기가 조금씩 다르다.
static func _leaves() -> Image:
	var c := Canvas.new(SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001
	var twigs := 5
	for layer in 2:
		for tw in twigs:
			var base := Vector2(SIZE * 0.5 + rng.randf_range(-24.0, 24.0), SIZE * 0.98)
			var ang := deg_to_rad(lerpf(-38.0, 38.0, float(tw) / float(twigs - 1)) + rng.randf_range(-9.0, 9.0))
			var dir := Vector2(sin(ang), -cos(ang))
			var length := SIZE * rng.randf_range(0.66, 0.9) * (0.9 if layer == 0 else 1.0)
			var bend := Vector2(-dir.y, dir.x) * rng.randf_range(-40.0, 40.0)
			var mid := base + dir * length * 0.5 + bend * 0.5
			var tip := base + dir * length + bend
			if layer == 1:
				c.line(base, mid, 2.2, Color(0.34, 0.28, 0.19), Color(0.36, 0.33, 0.21))
				c.line(mid, tip, 1.6, Color(0.36, 0.33, 0.21), Color(0.4, 0.42, 0.24))
			var count := 15
			for i in count:
				var t := lerpf(0.18, 1.0, float(i) / float(count - 1))
				var at := base.lerp(mid, minf(t * 2.0, 1.0)) if t < 0.5 else mid.lerp(tip, (t - 0.5) * 2.0)
				var twig_dir := (mid - base).normalized() if t < 0.5 else (tip - mid).normalized()
				var side := -1.0 if i % 2 == 0 else 1.0
				var la := atan2(twig_dir.x, -twig_dir.y) + deg_to_rad(rng.randf_range(38.0, 70.0)) * side
				var ld := Vector2(sin(la), -cos(la))
				var ll := lerpf(82.0, 52.0, t) * rng.randf_range(0.85, 1.12)
				var shade := rng.randf_range(0.8, 1.08) * (0.72 if layer == 0 else 1.0)
				var yellow := rng.randf_range(0.0, 0.22)
				var leaf := Color(0.58, 0.74, 0.4).lerp(Color(0.78, 0.76, 0.38), yellow) * shade
				_leaf(c, at, ld, ll, ll * rng.randf_range(0.4, 0.5), leaf)
	return c.to_image()


## 잎 한 장: 끝이 뾰족한 렌즈 모양, 가운데 잎맥은 옅고 가장자리는 짙다.
static func _leaf(c: Canvas, base: Vector2, dir: Vector2, length: float, width: float, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var tip := base + dir * length
	var lo := Vector2(minf(base.x, tip.x), minf(base.y, tip.y)) - Vector2(width, width)
	var hi := Vector2(maxf(base.x, tip.x), maxf(base.y, tip.y)) + Vector2(width, width)
	for y in range(int(lo.y), int(hi.y) + 1):
		for x in range(int(lo.x), int(hi.x) + 1):
			var p := Vector2(x, y) - base
			var u := p.dot(dir) / length
			if u < 0.0 or u > 1.0:
				continue
			var v := p.dot(side) / (width * 0.5)
			var half := pow(sin(PI * clampf(u * 0.92 + 0.04, 0.0, 1.0)), 0.75)
			var edge := half - absf(v)
			if edge <= 0.0:
				continue
			var cov := clampf(edge * width * 0.5, 0.0, 1.0)
			var shade := lerpf(0.72, 1.0, clampf(edge / maxf(half, 0.01), 0.0, 1.0))
			var rib := smoothstep(0.08, 0.0, absf(v)) * 0.35
			var vein := smoothstep(0.1, 0.0, absf(fposmod(u * 7.0 - absf(v) * 1.6, 1.0) - 0.5) - 0.42) * 0.12
			var colp := col * shade
			colp = colp.lerp(Color(0.9, 0.95, 0.7), rib + vein)
			c.put(x, y, cov, Color(colp.r, colp.g, colp.b))


## 솔잎 가지: 가운데 잔가지 양쪽으로 가는 솔잎이 비스듬히 빽빽하다. 끝으로 갈수록 짧아진다.
static func _needles() -> Image:
	var c := Canvas.new(SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7101
	var stem0 := Vector2(SIZE * 0.5, SIZE * 0.99)
	var stem1 := Vector2(SIZE * 0.5, SIZE * 0.03)
	for layer in 2:
		var count := 64
		for i in count:
			var t := lerpf(0.02, 0.98, float(i) / float(count - 1)) + rng.randf_range(-0.006, 0.006)
			var base := stem0.lerp(stem1, t)
			for side: float in [-1.0, 1.0]:
				var ang := deg_to_rad(rng.randf_range(42.0, 66.0) + layer * 10.0) * side
				var length := lerpf(120.0, 60.0, t) * rng.randf_range(0.8, 1.15) * (0.85 if layer == 1 else 1.0)
				var dir := Vector2(sin(ang), -cos(ang))
				var shade := rng.randf_range(0.75, 1.1) * (0.85 if layer == 0 else 1.0)
				var col := Color(0.42, 0.6, 0.42) * shade
				c.line(base, base + dir * length, 1.6, col.darkened(0.2), col.lightened(0.1))
	c.line(stem0, stem1, 3.0, Color(0.33, 0.25, 0.17), Color(0.38, 0.32, 0.2))
	return c.to_image()


## 나무껍질: 세로로 길게 갈라진 골과 거친 결(법선 RGB + 높이 A)
static func _bark() -> Image:
	var fibers := FastNoiseLite.new()
	fibers.seed = 7201
	fibers.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fibers.frequency = 0.05
	fibers.fractal_octaves = 4
	# 세로(V, 줄기 방향)로 길게 늘인 결
	var a := fibers.get_seamless_image(SIZE, SIZE / 8, false, false, 0.1, true)
	a.convert(Image.FORMAT_RGBA8)
	a.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	var cracks := FastNoiseLite.new()
	cracks.seed = 7202
	cracks.noise_type = FastNoiseLite.TYPE_CELLULAR
	cracks.frequency = 0.03
	cracks.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cracks.fractal_type = FastNoiseLite.FRACTAL_NONE
	var b := cracks.get_seamless_image(SIZE, SIZE / 4, false, false, 0.1, true)
	b.convert(Image.FORMAT_RGBA8)
	b.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	var ab := a.get_data()
	var bb := b.get_data()
	var hb := PackedByteArray()
	hb.resize(SIZE * SIZE * 4)
	for i in SIZE * SIZE:
		var v := clampf(float(ab[i * 4]) / 255.0 * 0.55 + smoothstep(0.0, 0.35, float(bb[i * 4]) / 255.0) * 0.45, 0.0, 1.0)
		var byte := int(v * 255.0)
		hb[i * 4] = byte
		hb[i * 4 + 1] = byte
		hb[i * 4 + 2] = byte
		hb[i * 4 + 3] = 255
	var height := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, hb)
	var normal := height.duplicate() as Image
	normal.bump_map_to_normal_map(8.0)
	var nb := normal.get_data()
	for i in SIZE * SIZE:
		nb[i * 4 + 3] = hb[i * 4]
	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, nb)
	img.generate_mipmaps()
	return img

class_name SmokeCloud
extends Node3D
## 짙은 연기 구름(고블린 투척병의 연기 폭탄). 부풀었다가 천천히 흩어진다. 시야를 가리는 것 말고 피해는 없다.

var radius: float = 4.0
var life: float = 7.0

var _particles: CPUParticles3D
var _t: float = 0.0

static var _puff_texture: Texture2D


static func spawn(ctx: Node, at: Vector3, r: float, duration: float) -> SmokeCloud:
	if ctx == null or not ctx.is_inside_tree():
		return null
	var tree := ctx.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	var c := SmokeCloud.new()
	c.radius = r
	c.life = duration
	parent.add_child(c)
	c.global_position = at
	return c


static func puff_texture() -> Texture2D:
	if _puff_texture:
		return _puff_texture
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	n.fractal_octaves = 3
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (0.65 + 0.35 * n.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_puff_texture = ImageTexture.create_from_image(img)
	return _puff_texture


func _ready() -> void:
	_particles = CPUParticles3D.new()
	_particles.amount = 26
	_particles.lifetime = life
	_particles.one_shot = true
	_particles.explosiveness = 0.85
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = radius * 0.35
	_particles.direction = Vector3.UP
	_particles.spread = 180.0
	_particles.initial_velocity_min = radius * 0.2
	_particles.initial_velocity_max = radius * 0.45
	_particles.damping_min = radius * 0.1
	_particles.damping_max = radius * 0.2
	_particles.gravity = Vector3(0, 0.08, 0)
	_particles.scale_amount_min = radius * 0.55
	_particles.scale_amount_max = radius * 0.9
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 1.25))
	_particles.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.62, 0.62, 0.6, 0.0))
	grad.set_color(1, Color(0.55, 0.55, 0.53, 0.0))
	grad.add_point(0.08, Color(0.62, 0.62, 0.6, 0.92))
	grad.add_point(0.7, Color(0.58, 0.58, 0.56, 0.75))
	_particles.color_ramp = grad
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	_particles.mesh = qm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = puff_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 1.0
	_particles.material_override = m
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	_particles.emitting = true


func _process(delta: float) -> void:
	_t += delta
	if _t > life + 0.5:
		queue_free()

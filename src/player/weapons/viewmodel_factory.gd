class_name ViewmodelFactory
extends RefCounted
## 회색 상자 단계의 임시 1인칭 무기 모델. 기본 도형을 조합해 무기군마다 다른 실루엣을 만든다.
## 정식 3D 모델이 준비되면 교체한다(기획서 §23.4).
##
## 좌표: -Z가 총구 방향, +Y가 위. 근접 무기는 +Y 방향으로 날을 세운다.
## 반환: { "root": Node3D, "muzzle": Marker3D(총기), "ads_offset": Vector3(총기) }

const SHADER := preload("res://assets/shaders/viewmodel.gdshader")


static func build_gun(data: WeaponData) -> Dictionary:
	var root := Node3D.new()
	root.name = "VM_%s" % data.id
	var body := _mat(data.body_color, 0.6, 0.35)
	var accent := _mat(data.accent_color, 0.5, 0.2)
	var dark := _mat(data.body_color.darkened(0.45), 0.7, 0.3)
	var muzzle_pos := Vector3(0, 0.02, -0.5)
	var ads := Vector3(0, -0.075, -0.3)
	match data.viewmodel_style:
		&"pistol":
			_box(root, Vector3(0.042, 0.048, 0.2), Vector3(0, 0.02, 0), body)
			_box(root, Vector3(0.036, 0.12, 0.052), Vector3(0, -0.058, 0.055), accent, Vector3(-14, 0, 0))
			_box(root, Vector3(0.03, 0.02, 0.07), Vector3(0, -0.012, -0.04), dark)
			_box(root, Vector3(0.012, 0.014, 0.012), Vector3(0, 0.05, -0.085), dark)
			_box(root, Vector3(0.024, 0.014, 0.012), Vector3(0, 0.05, 0.085), dark)
			muzzle_pos = Vector3(0, 0.022, -0.11)
			ads = Vector3(0, -0.05, -0.3)
		&"shotgun":
			_box(root, Vector3(0.07, 0.09, 0.3), Vector3(0, 0, 0), body)
			_cyl(root, 0.021, 0.52, Vector3(0, 0.025, -0.4), dark)
			_box(root, Vector3(0.062, 0.058, 0.16), Vector3(0, -0.03, -0.3), accent)
			_box(root, Vector3(0.055, 0.11, 0.26), Vector3(0, -0.03, 0.27), accent, Vector3(8, 0, 0))
			_box(root, Vector3(0.012, 0.016, 0.012), Vector3(0, 0.05, -0.64), dark)
			muzzle_pos = Vector3(0, 0.025, -0.67)
			ads = Vector3(0, -0.06, -0.34)
		&"energy":
			var glow := _mat(data.accent_color, 0.3, 0.1, data.accent_color, 3.0)
			_box(root, Vector3(0.09, 0.12, 0.42), Vector3(0, 0, 0), body)
			_cyl(root, 0.024, 0.34, Vector3(0, 0.02, -0.34), dark)
			for i in 3:
				_torus(root, 0.032, 0.046, Vector3(0, 0.02, -0.22 - i * 0.07), glow)
			_box(root, Vector3(0.02, 0.06, 0.16), Vector3(0.055, -0.01, 0.04), glow)
			_box(root, Vector3(0.045, 0.11, 0.05), Vector3(0, -0.1, 0.1), accent, Vector3(-12, 0, 0))
			_box(root, Vector3(0.05, 0.03, 0.09), Vector3(0, 0.075, 0.0), dark)
			muzzle_pos = Vector3(0, 0.02, -0.52)
			ads = Vector3(0, -0.09, -0.32)
		&"sniper":
			_box(root, Vector3(0.06, 0.08, 0.5), Vector3(0, 0, 0), body)
			_cyl(root, 0.015, 0.56, Vector3(0, 0.02, -0.52), dark)
			_cyl(root, 0.027, 0.3, Vector3(0, 0.078, -0.02), dark)
			_box(root, Vector3(0.055, 0.12, 0.27), Vector3(0, -0.035, 0.37), accent, Vector3(6, 0, 0))
			_box(root, Vector3(0.045, 0.1, 0.05), Vector3(0, -0.09, 0.12), accent, Vector3(-12, 0, 0))
			_box(root, Vector3(0.05, 0.015, 0.015), Vector3(0.045, 0.02, 0.12), dark)
			_box(root, Vector3(0.04, 0.12, 0.05), Vector3(0, -0.1, -0.08), dark)
			muzzle_pos = Vector3(0, 0.02, -0.81)
			ads = Vector3(0, -0.078, -0.25)
		_:
			# 소총
			_box(root, Vector3(0.07, 0.1, 0.42), Vector3(0, 0, 0), body)
			_cyl(root, 0.016, 0.3, Vector3(0, 0.02, -0.34), dark)
			_box(root, Vector3(0.066, 0.072, 0.2), Vector3(0, 0.008, -0.25), accent)
			_box(root, Vector3(0.045, 0.15, 0.062), Vector3(0, -0.11, -0.05), dark, Vector3(12, 0, 0))
			_box(root, Vector3(0.05, 0.095, 0.21), Vector3(0, -0.02, 0.29), accent)
			_box(root, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.095, 0.1), dark, Vector3(-14, 0, 0))
			_box(root, Vector3(0.022, 0.032, 0.06), Vector3(0, 0.067, 0.02), dark)
			_box(root, Vector3(0.01, 0.03, 0.01), Vector3(0, 0.065, -0.3), dark)
			muzzle_pos = Vector3(0, 0.02, -0.5)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = muzzle_pos
	root.add_child(muzzle)
	return {"root": root, "muzzle": muzzle, "ads_offset": ads}


static func build_melee(data: MeleeData) -> Dictionary:
	var root := Node3D.new()
	root.name = "VM_%s" % data.id
	var blade := _mat(data.body_color, 0.25, 0.85)
	var grip := _mat(data.accent_color, 0.8, 0.05)
	var guard := _mat(data.accent_color.lightened(0.25), 0.5, 0.6)
	match data.viewmodel_style:
		&"karambit":
			_box(root, Vector3(0.026, 0.11, 0.032), Vector3(0, 0, 0), grip)
			_torus(root, 0.016, 0.026, Vector3(0, -0.075, 0), guard, Vector3(0, 0, 90))
			_box(root, Vector3(0.006, 0.07, 0.03), Vector3(0, 0.085, -0.012), blade, Vector3(-20, 0, 0))
			_box(root, Vector3(0.006, 0.06, 0.026), Vector3(0, 0.135, -0.05), blade, Vector3(-55, 0, 0))
			_box(root, Vector3(0.006, 0.05, 0.02), Vector3(0, 0.155, -0.1), blade, Vector3(-95, 0, 0))
		_:
			_cyl(root, 0.018, 0.17, Vector3(0, 0, 0), grip, Vector3.ZERO)
			_box(root, Vector3(0.15, 0.024, 0.035), Vector3(0, 0.095, 0), guard)
			_box(root, Vector3(0.038, 0.72, 0.008), Vector3(0, 0.47, 0), blade)
			_box(root, Vector3(0.026, 0.06, 0.007), Vector3(0, 0.855, 0), blade, Vector3(0, 0, 45))
			_cyl(root, 0.024, 0.03, Vector3(0, -0.095, 0), guard, Vector3.ZERO)
	return {"root": root}


static func _mat(color: Color, roughness: float, metallic: float,
		emission: Color = Color.BLACK, emission_energy: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", roughness)
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("emission_energy", emission_energy)
	return m


static func _add(root: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(root, mesh, pos, mat, rot_deg)


## 원기둥. 기본은 -Z 방향(총열)으로 눕힌다.
static func _cyl(root: Node3D, radius: float, length: float, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3(90, 0, 0)) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 1
	return _add(root, mesh, pos, mat, rot_deg)


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

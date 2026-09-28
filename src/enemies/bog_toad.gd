class_name BogToad
extends Enemy
## 늪 두꺼비: 길게 뻗는 혀로 끌어당기고(혀 휘감기는 흘려 낼 수 있다), 몸으로 덮치고(막을 수 없다), 쓸개즙을 뱉는다.

var _tongue: MeshInstance3D = null
var _tongue_t: float = -1.0
var _tongue_len: float = 0.0


func _on_attack_active(a: EnemyAttackData) -> void:
	if a.id == &"tongue_lash":
		_tongue_len = a.reach
		if target:
			_tongue_len = minf(a.reach, global_position.distance_to(target.global_position) + 0.3)
		_tongue_t = 0.0
		Sfx.play_at(&"spear_whoosh", global_position + Vector3.UP * eye_height, 0.0, 1.4)


func _anim_action() -> StringName:
	if state == State.ATTACK and _attack and _attack.id == &"tongue_lash":
		return &"windup" if _attack_phase == AttackPhase.WINDUP else &"strike"
	return super._anim_action()


func _process(delta: float) -> void:
	super._process(delta)
	if _tongue_t < 0.0:
		if _tongue:
			_tongue.visible = false
		return
	_tongue_t += delta
	var dur := 0.45
	var k := sin(clampf(_tongue_t / dur, 0.0, 1.0) * PI)
	if _tongue_t >= dur:
		_tongue_t = -1.0
	if _tongue == null:
		_tongue = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.06
		cm.height = 1.0
		cm.radial_segments = 8
		_tongue.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.75, 0.35, 0.38)
		m.roughness = 0.25
		m.clearcoat_enabled = true
		m.clearcoat = 0.8
		_tongue.material_override = m
		_tongue.top_level = true
		add_child(_tongue)
	var from := global_position + Vector3.UP * (eye_height * 0.7) - global_basis.z * 0.55
	var dir := -global_basis.z
	if target:
		var to := target.get_chest_position() - from
		if to.length_squared() > 0.01:
			dir = to.normalized()
	var length := maxf(_tongue_len * k, 0.05)
	_tongue.visible = true
	_tongue.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK) \
		* Basis(Vector3.RIGHT, PI * 0.5), from + dir * length * 0.5)
	_tongue.scale = Vector3(1.0, length, 1.0)

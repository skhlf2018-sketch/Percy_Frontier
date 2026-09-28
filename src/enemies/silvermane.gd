class_name Silvermane
extends Wolf
## 은갈기 늑대(희귀): 안개 낀 밤에만 나타난다. 물린 자리가 얼어붙는다.
## 안개 걸음: 안개로 몸을 감춰 전혀 다른 쪽으로 옮긴 뒤 곧바로 덮친다. 옮겨 갈 자리에 먼저 서리 자국이 번진다.

const MIST_TIME := 1.1
const MIST_RADIUS := 6.0

var _mist_left: float = -1.0
var _mist_dest := Vector3.ZERO
var _frost_marks: Array[Node3D] = []


func _on_attack_active(a: EnemyAttackData) -> void:
	if a.id != &"mist_step" or target == null:
		return
	# 플레이어 옆이나 뒤쪽의 땅
	var side := 1.0 if randf() < 0.5 else -1.0
	var ang := target.yaw + side * deg_to_rad(randf_range(100.0, 170.0))
	var p := target.global_position + Vector3(-sin(ang), 0.0, -cos(ang)) * MIST_RADIUS
	_mist_dest = _ground(p)
	_mist_left = MIST_TIME
	Sfx.play_at(&"frost_mist", global_position + Vector3.UP, 0.0)
	CombatFx.explosion(self, global_position + Vector3.UP * 0.5, 1.6, Color(0.8, 0.9, 1.0, 0.5))
	_spawn_frost_mark(_mist_dest)
	_set_hidden(true)


func _set_hidden(value: bool) -> void:
	if _visual:
		_visual.visible = not value
	for hb in _hurtboxes:
		hb.set_enabled(not value)
	collision_layer = 0 if value else CombatLayers.ENEMY


func _physics_process(delta: float) -> void:
	if _mist_left >= 0.0 and state != State.DEAD:
		_mist_left -= delta
		velocity = Vector3.ZERO
		if _mist_left < 0.0:
			global_position = _mist_dest
			_set_hidden(false)
			Sfx.play_at(&"wolf_growl", global_position + Vector3.UP, 2.0, 0.8)
			CombatFx.explosion(self, global_position + Vector3.UP * 0.5, 1.4, Color(0.8, 0.9, 1.0, 0.5))
			# 나타나자마자 서리 물기
			var bite: EnemyAttackData = null
			for a in data.attacks:
				if a.id == &"frost_bite":
					bite = a
			if bite and target and target.alive:
				_cooldowns.erase(bite.id)
				_face_direction(_flat_dir_to(target.global_position), 10.0)
				if target.request_attack_token(self, bite.token_group):
					_start_attack(bite)
					_attack_timer = 0.45 * _telegraph_mult()
		return
	super._physics_process(delta)


func _die(info: DamageInfo, zone: int) -> void:
	_set_hidden(false)
	super._die(info, zone)


func _ground(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 8.0, CombatLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else p


## 서리 자국: 땅에 번지는 옅은 원판(몇 초 뒤 사라진다)
func _spawn_frost_mark(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.9
	cm.height = 0.02
	cm.radial_segments = 20
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.93, 1.0, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.6, 0.8, 1.0)
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(mi)
	mi.global_position = at + Vector3.UP * 0.03
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 3.0).set_delay(1.5)
	tw.tween_callback(mi.queue_free)

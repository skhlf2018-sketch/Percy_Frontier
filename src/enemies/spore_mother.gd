class_name SporeMother
extends Enemy
## 포자 모체(정예): 움직이지 않는다. 둘레에 포자낭을 낳고(최대 넷), 불붙는 포자 구름을 뱉는다.
## 숨을 들이쉴 때(3초) 갓이 벌어지며 붉은 핵이 드러난다. 핵은 큰 약점이다.

const MAX_PODS := 4

var _pods: Array[Enemy] = []
var _core: Hurtbox = null


func _on_ready() -> void:
	for hb in find_children("CoreHurtbox", "Hurtbox", true, false):
		_core = hb


func _process_chase(delta: float) -> void:
	_stop(delta)
	if target == null or not target.alive:
		_lose_target()
		return
	_face_toward(target.global_position, delta)
	_try_start_attack()


func _process_return(delta: float) -> void:
	_stop(delta)
	hp = minf(data.max_hp, hp + data.max_hp * RETURN_HEAL_PER_SEC * delta)
	if _state_time > 3.0:
		awareness = 0.0
		_set_state(State.IDLE)


func _process_investigate(delta: float) -> void:
	_stop(delta)
	_set_state(State.IDLE)


func _attack_allowed(a: EnemyAttackData) -> bool:
	if a.id == &"birth_pod":
		_pods = _pods.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and e.is_alive())
		return _pods.size() < MAX_PODS
	return true


func _on_attack_windup(a: EnemyAttackData) -> void:
	if a.id == &"bloom":
		Sfx.play_at(&"spit_charge", global_position + Vector3.UP * 1.5, 2.0, 0.5)


func _on_attack_active(a: EnemyAttackData) -> void:
	match a.id:
		&"birth_pod":
			_spawn_pod()
		&"bloom":
			if _core:
				_core.set_enabled(true)
			GameEvents.notify("%s의 핵이 드러났다" % data.display_name, GameEvents.NoticeKind.INFO)


## 숨 들이쉬기(판정 시간) 동안만 핵이 열린다.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _core and _core.is_enabled():
		var blooming := state == State.ATTACK and _attack != null and _attack.id == &"bloom" \
			and _attack_phase == AttackPhase.ACTIVE
		if not blooming:
			_core.set_enabled(false)


func stagger(duration: float, forced: bool) -> void:
	super.stagger(duration, forced)
	if _core:
		_core.set_enabled(false)


func _spawn_pod() -> void:
	var e := EnemyBody.create(&"bloat_pod")
	if e == null:
		return
	var ang := randf() * TAU
	var r := randf_range(3.0, 6.0)
	var at := global_position + Vector3(cos(ang), 0.0, sin(ang)) * r
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 8.0, CombatLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = hit.position
	var parent: Node = get_parent()
	parent.add_child(e)
	e.global_position = at
	e.reset_physics_interpolation()
	_pods.append(e)
	CombatFx.explosion(self, at + Vector3.UP * 0.3, 1.2, Color(0.8, 0.6, 0.3, 0.5))
	Sfx.play_at(&"sac_burst", at, -4.0, 1.4)


func _on_died() -> void:
	# 모체가 죽으면 낳은 포자낭은 곧 연달아 터진다.
	for e in _pods:
		if is_instance_valid(e) and e is BloatPod and e.is_alive():
			(e as BloatPod).chain_trigger()


func _anim_action() -> StringName:
	if state == State.ATTACK and _attack:
		if _attack.id == &"bloom" and _attack_phase == AttackPhase.ACTIVE:
			return &"open"
		if _attack_phase == AttackPhase.WINDUP:
			return &"cast" if _attack.id == &"bloom" else &"windup"
	return &""

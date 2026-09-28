class_name BloatPod
extends Enemy
## 부푼 포자낭: 움직이지 않는다. 가까이 오면 부풀어 오르다 터져 불붙는 포자를 뿌린다.
## 쏘아서 터뜨리면 그 자리에서 터지며, 곁의 적과 다른 포자낭도 휘말린다(다른 포자낭은 곧이어 연달아 터진다).

const CHAIN_DELAY := 0.25

var _burst: bool = false
var _chain_timer: float = -1.0


func _process_chase(delta: float) -> void:
	_stop(delta)
	if target and target.alive:
		_try_start_attack()


func _process_return(delta: float) -> void:
	_stop(delta)
	hp = data.max_hp
	awareness = 0.0
	_set_state(State.IDLE)


func _process_investigate(delta: float) -> void:
	_stop(delta)
	_set_state(State.IDLE)


func _face_direction(_dir: Vector3, _delta: float) -> void:
	pass


func _on_attack_windup(_a: EnemyAttackData) -> void:
	Sfx.play_at(&"spit_charge", global_position + Vector3.UP * 0.6, 0.0, 0.8)


func _on_attack_active(a: EnemyAttackData) -> void:
	if a.id == &"swell_burst":
		explode()


## 가까운 포자낭이 터지면 잠시 뒤 이것도 터진다.
func chain_trigger() -> void:
	if not _burst and state != State.DEAD and _chain_timer < 0.0:
		_chain_timer = CHAIN_DELAY


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _chain_timer >= 0.0 and state != State.DEAD:
		_chain_timer -= delta
		if _chain_timer < 0.0:
			explode()


func _die(info: DamageInfo, zone: int) -> void:
	super._die(info, zone)
	if not _burst:
		explode()


## 터진다: 둘레의 플레이어·적에게 피해와 화상, 다른 포자낭을 연달아 터뜨린다.
func explode() -> void:
	if _burst:
		return
	_burst = true
	var a: EnemyAttackData = data.attacks[0] if not data.attacks.is_empty() else null
	var radius := a.projectile_blast_radius if a else 3.5
	var center := global_position + Vector3.UP * 0.5
	CombatFx.explosion(self, center, radius, Color(1.0, 0.55, 0.15))
	Sfx.play_at(&"sac_burst", center, 4.0, 0.8)
	Hearing.emit(get_tree(), center, 25.0, self, Hearing.Kind.EXPLOSION)
	if a:
		Enemy.projectile_blast(self, a, global_position, weakref(self))
	for e in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e == self or not (e is Enemy) or not e.is_alive():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d > radius:
			continue
		if e is BloatPod:
			(e as BloatPod).chain_trigger()
		else:
			var info := DamageInfo.create(a.damage if a else 18.0, DamageInfo.Kind.EXPLOSION, self)
			info.status_buildup = a.status_buildup() if a else {}
			info.hit_position = center
			info.direction = (e.global_position - center).normalized()
			info.knockback = 4.0
			e.receive_hit(info, null)
	if state != State.DEAD:
		hp = 0.0
		_die(null, Hurtbox.Zone.NORMAL)
	if _visual:
		_visual.visible = false


func _anim_action() -> StringName:
	if state == State.ATTACK and _attack_phase == AttackPhase.WINDUP:
		return &"windup"
	return &""

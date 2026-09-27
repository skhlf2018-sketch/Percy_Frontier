class_name TrainingDummy
extends Enemy
## 훈련용 표적. 머리 약점과 가슴 장갑판으로 부위 판정·장갑 파괴·처치 피드백을 시험한다.
## 공격하지 않으며, 피해를 받지 않으면 HP가 복구되고 부서진 장갑도 다시 붙는다. 쓰러지면 잠시 뒤 일어난다.
## 도감·분석·보상 대상이 아니다.

const REGEN_DELAY := 3.0
const ARMOR_RESTORE_DELAY := 6.0
const REVIVE_TIME := 2.5

## 좌우 왕복 거리(0이면 고정 표적)
@export var sway_distance: float = 0.0
@export var sway_speed: float = 0.6

var _armor_broken_at: float = -1.0
var _sway_time: float = 0.0


func _on_ready() -> void:
	status.resistance = {
		StatusEffects.Type.BURN: 1.0, StatusEffects.Type.CHILL: 1.0,
		StatusEffects.Type.SHOCK: 1.0, StatusEffects.Type.BLEED: 1.0,
	}


func hear_noise(_position: Vector3, _radius: float, _source: Node, _kind: int) -> void:
	pass


func _perceive() -> void:
	pass


func _process_state(delta: float) -> void:
	if state == State.STAGGER or state == State.STUNNED:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_set_state(State.IDLE)
	if _clock - _last_damaged_time > REGEN_DELAY and hp < data.max_hp:
		hp = minf(data.max_hp, hp + data.max_hp * delta)
	if _armor_broken_at >= 0.0 and _clock - _armor_broken_at > ARMOR_RESTORE_DELAY:
		_armor_broken_at = -1.0
		for hb in _hurtboxes:
			if hb.zone == Hurtbox.Zone.ARMOR:
				hb.restore_armor()
	if sway_distance > 0.0 and state == State.IDLE and not status.is_frozen():
		_sway_time += delta
		var right := home_basis_right()
		var desired := home_position + right * sin(_sway_time * sway_speed * TAU / 2.0) * sway_distance
		var to := desired - global_position
		to.y = 0.0
		velocity.x = to.x / maxf(delta, 0.001)
		velocity.z = to.z / maxf(delta, 0.001)
	else:
		_stop(delta)


func home_basis_right() -> Vector3:
	return Basis(Vector3.UP, home_yaw).x


func _on_armor_broken(_hb: Hurtbox) -> void:
	_armor_broken_at = _clock


func _reward(_info: DamageInfo, _zone: int) -> void:
	pass


func _process_dead(delta: float) -> void:
	if _visual:
		_visual.rotation.x = lerpf(_visual.rotation.x, -PI * 0.45, 1.0 - exp(-8.0 * delta))
	_corpse_timer -= delta
	if _corpse_timer <= CORPSE_TIME - REVIVE_TIME:
		_revive()


func _revive() -> void:
	hp = data.max_hp
	poise = data.poise
	status.clear_all()
	for hb in _hurtboxes:
		hb.set_enabled(true)
		if hb.zone == Hurtbox.Zone.ARMOR:
			hb.restore_armor()
	collision_layer = CombatLayers.ENEMY
	collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY
	if _visual:
		_visual.rotation = Vector3.ZERO
		_visual.scale = Vector3.ONE
	_armor_broken_at = -1.0
	_set_state(State.IDLE)

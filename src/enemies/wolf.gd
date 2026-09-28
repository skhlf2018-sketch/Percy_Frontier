class_name Wolf
extends Enemy
## 잿빛 늑대: 무리 사냥. 한 마리가 앞에서 시선을 끄는 동안 나머지는 옆과 뒤로 돌아 들어온다(포위).
## - 무리 안 순서대로 플레이어 둘레의 자리(앞, 좌우, 뒤)를 맡는다. 자리를 잡거나 오래 기다리면 뛰어든다.
## - 우두머리의 울음을 들으면 잠시 더 빠르고 공격이 잦아진다.
## - 무리를 모두 잃고 크게 다치면 달아난다.

const RING_RADIUS := 4.8
const SLOT_ANGLES := [0.0, 110.0, -110.0, 180.0, 60.0, -60.0]
const BUFF_SPEED := 1.25
const BUFF_COOLDOWN := 0.65
const FLEE_HEALTH := 0.25

var buff_until: float = -100.0
var _slot: int = 0
var _in_slot_time: float = 0.0
var _fled: bool = false
var _growl_timer: float = 0.0


func _on_ready() -> void:
	_growl_timer = randf_range(2.0, 5.0)


func is_buffed() -> bool:
	return _clock < buff_until


func buff(duration: float) -> void:
	buff_until = maxf(buff_until, _clock + duration)


func _pack() -> Array[Wolf]:
	var out: Array[Wolf] = []
	for e in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e is Wolf and e.is_alive() and e.global_position.distance_to(global_position) < 40.0:
			out.append(e)
	return out


## 무리 안에서 맡을 자리(인스턴스 순서로 정한다)
func _update_slot() -> void:
	var pack := _pack()
	pack.sort_custom(func(a: Wolf, b: Wolf) -> bool: return a.get_instance_id() < b.get_instance_id())
	_slot = maxi(pack.find(self), 0)


func _call_pack() -> void:
	# 늑대는 종이 달라도(우두머리·은갈기) 같은 무리로 모인다.
	if target == null or state == State.DEAD:
		return
	Sfx.play_at(&"wolf_growl", global_position + Vector3.UP * eye_height)
	for w in _pack():
		if w != self and w.global_position.distance_to(global_position) <= data.pack_alert_radius:
			w.alert(target)


func _on_alerted() -> void:
	Sfx.play_at(&"wolf_growl", global_position + Vector3.UP * eye_height, -2.0, randf_range(0.9, 1.1))


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if not _fled and health_ratio() < FLEE_HEALTH and _pack().size() <= 1:
		_fled = true
		_set_state(State.FLEE)
		return
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = randf_range(3.0, 6.0)
		Sfx.play_at(&"wolf_growl", global_position + Vector3.UP * eye_height, -6.0, randf_range(0.85, 1.15))
	_update_slot()
	var speed := data.run_speed * (BUFF_SPEED if is_buffed() else 1.0)
	var dist := global_position.distance_to(target.global_position)
	# 자리: 플레이어가 보는 방향 기준으로 앞·옆·뒤
	var angle := deg_to_rad(float(SLOT_ANGLES[_slot % SLOT_ANGLES.size()]))
	var yaw := target.yaw
	var dir := Vector3(-sin(yaw + angle), 0.0, -cos(yaw + angle))
	var slot_point := target.global_position + dir * RING_RADIUS
	var at_slot := global_position.distance_to(slot_point) < 1.6
	_in_slot_time = _in_slot_time + delta if at_slot else maxf(0.0, _in_slot_time - delta * 0.5)
	# 앞자리 늑대나, 옆·뒤 자리를 잡았거나, 오래 맴돈 늑대가 뛰어든다.
	var may_attack := _slot == 0 or _in_slot_time > 0.4 or dist < 2.4 or _state_time > 6.0
	if may_attack and _try_start_attack():
		_in_slot_time = 0.0
		return
	if dist > RING_RADIUS * 2.5 or not _sees_target:
		_move_toward(last_known_position, speed, delta)
	else:
		_move_toward(slot_point, speed * (0.75 if at_slot else 1.0), delta)
		_face_toward(target.global_position, delta)


func _start_attack(a: EnemyAttackData) -> void:
	super._start_attack(a)
	if is_buffed():
		_attack_timer *= 0.8


func _end_attack(completed: bool) -> void:
	var was := _attack
	super._end_attack(completed)
	if was and is_buffed() and _cooldowns.has(was.id):
		_cooldowns[was.id] = float(_cooldowns[was.id]) * BUFF_COOLDOWN

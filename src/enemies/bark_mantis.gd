class_name BarkMantis
extends Enemy
## 나무껍질 사마귀: 나뭇가지처럼 꼼짝 않고 서 있다가 가까이 오면 벤다. 가만히 있을 때는 멀리서 알아채지 못한다.
## 두 번 베기는 판정이 두 번이다(첫 번째만 막고 방심하면 두 번째에 맞는다).

const REVEAL_DISTANCE := 5.0
const SECOND_HIT_DELAY := 0.18

var hidden: bool = true
var _second_hit: float = -1.0


func _perceive() -> void:
	if hidden and state == State.IDLE:
		var p := _find_player()
		if p and p.alive and global_position.distance_to(p.global_position) < REVEAL_DISTANCE \
				and CombatQuery.has_line_of_sight(get_world_3d(), global_position + Vector3.UP * eye_height, p.get_chest_position()):
			hidden = false
			alert(p)
		return
	super._perceive()


func _on_disturbed() -> void:
	hidden = false


func _process_idle(delta: float) -> void:
	_stop(delta)
	if not hidden and _state_time > 6.0:
		hidden = true


func _on_attack_active(a: EnemyAttackData) -> void:
	if a.id == &"scythe_double":
		_second_hit = SECOND_HIT_DELAY
	Sfx.play_at(&"melee_swing", global_position + Vector3.UP * eye_height, 0.0, 1.3)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _second_hit >= 0.0:
		_second_hit -= delta
		if _second_hit < 0.0 and _attack and _attack.id == &"scythe_double" and state == State.ATTACK:
			_attack_hit_done = false
			_try_hit_target(_attack)
			Sfx.play_at(&"melee_swing", global_position + Vector3.UP * eye_height, 0.0, 1.5)


func _anim_action() -> StringName:
	if hidden and state == State.IDLE:
		return &"hide"
	return super._anim_action()

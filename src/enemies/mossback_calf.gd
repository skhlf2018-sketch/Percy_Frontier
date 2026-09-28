class_name MossbackCalf
extends Enemy
## 이끼등 새끼: 머리로 들이받는 게 전부지만, 크게 다치면 울어서 근처의 어른 돌격수를 부르고 그쪽으로 달아난다.

const CALL_RADIUS := 45.0

var _called: bool = false


func _on_damaged_by(p: Player) -> void:
	super._on_damaged_by(p)
	if not _called and health_ratio() < 0.6:
		_called = true
		Sfx.play_at(&"charger_roar", global_position + Vector3.UP * eye_height, 0.0, 1.8)
		for e in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
			if e is RockCharger and e.is_alive() and e.global_position.distance_to(global_position) < CALL_RADIUS:
				e.alert(p)
		GameEvents.notify("%s가 운다 — 어른 돌격수가 달려온다" % data.display_name, GameEvents.NoticeKind.WARNING)


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	# 부른 어른에게로 달아난다.
	if _called and health_ratio() < 0.35:
		var adult: Node3D = null
		for e in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
			if e is RockCharger and e.is_alive():
				if adult == null or e.global_position.distance_to(global_position) < adult.global_position.distance_to(global_position):
					adult = e
		if adult and adult.global_position.distance_to(global_position) > 4.0:
			_move_toward(adult.global_position, data.run_speed, delta)
			return
	super._process_chase(delta)

class_name WolfAlpha
extends Wolf
## 늑대 우두머리(정예): 긴 울음으로 무리를 몰아세운다(12초 동안 더 빠르고 공격이 잦다).
## 울음은 전조가 길어 그사이 경직시키면 끊긴다. 크게 몸을 낮춘 뒤의 덮치기는 막을 수 없다.

const HOWL_BUFF := 12.0


func _attack_allowed(a: EnemyAttackData) -> bool:
	if a.id == &"howl":
		# 이끌 무리가 있고 아직 몰아세우지 않았을 때만 운다.
		return _pack().size() >= 2 and not is_buffed()
	return super._attack_allowed(a)


func _on_attack_windup(a: EnemyAttackData) -> void:
	if a.id == &"howl":
		Sfx.play_at(&"wolf_howl", global_position + Vector3.UP * eye_height, 3.0, 0.85)


func _on_attack_active(a: EnemyAttackData) -> void:
	if a.id != &"howl":
		return
	for w in _pack():
		w.buff(HOWL_BUFF)
		if w != self and w.target == null and target:
			w.alert(target)
	GameEvents.notify("%s의 울음 — 늑대들이 사나워졌다" % data.display_name, GameEvents.NoticeKind.WARNING)


func _anim_action() -> StringName:
	if state == State.ATTACK and _attack and _attack.id == &"howl":
		return &"howl"
	return super._anim_action()

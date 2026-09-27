class_name SkillCaster
extends Node
## 몬스터 스킬 시전(기획서 §8.5). 장착 슬롯 4개(기본 키 4~7), Q는 마지막으로 쓴 스킬.
## 스킬은 공명을 소모하고 짧은 재사용 시간을 가진다. 역할: 피해·이동·제어·방어.

signal skill_cast(slot: int, skill: SkillData)
signal cast_failed(slot: int, reason: String)

var player: Player
var cooldowns: Dictionary = {}
## Q로 다시 쓸 슬롯(-1이면 없음)
var last_slot: int = -1

var _dash_skill: SkillData
var _dash_hit: Dictionary = {}


func setup(p: Player) -> void:
	player = p


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.can_act():
		return
	for i in GameState.SKILL_SLOT_COUNT:
		if event.is_action_pressed(StringName("skill_%d" % (i + 1))):
			cast_slot(i)
			return
	if event.is_action_pressed(&"skill_quick"):
		if last_slot >= 0:
			cast_slot(last_slot)
		else:
			cast_failed.emit(-1, "아직 사용한 스킬이 없습니다.")


func skill_in_slot(slot: int) -> SkillData:
	if slot < 0 or slot >= GameState.skill_slots.size():
		return null
	var id: StringName = GameState.skill_slots[slot]
	return GameDB.skill(id) if id != &"" else null


func cooldown_left(skill: SkillData) -> float:
	return cooldowns.get(skill.id, 0.0) if skill else 0.0


func cooldown_ratio(skill: SkillData) -> float:
	if skill == null or skill.cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_left(skill) / skill.cooldown, 0.0, 1.0)


func can_afford(skill: SkillData) -> bool:
	return skill != null and player.stats.resonance >= skill.resonance_cost


func cast_slot(slot: int) -> bool:
	var skill := skill_in_slot(slot)
	if skill == null:
		_fail(slot, "스킬 슬롯 %d이(가) 비어 있습니다." % (slot + 1))
		return false
	if not player.can_act() or player.is_busy_with_consumable():
		return false
	if cooldown_left(skill) > 0.0:
		_fail(slot, "%s 재사용 대기 중" % skill.display_name)
		return false
	if not player.stats.spend_resonance(skill.resonance_cost):
		_fail(slot, "공명이 부족합니다 (%d 필요)" % int(skill.resonance_cost))
		return false
	cooldowns[skill.id] = skill.cooldown
	last_slot = slot
	player.apply_action_bleed()
	match skill.kind:
		SkillData.Kind.PULSE:
			_cast_pulse(skill)
		SkillData.Kind.DASH:
			_cast_dash(skill)
		SkillData.Kind.SHIELD:
			_cast_shield(skill)
		SkillData.Kind.PROJECTILE:
			_cast_projectile(skill)
	skill_cast.emit(slot, skill)
	return true


func _fail(slot: int, reason: String) -> void:
	Sfx.play(&"dry_fire", -6.0)
	cast_failed.emit(slot, reason)


func reset_cooldowns() -> void:
	cooldowns.clear()
	_dash_skill = null


func _physics_process(delta: float) -> void:
	for id in cooldowns.keys():
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)
	if _dash_skill:
		_update_dash()


func _skill_damage(skill: SkillData, position: Vector3, direction: Vector3) -> DamageInfo:
	var info := DamageInfo.create(skill.damage, DamageInfo.Kind.SKILL, player)
	info.stagger = skill.stagger
	info.status_buildup = skill.status_buildup()
	info.hit_position = position
	info.direction = direction
	info.knockback = skill.knockback
	return info


func _hit_entity(entity: Node, info: DamageInfo) -> void:
	if entity == null or not is_instance_valid(entity) or not entity.has_method("receive_hit"):
		return
	var result: HitResult = entity.receive_hit(info, null)
	player.weapons.handle_hit_result(result)


# 서리 파동: 주변 범위 제어
func _cast_pulse(skill: SkillData) -> void:
	var center := player.global_position + Vector3.UP * 0.9
	for entity in CombatQuery.entities_in_radius(player.get_world_3d(), center, skill.radius):
		var dir: Vector3 = (entity.global_position - player.global_position)
		dir.y = 0.0
		_hit_entity(entity, _skill_damage(skill, entity.global_position, dir.normalized()))
	CombatFx.ring(player, player.global_position + Vector3.UP * 0.1, skill.radius, skill.color, 0.45)
	CombatFx.ring(player, player.global_position + Vector3.UP * 0.8, skill.radius * 0.7, skill.color, 0.35)
	Sfx.play(&"skill_frost")
	player.camera_rig.add_trauma(0.15)
	Hearing.emit(player.get_tree(), center, 15.0, player, Hearing.Kind.IMPACT)


# 습격 도약: 전방 돌진, 도약 중 무적, 지나친 적에게 피해와 출혈
func _cast_dash(skill: SkillData) -> void:
	var fwd := -player.look_basis().z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var speed := skill.distance / maxf(skill.duration, 0.05)
	player.start_forced_motion(fwd * speed + Vector3.UP * 2.0, skill.duration, skill.duration + 0.08)
	player.cancel_sprint()
	_dash_skill = skill
	_dash_hit.clear()
	Sfx.play(&"skill_leap")
	player.camera_rig.add_trauma(0.1)


func _update_dash() -> void:
	if not player.is_in_forced_motion():
		_dash_skill = null
		return
	var center := player.global_position + Vector3.UP * 0.9
	for entity in CombatQuery.entities_in_radius(player.get_world_3d(), center, _dash_skill.radius + 0.6):
		if _dash_hit.has(entity):
			continue
		_dash_hit[entity] = true
		var dir := -player.look_basis().z
		_hit_entity(entity, _skill_damage(_dash_skill, entity.global_position, dir))
		CombatFx.impact(player, entity.global_position + Vector3.UP * 0.5, _dash_skill.color, 0.15, 0.2)


# 갑각 방벽: 피해 흡수 보호막, 지속 중 밀려나지 않음
func _cast_shield(skill: SkillData) -> void:
	player.stats.add_shield(skill.shield_amount, skill.duration)
	player.set_knockback_immunity(skill.duration)
	CombatFx.ring(player, player.global_position + Vector3.UP * 1.0, 1.6, skill.color, 0.5)
	Sfx.play(&"skill_shield")


# 화염 포자탄: 곡선으로 날아가 터지는 범위 피해·화상
func _cast_projectile(skill: SkillData) -> void:
	var aim := player.get_aim_transform()
	var dir := -aim.basis.z
	var p := Projectile.create(skill.color, 0.14, 1.2)
	p.collision_mask = CombatLayers.PLAYER_ATTACK_MASK
	p.exclude = [player.get_rid()]
	p.gravity = skill.gravity
	p.life = 4.0
	var explode := func(position: Vector3) -> void: _spore_explode(skill, position)
	p.on_hit = func(hit: Dictionary) -> void: explode.call(hit.position)
	p.on_expire = func() -> void: explode.call(p.global_position)
	var parent: Node = player.get_tree().current_scene if player.get_tree().current_scene else player.get_tree().root
	p.launch(parent, aim.origin + dir * 0.6, dir * skill.speed + Vector3.UP * 2.5)
	Sfx.play(&"skill_launch")


func _spore_explode(skill: SkillData, position: Vector3) -> void:
	if not is_instance_valid(player):
		return
	var center := position + Vector3.UP * 0.3
	for entity in CombatQuery.entities_in_radius(player.get_world_3d(), center, skill.radius):
		var dir: Vector3 = entity.global_position - position
		dir.y = 0.0
		_hit_entity(entity, _skill_damage(skill, entity.global_position, dir.normalized()))
	CombatFx.explosion(player, position, skill.radius, skill.color)
	Sfx.play_at(&"explosion", position)
	Hearing.emit(player.get_tree(), position, 30.0, player, Hearing.Kind.EXPLOSION)

class_name SporeSpitter
extends Enemy
## 포자 사수. 핵심 질문: "전조 중 빛나는 포자 주머니를 맞힐 수 있는가".
## - 거리를 유지하며 곡사로 화염 포자를 던진다. 가까이 오면 물러난다.
## - 전조 동안 등 위의 포자 주머니가 빛난다. 이때 주머니를 맞히면 그 자리에서 터져
##   공격이 끊기고 자신과 주변 적이 화상을 입는다. 주머니는 잠시 뒤 다시 자란다.

const PREFERRED_MIN := 10.0
const PREFERRED_MAX := 22.0
const RETREAT_DISTANCE := 8.0
const SAC_REGROW_TIME := 8.0
const SAC_BURST_RADIUS := 3.5

@export var sac_path: NodePath = ^"Visual/Sac"

var sac_depleted: bool = false
var _sac_regrow: float = 0.0
var _sac: MeshInstance3D
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0


func _on_ready() -> void:
	if _sac == null:
		_sac = get_node_or_null(sac_path)
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0


## 새 모델: 갓 뒤의 포자 주머니를 따로 붙인다(맞히면 터지고, 다시 자란다).
func _on_body_built(rig_node: CreatureRig) -> void:
	var sac := MeshInstance3D.new()
	sac.name = "Sac"
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.42
	sac.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.1)
	m.emission_energy_multiplier = 1.8
	m.rim_enabled = true
	m.rim = 0.6
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.8
	sac.material_override = m
	rig_node.attach_socket(&"sac", sac)
	_sac = sac


func _attack_allowed(_a: EnemyAttackData) -> bool:
	return not sac_depleted


func _on_attack_windup(_a: EnemyAttackData) -> void:
	Sfx.play_at(&"spit_charge", global_position + Vector3.UP * eye_height, -2.0)


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if _try_start_attack():
		return
	var dist := global_position.distance_to(target.global_position)
	var away := global_position - target.global_position
	away.y = 0.0
	away = away.normalized()
	if dist < RETREAT_DISTANCE or sac_depleted:
		_move_toward(global_position + away * 5.0, data.run_speed, delta)
		_face_toward(target.global_position, delta)
	elif dist > PREFERRED_MAX or not _sees_target:
		_move_toward(last_known_position, data.run_speed, delta)
	else:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(1.5, 3.0)
			_strafe_sign = -_strafe_sign
		var side := away.cross(Vector3.UP) * _strafe_sign
		_move_toward(global_position + side * 3.0, data.walk_speed, delta)
		_face_toward(target.global_position, delta)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not sac_depleted or state == State.DEAD:
		return
	_sac_regrow -= delta
	if _sac_regrow <= 0.0:
		sac_depleted = false
		if _sac:
			_sac.visible = true


## 전조 중 포자 주머니 명중 → 폭발
func _on_hit_zone(_hurtbox: Hurtbox, zone: int, info: DamageInfo) -> void:
	if zone != Hurtbox.Zone.WEAK_POINT or sac_depleted or _attack_phase != AttackPhase.WINDUP:
		return
	if not info.is_from_player():
		return
	_burst_sac()


func _burst_sac() -> void:
	sac_depleted = true
	_sac_regrow = SAC_REGROW_TIME
	if _sac:
		_sac.visible = false
	var center := global_position + Vector3.UP * (eye_height + 0.3)
	CombatFx.explosion(self, center, SAC_BURST_RADIUS, Color(1.0, 0.55, 0.15))
	Sfx.play_at(&"sac_burst", center, 2.0)
	GameState.bestiary.record(data, Bestiary.Event.PART_BREAK)
	GameEvents.notify("포자 주머니 파열!", GameEvents.NoticeKind.INFO)
	# 터진 주머니는 자신을 반드시 태우고(화상 저항과 무관), 주변 적에게는 화상을 누적시킨다.
	var burn := StatusEffects.Type.BURN
	status.add_buildup(burn, StatusEffects.THRESHOLD / maxf(status.resistance.get(burn, 1.0), 0.1))
	for e in get_tree().get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e != self and e is Enemy and e.is_alive() and e.global_position.distance_to(global_position) <= SAC_BURST_RADIUS:
			e.status.add_buildup(burn, 60.0)
	if state != State.DEAD:
		stagger(1.5, true)


func _process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _sac == null:
		super._process(delta)
		return
	var s := 1.0
	if _attack_phase == AttackPhase.WINDUP:
		s = 1.0 + 0.25 * (telegraph_info().get("progress", 0.0) as float) + sin(_clock * 25.0) * 0.05
	_sac.scale = _sac.scale.lerp(Vector3.ONE * s, 1.0 - exp(-12.0 * delta))
	super._process(delta)

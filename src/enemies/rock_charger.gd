class_name RockCharger
extends Enemy
## 바위등 돌격수(정예). 핵심 질문: "전면 장갑을 깰 것인가, 느린 회전을 이용해 등 뒤 약점을 노릴 것인가".
## - 몸을 돌리는 속도가 느려 옆과 뒤가 드러난다.
## - 돌진(패링 불가, 긴 전조와 포효)은 벽에 부딪히면 스스로 기절한다. 지형을 이용하는 공략.
## - 전면 장갑이 깨지면 분노해 빨라지지만 드러난 핵이 약점이 된다(기획서 §8.3: 파괴하면 행동이 달라진다).

const ENRAGE_SPEED_MULT := 1.25
const ENRAGE_WINDUP_MULT := 0.75

var enraged: bool = false
var _step_phase: float = 0.0


func _attack_allowed(a: EnemyAttackData) -> bool:
	if target == null:
		return false
	var limit := 35.0 if a.kind == EnemyAttackData.Kind.CHARGE else 55.0
	return facing_angle_to(target.global_position) <= limit


func _start_attack(a: EnemyAttackData) -> void:
	super._start_attack(a)
	if enraged:
		_attack_timer *= ENRAGE_WINDUP_MULT
	if a.kind == EnemyAttackData.Kind.CHARGE:
		Sfx.play_at(&"charger_roar", global_position + Vector3.UP * eye_height, 1.0)


func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	if _try_start_attack():
		return
	var speed := data.run_speed * (ENRAGE_SPEED_MULT if enraged else 1.0)
	var dist := global_position.distance_to(target.global_position)
	if dist < 3.0:
		_stop(delta)
		_face_toward(target.global_position, delta)
	else:
		_move_toward(last_known_position, speed, delta)


func _crash(stun_time: float) -> void:
	super._crash(stun_time)
	var p := _find_player()
	if p and p.global_position.distance_to(global_position) < 15.0:
		p.camera_rig.add_trauma(0.2)


func _on_armor_broken(_hb: Hurtbox) -> void:
	if enraged:
		return
	enraged = true
	Sfx.play_at(&"charger_roar", global_position + Vector3.UP * eye_height, 3.0, 1.2)
	GameEvents.notify("%s의 전면 장갑이 부서졌다 — 분노 상태" % data.display_name, GameEvents.NoticeKind.INFO)


## 새 모델: 얼굴 앞의 바위 장갑판과 그 밑의 핵을 붙이고 장갑 판정에 잇는다.
func _on_body_built(rig_node: CreatureRig) -> void:
	var plate := _make_plate()
	rig_node.attach_socket(&"face", plate, Transform3D(Basis(), Vector3(0, 0.02, -0.12)))
	var core := MeshInstance3D.new()
	core.name = "Core"
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.5
	core.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.4, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.1)
	m.emission_energy_multiplier = 2.5
	core.material_override = m
	core.visible = false
	rig_node.attach_socket(&"face", core, Transform3D(Basis(), Vector3(0, 0.0, -0.05)))
	for hb in _hurtboxes_named(&"FrontPlateHurtbox"):
		hb.armor_visual = plate
		hb.exposed_visual = core


func _hurtboxes_named(n: StringName) -> Array[Hurtbox]:
	var out: Array[Hurtbox] = []
	for hb in find_children(String(n), "Hurtbox", true, false):
		out.append(hb)
	return out


## 바위 장갑판: 이마를 덮는 두꺼운 바위(이끼 낀 윗면)
func _make_plate() -> Node3D:
	var b := RigBuilder.new()
	b.bone(&"root", &"", Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var rock := Color(0.44, 0.41, 0.37)
	var slab: Array[RigBuilder.P] = [
		RigBuilder.pt(Vector3(0, 0.0, 0.18), 0.62, 0.5, &"root"),
		RigBuilder.pt(Vector3(0, 0.05, -0.05), 0.72, 0.58, &"root"),
		RigBuilder.pt(Vector3(0, 0.02, -0.2), 0.6, 0.48, &"root"),
	]
	b.loft(slab, CreatureMaterials.Kind.STONE, rock, rock.darkened(0.3), 18, 3, Vector3.UP, true, true,
		func(v: Vector3, n: Vector3, c: Color) -> Color:
			var crack := smoothstep(0.07, 0.0, absf(SpeciesModels.noise3(v * 3.0)))
			var moss := smoothstep(0.4, 0.9, n.y) * smoothstep(0.0, 0.4, SpeciesModels.noise3(v * 2.0 + Vector3(2, 0, 5)))
			return Color(c.darkened(crack * 0.5).lerp(Color(0.26, 0.36, 0.16), moss * 0.8), c.a))
	BeastModels.rock_lumps(b, &"root", Vector3(0, 0.35, 0.0), 3, 0.18, rng, 0.7, rock)
	var t := b.build()
	var mi := MeshInstance3D.new()
	mi.name = "Plate"
	mi.mesh = t.mesh
	return mi


func _anim_action() -> StringName:
	if state == State.STUNNED:
		return &"stun"
	return super._anim_action()

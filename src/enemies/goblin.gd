class_name Goblin
extends Enemy
## 고블린: 무기를 들고 무리 지어 다닌다. 역할마다 싸우는 방식이 다르다.
##  - 척후병: 사람을 보면 휘파람을 불며 가까운 동료에게 달려가 무리를 부른 뒤 싸운다.
##  - 도끼잡이: 나무 방패를 늘 앞세운다(정면 탄은 방패에 박힌다. 방패는 부술 수 있다).
##  - 사수: 거리를 두고 옆으로 움직이며 쏜다. 조준 중에는 붉은 조준선이 보인다.
##  - 투척병: 멀리서 뼈창을 던지고, 가까이 오면 연기 폭탄을 던지고 물러난다.
##  - 주술사: 다친 동료를 치유한다(주문 중 경직시키면 끊긴다). 동료 뒤에 숨는다.
##  - 두목: 크게 다치면 함성으로 무리를 몰아세우고, 더 크게 다치면 광폭해진다.
##  - 외눈 저격수: 멀리서 조준경을 번뜩이며 쏘고, 쏠 때마다 자리를 옮긴다.
## 들고 있던 무기는 실제 무기(WeaponItem)이며, 쓰러지면 떨어뜨릴 수 있다(일반 35%, 정예·희귀는 반드시).

enum Role { SCOUT, BRUTE, GUNNER, THROWER, SHAMAN, CHIEF, SNIPER }

const ROLE_OF := {
	&"goblin_scout": Role.SCOUT, &"goblin_brute": Role.BRUTE, &"goblin_gunner": Role.GUNNER,
	&"goblin_thrower": Role.THROWER, &"goblin_shaman": Role.SHAMAN, &"goblin_chief": Role.CHIEF,
	&"oneeye_sniper": Role.SNIPER,
}
## 역할별 무기: bases = [[기본 무기, 가중치]], drop = 떨어뜨릴 확률, tiers = 희귀도 가중치[표준, 개량, 희귀, 에픽, 전설]
const WEAPONS := {
	Role.SCOUT: {"bases": [[&"goblin_cleaver", 1.0]], "drop": 0.35, "tiers": [60, 30, 10, 0, 0]},
	Role.BRUTE: {"bases": [[&"hand_axe", 1.0]], "drop": 0.35, "tiers": [60, 30, 10, 0, 0]},
	Role.GUNNER: {"bases": [[&"pipe_shotgun", 1.0], [&"scrap_smg", 1.0]], "drop": 0.35, "tiers": [55, 32, 12, 1, 0]},
	Role.THROWER: {"bases": [[&"bone_spear", 1.0]], "drop": 0.35, "tiers": [60, 30, 10, 0, 0]},
	Role.SHAMAN: {"bases": [], "drop": 0.0, "tiers": []},
	Role.CHIEF: {"bases": [[&"chief_greatblade", 1.0]], "drop": 1.0, "tiers": [0, 0, 55, 35, 10]},
	Role.SNIPER: {"bases": [[&"bolt_rifle", 0.7], [&"sniper_l14", 0.3]], "drop": 1.0, "tiers": [0, 0, 50, 35, 15]},
}
const BUFF_SPEED := 1.2
const HEAL_RATIO := 0.35
const HEAL_RANGE := 25.0
const ALLY_RANGE := 60.0

var role: int = Role.SCOUT
## 들고 있는 무기(쓰러지면 떨어뜨릴 수 있다). 주술사는 없다.
var weapon: WeaponItem = null
var buff_until: float = -100.0

var _weapon_node: Node3D = null
var _muzzle: Node3D = null
var _glint: MeshInstance3D = null
var _run_to: Goblin = null
var _run_time: float = 0.0
var _whistle_timer: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _retreat_left: float = 0.0
var _relocate_to := Vector3.INF
## 높은 자리(감시탑 위)를 지키는 저격수: 탑 가운데에서 이 반경의 가장자리(난간 뒤)를 따라 자리를 옮기고 물러나지 않는다.
var perch_radius: float = 0.0
var _heal_target: Enemy = null
var _enraged: bool = false
var _dropped: bool = false


func _on_ready() -> void:
	role = int(ROLE_OF.get(data.id, Role.SCOUT))
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	if weapon == null:
		weapon = roll_weapon(role, RandomNumberGenerator.new())
	_equip_visual()
	if _anim and role == Role.BRUTE:
		_anim.stance = &"block"


## 역할에 맞는 무기를 희귀도 표에 따라 굴린다.
static func roll_weapon(r: int, rng: RandomNumberGenerator) -> WeaponItem:
	var spec: Dictionary = WEAPONS.get(r, {})
	var bases: Array = spec.get("bases", [])
	if bases.is_empty():
		return null
	rng.randomize()
	var total := 0.0
	for b: Array in bases:
		total += float(b[1])
	var pick := rng.randf() * total
	var base: StringName = bases[0][0]
	for b: Array in bases:
		pick -= float(b[1])
		if pick <= 0.0:
			base = b[0]
			break
	var tiers: Array = spec.tiers
	var tsum := 0.0
	for t in tiers:
		tsum += float(t)
	var roll := rng.randf() * tsum
	var tier := 0
	for i in tiers.size():
		roll -= float(tiers[i])
		if roll <= 0.0:
			tier = i
			break
	return WeaponItem.roll(base, tier, rng)


## 손에 무기 모델을 쥐여 준다(희귀도 색이 그대로 보인다). 도끼잡이는 왼팔에 방패.
func _equip_visual() -> void:
	if _rig == null:
		return
	if weapon:
		_weapon_node = ViewmodelFactory.build_world(weapon.base_id, weapon.rarity)
		# 총은 팔을 따라 총구가 앞을 보게, 날붙이는 날이 비스듬히 위를 보게 쥔다.
		var grip := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-55.0)), Vector3.ZERO)
		if weapon.is_gun():
			grip = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.03, 0.06))
		_rig.attach_socket(&"hand_r", _weapon_node, grip)
		_muzzle = _weapon_node.get_node_or_null(^"Muzzle")
	if role == Role.BRUTE:
		_rig.attach_socket(&"shield", _make_shield())
	elif role == Role.SHAMAN:
		_rig.attach_socket(&"hand_r", _make_staff(), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
	if role == Role.SNIPER and _muzzle:
		_glint = MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.35, 0.35)
		_glint.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = false
		m.albedo_texture = _glint_texture()
		m.albedo_color = Color(0.85, 0.95, 1.0)
		_glint.material_override = m
		_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glint.visible = false
		_muzzle.add_child(_glint)
		_glint.position = Vector3(0, 0.05, 0.25)


static func _glint_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5)
			var core := clampf(1.0 - d.length() / 10.0, 0.0, 1.0)
			var streak := clampf(1.0 - absf(d.y) / 2.0, 0.0, 1.0) * clampf(1.0 - absf(d.x) / 32.0, 0.0, 1.0)
			var streak2 := clampf(1.0 - absf(d.x) / 2.0, 0.0, 1.0) * clampf(1.0 - absf(d.y) / 24.0, 0.0, 1.0)
			var a := clampf(core * core + streak * 0.8 + streak2 * 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _make_shield() -> Node3D:
	var root := Node3D.new()
	root.name = "Shield"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.25, 0.15)
	wood.roughness = 0.85
	wood.normal_enabled = true
	wood.normal_texture = CreatureMaterials.normal_texture(&"wood")
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(3, 3, 3)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.05
	cm.radial_segments = 20
	disc.mesh = cm
	disc.material_override = wood
	disc.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(disc)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.36, 0.34, 0.32)
	iron.metallic = 0.8
	iron.roughness = 0.5
	var boss := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.07
	boss.mesh = sm
	boss.material_override = iron
	boss.position = Vector3(0, 0, 0.03)
	root.add_child(boss)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.32
	rim.mesh = tm
	rim.material_override = iron
	rim.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(rim)
	return root


## 주술사의 지팡이: 끝에 초록빛 구슬
func _make_staff() -> Node3D:
	var root := Node3D.new()
	root.name = "Staff"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.22, 0.14)
	wood.roughness = 0.85
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.022
	cm.height = 1.3
	pole.mesh = cm
	pole.material_override = wood
	pole.position = Vector3(0, 0.3, 0)
	root.add_child(pole)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	orb.mesh = sm
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.4, 1.0, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(0.35, 1.0, 0.55)
	glow.emission_energy_multiplier = 2.5
	orb.material_override = glow
	orb.position = Vector3(0, 0.98, 0)
	root.add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.6)
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.position = orb.position
	root.add_child(light)
	return root


func is_buffed() -> bool:
	return _clock < buff_until


func buff(duration: float) -> void:
	buff_until = maxf(buff_until, _clock + duration)


func _speed() -> float:
	var s := data.run_speed
	if is_buffed():
		s *= BUFF_SPEED
	if _enraged:
		s *= 1.15
	return s


func muzzle_position() -> Vector3:
	if _muzzle and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return super.muzzle_position()


func _shot_sound() -> StringName:
	return &"shot_sniper" if role == Role.SNIPER else &"shot_crude"


static func goblins_near(tree: SceneTree, at: Vector3, radius: float) -> Array[Goblin]:
	var out: Array[Goblin] = []
	for e in tree.get_nodes_in_group(Hearing.ENEMY_GROUP):
		if e is Goblin and e.is_alive() and e.global_position.distance_to(at) <= radius:
			out.append(e)
	return out


# --- 발견·무리 ---

func _on_alerted() -> void:
	Sfx.play_at(&"goblin_shout", global_position + Vector3.UP * eye_height, -2.0, randf_range(0.9, 1.15))
	if role == Role.SCOUT:
		# 싸우지 않은 동료를 찾아 달려간다.
		var best: Goblin = null
		var best_d := ALLY_RANGE
		for g in goblins_near(get_tree(), global_position, ALLY_RANGE):
			if g == self or g.role == Role.SCOUT or g.is_engaged():
				continue
			var d := g.global_position.distance_to(global_position)
			if d < best_d and d > 8.0:
				best = g
				best_d = d
		_run_to = best
		_run_time = 0.0


## 고블린은 역할이 달라도 같은 무리로 모인다.
func _call_pack() -> void:
	if target == null or state == State.DEAD:
		return
	for g in goblins_near(get_tree(), global_position, data.pack_alert_radius):
		if g != self:
			g.alert(target)


# --- 추격 ---

func _process_chase(delta: float) -> void:
	if target == null or not target.alive:
		_lose_target()
		return
	# 척후병: 동료에게 달려가 무리를 부른다.
	if _run_to:
		if not is_instance_valid(_run_to) or not _run_to.is_alive():
			_run_to = null
		else:
			_run_time += delta
			_whistle_timer -= delta
			if _whistle_timer <= 0.0:
				_whistle_timer = 1.4
				Sfx.play_at(&"goblin_whistle", global_position + Vector3.UP * eye_height, 2.0)
				Hearing.emit(get_tree(), global_position, 25.0, self, Hearing.Kind.IMPACT)
			if global_position.distance_to(_run_to.global_position) < 5.0 or _run_time > 9.0:
				for g in goblins_near(get_tree(), _run_to.global_position, 30.0):
					g.alert(target)
				_run_to = null
			else:
				_move_toward(_run_to.global_position, _speed() * 1.1, delta)
				return
	match role:
		Role.GUNNER:
			_ranged_chase(delta, 6.0, 16.0)
		Role.THROWER:
			_ranged_chase(delta, 9.0, 20.0)
		Role.SHAMAN:
			_support_chase(delta)
		Role.SNIPER:
			_sniper_chase(delta)
		_:
			if _try_start_attack():
				return
			_move_toward(last_known_position, _speed(), delta)
			if _sees_target:
				_face_toward(target.global_position, delta)


## 거리를 두는 사수: 너무 가까우면 물러나고, 멀면 다가가고, 알맞으면 옆으로 걷는다.
func _ranged_chase(delta: float, near: float, far: float) -> void:
	var dist := global_position.distance_to(target.global_position)
	if _retreat_left > 0.0:
		_retreat_left -= delta
		_move_away(delta, _speed())
		return
	if _try_start_attack():
		return
	if not _sees_target or dist > far:
		_move_toward(last_known_position, _speed(), delta)
	elif dist < near:
		_move_away(delta, _speed() * 0.85)
		_face_toward(target.global_position, delta)
	else:
		_strafe(delta)


func _move_away(delta: float, speed: float) -> void:
	var away := global_position - target.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = global_basis.z
	_move_toward(global_position + away.normalized() * 5.0, speed, delta)


func _strafe(delta: float) -> void:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.2, 2.6)
		_strafe_sign = -_strafe_sign
	var to := target.global_position - global_position
	to.y = 0.0
	var side := to.normalized().cross(Vector3.UP) * _strafe_sign
	_move_toward(global_position + side * 3.0, data.walk_speed * 1.3, delta)
	_face_toward(target.global_position, delta)


## 주술사: 동료 뒤(플레이어 반대쪽)에 선다.
func _support_chase(delta: float) -> void:
	if _try_start_attack():
		return
	var ally: Goblin = null
	var best := HEAL_RANGE
	for g in goblins_near(get_tree(), global_position, HEAL_RANGE):
		if g == self or g.role == Role.SHAMAN:
			continue
		var d := g.global_position.distance_to(global_position)
		if d < best:
			best = d
			ally = g
	var dist := global_position.distance_to(target.global_position)
	if ally:
		var away := ally.global_position - target.global_position
		away.y = 0.0
		var spot := ally.global_position + away.normalized() * 4.0
		if global_position.distance_to(spot) > 1.5:
			_move_toward(spot, _speed(), delta)
		else:
			_stop(delta)
		_face_toward(target.global_position, delta)
	elif dist < 10.0:
		_move_away(delta, _speed())
	else:
		_strafe(delta)


func set_perch(r: float) -> void:
	perch_radius = r


## 탑 위 가장자리에서 대상 쪽을 내려다보는 자리(angle_offset만큼 옆으로)
func _perch_point(angle_offset: float = 0.0) -> Vector3:
	var to := target.global_position - home_position if target else -global_basis.z
	to.y = 0.0
	var ang := atan2(to.z, to.x) + angle_offset
	return home_position + Vector3(cos(ang), 0.0, sin(ang)) * perch_radius


## 저격수: 멀리서 쏘고, 쏠 때마다 옆으로 자리를 옮긴다.
func _sniper_chase(delta: float) -> void:
	var dist := global_position.distance_to(target.global_position)
	if _relocate_to != Vector3.INF:
		var arrive := 0.45 if perch_radius > 0.0 else 1.2
		if global_position.distance_to(_relocate_to) < arrive or _state_time > 7.0:
			_relocate_to = Vector3.INF
		else:
			_move_toward(_relocate_to, _speed(), delta)
			return
	if perch_radius > 0.0 and _off_perch_edge():
		_relocate_to = _perch_point()
		_state_time = 0.0
		return
	if dist < 12.0 and _retreat_left <= 0.0 and perch_radius <= 0.0:
		_retreat_left = 2.5
	if _retreat_left > 0.0:
		_retreat_left -= delta
		if dist < 2.2 and _try_start_attack():
			return
		_move_away(delta, _speed())
		return
	if _try_start_attack():
		return
	if not _sees_target or dist > 55.0:
		_move_toward(last_known_position, _speed(), delta)
	else:
		_stop(delta)
		_face_toward(target.global_position, delta)


# --- 공격 ---

func _attack_allowed(a: EnemyAttackData) -> bool:
	match a.id:
		&"heal_chant":
			_heal_target = _find_heal_target()
			return _heal_target != null
		&"war_cry":
			return health_ratio() < 0.7 and not is_buffed() and goblins_near(get_tree(), global_position, 30.0).size() >= 2
		&"smoke_bomb":
			return global_position.distance_to(target.global_position) < 7.0
	if a.kind == EnemyAttackData.Kind.SHOT:
		# 총구가 대상을 향해야 쏜다.
		return facing_angle_to(target.global_position) < 40.0
	return true


func _find_heal_target() -> Enemy:
	var best: Enemy = null
	var worst := 0.75
	for g in goblins_near(get_tree(), global_position, HEAL_RANGE):
		if g.health_ratio() < worst:
			worst = g.health_ratio()
			best = g
	return best


func _start_attack(a: EnemyAttackData) -> void:
	super._start_attack(a)
	if is_buffed() or _enraged:
		_attack_timer *= 0.8
	match a.id:
		&"heal_chant":
			Sfx.play_at(&"goblin_chant", global_position + Vector3.UP * eye_height)
		&"war_cry":
			Sfx.play_at(&"goblin_warcry", global_position + Vector3.UP * eye_height, 4.0)
		&"overhead_cleave":
			Sfx.play_at(&"goblin_shout", global_position + Vector3.UP * eye_height, 0.0, 0.8)


func _on_attack_active(a: EnemyAttackData) -> void:
	match a.id:
		&"heal_chant":
			if _heal_target and is_instance_valid(_heal_target) and _heal_target.is_alive():
				_heal_target.hp = minf(_heal_target.data.max_hp, _heal_target.hp + _heal_target.data.max_hp * HEAL_RATIO)
				Sfx.play_at(&"heal_chime", _heal_target.global_position + Vector3.UP)
				CombatFx.explosion(_heal_target, _heal_target.global_position + Vector3.UP * 0.8, 1.2, Color(0.4, 1.0, 0.55, 0.6))
			_heal_target = null
		&"war_cry":
			for g in goblins_near(get_tree(), global_position, 30.0):
				g.buff(12.0)
			CombatFx.explosion(self, global_position + Vector3.UP, 3.0, Color(1.0, 0.45, 0.25, 0.4))
			GameEvents.notify("%s의 함성 — 고블린들이 사나워졌다" % data.display_name, GameEvents.NoticeKind.WARNING)
		&"spear_throw":
			Sfx.play_at(&"spear_whoosh", global_position + Vector3.UP * eye_height)


func _end_attack(completed: bool) -> void:
	var was := _attack
	super._end_attack(completed)
	if was == null or not completed:
		return
	match was.id:
		&"smoke_bomb":
			_retreat_left = 3.0
		&"aimed_shot":
			_pick_relocation()


## 탑 위 저격수가 가장자리에서 벗어났거나(가운데), 대상과 반대쪽 난간에 있는지
func _off_perch_edge() -> bool:
	var off := global_position - home_position
	off.y = 0.0
	if off.length() < perch_radius * 0.7:
		return true
	var to := target.global_position - home_position
	to.y = 0.0
	return to.length_squared() > 0.01 and rad_to_deg(off.angle_to(to)) > 55.0


func _pick_relocation() -> void:
	if target == null:
		return
	if perch_radius > 0.0:
		# 난간을 따라 옆 칸으로 옮긴다(대상을 내려다보는 방향은 유지한다).
		var side := 1.0 if randf() < 0.5 else -1.0
		_relocate_to = _perch_point(side * randf_range(0.5, 0.85))
		_state_time = 0.0
		return
	var to := global_position - target.global_position
	to.y = 0.0
	var side := to.normalized().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	_relocate_to = global_position + side * randf_range(9.0, 14.0) + to.normalized() * randf_range(-3.0, 4.0)
	_state_time = 0.0


## 투사체 폭발: 연기 폭탄은 피해 대신 짙은 연기를 남긴다.
func _fire_projectile(a: EnemyAttackData) -> void:
	if a.id == &"smoke_bomb":
		var at := target.global_position if target else global_position
		super._fire_projectile(a)
		_spawn_smoke.call_deferred(at)
		return
	super._fire_projectile(a)


func _spawn_smoke(at: Vector3) -> void:
	if not is_inside_tree():
		return
	Sfx.play_at(&"smoke_pop", at)
	SmokeCloud.spawn(self, at, 4.5, 7.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if role == Role.CHIEF and not _enraged and state != State.DEAD and health_ratio() < 0.4:
		_enraged = true
		Sfx.play_at(&"goblin_warcry", global_position + Vector3.UP * eye_height, 6.0, 0.8)
		GameEvents.notify("%s가 광폭해졌다" % data.display_name, GameEvents.NoticeKind.WARNING)
	if _glint:
		var aiming := state == State.ATTACK and _attack != null and _attack.kind == EnemyAttackData.Kind.SHOT \
			and _attack_phase == AttackPhase.WINDUP and not _aim_locked
		_glint.visible = aiming
		if aiming and target:
			var d := global_position.distance_to(target.global_position)
			var pulse := 0.8 + 0.4 * sin(_clock * 18.0)
			_glint.scale = Vector3.ONE * clampf(d / 12.0, 1.0, 5.0) * pulse


func _anim_action() -> StringName:
	if state == State.ATTACK and _attack:
		match _attack.id:
			&"heal_chant", &"war_cry":
				return &"cast"
			&"crude_shot", &"aimed_shot":
				return &"aim"
	# 사수·저격수는 싸우는 동안 총을 겨눈 채 움직인다.
	if (role == Role.GUNNER or role == Role.SNIPER) and is_engaged() and state == State.CHASE and _sees_target:
		return &"aim"
	return super._anim_action()


# --- 쓰러짐 ---

func _on_died() -> void:
	if _dropped or weapon == null:
		return
	_dropped = true
	var chance: float = float(WEAPONS.get(role, {}).get("drop", 0.0))
	if randf() >= chance:
		return
	var at := global_position + global_basis.x * 0.6
	if _weapon_node and is_instance_valid(_weapon_node):
		_weapon_node.visible = false
	var p := WeaponPickup.drop(self, weapon, at)
	if p and weapon.rarity >= ItemRarity.Tier.RARE:
		GameEvents.notify("%s이(가) %s [%s]을(를) 떨어뜨렸다" % [data.display_name, weapon.display_name(), weapon.rarity_name()],
			GameEvents.NoticeKind.PICKUP)

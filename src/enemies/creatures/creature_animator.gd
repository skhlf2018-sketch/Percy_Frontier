class_name CreatureAnimator
extends RefCounted
## 절차적 동작: 속도에 따라 걸음새(걷기·속보·질주)를 바꾸고, 행동(전조·공격·울부짖기·조준·던지기·주문·방어·경직)을
## 자세로 섞는다. 뼈 이름 규칙은 SpeciesModels를 따른다.
##  - 네발: fl_/hl_ (upper, lower, foot / hind는 meta도), spine, chest, neck, head, jaw, ear_l/r, tail1~3
##  - 두발: leg_upper/lower_l/r, foot_l/r, arm_upper/lower_l/r, hand_l/r, spine, chest, neck, head, jaw
## 회전 부호: 아래로 뻗은 팔다리는 +X가 앞으로, 위로 선 몸통·목은 -X가 앞으로 숙이기다.

enum Body { QUADRUPED, BIPED, HOPPER, CRAWLER, FLYER, STATIC, SERPENT }

var rig: CreatureRig
var body: int = Body.QUADRUPED
## 다리 길이(보폭 계산). 모델 크기에 맞춘다.
var leg_length: float = 0.5
## 걷기/질주 경계 속도(m/s)
var run_speed: float = 6.0

## 매 프레임 넣어 주는 상태
var speed: float = 0.0
var turn_rate: float = 0.0
## 목표를 바라보는 머리 각도(몸 기준, 라디안)
var look_yaw: float = 0.0
var look_pitch: float = 0.0
## 행동: &"" 없음, &"windup", &"lunge", &"strike", &"howl", &"aim", &"throw_windup", &"throw", &"cast", &"block",
## &"stagger", &"stun", &"crouch", &"hide"
var action: StringName = &""
## 행동 세기(0..1). 자세를 섞는 비율.
var action_weight: float = 0.0
## 늘 유지하는 자세(방패를 앞세운 도끼잡이의 &"block" 등). 행동과 함께 섞인다.
var stance: StringName = &""

var _phase: float = 0.0
var _t: float = 0.0
var _speed_s: float = 0.0
var _weights: Dictionary = {}
var _ear_twitch: float = 0.0
var _seed: float = 0.0


func _init(r: CreatureRig, kind: int, leg_len: float, fast: float = 6.0) -> void:
	rig = r
	body = kind
	leg_length = leg_len
	run_speed = fast
	_seed = randf() * 100.0
	_phase = randf()


func update(delta: float) -> void:
	_t += delta
	_speed_s = lerpf(_speed_s, speed, 1.0 - exp(-8.0 * delta))
	# 행동 자세는 부드럽게 들어가고 빠진다.
	for key: StringName in _weights.keys():
		if key != action:
			_weights[key] = move_toward(float(_weights[key]), 0.0, delta * 6.0)
			if float(_weights[key]) <= 0.0:
				_weights.erase(key)
	if action != &"":
		_weights[action] = move_toward(float(_weights.get(action, 0.0)), action_weight, delta * 10.0)
	match body:
		Body.BIPED:
			_biped(delta)
		Body.HOPPER:
			_hopper(delta)
		Body.CRAWLER:
			_crawler(delta)
		Body.FLYER:
			_flyer(delta)
		Body.STATIC:
			_static(delta)
		Body.SERPENT:
			_serpent(delta)
		_:
			_quadruped(delta)


func w(key: StringName) -> float:
	var v := float(_weights.get(key, 0.0))
	return maxf(v, 1.0) if key == stance and stance != &"" else v


# --- 네발 ---

func _quadruped(delta: float) -> void:
	var v := _speed_s
	var gallop := smoothstep(run_speed * 0.55, run_speed * 0.85, v)
	var stride := leg_length * lerpf(1.4, 2.6, gallop)
	_phase = fmod(_phase + delta * v / maxf(stride, 0.05), 1.0)
	var moving := clampf(v / 1.2, 0.0, 1.0)
	var amp := lerpf(0.28, 0.6, clampf(v / run_speed, 0.0, 1.0)) * moving
	var duty := lerpf(0.62, 0.42, gallop)
	# 걸음새: 속보(대각 쌍) → 질주(뒷다리 한 쌍, 앞다리 한 쌍)
	var offs := {
		&"fl_l": lerpf(0.0, 0.55, gallop), &"fl_r": lerpf(0.5, 0.65, gallop),
		&"hl_l": lerpf(0.5, 0.0, gallop), &"hl_r": lerpf(0.0, 0.1, gallop),
	}
	var crouch := w(&"windup") + w(&"crouch") * 0.8 + w(&"hide")
	var lunge := w(&"lunge")
	for leg: StringName in offs:
		var p := fmod(_phase + float(offs[leg]), 1.0)
		var swing: float
		var lift := 0.0
		if p < duty:
			swing = lerpf(amp, -amp, p / duty)
		else:
			var q := (p - duty) / (1.0 - duty)
			swing = lerpf(-amp, amp, smoothstep(0.0, 1.0, q))
			lift = sin(q * PI) * moving
		var side := String(leg).substr(3)
		var front := String(leg).begins_with("f")
		var up := StringName(("fl_upper_" if front else "hl_upper_") + side)
		var lo := StringName(("fl_lower_" if front else "hl_lower_") + side)
		if front:
			var reach := lunge * 0.9 - crouch * 0.15
			rig.rot(up, Vector3(swing + reach, 0, 0))
			rig.rot(lo, Vector3(lift * 0.35 + crouch * 0.3, 0, 0))
			rig.rot(StringName("fl_foot_" + side), Vector3(-lift * 1.1 - crouch * 0.25, 0, 0))
		else:
			var push := -lunge * 0.7 + crouch * 0.55
			rig.rot(up, Vector3(swing + push, 0, 0))
			rig.rot(lo, Vector3(-lift * 0.5 - crouch * 0.7, 0, 0))
			if rig.has_bone(StringName("hl_meta_" + side)):
				rig.rot(StringName("hl_meta_" + side), Vector3(lift * 0.7 + crouch * 0.5, 0, 0))
			rig.rot(StringName("hl_foot_" + side), Vector3(-lift * 0.4, 0, 0))
	# 몸: 걸음마다 오르내림, 질주할 때 등이 굽혔다 펴진다.
	var bob := -absf(sin(_phase * TAU * 2.0)) * 0.018 * moving * (1.0 - gallop) - sin(_phase * TAU) * 0.03 * gallop
	var breathe := sin(_t * 2.2 + _seed) * 0.012 * (1.0 - moving)
	rig.move(&"root", Vector3(0, bob - crouch * leg_length * 0.25 + lunge * 0.04, 0))
	rig.rot(&"root", Vector3(-sin(_phase * TAU) * 0.07 * gallop - crouch * 0.1 + lunge * 0.05, 0, -turn_rate * 0.05))
	rig.rot(&"spine", Vector3(sin(_phase * TAU + 0.6) * 0.1 * gallop, 0, 0))
	rig.scale_bone(&"chest", Vector3.ONE * (1.0 + breathe * 0.5))
	# 목·머리: 대상을 바라보고, 전조에서는 낮게, 울부짖을 때는 하늘로
	var howl := w(&"howl")
	# 목·머리: +X가 머리를 드는 쪽
	var neck_pitch := look_pitch * 0.4 - crouch * 0.35 + howl * 0.9 - lunge * 0.1
	rig.rot(&"neck", Vector3(neck_pitch - gallop * 0.12, look_yaw * 0.45, 0))
	var shake := sin(_t * 30.0) * 0.25 * w(&"stagger")
	rig.rot(&"head", Vector3(look_pitch * 0.5 + howl * 0.5 - crouch * 0.1, look_yaw * 0.45 + shake, shake * 0.5))
	var jaw := 0.12 * crouch + 0.55 * lunge + 0.45 * howl + 0.35 * w(&"strike") + 0.1 * clampf(v / run_speed, 0.0, 1.0)
	rig.rot(&"jaw", Vector3(-jaw, 0, 0))
	# 귀: 가끔 쫑긋, 공격할 때는 뒤로 눕힌다.
	_ear_twitch = maxf(0.0, _ear_twitch - delta)
	if _ear_twitch <= 0.0 and randf() < delta * 0.25:
		_ear_twitch = 0.25
	var flat := (crouch + lunge) * 0.7
	var tw := sin(_ear_twitch * 25.0) * 0.25 if _ear_twitch > 0.0 else 0.0
	rig.rot(&"ear_l", Vector3(flat, tw, flat * 0.4))
	rig.rot(&"ear_r", Vector3(flat, -tw * 0.5, -flat * 0.4))
	# 꼬리
	var wag := sin(_t * 1.6 + _seed) * 0.12 + sin(_phase * TAU) * 0.15 * moving
	# 꼬리: -X가 꼬리를 드는 쪽
	var tail_up := -0.2 * crouch + 0.35 * lunge + 0.3 * gallop
	rig.rot(&"tail1", Vector3(-tail_up, wag, 0))
	rig.rot(&"tail2", Vector3(-tail_up * 0.5, wag * 0.8, 0))
	rig.rot(&"tail3", Vector3(0.0, wag * 0.6, 0))


# --- 토끼(깡충) ---

func _hopper(delta: float) -> void:
	var v := _speed_s
	var moving := clampf(v / 1.0, 0.0, 1.0)
	var stride := leg_length * 3.2
	_phase = fmod(_phase + delta * v / maxf(stride, 0.05), 1.0)
	var hop := sin(_phase * TAU)
	var air := maxf(0.0, hop) * moving
	var crouch := w(&"windup") + w(&"hide") * 0.9
	var lunge := w(&"lunge")
	for side in ["l", "r"]:
		# 뒷다리는 박차고(뒤로 뻗고), 앞다리는 착지 쪽으로 뻗는다.
		rig.rot(StringName("hl_upper_" + side), Vector3(-air * 0.9 + crouch * 0.4 - lunge * 1.0, 0, 0))
		rig.rot(StringName("hl_lower_" + side), Vector3(air * 0.6 - crouch * 0.3 + lunge * 0.5, 0, 0))
		rig.rot(StringName("hl_foot_" + side), Vector3(-air * 0.4 + lunge * 0.6, 0, 0))
		rig.rot(StringName("fl_upper_" + side), Vector3(air * 0.8 - (1.0 - air) * 0.2 * moving + lunge * 1.1, 0, 0))
		rig.rot(StringName("fl_lower_" + side), Vector3(-crouch * 0.4, 0, 0))
	rig.move(&"root", Vector3(0, air * leg_length * 0.35 - crouch * leg_length * 0.2 + lunge * 0.05, 0))
	rig.rot(&"root", Vector3(-hop * 0.18 * moving - crouch * 0.12 + lunge * 0.2, 0, 0))
	var breathe := sin(_t * 5.5 + _seed) * 0.02 * (1.0 - moving)
	rig.scale_bone(&"chest", Vector3.ONE * (1.0 + breathe * 0.5))
	rig.rot(&"neck", Vector3(look_pitch * 0.4 - crouch * 0.25, look_yaw * 0.5, 0))
	var sniff := sin(_t * 14.0 + _seed) * 0.03 * (1.0 - moving)
	rig.rot(&"head", Vector3(look_pitch * 0.4 + sniff, look_yaw * 0.4 + sin(_t * 30.0) * 0.2 * w(&"stagger"), 0))
	rig.rot(&"jaw", Vector3(-(0.4 * lunge + 0.15 * crouch), 0, 0))
	# 귀: 숨을 때 등으로 눕히고, 경계할 때 곧게 세운다.
	var ear_back := crouch * 1.1 + moving * 0.35 + lunge * 0.8
	_ear_twitch = maxf(0.0, _ear_twitch - delta)
	if _ear_twitch <= 0.0 and randf() < delta * 0.4:
		_ear_twitch = 0.3
	var tw := sin(_ear_twitch * 22.0) * 0.3 if _ear_twitch > 0.0 else 0.0
	rig.rot(&"ear_l", Vector3(ear_back, tw, 0.1))
	rig.rot(&"ear_r", Vector3(ear_back, -tw, -0.1))


# --- 두발(고블린) ---

func _biped(delta: float) -> void:
	var v := _speed_s
	var moving := clampf(v / 0.8, 0.0, 1.0)
	var run := smoothstep(2.5, 4.5, v)
	var stride := leg_length * lerpf(1.5, 2.4, run)
	_phase = fmod(_phase + delta * v / maxf(stride, 0.05), 1.0)
	var s := sin(_phase * TAU)
	var c := cos(_phase * TAU)
	var amp := lerpf(0.35, 0.7, run) * moving
	var aim := w(&"aim")
	var wind := w(&"windup")
	var strike := w(&"strike")
	var twind := w(&"throw_windup")
	var throw := w(&"throw")
	var cast := w(&"cast")
	var block := w(&"block")
	var stag := w(&"stagger") + w(&"stun")
	var crouch := w(&"crouch")
	# 구부정한 기본 자세: 무릎을 굽히고 등을 숙인다.
	var hunch := 0.16 + 0.1 * run + crouch * 0.25
	for i in 2:
		var side := "l" if i == 0 else "r"
		var sg := s if i == 0 else -s
		var lift := maxf(0.0, (c if i == 0 else -c)) * moving
		rig.rot(StringName("leg_upper_" + side), Vector3(0.22 + crouch * 0.4 + sg * amp, 0, 0))
		rig.rot(StringName("leg_lower_" + side), Vector3(-0.42 - crouch * 0.7 - lift * (0.7 + 0.5 * run), 0, 0))
		rig.rot(StringName("foot_" + side), Vector3(0.2 + crouch * 0.3 + lift * 0.3 - sg * amp * 0.3, 0, 0))
	var bob := -absf(c) * 0.03 * moving
	rig.move(&"root", Vector3(0, bob - 0.035 - crouch * 0.1, 0))
	rig.rot(&"root", Vector3(0, s * 0.08 * moving, 0))
	rig.rot(&"spine", Vector3(-hunch + stag * 0.25, -s * 0.1 * moving + wind * 0.3 - strike * 0.35 + twind * 0.35 - throw * 0.4, 0))
	var breathe := sin(_t * 1.9 + _seed) * 0.015
	rig.rot(&"chest", Vector3(-hunch * 0.8 + breathe + stag * 0.2, wind * 0.15 - strike * 0.15, 0))
	rig.rot(&"neck", Vector3(hunch * 1.1 + look_pitch * 0.4 - stag * 0.3, look_yaw * 0.4, 0))
	rig.rot(&"head", Vector3(hunch * 0.5 + look_pitch * 0.5, look_yaw * 0.5 + sin(_t * 25.0) * 0.2 * stag, 0))
	rig.rot(&"jaw", Vector3(-(0.08 + 0.25 * (wind + twind + cast) + 0.03 * sin(_t * 3.0 + _seed)), 0, 0))
	# 팔: 걸을 때 흔들고, 행동 자세를 섞는다.
	for i in 2:
		var side := "l" if i == 0 else "r"
		var right := i == 1
		var sg := -s if i == 0 else s
		var sx := -1.0 if i == 0 else 1.0
		var upper := Vector3(0.1 + sg * amp * 0.8, 0, sx * 0.12)
		var lower := Vector3(0.35 + moving * 0.3, 0, 0)
		if right:
			upper = upper.lerp(Vector3(1.45, 0.1, 0.05), aim)
			lower = lower.lerp(Vector3(0.15, 0, 0), aim)
			upper = upper.lerp(Vector3(2.7, 0.2, 0.25), wind + twind)
			lower = lower.lerp(Vector3(1.4, 0, 0), wind + twind)
			upper = upper.lerp(Vector3(0.7, -0.3, 0.1), strike + throw)
			lower = lower.lerp(Vector3(0.15, 0, 0), strike + throw)
		else:
			upper = upper.lerp(Vector3(1.25, -0.5, -0.1), aim)
			lower = lower.lerp(Vector3(0.6, 0, 0), aim)
			upper = upper.lerp(Vector3(1.1, 0.6, -0.1), block)
			lower = lower.lerp(Vector3(1.3, 0, 0), block)
			upper = upper.lerp(Vector3(0.5, 0, -0.2), wind + twind)
		upper = upper.lerp(Vector3(2.5, 0, sx * 0.45), cast)
		lower = lower.lerp(Vector3(0.4, 0, 0), cast)
		rig.rot(StringName("arm_upper_" + side), upper)
		rig.rot(StringName("arm_lower_" + side), lower)
	var ear := sin(_t * 1.3 + _seed) * 0.08
	rig.rot(&"ear_l", Vector3(0, ear, -stag * 0.3))
	rig.rot(&"ear_r", Vector3(0, -ear, stag * 0.3))


# --- 여러 다리(거미·사마귀·포자 식생체) ---

var _leg_count: int = -1


func _crawler(delta: float) -> void:
	if _leg_count < 0:
		_leg_count = 0
		while rig.has_bone(StringName("leg%d_upper" % _leg_count)):
			_leg_count += 1
	var v := _speed_s
	var moving := clampf(v / 0.6, 0.0, 1.0)
	var stride := leg_length * 1.3
	_phase = fmod(_phase + delta * v / maxf(stride, 0.05), 1.0)
	var wind := w(&"windup")
	var strike := w(&"strike") + w(&"lunge")
	var crouch := w(&"crouch") + w(&"hide")
	var rear := wind * 0.35 - crouch * 0.2
	for i in _leg_count:
		# 왼0 오0 왼1 오1 … 번갈아 두 무리(세 다리씩 또는 네 다리씩)가 함께 움직인다.
		var side := -1.0 if i % 2 == 0 else 1.0
		var group := (i / 2 + i % 2) % 2
		var p := fmod(_phase + 0.5 * group, 1.0)
		var swing := sin(p * TAU) * 0.35 * moving
		var lift := maxf(0.0, cos(p * TAU)) * 0.35 * moving
		rig.rot(StringName("leg%d_upper" % i), Vector3(0.0, side * swing, side * (lift + crouch * 0.25)))
		rig.rot(StringName("leg%d_lower" % i), Vector3(0.0, 0.0, -side * lift * 0.6))
	var bob := sin(_phase * TAU * 2.0) * 0.012 * moving
	rig.move(&"root", Vector3(0, bob - crouch * leg_length * 0.15, 0))
	rig.rot(&"root", Vector3(rear, 0, 0))
	# 머리·몸 흔들림, 배는 숨쉬듯
	var breathe := sin(_t * 2.0 + _seed) * 0.03
	rig.rot(&"abdomen", Vector3(breathe - rear * 0.5, sin(_t * 0.7 + _seed) * 0.05, 0))
	rig.rot(&"neck", Vector3(look_pitch * 0.3 + wind * 0.25, look_yaw * 0.4, 0))
	rig.rot(&"head", Vector3(look_pitch * 0.3, look_yaw * 0.4 + sin(_t * 25.0) * 0.2 * w(&"stagger"), 0))
	rig.rot(&"jaw", Vector3(-(0.15 * wind + 0.35 * strike + 0.05 * sin(_t * 9.0 + _seed)), 0, 0))
	# 낫다리: 전조에 치켜들고, 판정 때 앞으로 내려친다.
	for i in 2:
		var sn := "l" if i == 0 else "r"
		var sx := -1.0 if i == 0 else 1.0
		var up := Vector3(0.1, 0, 0).lerp(Vector3(-0.9, sx * 0.2, 0), wind).lerp(Vector3(0.9, 0, 0), strike)
		var lo := Vector3(0.0, 0, 0).lerp(Vector3(-0.6, 0, 0), wind).lerp(Vector3(0.9, 0, 0), strike)
		rig.rot(StringName("arm_upper_" + sn), up)
		rig.rot(StringName("arm_lower_" + sn), lo)


# --- 날짐승(박쥐) ---

func _flyer(delta: float) -> void:
	var dive := w(&"lunge") + w(&"strike")
	var hover := 1.0 - dive
	var rate := lerpf(9.0, 13.0, clampf(_speed_s / 6.0, 0.0, 1.0))
	_phase = fmod(_phase + delta * rate / TAU, 1.0)
	var flap := sin(_phase * TAU) * 0.9 * hover
	var tuck := dive * 0.9
	for i in 2:
		var sn := "l" if i == 0 else "r"
		var sx := -1.0 if i == 0 else 1.0
		rig.rot(StringName("wing_upper_" + sn), Vector3(tuck * 0.4, sx * tuck * 0.6, sx * flap))
		rig.rot(StringName("wing_lower_" + sn), Vector3(0, sx * tuck * 0.9, sx * flap * 0.6))
	rig.move(&"root", Vector3(0, -sin(_phase * TAU) * 0.04 * hover, 0))
	rig.rot(&"root", Vector3(-dive * 0.5 + look_pitch * 0.3, 0, -turn_rate * 0.08))
	rig.rot(&"head", Vector3(look_pitch * 0.4, look_yaw * 0.5, 0))
	rig.rot(&"jaw", Vector3(-(0.3 * w(&"windup") + 0.5 * dive), 0, 0))
	var tw := sin(_t * 17.0 + _seed) * 0.15
	rig.rot(&"ear_l", Vector3(0, tw, 0))
	rig.rot(&"ear_r", Vector3(0, -tw, 0))


# --- 움직이지 않는 것(포자낭·포자 모체) ---

func _static(_delta: float) -> void:
	var swell := w(&"windup")
	var open := w(&"open") + w(&"cast")
	var pulse := 1.0 + sin(_t * 1.6 + _seed) * 0.02 + swell * (0.25 + 0.05 * sin(_t * 30.0))
	rig.scale_bone(&"body", Vector3.ONE * pulse)
	for i in 5:
		var bn := StringName("petal%d" % i)
		if not rig.has_bone(bn):
			break
		var a := TAU * float(i) / 5.0
		var outv := Vector3(sin(a), 0, cos(a))
		# 꽃잎을 바깥쪽으로 젖힌다(몸 기준 바깥 축에 수직인 축으로 돈다).
		var axis := outv.cross(Vector3.UP)
		var ang := -(0.08 + 0.9 * open) + sin(_t * 1.1 + float(i)) * 0.03
		rig.skeleton.set_bone_pose_rotation(rig.bone_idx(bn), Quaternion(axis.normalized(), ang))


# --- 뱀몸(늪턱 구렁) ---

var _roll: float = 0.0
## 꼬리 휩쓸기 방향(+1 오른쪽, -1 왼쪽)
var sweep_side: float = 1.0


func _serpent(delta: float) -> void:
	var v := _speed_s
	var moving := clampf(v / 1.5, 0.0, 1.0)
	_phase = fmod(_phase + delta * (0.25 + v * 0.35), 1.0)
	var roar := w(&"roar")
	var wind := w(&"windup")
	var lunge := w(&"lunge")
	var strike := w(&"strike")
	var sweep := w(&"sweep")
	var sub := w(&"submerge")
	var roll := w(&"roll")
	# 몸을 따라 뒤로 흐르는 물결(꼬리로 갈수록 크다)
	var i := 0
	while rig.has_bone(StringName("spine%d" % i)):
		var t := float(i) / 9.0
		var amp := lerpf(0.05, 0.28, t) * (0.35 + 0.65 * moving)
		var wave := sin(_phase * TAU - float(i) * 0.75) * amp
		var curl := sweep * sweep_side * lerpf(0.0, 0.5, t) + wind * lerpf(0.0, 0.12, t)
		rig.rot(StringName("spine%d" % i), Vector3(0.0, wave + curl, 0.0))
		i += 1
	# 다리: 옆으로 벌린 기는 걸음
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		var group := (k / 2 + k % 2) % 2
		var p := fmod(_phase * 2.0 + 0.5 * group, 1.0)
		var swing := sin(p * TAU) * 0.4 * moving
		var lift := maxf(0.0, cos(p * TAU)) * 0.3 * moving
		rig.rot(StringName("leg%d_upper" % k), Vector3(0.0, side * swing, side * (lift + sub * 0.8)))
		rig.rot(StringName("leg%d_lower" % k), Vector3(0.0, 0.0, -side * lift * 0.5))
	# 가라앉기·몸 굴리기·들이받기 자세
	_roll = _roll + delta * 9.0 * roll if roll > 0.05 else lerp_angle(_roll, 0.0, 1.0 - exp(-6.0 * delta))
	rig.move(&"root", Vector3(0, -sub * 2.2 - wind * 0.15 + lunge * 0.1, 0))
	rig.rot(&"root", Vector3(-wind * 0.08 + roar * 0.12, 0, _roll))
	var breathe := sin(_t * 1.2 + _seed) * 0.02
	rig.rot(&"neck", Vector3(look_pitch * 0.3 + roar * 0.7 - wind * 0.15 + breathe, look_yaw * 0.5, 0))
	rig.rot(&"head", Vector3(look_pitch * 0.3 + roar * 0.25 - lunge * 0.1, look_yaw * 0.4 + sin(_t * 28.0) * 0.12 * w(&"stagger"), 0))
	var jaw := 0.08 + 0.2 * wind + 0.75 * roar + 0.6 * lunge + 0.5 * strike + 0.04 * sin(_t * 0.9 + _seed)
	rig.rot(&"jaw", Vector3(-jaw, 0, 0))

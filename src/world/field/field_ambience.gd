class_name FieldAmbience
extends Node
## 필드 환경음(기획서 §23.5): 바람, 낮의 새소리, 밤의 풀벌레와 부엉이, 강물, 마을의 망치 소리.
## 유니크가 다가오면 경고음 대신 환경음이 사라지고 낮은 울림만 남는다(§23.5 "환경음의 비정상적 변화").
## 반복되는 바탕음은 시작할 때 한 번 합성해 끊김 없이 되풀이한다.

const MIX_RATE := 22050

var world: FieldWorld
var player: Node3D

var _wind: AudioStreamPlayer
var _insects: AudioStreamPlayer
var _river: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _bird_timer: float = 2.0
var _owl_timer: float = 18.0
var _hammer_timer: float = 4.0
var _rng := RandomNumberGenerator.new()

static var _loops: Dictionary = {}


func setup(field: FieldWorld) -> void:
	world = field
	_rng.seed = 4242
	_wind = _loop_player(&"wind")
	_insects = _loop_player(&"insects")
	_river = _loop_player(&"river")
	_drone = _loop_player(&"drone")


func _loop_player(id: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = loop_stream(id)
	p.bus = &"SFX"
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _exit_tree() -> void:
	for p in [_wind, _insects, _river, _drone]:
		if p:
			p.stop()


func _process(delta: float) -> void:
	if world == null or player == null or not is_instance_valid(player):
		return
	var pos := player.global_position
	var p2 := Vector2(pos.x, pos.z)
	var layout := world.layout
	var dn := world.day_night
	var day := dn.daylight()
	var night := 1.0 - day
	var eerie := dn.eerie
	var calm := 1.0 - eerie
	var town := 1.0 if layout.in_town(p2, 6.0) else 0.0
	var shade := layout.shade_factor(p2)
	var river := clampf(1.0 - layout.distance_to_river(p2) / 32.0, 0.0, 1.0)
	var pond := clampf(1.0 - (p2.distance_to(FieldLayout.POND_CENTER) - FieldLayout.POND_RADIUS) / 25.0, 0.0, 1.0)
	var height_wind := clampf((pos.y - 8.0) / 20.0, 0.0, 1.0)
	_fade(_wind, (0.32 + height_wind * 0.35 + shade * 0.1) * (1.0 - town * 0.5) * (0.6 + calm * 0.4), delta)
	_fade(_insects, night * calm * (0.45 if town > 0.5 else 0.8) * (1.0 - shade * 0.3), delta)
	_fade(_river, maxf(river, pond * 0.5) * 0.8 * (0.3 + calm * 0.7), delta)
	_fade(_drone, eerie * 0.9, delta)

	# 새소리: 낮, 그늘 숲 깊은 곳과 마을에서는 드물다.
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		var rate := day * calm * (1.0 - shade * 0.75) * (1.0 - town * 0.6)
		_bird_timer = _rng.randf_range(1.5, 4.5) / maxf(rate, 0.15)
		if rate > 0.1:
			var ids: Array[StringName] = [&"bird_chirp_a", &"bird_chirp_b", &"bird_trill"]
			_play_around(pos, ids[_rng.randi() % ids.size()], 12.0, 35.0, 4.0, 10.0, -8.0, _rng.randf_range(0.9, 1.15))
	# 부엉이: 밤
	_owl_timer -= delta
	if _owl_timer <= 0.0:
		_owl_timer = _rng.randf_range(16.0, 40.0)
		if night > 0.7 and calm > 0.9 and town < 0.5:
			_play_around(pos, &"owl_hoot", 30.0, 55.0, 6.0, 12.0, -6.0, _rng.randf_range(0.92, 1.05))
	# 마을 공방의 망치질: 낮에만
	_hammer_timer -= delta
	if _hammer_timer <= 0.0:
		_hammer_timer = _rng.randf_range(2.5, 5.0)
		if day > 0.5 and pos.distance_to(world.town.center) < 70.0 and world.town.spots.has("smith"):
			var smith: Transform3D = world.town.spots["smith"]
			for i in 3:
				get_tree().create_timer(i * 0.42).timeout.connect(func() -> void:
					Sfx.play_at(&"anvil_strike", smith.origin + Vector3.UP * 1.0, -10.0, _rng.randf_range(0.97, 1.03), 90.0))


func _fade(p: AudioStreamPlayer, target_linear: float, delta: float) -> void:
	var current := db_to_linear(p.volume_db)
	current = move_toward(current, clampf(target_linear, 0.0, 1.0), delta * 0.5)
	p.volume_db = linear_to_db(maxf(current, 0.0001))


func _play_around(center: Vector3, id: StringName, min_d: float, max_d: float, min_h: float, max_h: float,
		volume_db: float, pitch: float) -> void:
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(min_d, max_d)
	var at := center + Vector3(cos(a) * d, _rng.randf_range(min_h, max_h), sin(a) * d)
	Sfx.play_at(id, at, volume_db, pitch, 90.0)


# --- 반복 바탕음 합성 ---

static func loop_stream(id: StringName) -> AudioStreamWAV:
	if _loops.has(id):
		return _loops[id]
	var seconds := 6.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var n := int(seconds * MIX_RATE)
	var fade := int(1.0 * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	match id:
		&"wind":
			var lp := 0.0
			var lp2 := 0.0
			for i in n + fade:
				var t := float(i) / MIX_RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.03
				lp2 += (lp - lp2) * 0.2
				var gust := 0.55 + 0.3 * sin(t * 0.9) + 0.15 * sin(t * 2.3 + 1.0)
				buf[i] = lp2 * 6.0 * gust
		&"river":
			var lp := 0.0
			for i in n + fade:
				var t := float(i) / MIX_RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
				var bubble := 0.75 + 0.25 * sin(t * 7.0 + sin(t * 1.7) * 3.0)
				buf[i] = lp * bubble * 0.8
		&"insects":
			# 여러 마리의 귀뚜라미: 빠른 떨림으로 된 짧은 울음이 제각각의 박자로 반복된다.
			var crickets := [[4200.0, 2.6, 0.0], [4700.0, 3.1, 0.4], [3900.0, 2.2, 1.1], [5100.0, 3.7, 0.7]]
			for i in n + fade:
				var t := float(i) / MIX_RATE
				var s := 0.0
				for c in crickets:
					var local := fmod(t * c[1] + c[2], 1.0)
					if local < 0.22:
						var env := sin(PI * local / 0.22)
						var trem := 0.5 + 0.5 * sin(TAU * 45.0 * t)
						s += sin(TAU * c[0] * t) * env * trem * 0.3
				buf[i] = s + rng.randf_range(-1.0, 1.0) * 0.02
		&"drone":
			var lp := 0.0
			for i in n + fade:
				var t := float(i) / MIX_RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.01
				var s := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 58.3 * t) * 0.4 + sin(TAU * 110.0 * t) * 0.12
				s *= 0.6 + 0.4 * sin(t * 0.7)
				buf[i] = s + lp * 3.0
	# 끝의 1초를 처음과 겹쳐 이음매가 들리지 않게 한다.
	for i in fade:
		var w := float(i) / float(fade)
		buf[i] = buf[i] * w + buf[n + i] * (1.0 - w)
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var norm := 0.8 / peak if peak > 0.0001 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * norm, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	_loops[id] = wav
	return wav

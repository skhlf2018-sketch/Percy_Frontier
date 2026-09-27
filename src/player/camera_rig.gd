class_name CameraRig
extends Node3D
## 카메라 연출: 화면 흔들림, 피격 움찔, 착지 흔들림, 걷기 흔들림(헤드밥).
## 설정의 '화면 흔들림 강도'와 '헤드밥' 옵션을 따른다(기획서 §8.7, §21.3).
## 조준 방향은 머리(Head)에서 계산하므로 이 연출은 명중에 영향을 주지 않는다.

const MAX_SHAKE_DEG := Vector3(3.0, 2.5, 2.0)
const TRAUMA_DECAY := 1.8
const BOB_AMPLITUDE := Vector2(0.018, 0.028)

var trauma: float = 0.0
## 0 정지 ~ 1 최고 속도. 플레이어가 매 프레임 넣는다.
var bob_speed: float = 0.0
var bob_active: bool = false

var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _flinch := Vector3.ZERO
var _land: float = 0.0
var _bob_phase: float = 0.0


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.5


func _shake_scale() -> float:
	return float(Settings.get_value(&"camera_shake"))


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount * _shake_scale(), 0.0, 1.0)


## 피격 움찔. from_right: 오른쪽에서 맞았으면 양수
func flinch(strength: float, from_right: float) -> void:
	var s := _shake_scale() * strength
	_flinch += Vector3(randf_range(1.2, 2.4) * s, -from_right * 1.5 * s, -from_right * 2.5 * s)


func land(impact_speed: float) -> void:
	_land = maxf(_land, clampf(impact_speed * 0.012, 0.0, 0.12) * maxf(_shake_scale(), 0.25))


func _process(delta: float) -> void:
	_time += delta
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	var amount := trauma * trauma
	var rot := Vector3(
		_noise.get_noise_2d(_time * 40.0, 0.0) * MAX_SHAKE_DEG.x,
		_noise.get_noise_2d(0.0, _time * 40.0) * MAX_SHAKE_DEG.y,
		_noise.get_noise_2d(_time * 40.0, 100.0) * MAX_SHAKE_DEG.z) * amount
	_flinch = _flinch.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
	rot += _flinch
	var pos := Vector3.ZERO
	if bool(Settings.get_value(&"head_bob")) and bob_active and bob_speed > 0.05:
		_bob_phase += delta * lerpf(7.0, 11.0, bob_speed)
		pos.x = cos(_bob_phase) * BOB_AMPLITUDE.x * bob_speed
		pos.y = absf(sin(_bob_phase)) * BOB_AMPLITUDE.y * bob_speed
	_land = lerpf(_land, 0.0, 1.0 - exp(-8.0 * delta))
	pos.y -= _land
	rotation_degrees = rot
	position = pos

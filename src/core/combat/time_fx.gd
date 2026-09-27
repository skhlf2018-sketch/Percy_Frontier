class_name TimeFx
extends RefCounted
## 게임 속도 연출(타격 정지, 간발의 회피 슬로 모션). 여러 요청이 겹치면 가장 느린 값을 쓰고,
## 모든 요청이 끝나면 원래 속도로 돌아온다. 시간은 게임 속도와 무관한 실제 경과로 잰다.

static var _requests: Array[Dictionary] = []
static var _serial: int = 0


## scale 배속을 seconds(실제 시간) 동안 요청한다.
static func request(tree: SceneTree, scale: float, seconds: float) -> void:
	if tree == null:
		return
	_serial += 1
	var id := _serial
	_requests.append({"id": id, "scale": clampf(scale, 0.01, 1.0)})
	_apply()
	await tree.create_timer(seconds, true, false, true).timeout
	for i in _requests.size():
		if _requests[i].id == id:
			_requests.remove_at(i)
			break
	_apply()


static func _apply() -> void:
	var s := 1.0
	for r in _requests:
		s = minf(s, float(r.scale))
	Engine.time_scale = s


static func is_slowed() -> bool:
	return not _requests.is_empty()


## 장면을 바꾸거나 테스트를 끝낼 때 원래 속도로 되돌린다.
static func reset() -> void:
	_requests.clear()
	Engine.time_scale = 1.0

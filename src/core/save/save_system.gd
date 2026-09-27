class_name SaveSystem
extends RefCounted
## 저장 파일(기획서 §20.2): 자동 저장 1칸과 수동 저장 3칸. 파일은 JSON이고 버전 정보를 남긴다.
## 덮어쓰기 전의 파일은 .bak으로 남겨, 저장 도중 문제가 생겨도 직전 상태로 되돌릴 수 있다.
## 게임 속 상태를 모으고 되돌리는 일은 Game이 맡고, 여기서는 파일 읽기·쓰기만 한다.

const VERSION := 1
const DIR := "user://saves"
const AUTO := "auto"
const MANUAL_SLOTS: Array[String] = ["1", "2", "3"]

static var directory := DIR


static func all_slots() -> Array[String]:
	var out: Array[String] = [AUTO]
	out.append_array(MANUAL_SLOTS)
	return out


static func slot_label(slot: String) -> String:
	return "자동 저장" if slot == AUTO else "수동 저장 %s" % slot


static func path_for(slot: String) -> String:
	return directory.path_join("%s.json" % slot)


## 저장한다. 성공하면 OK.
static func write(slot: String, game_data: Dictionary, summary: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory) if directory.begins_with("user://") else directory)
	var path := path_for(slot)
	var doc := {
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"summary": summary,
		"game": game_data,
	}
	var text := JSON.stringify(doc, "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	# 이전 파일은 백업으로 남기고, 새 파일을 제자리에 옮긴다.
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path)


## 읽는다. 파일이 없거나 깨졌으면 백업을 시도하고, 그래도 안 되면 빈 사전.
static func read(slot: String) -> Dictionary:
	var doc := _read_file(path_for(slot))
	if doc.is_empty():
		doc = _read_file(path_for(slot) + ".bak")
	return doc


static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	# 깨진 파일은 조용히 건너뛰고 백업을 읽는다(JSON.parse_string은 엔진 오류를 남긴다).
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	var doc: Dictionary = json.data
	if not doc.has("game") or int(doc.get("version", 0)) <= 0:
		return {}
	if int(doc.version) > VERSION:
		push_warning("더 새로운 버전의 저장 파일입니다: %s" % path)
	return doc


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot)) or FileAccess.file_exists(path_for(slot) + ".bak")


## 가장 최근에 저장한 칸(없으면 빈 문자열)
static func latest_slot() -> String:
	var best := ""
	var best_time := -1
	for slot in all_slots():
		var doc := read(slot)
		if doc.is_empty():
			continue
		var t := int(doc.get("saved_at", 0))
		if t > best_time:
			best_time = t
			best = slot
	return best


static func delete(slot: String) -> void:
	for p in [path_for(slot), path_for(slot) + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## 목록 표시용 한 줄 설명
static func describe(doc: Dictionary) -> String:
	if doc.is_empty():
		return "비어 있음"
	var s: Dictionary = doc.get("summary", {})
	var when := Time.get_datetime_string_from_unix_time(int(doc.get("saved_at", 0)) + _tz_offset(), true)
	var play := int(s.get("play_time", 0))
	return "%s · Lv %d · %s · 게임 속 %s · 플레이 %d:%02d · %s" % [
		s.get("name", "?"), int(s.get("level", 1)), s.get("area", ""), s.get("clock", ""),
		play / 3600, (play / 60) % 60, when]


static func _tz_offset() -> int:
	var tz := Time.get_time_zone_from_system()
	return int(tz.get("bias", 0)) * 60

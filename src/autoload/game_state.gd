extends Node
## 한 번의 플레이 동안 유지되는 진행 상태: 성장(레벨·능력치), 도감·분석도, 스킬 해금과 장착, 장비 선택,
## 발견한 지역.

signal skills_changed
signal loadout_changed
signal inventory_changed
## 의뢰 상태가 바뀌었다(QuestLog가 새로 만들어져도 이 신호는 그대로 이어진다)
signal quests_changed
## 지도에 새 칸이 드러났다
signal map_revealed

## 공명 장치 기본 기록에 들어 있는 시작 스킬
const STARTER_SKILL := &"frost_pulse"
const SKILL_SLOT_COUNT := 4

var bestiary: Bestiary
var progress: PlayerProgress
## 발견한 지역 id(처음 들어가면 경험치와 알림)
var discovered_areas: Array[StringName] = []
var unlocked_skills: Array[StringName] = []
## 장착 슬롯(키 4~7). 빈 슬롯은 &""
var skill_slots: Array[StringName] = []
var primary_weapon: StringName = &"rifle_bfa3"
var secondary_weapon: StringName = &"pistol_bf9"
var melee_weapon: StringName = &"sword_survey"
## 캐릭터 외형(HumanoidModel 사전)
var appearance: Dictionary = {}
## 누적 플레이 시간(초)
var play_time: float = 0.0
## 재료·의뢰 물품 보관함(아이템 id → 개수)과 은화
var inventory: Dictionary = {}
var silver: int = 0
## 의뢰 진행
var quests: QuestLog
## 가진 무기(총기·근접 id)와 강화 단계(id → 0..3)
var owned_weapons: Array[StringName] = []
var upgrades: Dictionary = {}
## 지도에 드러난 칸(기획서 §13.3: 방문한 지형을 기록한다). MAP_CELLS×MAP_CELLS, 1이면 드러남.
var map_cells := PackedByteArray()

const MAP_CELLS := 64
const MAP_CELL_SIZE := 8.0
const MAP_HALF := MAP_CELLS * MAP_CELL_SIZE * 0.5


func _ready() -> void:
	reset_session()


func reset_session() -> void:
	progress = PlayerProgress.new()
	progress.leveled_up.connect(_on_leveled_up)
	discovered_areas = []
	bestiary = Bestiary.new()
	bestiary.skill_unlocked.connect(_on_skill_unlocked)
	bestiary.analysis_changed.connect(_on_analysis_changed)
	bestiary.entry_discovered.connect(_on_entry_discovered)
	unlocked_skills = [STARTER_SKILL]
	skill_slots = [STARTER_SKILL, &"", &"", &""]
	primary_weapon = &"rifle_bfa3"
	secondary_weapon = &"pistol_bf9"
	melee_weapon = &"sword_survey"
	appearance = HumanoidModel.default_appearance()
	play_time = 0.0
	inventory = {}
	silver = 0
	quests = QuestLog.new()
	quests.item_counter = item_count
	quests.completed.connect(_on_quest_completed)
	quests.changed.connect(quests_changed.emit)
	owned_weapons = [&"rifle_bfa3", &"pistol_bf9", &"sword_survey"]
	upgrades = {}
	map_cells = PackedByteArray()
	map_cells.resize(MAP_CELLS * MAP_CELLS)
	skills_changed.emit()
	loadout_changed.emit()
	inventory_changed.emit()
	quests_changed.emit()
	map_revealed.emit()


## 새 캐릭터로 시작한다(캐릭터 생성 결과).
func start_new_character(config: Dictionary) -> void:
	reset_session()
	progress.character_name = String(config.get("name", "탐사자"))
	progress.set_origin(StringName(config.get("origin", "")))
	appearance = HumanoidModel.default_appearance()
	appearance.merge(config.get("appearance", {}), true)
	# 근접 탐사자는 쌍검을 들고 시작한다(다른 무기는 퍼시 공방에서 바꾼다).
	if progress.origin == &"blade":
		melee_weapon = &"twin_moon"
		owned_weapons.append(&"twin_moon")


# --- 저장(기획서 §20.1) ---

func to_dict() -> Dictionary:
	var unlocked: Array[String] = []
	for s in unlocked_skills:
		unlocked.append(String(s))
	var slots: Array[String] = []
	for s in skill_slots:
		slots.append(String(s))
	var areas: Array[String] = []
	for a in discovered_areas:
		areas.append(String(a))
	return {
		"progress": progress.to_dict(),
		"appearance": appearance.duplicate(),
		"bestiary": bestiary.to_dict(),
		"unlocked_skills": unlocked,
		"skill_slots": slots,
		"primary": String(primary_weapon),
		"secondary": String(secondary_weapon),
		"melee": String(melee_weapon),
		"areas": areas,
		"play_time": play_time,
		"inventory": _string_keys(inventory),
		"silver": silver,
		"quests": quests.to_dict(),
		"owned_weapons": owned_weapons.map(func(x: StringName) -> String: return String(x)),
		"upgrades": _string_keys(upgrades),
		"map": _pack_bits(map_cells),
	}


## 0/1 배열을 비트로 묶어 base64 문자열로 만든다.
static func _pack_bits(cells: PackedByteArray) -> String:
	var packed := PackedByteArray()
	packed.resize((cells.size() + 7) >> 3)
	for i in cells.size():
		if cells[i] != 0:
			packed[i >> 3] |= 1 << (i & 7)
	return Marshalls.raw_to_base64(packed)


static func _unpack_bits(text: String, count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(count)
	var packed := Marshalls.base64_to_raw(text) if text != "" else PackedByteArray()
	for i in mini(count, packed.size() * 8):
		out[i] = (packed[i >> 3] >> (i & 7)) & 1
	return out


static func _string_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out


func from_dict(d: Dictionary) -> void:
	reset_session()
	progress.from_dict(d.get("progress", {}))
	appearance.merge(d.get("appearance", {}), true)
	bestiary.from_dict(d.get("bestiary", {}))
	unlocked_skills = [STARTER_SKILL]
	for s in d.get("unlocked_skills", []):
		var id := StringName(s)
		if GameDB.skill(id) and not unlocked_skills.has(id):
			unlocked_skills.append(id)
	var slots: Array = d.get("skill_slots", [])
	for i in SKILL_SLOT_COUNT:
		var id := StringName(slots[i]) if i < slots.size() else &""
		skill_slots[i] = id if (id == &"" or unlocked_skills.has(id)) else &""
	if GameDB.weapon(StringName(d.get("primary", ""))):
		primary_weapon = StringName(d.primary)
	if GameDB.weapon(StringName(d.get("secondary", ""))):
		secondary_weapon = StringName(d.secondary)
	if GameDB.melee(StringName(d.get("melee", ""))):
		melee_weapon = StringName(d.melee)
	discovered_areas = []
	for a in d.get("areas", []):
		discovered_areas.append(StringName(a))
	play_time = maxf(float(d.get("play_time", 0.0)), 0.0)
	inventory = {}
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		var id := StringName(k)
		if ItemDB.has_item(id) and int(inv[k]) > 0:
			inventory[id] = int(inv[k])
	silver = maxi(int(d.get("silver", 0)), 0)
	quests.from_dict(d.get("quests", {}))
	var owned: Array = d.get("owned_weapons", [])
	if not owned.is_empty():
		owned_weapons = []
		for w in owned:
			var id := StringName(w)
			if (GameDB.weapon(id) or GameDB.melee(id)) and not owned_weapons.has(id):
				owned_weapons.append(id)
	for must in [primary_weapon, secondary_weapon, melee_weapon]:
		if not owned_weapons.has(must):
			owned_weapons.append(must)
	upgrades = {}
	var up: Dictionary = d.get("upgrades", {})
	for k in up:
		upgrades[StringName(k)] = clampi(int(up[k]), 0, MAX_UPGRADE)
	map_cells = _unpack_bits(String(d.get("map", "")), MAP_CELLS * MAP_CELLS)
	skills_changed.emit()
	loadout_changed.emit()
	inventory_changed.emit()
	quests_changed.emit()
	map_revealed.emit()


## 경험치를 준다(처치, 발견, 의뢰).
func grant_xp(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	progress.add_xp(amount)
	GameEvents.xp_gained.emit(amount, reason)


## 지역에 처음 들어가면 기록하고 경험치를 준다. 처음이면 true.
func discover_area(area_id: StringName, area_name: String, xp: int = 20) -> bool:
	if discovered_areas.has(area_id):
		return false
	discovered_areas.append(area_id)
	GameEvents.announce("지역 발견 · %s" % area_name, "퍼시 외곽권", GameEvents.AnnounceKind.DISCOVERY)
	grant_xp(xp, "지역 발견")
	return true


func _on_leveled_up(new_level: int, points: int) -> void:
	GameEvents.announce("레벨 업 · Lv %d" % new_level,
		"최대 HP·스태미나 증가 · 능력 포인트 +%d (Tab: 상태창)" % points, GameEvents.AnnounceKind.LEVEL_UP)


func is_skill_unlocked(skill_id: StringName) -> bool:
	return unlocked_skills.has(skill_id)


## 스킬을 해금하고 첫 빈 슬롯에 장착한다. 장착한 슬롯 번호(없으면 -1)를 돌려준다.
func unlock_skill(skill_id: StringName) -> int:
	if GameDB.skill(skill_id) == null:
		push_error("알 수 없는 스킬: %s" % skill_id)
		return -1
	if unlocked_skills.has(skill_id):
		return skill_slots.find(skill_id)
	unlocked_skills.append(skill_id)
	var slot := skill_slots.find(&"")
	if slot >= 0:
		skill_slots[slot] = skill_id
	skills_changed.emit()
	return slot


# --- 지도 ---

## 위치(x, z) 둘레 radius 안의 칸을 드러낸다. 새로 드러난 칸이 있으면 true.
func reveal_map(p: Vector2, radius: float) -> bool:
	var changed := false
	var c0 := _map_cell(p - Vector2(radius, radius))
	var c1 := _map_cell(p + Vector2(radius, radius))
	for iz in range(c0.y, c1.y + 1):
		for ix in range(c0.x, c1.x + 1):
			var idx := iz * MAP_CELLS + ix
			if map_cells[idx] != 0:
				continue
			var cell_center := Vector2((ix + 0.5) * MAP_CELL_SIZE - MAP_HALF, (iz + 0.5) * MAP_CELL_SIZE - MAP_HALF)
			if cell_center.distance_to(p) <= radius:
				map_cells[idx] = 1
				changed = true
	if changed:
		map_revealed.emit()
	return changed


func is_map_revealed(p: Vector2) -> bool:
	var c := _map_cell(p)
	return map_cells[c.y * MAP_CELLS + c.x] != 0


## 드러난 칸의 비율(0..1)
func map_explored_ratio() -> float:
	var n := 0
	for v in map_cells:
		n += v
	return float(n) / float(map_cells.size())


func _map_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x + MAP_HALF) / MAP_CELL_SIZE)), 0, MAP_CELLS - 1),
		clampi(int(floor((p.y + MAP_HALF) / MAP_CELL_SIZE)), 0, MAP_CELLS - 1))


# --- 보관함(기획서 §11.5) ---

func item_count(id: StringName) -> int:
	return int(inventory.get(id, 0))


func add_item(id: StringName, count: int = 1) -> void:
	if count <= 0 or not ItemDB.has_item(id):
		return
	inventory[id] = item_count(id) + count
	inventory_changed.emit()
	GameEvents.item_collected.emit(id, count)
	quests.notify(&"item", id)


## 개수만큼 있으면 빼고 true
func remove_item(id: StringName, count: int = 1) -> bool:
	if count <= 0 or item_count(id) < count:
		return false
	inventory[id] = item_count(id) - count
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()
	return true


func add_silver(amount: int) -> void:
	if amount <= 0:
		return
	silver += amount
	inventory_changed.emit()


func spend_silver(amount: int) -> bool:
	if amount < 0 or silver < amount:
		return false
	silver -= amount
	inventory_changed.emit()
	return true


# --- 무기 소유와 강화(기획서 §9.5) ---

const MAX_UPGRADE := 3


func owns_weapon(id: StringName) -> bool:
	return owned_weapons.has(id)


func give_weapon(id: StringName) -> void:
	if not owned_weapons.has(id):
		owned_weapons.append(id)
		loadout_changed.emit()


func upgrade_level(id: StringName) -> int:
	return int(upgrades.get(id, 0))


## 강화 단계당 피해 +8%
func upgrade_mult(id: StringName) -> float:
	return 1.0 + 0.08 * upgrade_level(id)


func set_upgrade(id: StringName, level: int) -> void:
	upgrades[id] = clampi(level, 0, MAX_UPGRADE)
	loadout_changed.emit()


# --- 의뢰 보상 ---

func _on_quest_completed(id: StringName) -> void:
	var q := QuestDB.get_quest(id)
	var reward: Dictionary = q.get("reward", {})
	var parts: Array[String] = []
	if int(reward.get("xp", 0)) > 0:
		parts.append("경험치 %d" % int(reward.xp))
	if int(reward.get("silver", 0)) > 0:
		add_silver(int(reward.silver))
		parts.append("은화 %d" % int(reward.silver))
	var cons: Dictionary = reward.get("consumables", {})
	for cid in cons:
		GameEvents.consumable_granted.emit(cid, int(cons[cid]))
		var c := GameDB.consumable(cid)
		parts.append("%s %d" % [c.display_name if c else String(cid), int(cons[cid])])
	GameEvents.announce("의뢰 완료 · %s" % QuestDB.title(id), " · ".join(parts), GameEvents.AnnounceKind.QUEST)
	if q.has("done_text"):
		GameEvents.notify(String(q.done_text), GameEvents.NoticeKind.INFO)
	if int(reward.get("xp", 0)) > 0:
		grant_xp(int(reward.xp), "의뢰 완료")


## 해금한 스킬을 슬롯에 넣는다. 다른 슬롯에 있던 스킬이면 두 슬롯을 맞바꾼다.
func assign_skill(skill_id: StringName, slot: int) -> bool:
	if slot < 0 or slot >= SKILL_SLOT_COUNT or not unlocked_skills.has(skill_id):
		return false
	var from := skill_slots.find(skill_id)
	if from == slot:
		return true
	var previous := skill_slots[slot]
	skill_slots[slot] = skill_id
	if from >= 0:
		skill_slots[from] = previous
	skills_changed.emit()
	return true


func set_primary_weapon(id: StringName) -> void:
	if GameDB.weapon(id) == null or primary_weapon == id:
		return
	primary_weapon = id
	loadout_changed.emit()


func set_melee_weapon(id: StringName) -> void:
	if GameDB.melee(id) == null or melee_weapon == id:
		return
	melee_weapon = id
	loadout_changed.emit()


## 시험장 전용: 모든 분석 대상의 분석을 완료한다.
func complete_all_analysis() -> void:
	for data in GameDB.analyzable_enemies():
		bestiary.complete(data)


func _on_skill_unlocked(skill_id: StringName, enemy_id: StringName, via_core: bool) -> void:
	var slot := unlock_skill(skill_id)
	var skill := GameDB.skill(skill_id)
	var enemy := GameDB.enemy(enemy_id)
	if skill == null or enemy == null:
		return
	var how := "스킬 핵 획득" if via_core else "분석 완료"
	var text := "%s %s — 스킬 해금: %s" % [enemy.display_name, how, skill.display_name]
	if slot >= 0:
		text += " (스킬 슬롯 %d)" % (slot + 1)
	GameEvents.notify(text, GameEvents.NoticeKind.UNLOCK)
	GameEvents.announce("스킬 습득 · %s" % skill.display_name,
		"%s %s%s" % [enemy.display_name, how, " · 슬롯 %d에 장착" % (slot + 1) if slot >= 0 else ""],
		GameEvents.AnnounceKind.SKILL)


func _on_analysis_changed(enemy_id: StringName, analysis: float, gained: float) -> void:
	if gained <= 0.0:
		return
	var enemy := GameDB.enemy(enemy_id)
	if enemy == null:
		return
	GameEvents.notify("%s 분석도 %d%%" % [enemy.display_name, int(floor(analysis))],
		GameEvents.NoticeKind.ANALYSIS)


func _on_entry_discovered(enemy_id: StringName) -> void:
	var enemy := GameDB.enemy(enemy_id)
	if enemy:
		GameEvents.notify("도감 등록: %s (%s)" % [enemy.display_name, enemy.tier_label()],
			GameEvents.NoticeKind.ANALYSIS)

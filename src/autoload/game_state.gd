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
## 탐사 단서·유니크 기록·각인·칭호가 바뀌었다
signal exploration_changed

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
## 든 무기(기획서 §9.1·§11.5): WeaponItem.Slot → WeaponItem. 칸마다 한 자루씩만 든다.
var equipped: Dictionary = {}
## 퍼시 창고(§11.5, 지역 간 공유)
var warehouse: Array[WeaponItem] = []
## 칸별 기본 무기 id(읽기 전용)
var primary_weapon: StringName:
	get:
		return _base_of(WeaponItem.Slot.PRIMARY)
var secondary_weapon: StringName:
	get:
		return _base_of(WeaponItem.Slot.SECONDARY)
var melee_weapon: StringName:
	get:
		return _base_of(WeaponItem.Slot.MELEE)
## 캐릭터 외형(HumanoidModel 사전)
var appearance: Dictionary = {}
## 누적 플레이 시간(초)
var play_time: float = 0.0
## 재료·의뢰 물품 보관함(아이템 id → 개수)과 은화
var inventory: Dictionary = {}
var silver: int = 0
## 의뢰 진행
var quests: QuestLog
## 지도에 드러난 칸(기획서 §13.3: 방문한 지형을 기록한다). MAP_CELLS×MAP_CELLS, 1이면 드러남.
var map_cells := PackedByteArray()
## 발견한 탐사 단서 id(기획서 §13.2)
var clues: Array[StringName] = []
## 유니크 기록(기획서 §15.1: 최초 발견·최초 생존·최초 처치): id → {"sighted", "survived", "defeated", "encounters"}
var unique_log: Dictionary = {}
## 유니크가 남긴 각인과 칭호
var marks: Array[StringName] = []
var titles: Array[StringName] = []
## 보스 기록(기획서 §20.1 "보스 처치 기록"): id → {"seen", "defeated", "attempts"}
var bosses: Dictionary = {}

const MAP_CELLS := 64
const MAP_CELL_SIZE := 8.0
const MAP_HALF := MAP_CELLS * MAP_CELL_SIZE * 0.5


func _ready() -> void:
	reset_session()


func _exit_tree() -> void:
	# 정적 캐시에 든 생물 메시·재질은 렌더링 서버가 내려가기 전에 놓아야 종료가 멈추지 않는다.
	SpeciesModels.clear_cache()


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
	equipped = {
		WeaponItem.Slot.PRIMARY: WeaponItem.create(&"rifle_bfa3"),
		WeaponItem.Slot.SECONDARY: WeaponItem.create(&"pistol_bf9"),
		WeaponItem.Slot.MELEE: WeaponItem.create(&"sword_survey"),
	}
	warehouse = []
	appearance = HumanoidModel.default_appearance()
	play_time = 0.0
	inventory = {}
	silver = 0
	quests = QuestLog.new()
	quests.item_counter = item_count
	quests.completed.connect(_on_quest_completed)
	quests.changed.connect(quests_changed.emit)
	map_cells = PackedByteArray()
	map_cells.resize(MAP_CELLS * MAP_CELLS)
	clues = []
	unique_log = {}
	marks = []
	titles = []
	bosses = {}
	quests.clue_counter = clue_count
	quests.boss_counter = func(boss_id: StringName) -> int: return 1 if boss_defeated(boss_id) else 0
	quests.unique_counter = func(unique_id: StringName) -> int: return 1 if unique_record(unique_id).survived else 0
	skills_changed.emit()
	loadout_changed.emit()
	inventory_changed.emit()
	quests_changed.emit()
	map_revealed.emit()
	exploration_changed.emit()


## 새 캐릭터로 시작한다(캐릭터 생성 결과).
func start_new_character(config: Dictionary) -> void:
	reset_session()
	progress.character_name = String(config.get("name", "탐사자"))
	progress.set_origin(StringName(config.get("origin", "")))
	appearance = HumanoidModel.default_appearance()
	appearance.merge(config.get("appearance", {}), true)
	# 근접 탐사자는 쌍검을 들고 시작한다(다른 무기는 퍼시 공방에서 바꾼다).
	if progress.origin == &"blade":
		var sword := equip_item(WeaponItem.create(&"twin_moon"))
		if sword:
			warehouse.append(sword)


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
		"equipped": _equipped_dict(),
		"warehouse": warehouse.map(func(it: WeaponItem) -> Dictionary: return it.to_dict()),
		"areas": areas,
		"play_time": play_time,
		"inventory": _string_keys(inventory),
		"silver": silver,
		"quests": quests.to_dict(),
		"map": _pack_bits(map_cells),
		"clues": clues.map(func(x: StringName) -> String: return String(x)),
		"unique_log": _string_keys(unique_log),
		"marks": marks.map(func(x: StringName) -> String: return String(x)),
		"titles": titles.map(func(x: StringName) -> String: return String(x)),
		"bosses": _string_keys(bosses),
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
	_load_weapons(d)
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
	map_cells = _unpack_bits(String(d.get("map", "")), MAP_CELLS * MAP_CELLS)
	for c in d.get("clues", []):
		var id := StringName(c)
		if UniqueDB.has_clue(id) and not clues.has(id):
			clues.append(id)
	var ul: Dictionary = d.get("unique_log", {})
	for k in ul:
		var id := StringName(k)
		if not UniqueDB.UNIQUES.has(id) or not (ul[k] is Dictionary):
			continue
		var rec: Dictionary = ul[k]
		unique_log[id] = {"sighted": bool(rec.get("sighted", false)), "survived": bool(rec.get("survived", false)),
			"defeated": bool(rec.get("defeated", false)), "encounters": maxi(int(rec.get("encounters", 0)), 0)}
	for m in d.get("marks", []):
		if UniqueDB.MARKS.has(StringName(m)) and not marks.has(StringName(m)):
			marks.append(StringName(m))
	for t in d.get("titles", []):
		if UniqueDB.TITLES.has(StringName(t)) and not titles.has(StringName(t)):
			titles.append(StringName(t))
	var bl: Dictionary = d.get("bosses", {})
	for k in bl:
		var id := StringName(k)
		var data := GameDB.enemy(id)
		if data == null or data.threat_tier != EnemyData.ThreatTier.BOSS or not (bl[k] is Dictionary):
			continue
		var rec: Dictionary = bl[k]
		bosses[id] = {"seen": bool(rec.get("seen", false)), "defeated": bool(rec.get("defeated", false)),
			"attempts": maxi(int(rec.get("attempts", 0)), 0)}
	skills_changed.emit()
	loadout_changed.emit()
	inventory_changed.emit()
	quests_changed.emit()
	map_revealed.emit()
	exploration_changed.emit()


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


# --- 탐사 단서와 유니크 기록(기획서 §13, §15) ---

## 단서를 기록한다. 처음이면 true.
func add_clue(id: StringName) -> bool:
	if clues.has(id) or not UniqueDB.has_clue(id):
		return false
	clues.append(id)
	var unique_id: StringName = UniqueDB.clue(id).unique
	var n := clue_count(unique_id)
	var sub := "%s 단서 · %s — J: 탐사 기록" % [UniqueDB.clue_kind_name(id), UniqueDB.clue(id).where]
	GameEvents.announce("탐사 단서 · %s" % UniqueDB.clue_title(id), sub, GameEvents.AnnounceKind.DISCOVERY)
	Sfx.play_ui(&"clue_found")
	var need := int(UniqueDB.UNIQUES[unique_id].clues_needed)
	if n == need:
		GameEvents.notify("탐사 기록에 추정이 정리되었습니다: %s" % UniqueDB.UNIQUES[unique_id].deduction,
			GameEvents.NoticeKind.ANALYSIS)
	grant_xp(15, "탐사 단서")
	exploration_changed.emit()
	# 의뢰의 단서 단계는 유니크별로 센다.
	quests.notify(&"clue", unique_id)
	return true


## 유니크별(또는 &"any": 전체) 단서 수
func clue_count(unique_id: StringName = &"any") -> int:
	if unique_id == &"any":
		return clues.size()
	var n := 0
	for c in clues:
		if UniqueDB.clue(c).unique == unique_id:
			n += 1
	return n


func unique_record(unique_id: StringName) -> Dictionary:
	return unique_log.get(unique_id, {"sighted": false, "survived": false, "defeated": false, "encounters": 0})


## 유니크 기록 항목(sighted/survived/defeated)을 채운다. 처음이면 true.
func record_unique(unique_id: StringName, key: String) -> bool:
	var rec := unique_record(unique_id).duplicate()
	if key == "encounters":
		rec.encounters = int(rec.encounters) + 1
		unique_log[unique_id] = rec
		exploration_changed.emit()
		return true
	if bool(rec.get(key, false)):
		return false
	rec[key] = true
	unique_log[unique_id] = rec
	exploration_changed.emit()
	return true


# --- 보스 기록(기획서 §16, §19.3: 이야기상 처치는 유지된다) ---

func boss_record(boss_id: StringName) -> Dictionary:
	return bosses.get(boss_id, {"seen": false, "defeated": false, "attempts": 0})


func boss_defeated(boss_id: StringName) -> bool:
	return bool(boss_record(boss_id).defeated)


## 보스 기록 항목(seen/defeated)을 채우거나 도전 횟수(attempts)를 센다. 처음 채웠으면 true.
func record_boss(boss_id: StringName, key: String) -> bool:
	var rec := boss_record(boss_id).duplicate()
	if key == "attempts":
		rec.attempts = int(rec.attempts) + 1
		bosses[boss_id] = rec
		return true
	if bool(rec.get(key, false)):
		return false
	rec[key] = true
	bosses[boss_id] = rec
	exploration_changed.emit()
	if key == "defeated":
		quests.notify(&"boss", boss_id)
	return true


func has_mark(id: StringName) -> bool:
	return marks.has(id)


func grant_mark(id: StringName) -> bool:
	if marks.has(id) or not UniqueDB.MARKS.has(id):
		return false
	marks.append(id)
	exploration_changed.emit()
	return true


func grant_title(id: StringName) -> bool:
	if titles.has(id) or not UniqueDB.TITLES.has(id):
		return false
	titles.append(id)
	exploration_changed.emit()
	return true


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


# --- 든 무기·창고·강화(기획서 §9.5, §11.5) ---

const MAX_UPGRADE := 3
const WAREHOUSE_SIZE := 12
## 확정 보상이 들어가는 여유 칸(창고가 가득 찼을 때)
const REWARD_OVERFLOW := 6


func _base_of(slot: int) -> StringName:
	var it: WeaponItem = equipped.get(slot)
	return it.base_id if it else &""


func equipped_item(slot: int) -> WeaponItem:
	return equipped.get(slot)


## 무기를 든다. 같은 칸에 들고 있던 무기를 돌려준다(부르는 쪽이 바닥에 내려놓거나 창고에 넣는다).
func equip_item(item: WeaponItem) -> WeaponItem:
	if item == null or not item.is_valid():
		return null
	var s := item.slot()
	var old: WeaponItem = equipped.get(s)
	equipped[s] = item
	loadout_changed.emit()
	return old


## 칸에 든 무기의 강화 단계를 바꾼다.
func set_upgrade(slot: int, level: int) -> void:
	var it: WeaponItem = equipped.get(slot)
	if it:
		it.upgrade = clampi(level, 0, MAX_UPGRADE)
		loadout_changed.emit()


func warehouse_full() -> bool:
	return warehouse.size() >= WAREHOUSE_SIZE


## 보스·유니크 확정 보상: 창고가 가득 차 있어도 넣는다(기획서 §11.1: 중요한 보상은 사라지지 않는다).
## 넘친 칸은 보상 전용 여유 칸(REWARD_OVERFLOW)에 들어가며, 비울 때까지 창고에 새 무기를 맡길 수 없다.
func store_reward(item: WeaponItem) -> void:
	if item == null or warehouse.has(item):
		return
	warehouse.append(item)
	loadout_changed.emit()


## 창고에 넣는다. 자리가 없으면 false.
func store_item(item: WeaponItem) -> bool:
	if item == null or warehouse_full():
		return false
	warehouse.append(item)
	loadout_changed.emit()
	return true


## 창고의 무기를 꺼내 든다. 같은 칸에 들고 있던 무기는 그 자리에 들어간다.
func take_from_warehouse(index: int) -> bool:
	if index < 0 or index >= warehouse.size():
		return false
	var it := warehouse[index]
	warehouse.remove_at(index)
	var old := equip_item(it)
	if old:
		warehouse.insert(mini(index, warehouse.size()), old)
	loadout_changed.emit()
	return true


func remove_from_warehouse(index: int) -> WeaponItem:
	if index < 0 or index >= warehouse.size():
		return null
	var it := warehouse[index]
	warehouse.remove_at(index)
	loadout_changed.emit()
	return it


func _equipped_dict() -> Dictionary:
	var out := {}
	for s in equipped:
		out[str(s)] = (equipped[s] as WeaponItem).to_dict()
	return out


## 저장 문서의 무기를 되살린다. 예전 형식(칸별 id·강화 사전·가진 무기 목록)도 읽는다.
func _load_weapons(d: Dictionary) -> void:
	var eq: Dictionary = d.get("equipped", {})
	if not eq.is_empty():
		for k in eq:
			var it := WeaponItem.from_dict(eq[k])
			if it and it.slot() == int(k):
				equipped[it.slot()] = it
		warehouse = []
		for w in d.get("warehouse", []):
			var it := WeaponItem.from_dict(w)
			if it and warehouse.size() < WAREHOUSE_SIZE + REWARD_OVERFLOW:
				warehouse.append(it)
		return
	# v0.3 이전: 칸별 id와 강화 단계, 가진 무기 목록
	var up: Dictionary = d.get("upgrades", {})
	for key in ["primary", "secondary", "melee"]:
		var id := StringName(d.get(key, ""))
		var it := WeaponItem.from_dict({"base": String(id), "upgrade": int(up.get(String(id), 0))})
		if it:
			equipped[it.slot()] = it
	for w in d.get("owned_weapons", []):
		var id := StringName(w)
		if id in [primary_weapon, secondary_weapon, melee_weapon]:
			continue
		var it := WeaponItem.from_dict({"base": String(id), "upgrade": int(up.get(String(id), 0))})
		if it and warehouse.size() < WAREHOUSE_SIZE:
			warehouse.append(it)


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


## 시험장 무기 거치대·시험용: 그 칸을 표준 무기로 바꾼다(들고 있던 무기는 사라진다).
func set_primary_weapon(id: StringName) -> void:
	var w := GameDB.weapon(id)
	if w == null or w.slot != WeaponData.Slot.PRIMARY or primary_weapon == id:
		return
	equip_item(WeaponItem.create(id))


func set_melee_weapon(id: StringName) -> void:
	if GameDB.melee(id) == null or melee_weapon == id:
		return
	equip_item(WeaponItem.create(id))


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

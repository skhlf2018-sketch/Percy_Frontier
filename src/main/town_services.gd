class_name TownServices
extends RefCounted
## 퍼시 주민과의 대화와 시설(기획서 §18.1): 의뢰 담당자·여관·잡화점·무기 공방·공명 연구소·경비·사냥꾼.
## 대화는 선택 메뉴로 보여 준다. 의뢰의 대화 단계는 말을 거는 순간 넘어간다.

const SHOP_CONSUMABLES := [[&"field_suture", 35], [&"purge_ampoule", 50]]
## 탄약 묶음: [종류, 양, 값]
const SHOP_AMMO := [[&"pistol", 36, 12], [&"rifle", 60, 20], [&"shell", 12, 18], [&"sniper", 10, 25]]
const WEAPON_PRICES := {
	&"shotgun_logger": 220, &"energy_re2": 380, &"sniper_l14": 450,
	&"karambit_hook": 150, &"twin_moon": 180, &"sword_survey": 120, &"rifle_bfa3": 150,
}
const UPGRADE_SILVER := [80, 160, 300]
const UPGRADE_GUN_ITEMS := [{&"stone_scale": 2}, {&"stone_scale": 3, &"spore_sac": 1}, {&"stone_scale": 3, &"charger_horn": 1}]
const UPGRADE_MELEE_ITEMS := [{&"rabbit_fang": 3}, {&"rabbit_fang": 3, &"stone_scale": 2}, {&"charger_horn": 1, &"stone_scale": 2}]
const RESET_COST_PER_LEVEL := 40
## 거점에서 기다릴 수 있는 시각(기획서 §13.4)
const WAIT_TIMES := [["아침 (06:00)", 6.0], ["한낮 (12:00)", 12.0], ["해 질 녘 (18:30)", 18.5], ["한밤 (23:00)", 23.0]]

var game: Game


func _init(g: Game) -> void:
	game = g


func _menus() -> MenuLayer:
	return game.menus


func _say(npc: TownNpc, text: String, entries: Array) -> void:
	_menus().open_choice("%s · %s" % [npc.display_name, npc.role], text, entries)


# --- 입구 ---

func talk(npc: TownNpc) -> void:
	var quests := GameState.quests
	# 대화 단계가 걸린 의뢰는 말을 거는 순간 넘어간다.
	var progressed: Array[StringName] = []
	for id in quests.active_ids():
		if quests.try_talk_step(id, npc.npc_id):
			progressed.append(id)
	GameEvents.npc_talked.emit(npc.npc_id)
	match npc.npc_id:
		&"clerk":
			_clerk(npc, progressed)
		&"innkeeper":
			_innkeeper(npc, progressed)
		&"merchant":
			_merchant(npc)
		&"smith":
			_smith(npc, progressed)
		&"researcher":
			_researcher(npc)
		&"guard":
			_guard(npc)
		&"hunter":
			_hunter(npc, progressed)


func _quest_offer(entries: Array, quest_id: StringName, pitch: String) -> void:
	if GameState.quests.state_of(quest_id) != QuestLog.State.INACTIVE:
		return
	entries.append({"text": "의뢰: %s" % QuestDB.title(quest_id), "detail": pitch,
		"action": func() -> void: GameState.quests.start(quest_id)})


# --- 주민별 대화 ---

func _clerk(npc: TownNpc, progressed: Array[StringName]) -> void:
	var q := GameState.quests
	var text := "퍼시의 의뢰는 제가 맡고 있습니다. 게시판에 붙은 일이 있으면 말씀드리죠."
	if progressed.has(&"main_signal"):
		text = "살아 계셨군요! 신호는 받았는데 구조대를 보낼 수가 없었습니다. 통신탑이 고장 나서요. " \
			+ "북동 초원의 바위등 돌격수 등껍질, 돌비늘 조각이면 고칠 수 있습니다. 세 개만 구해다 주세요. 대장장이 도르가가 손볼 겁니다."
	elif progressed.has(&"rabbit_trouble"):
		text = "토끼들이 좀 잠잠해졌다고 하더군요. 수고하셨습니다. 약속한 은화입니다."
	elif q.is_active(&"main_signal") and q.step_of(&"main_signal") == 2:
		text = "돌비늘 조각은 북동 초원의 바위등 돌격수에게서 나옵니다. 정면 장갑이 단단하니 등 뒤의 배기공이나 돌진 뒤 벽에 부딪혀 기절한 틈을 노리세요."
	var entries: Array = []
	if q.state_of(&"main_signal") != QuestLog.State.INACTIVE:
		_quest_offer(entries, &"rabbit_trouble",
			"강하 지점과 다리 사이 풀숲에서 살인토끼가 길손을 덮칩니다. 여섯 마리만 쫓아 주세요. (보상: 은화 80, 경험치 90)")
	entries.append({"text": "퍼시에 대해 묻는다", "keep_open": true, "action": func() -> void:
		_say(npc, "퍼시는 프론티어에서 가장 오래된 안전 지대에 세운 정착지입니다. 숲이 주는 것으로 먹고살지만, 숲이 언제 등을 돌릴지 모르죠. "
			+ "그래서 우리 같은 사람들이 필요한 겁니다.", [])})
	_say(npc, text, entries)


func _innkeeper(npc: TownNpc, progressed: Array[StringName]) -> void:
	var text := "어서 와요, 첫 등불에. 여기서 쉬고 가면 다음에 쓰러져도 여기서 눈을 뜨게 될 거예요."
	if progressed.has(&"herb_basket"):
		text = "어머, 내 바구니! 연못가 그 버섯 녀석들 때문에 다시는 못 찾을 줄 알았어요. 이걸로 봉합제를 만들어 뒀으니 가져가요."
	elif GameState.quests.is_active(&"herb_basket"):
		text = "바구니는 남서쪽 늪 연못가에 두고 왔어요. 불붙는 포자를 쏘는 녀석들이 있으니 조심해요."
	var entries: Array = []
	var inn := game.field.supply_point_by_name("Supply_inn") if game.field else null
	if inn:
		entries.append({"text": "휴식하고 저장한다", "detail": "HP·스태미나 회복, 탄약 보급, 이곳이 부활 지점이 됩니다. 야외 무리가 다시 나타납니다.",
			"keep_open": true, "action": func() -> void: game.open_rest_menu(game.player, inn)})
	_quest_offer(entries, &"herb_basket",
		"약초를 캐러 갔다가 남서쪽 늪 연못가에 바구니를 두고 왔어요. 찾아 주면 약초로 만든 봉합제를 드릴게요. (보상: 응급 봉합제 2, 은화 30)")
	_say(npc, text, entries)


func _merchant(npc: TownNpc) -> void:
	var entries: Array = [
		{"text": "물건을 산다", "keep_open": true, "action": func() -> void: open_shop(npc)},
		{"text": "재료를 판다", "keep_open": true, "action": func() -> void: open_sell(npc)},
	]
	_say(npc, "필요한 건 다 있어. 은화만 있다면 말이지. 쓸 만한 재료를 가져오면 값을 쳐 주고. (가진 은화: %d)" % GameState.silver, entries)


func _smith(npc: TownNpc, progressed: Array[StringName]) -> void:
	var text := "무기라면 나한테 맡겨. 바꾸든, 사든, 벼리든."
	if progressed.has(&"main_signal"):
		text = "돌비늘 조각이군. 이 정도면 통신탑 받침을 새로 댈 수 있지. …됐다. 봐, 탑 꼭대기 불빛이 다시 들어왔어."
		if game.field:
			game.field.town.fix_tower()
	var entries: Array = [
		{"text": "무기를 바꾼다", "keep_open": true, "action": func() -> void: open_equip(npc)},
		{"text": "무기를 산다", "keep_open": true, "action": func() -> void: open_buy_weapons(npc)},
		{"text": "무기를 강화한다", "keep_open": true, "action": func() -> void: open_upgrade(npc)},
	]
	_say(npc, text, entries)


func _researcher(npc: TownNpc) -> void:
	var cost := RESET_COST_PER_LEVEL * GameState.progress.level
	var entries: Array = [
		{"text": "분석 기록을 본다", "action": func() -> void: game.menus.open_status(StatusWindow.TAB_BESTIARY)},
		{"text": "스킬 슬롯을 정리한다", "action": func() -> void: game.menus.open_status(StatusWindow.TAB_SKILLS)},
		{"text": "능력치를 재설정한다 (은화 %d)" % cost,
			"detail": "분배한 능력 포인트를 모두 돌려받습니다. 시작 성향 보너스는 그대로입니다(기획서 §9.6).",
			"enabled": GameState.silver >= cost and _allocated_total() > 0,
			"keep_open": true, "action": func() -> void:
				if GameState.spend_silver(cost):
					var n := GameState.progress.reset_allocation()
					_say(npc, "공명 장치의 성장 기록을 되돌렸어요. 포인트 %d개를 다시 나눌 수 있어요." % n, [])},
	]
	_say(npc, "공명 장치는 몬스터가 남긴 법칙의 기록을 읽어요. 많이 보고, 많이 싸울수록 더 많이 읽죠.", entries)


func _allocated_total() -> int:
	var n := 0
	for v in GameState.progress.allocated:
		n += v
	return n


func _guard(npc: TownNpc) -> void:
	var text := "밤에는 정문 밖으로 멀리 나가지 마. 그늘 숲 쪽은 특히. 요즘 밤이면 숲이 이상할 만큼 조용해진다더군. 사냥꾼 노라한테 물어봐."
	_say(npc, text, [])


func _hunter(npc: TownNpc, progressed: Array[StringName]) -> void:
	var q := GameState.quests
	var text := "숲에서 먹고사는 사람이야. 요즘 숲이 이상해."
	if progressed.has(&"night_silence"):
		text = "…그걸 봤다고? 그리고 살아서 돌아왔고. 그 표식, 한동안 지워지지 않을 거야. 숲의 작은 것들은 이제 너를 피하겠지."
	elif q.is_active(&"night_silence"):
		text = "그늘 숲 가장자리를 살펴봐. 부러진 나무, 이상하게 큰 발자국. 그리고 밤에… 풀벌레 소리가 멎으면, 뒤를 보지 말고 뛰어."
	var entries: Array = []
	_quest_offer(entries, &"night_silence",
		"밤이 되면 그늘 숲이 조용해져. 새도 벌레도 다 입을 닫지. 무언가가 있어. 흔적을 찾아 봐. (추적 의뢰)")
	_say(npc, text, entries)


# --- 잡화점 ---

func open_shop(npc: TownNpc) -> void:
	var p := game.player
	var entries: Array = [{"header": true, "text": "소모품"}]
	for item in SHOP_CONSUMABLES:
		var id: StringName = item[0]
		var price: int = item[1]
		var c := GameDB.consumable(id)
		var have := int(p.consumable_counts.get(id, 0))
		var full := have >= c.max_carry
		entries.append({"text": "%s  ·  은화 %d  (가진 수 %d/%d)" % [c.display_name, price, have, c.max_carry],
			"detail": c.description if not full else "더 들 수 없습니다.",
			"enabled": not full and GameState.silver >= price, "keep_open": true,
			"action": func() -> void:
				if GameState.spend_silver(price):
					p.add_consumable(id, 1)
					Sfx.play_ui(&"pickup")
				open_shop(npc)})
	entries.append({"header": true, "text": "탄약"})
	for item in SHOP_AMMO:
		var type: StringName = item[0]
		var amount: int = item[1]
		var price: int = item[2]
		var full := p.ammo.get_count(type) >= p.ammo.get_max(type)
		entries.append({"text": "%s %d발  ·  은화 %d  (%d/%d)" % [AmmoInventory.type_name(type), amount, price,
				p.ammo.get_count(type), p.ammo.get_max(type)],
			"detail": "더 들 수 없습니다." if full else "",
			"enabled": not full and GameState.silver >= price, "keep_open": true,
			"action": func() -> void:
				if GameState.spend_silver(price):
					p.ammo.add(type, amount)
					p.weapons.ammo_changed.emit()
					Sfx.play_ui(&"pickup")
				open_shop(npc)})
	_menus().open_choice("잡화점 · 사기", "가진 은화: %d" % GameState.silver, entries)


func open_sell(npc: TownNpc) -> void:
	var entries: Array = []
	var total := 0
	for id: StringName in GameState.inventory:
		if ItemDB.is_quest_item(id):
			continue
		var count := GameState.item_count(id)
		var value := ItemDB.value_of(id)
		total += count * value
		entries.append({"text": "%s ×%d  ·  하나에 은화 %d" % [ItemDB.name_of(id), count, value],
			"detail": String(ItemDB.ITEMS[id].desc) + "\n누르면 하나 팝니다. 의뢰나 강화에 쓸 재료는 남겨 두세요.",
			"keep_open": true, "action": func() -> void:
				if GameState.remove_item(id, 1):
					GameState.add_silver(value)
				open_sell(npc)})
	if entries.is_empty():
		_menus().open_choice("잡화점 · 팔기", "팔 만한 재료가 없습니다. 몬스터를 쓰러뜨리면 재료가 떨어집니다.", [])
		return
	entries.append({"text": "모두 판다 (은화 %d)" % total, "keep_open": true, "action": func() -> void:
		for id: StringName in GameState.inventory.keys():
			if not ItemDB.is_quest_item(id):
				var n := GameState.item_count(id)
				if GameState.remove_item(id, n):
					GameState.add_silver(n * ItemDB.value_of(id))
		open_sell(npc)})
	_menus().open_choice("잡화점 · 팔기", "가진 은화: %d" % GameState.silver, entries)


# --- 무기 공방 ---

func open_equip(npc: TownNpc) -> void:
	var entries: Array = [{"header": true, "text": "주무기"}]
	for w in GameDB.weapons_for_slot(WeaponData.Slot.PRIMARY):
		if not GameState.owns_weapon(w.id):
			continue
		var equipped := GameState.primary_weapon == w.id
		var id := w.id
		entries.append({"text": "%s  ·  %s%s%s" % [w.display_name, w.class_label(), _upgrade_tag(id), "  (장착 중)" if equipped else ""],
			"detail": w.description, "enabled": not equipped, "keep_open": true,
			"action": func() -> void:
				GameState.set_primary_weapon(id)
				game.player.weapons.select_slot(WeaponManager.Slot.PRIMARY)
				open_equip(npc)})
	entries.append({"header": true, "text": "근접 무기"})
	for m in GameDB.all_melee():
		if not GameState.owns_weapon(m.id):
			continue
		var equipped := GameState.melee_weapon == m.id
		var id := m.id
		entries.append({"text": "%s%s%s" % [m.display_name, _upgrade_tag(id), "  (장착 중)" if equipped else ""],
			"detail": m.description, "enabled": not equipped, "keep_open": true,
			"action": func() -> void:
				GameState.set_melee_weapon(id)
				open_equip(npc)})
	_menus().open_choice("무기 공방 · 바꾸기", "가진 무기 가운데 고릅니다. 보조 총기는 고정입니다.", entries)


func _upgrade_tag(id: StringName) -> String:
	var lv := GameState.upgrade_level(id)
	return "  +%d" % lv if lv > 0 else ""


func open_buy_weapons(npc: TownNpc) -> void:
	var entries: Array = []
	for id: StringName in WEAPON_PRICES:
		if GameState.owns_weapon(id):
			continue
		var price: int = WEAPON_PRICES[id]
		var w := GameDB.weapon(id)
		var m := GameDB.melee(id)
		var label := w.display_name if w else m.display_name
		var kind := w.class_label() if w else "근접 무기"
		var desc := w.description if w else m.description
		entries.append({"text": "%s  ·  %s  ·  은화 %d" % [label, kind, price], "detail": desc,
			"enabled": GameState.silver >= price, "keep_open": true,
			"action": func() -> void:
				if GameState.spend_silver(price):
					GameState.give_weapon(id)
					Sfx.play_ui(&"unlock")
				open_buy_weapons(npc)})
	if entries.is_empty():
		_menus().open_choice("무기 공방 · 사기", "지금 팔 수 있는 무기는 모두 가지고 있습니다.", [])
		return
	_menus().open_choice("무기 공방 · 사기", "가진 은화: %d. 산 무기는 \"무기를 바꾼다\"에서 장착합니다." % GameState.silver, entries)


func upgrade_cost(id: StringName) -> Dictionary:
	var lv := GameState.upgrade_level(id)
	if lv >= GameState.MAX_UPGRADE:
		return {}
	var items: Dictionary = (UPGRADE_MELEE_ITEMS if GameDB.melee(id) else UPGRADE_GUN_ITEMS)[lv]
	return {"silver": UPGRADE_SILVER[lv], "items": items}


func can_afford(cost: Dictionary) -> bool:
	if cost.is_empty() or GameState.silver < int(cost.silver):
		return false
	for item in cost.items:
		if GameState.item_count(item) < int(cost.items[item]):
			return false
	return true


func apply_upgrade(id: StringName) -> bool:
	var cost := upgrade_cost(id)
	if not can_afford(cost):
		return false
	GameState.spend_silver(int(cost.silver))
	for item in cost.items:
		GameState.remove_item(item, int(cost.items[item]))
	GameState.set_upgrade(id, GameState.upgrade_level(id) + 1)
	return true


func open_upgrade(npc: TownNpc) -> void:
	var entries: Array = []
	for id: StringName in [GameState.primary_weapon, GameState.secondary_weapon, GameState.melee_weapon]:
		var w := GameDB.weapon(id)
		var m := GameDB.melee(id)
		var label := w.display_name if w else m.display_name
		var lv := GameState.upgrade_level(id)
		var cost := upgrade_cost(id)
		if cost.is_empty():
			entries.append({"text": "%s  +%d (최대)" % [label, lv], "enabled": false})
			continue
		var need: Array[String] = ["은화 %d" % int(cost.silver)]
		for item in cost.items:
			need.append("%s %d (가진 %d)" % [ItemDB.name_of(item), int(cost.items[item]), GameState.item_count(item)])
		var wid := id
		entries.append({"text": "%s  +%d → +%d  (피해 +8%%)" % [label, lv, lv + 1],
			"detail": "필요: " + ", ".join(need), "enabled": can_afford(cost), "keep_open": true,
			"action": func() -> void:
				if apply_upgrade(wid):
					Sfx.play_ui(&"unlock")
					GameEvents.notify("%s 강화 +%d" % [label, GameState.upgrade_level(wid)], GameEvents.NoticeKind.UNLOCK)
				open_upgrade(npc)})
	_menus().open_choice("무기 공방 · 강화", "장착한 무기를 벼립니다. 단계마다 피해가 8%씩 오릅니다(최대 +3).", entries)

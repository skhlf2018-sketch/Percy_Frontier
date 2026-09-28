class_name TownServices
extends RefCounted
## 퍼시 주민과의 대화와 시설(기획서 §18.1): 의뢰 담당자·여관·잡화점·무기 공방·공명 연구소·경비·사냥꾼.
## 대화는 선택 메뉴로 보여 준다. 의뢰의 대화 단계는 말을 거는 순간 넘어간다.

const SHOP_CONSUMABLES := [[&"field_suture", 35], [&"purge_ampoule", 50]]
## 탄약 묶음: [종류, 양, 값]
const SHOP_AMMO := [[&"pistol", 36, 12], [&"rifle", 60, 20], [&"shell", 12, 18], [&"sniper", 10, 25]]
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
	elif progressed.has(&"mire_maw_hunt"):
		text = "늪턱 구렁을… 정말로요? 늪길 탐사대의 흔적도 거기서 찾으셨다니. 이제 남서쪽 늪길로 짐마차가 다닐 수 있겠군요. " \
			+ "무기 공방에도 늪길로 들어온 물건이 생길 겁니다."
	elif q.is_active(&"mire_maw_hunt") and q.step_of(&"mire_maw_hunt") == 0:
		text = "통신탑을 고치자마자 나쁜 소식입니다. 남서쪽 늪길로 오던 탐사대의 신호가 끊겼어요. 늪이라면 사냥꾼 노라가 잘 압니다."
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
	var text := "무기라면 나한테 맡겨. 맡기든, 사든, 팔든, 벼리든. 들판에서 주운 물건도 값은 쳐 주지."
	if progressed.has(&"main_signal"):
		text = "돌비늘 조각이군. 이 정도면 통신탑 받침을 새로 댈 수 있지. …됐다. 봐, 탑 꼭대기 불빛이 다시 들어왔어."
		if game.field:
			game.field.town.fix_tower()
	var entries: Array = [
		{"text": "창고를 연다", "detail": "맡긴 무기를 꺼내 들거나 바꿔 듭니다.", "keep_open": true,
			"action": func() -> void: open_warehouse(npc)},
		{"text": "무기를 산다", "keep_open": true, "action": func() -> void: open_buy_weapons(npc)},
		{"text": "무기를 판다", "detail": "창고에 맡긴 무기를 팝니다.", "keep_open": true,
			"action": func() -> void: open_sell_weapons(npc)},
		{"text": "무기를 강화한다", "keep_open": true, "action": func() -> void: open_upgrade(npc)},
		{"text": "전리품으로 무기를 벼린다", "detail": "희귀 몬스터의 전리품이나 보스의 핵으로 이름 있는 무기를 만듭니다.",
			"keep_open": true, "action": func() -> void: open_trophy_craft(npc)},
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
	if GameState.unique_record(&"night_predator").survived:
		text = "소문 들었어. 그 숲에서 밤을 넘겼다며? …요즘 정문 밖 토끼들이 너만 보면 달아난다더군."
	_say(npc, text, [])


func _hunter(npc: TownNpc, progressed: Array[StringName]) -> void:
	var q := GameState.quests
	var text := "숲에서 먹고사는 사람이야. 요즘 숲이 이상해."
	var survived: bool = GameState.unique_record(&"night_predator").survived
	if progressed.has(&"mire_maw_hunt"):
		text = "늪길 탐사대 말이군. …늪턱 구렁 짓이야. 남서쪽 연못 너머, 늪이 끝나는 곳에 물이 고인 구렁이 있어. " \
			+ "악어 머리에 뱀 같은 몸통을 가진 놈이지. 멀리 있으면 크게 뛰어들어 무는데, 그때 옆으로 비켜서 돌기둥에 처박히게 해. " \
			+ "한참 정신을 못 차려. 그 틈에 목 아래 붉은 턱살을 노려. 옆이나 뒤로 돌면 꼬리가 날아오니 머리 쪽에 붙고. " \
			+ "다치면 진흙 속으로 숨는데, 발밑에 붉은 고리가 보이면 바로 뛰어. 구렁 동쪽 둔덕에 쉬어 갈 자리가 있어."
	elif q.is_active(&"mire_maw_hunt") and q.step_of(&"mire_maw_hunt") == 1:
		text = "늪턱 구렁은 머리로 들이받는 놈이야. 돌기둥 앞에 서 있다가 뛰어들 때 비켜. 붉은 턱살이 드러나면 그때가 기회야."
	elif progressed.has(&"night_silence"):
		text = "…그걸 봤다고? 그리고 살아서 돌아왔고. 그 표식, 한동안 지워지지 않을 거야. 숲의 작은 것들은 이제 너를 피하겠지."
	elif q.is_active(&"night_silence") and q.step_of(&"night_silence") == 0:
		text = "그늘 숲 가장자리를 살펴봐. 나무에 난 자국, 이상하게 큰 발자국. 북쪽 야영지에 누가 남기고 간 물건도 있다더군. " \
			+ "밤에 숲에 들어가 보는 것도 방법이지만… 풀벌레 소리가 멎으면, 뒤를 보지 말고 뛰어."
	elif q.is_active(&"night_silence"):
		text = "흔적은 모였군. 밤에, 숲 한가운데로 가 봐. 풀벌레 소리가 멎으면 그게 신호야. 이기려 들지 마. 버텨. " \
			+ "막는 것보다 피하는 게 낫고, 발톱은 흘려 낼 수 있어. 회복약은 넉넉히."
	elif survived:
		text = "살아남은 사람 눈빛이군. 그 각인, 자랑하고 다니진 마. 강한 놈들은 그 냄새를 더 잘 맡으니까."
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
		if not ItemDB.is_keepsake(id):
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
	entries.append({"text": "모두 판다 (은화 %d)" % total, "detail": "전용 무기 재료와 핵은 빼고 팝니다(하나씩은 팔 수 있습니다).",
		"keep_open": true, "action": func() -> void:
		for id: StringName in GameState.inventory.keys():
			if not ItemDB.is_keepsake(id):
				var n := GameState.item_count(id)
				if GameState.remove_item(id, n):
					GameState.add_silver(n * ItemDB.value_of(id))
		open_sell(npc)})
	_menus().open_choice("잡화점 · 팔기", "가진 은화: %d" % GameState.silver, entries)


# --- 무기 공방 ---
# 무기는 칸마다 한 자루씩 든다(기획서 §11.5). 여분은 공방 창고에 맡기고, 창고는 모든 지역이 함께 쓴다.

## 공방이 파는 표준품. 값은 무기 데이터의 price.
const SHOP_WEAPONS: Array[StringName] = [&"rifle_bfa3", &"shotgun_logger", &"energy_re2", &"sniper_l14",
	&"pistol_bf9", &"sword_survey", &"karambit_hook", &"twin_moon"]
## 늪턱 구렁을 쓰러뜨린 뒤 늪길로 들어오는 무기
const SHOP_WEAPONS_MIRE: Array[StringName] = [&"bolt_rifle", &"chief_greatblade"]
## 전리품 제작(기획서 §11.3 "퍼시: 특수 장비 제작", §14 희귀 몬스터·보스 전용 보상):
## 희귀 몬스터의 전리품이나 보스 핵으로 정해진 특성과 이름을 가진 무기를 벼린다. 특성은 굴리지 않는다.
const TROPHY_RECIPES: Array[Dictionary] = [
	{"base": &"karambit_hook", "tier": ItemRarity.Tier.EPIC, "name": "연쇄의 앞니",
		"perks": [&"keen", &"serrated", &"chain_weak"], "cost": {&"serial_fang": 1, &"rabbit_fang": 4}, "silver": 150,
		"source": "밤에 경계 숲의 토끼 무리 속에 섞이는 연쇄살인범토끼"},
	{"base": &"twin_moon", "tier": ItemRarity.Tier.EPIC, "name": "은갈기 쌍월",
		"perks": [&"quick_hands", &"resonant", &"counter_edge"], "cost": {&"silver_mane": 1, &"wolf_fang": 3}, "silver": 180,
		"source": "밤의 그늘 숲에 나타나는 은갈기 늑대"},
	{"base": &"shotgun_logger", "tier": ItemRarity.Tier.LEGENDARY, "name": "황금뿔 벌목꾼",
		"perks": [&"pack_breaker", &"keen", &"heavy_blow"], "cost": {&"gold_horn": 1, &"stone_scale": 4, &"charger_horn": 1},
		"silver": 250, "source": "낮에 북동 초원 깊은 곳을 누비는 황금뿔 돌격수"},
	{"base": &"sniper_l14", "tier": ItemRarity.Tier.LEGENDARY, "name": "외눈의 L-14",
		"perks": [&"one_eye", &"steady", &"resonant"], "cost": {&"oneeye_lens": 1, &"scrap_parts": 4}, "silver": 250,
		"source": "무너진 감시탑 위의 외눈 고블린 저격수"},
	{"base": &"pistol_bf9", "tier": ItemRarity.Tier.UNIQUE, "name": "늪턱의 송곳",
		"perks": [&"keen", &"serrated", &"last_rounds"], "cost": {&"maw_core": 1, &"maw_scale": 2}, "silver": 300,
		"source": "남서 늪 끝 구렁의 보스, 늪턱 구렁"},
]


## 공방 진열품: 데이터에 적힌 기본 희귀도로 만들고, 특성은 무기마다 늘 같게 굴린다(볼 때마다 바뀌지 않게).
static func shop_item(base: StringName) -> WeaponItem:
	var gun := GameDB.weapon(base)
	var m := GameDB.melee(base)
	var tier: int = gun.rarity if gun else (m.rarity if m else 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(base))
	return WeaponItem.roll(base, tier, rng)


## 선택 메뉴 한 줄: 이름(희귀도 색) · 분류 · 희귀도
static func item_label(it: WeaponItem) -> String:
	return "%s  ·  %s  ·  %s" % [it.display_name(), it.class_label(), it.rarity_name()]


## 무기 설명: 핵심 수치, 특성, 같은 칸에 든 무기와의 차이
static func item_detail(it: WeaponItem, compare_to: WeaponItem = null) -> String:
	var lines: Array[String] = [it.stat_line()]
	for pl in it.perk_lines():
		lines.append("◆ " + pl)
	if compare_to and compare_to != it:
		lines.append("지금 든 무기: %s [%s] — %s" % [compare_to.display_name(), compare_to.rarity_name(), compare_to.stat_line()])
	return "\n".join(lines)


func open_warehouse(npc: TownNpc) -> void:
	var entries: Array = [{"header": true, "text": "들고 있는 무기"}]
	for s in [WeaponItem.Slot.PRIMARY, WeaponItem.Slot.SECONDARY, WeaponItem.Slot.MELEE]:
		var cur := GameState.equipped_item(s)
		if cur:
			entries.append({"text": "%s — %s" % [WeaponItem.SLOT_NAMES[s], item_label(cur)], "detail": item_detail(cur),
				"color": cur.color(), "enabled": false})
	entries.append({"header": true, "text": "창고 (%d/%d)" % [GameState.warehouse.size(), GameState.WAREHOUSE_SIZE]})
	if GameState.warehouse.is_empty():
		entries.append({"text": "맡긴 무기가 없습니다.", "enabled": false})
	for i in GameState.warehouse.size():
		var it: WeaponItem = GameState.warehouse[i]
		var idx := i
		entries.append({"text": "%s  ·  %s" % [item_label(it), WeaponItem.SLOT_NAMES[it.slot()]],
			"detail": item_detail(it, GameState.equipped_item(it.slot())) + "\n누르면 꺼내 들고, 지금 든 무기를 대신 맡깁니다.",
			"color": it.color(), "keep_open": true,
			"action": func() -> void:
				if GameState.take_from_warehouse(idx):
					Sfx.play_ui(&"unlock")
					_select_slot_of(it)
				open_warehouse(npc)})
	_menus().open_choice("무기 공방 · 창고",
		"무기는 주무기·보조 총기·근접 무기를 한 자루씩만 듭니다. 여분은 여기 맡기고, 창고는 모든 거점이 함께 씁니다.", entries)


func _select_slot_of(it: WeaponItem) -> void:
	if game.player == null:
		return
	match it.slot():
		WeaponItem.Slot.PRIMARY:
			game.player.weapons.select_slot(WeaponManager.Slot.PRIMARY)
		WeaponItem.Slot.SECONDARY:
			game.player.weapons.select_slot(WeaponManager.Slot.SECONDARY)


## 사고팔 무기 목록. 지역 보스를 쓰러뜨리면 늪길로 새 물건이 들어온다(기획서 §18.2).
static func shop_weapons() -> Array[StringName]:
	var out: Array[StringName] = SHOP_WEAPONS.duplicate()
	if GameState.boss_defeated(&"mire_maw"):
		out.append_array(SHOP_WEAPONS_MIRE)
	return out


func open_buy_weapons(npc: TownNpc) -> void:
	var entries: Array = []
	var full := GameState.warehouse_full()
	for base in shop_weapons():
		var it := shop_item(base)
		if not it.is_valid():
			continue
		var price := it.price()
		var cur := GameState.equipped_item(it.slot())
		var detail := item_detail(it, cur)
		if full:
			detail += "\n창고가 가득 찼습니다. 지금 든 무기를 맡길 자리가 없습니다."
		entries.append({"text": "%s  ·  은화 %d" % [item_label(it), price], "detail": detail, "color": it.color(),
			"enabled": GameState.silver >= price and not full, "keep_open": true,
			"action": func() -> void:
				if buy_weapon(base):
					Sfx.play_ui(&"unlock")
					_select_slot_of(it)
				open_buy_weapons(npc)})
	_menus().open_choice("무기 공방 · 사기",
		"가진 은화: %d. 산 무기는 바로 들고, 들던 무기는 창고에 맡깁니다. (창고 %d/%d)" % [GameState.silver,
			GameState.warehouse.size(), GameState.WAREHOUSE_SIZE], entries)


## 표준품을 사서 든다. 들던 무기는 창고로 간다.
func buy_weapon(base: StringName) -> bool:
	var it := shop_item(base)
	if not it.is_valid() or GameState.warehouse_full() or not GameState.spend_silver(it.price()):
		return false
	var old := GameState.equip_item(it)
	if old:
		GameState.store_item(old)
	return true


func open_sell_weapons(npc: TownNpc) -> void:
	var entries: Array = []
	for i in GameState.warehouse.size():
		var it: WeaponItem = GameState.warehouse[i]
		var idx := i
		var value := it.sell_value()
		entries.append({"text": "%s  ·  은화 %d" % [item_label(it), value], "detail": item_detail(it) + "\n누르면 팝니다.",
			"color": it.color(), "keep_open": true,
			"action": func() -> void:
				var sold := GameState.remove_from_warehouse(idx)
				if sold:
					GameState.add_silver(value)
					Sfx.play_ui(&"pickup")
				open_sell_weapons(npc)})
	if entries.is_empty():
		_menus().open_choice("무기 공방 · 팔기", "창고에 맡긴 무기만 팔 수 있습니다. 들고 있는 무기는 창고에 맡긴 뒤 파세요.", [])
		return
	_menus().open_choice("무기 공방 · 팔기", "가진 은화: %d. 희귀할수록, 강화할수록 값을 더 쳐 줍니다." % GameState.silver, entries)


func upgrade_cost(it: WeaponItem) -> Dictionary:
	if it == null or it.upgrade >= GameState.MAX_UPGRADE:
		return {}
	var lv := it.upgrade
	var items: Dictionary = (UPGRADE_GUN_ITEMS if it.is_gun() else UPGRADE_MELEE_ITEMS)[lv]
	return {"silver": UPGRADE_SILVER[lv], "items": items}


static func can_afford(cost: Dictionary) -> bool:
	if cost.is_empty() or GameState.silver < int(cost.silver):
		return false
	for item in cost.items:
		if GameState.item_count(item) < int(cost.items[item]):
			return false
	return true


## 칸에 든 무기를 한 단계 벼린다.
func apply_upgrade(slot: int) -> bool:
	var it := GameState.equipped_item(slot)
	var cost := upgrade_cost(it)
	if not can_afford(cost):
		return false
	GameState.spend_silver(int(cost.silver))
	for item in cost.items:
		GameState.remove_item(item, int(cost.items[item]))
	GameState.set_upgrade(slot, it.upgrade + 1)
	return true


## 전리품 제작 결과물(정해진 희귀도·특성·이름)
static func trophy_item(recipe: Dictionary) -> WeaponItem:
	var perks: Array[StringName] = []
	perks.assign(recipe.perks)
	return WeaponItem.create(recipe.base, int(recipe.tier), perks, String(recipe.name))


static func can_craft_trophy(recipe: Dictionary) -> bool:
	return can_afford({"silver": int(recipe.silver), "items": recipe.cost})


## 전리품으로 무기를 벼려 바로 든다. 들던 무기는 창고로 간다(창고가 가득 차면 벼리지 않는다).
func craft_trophy(index: int) -> bool:
	if index < 0 or index >= TROPHY_RECIPES.size():
		return false
	var recipe: Dictionary = TROPHY_RECIPES[index]
	if not can_craft_trophy(recipe) or GameState.warehouse_full():
		return false
	if not GameState.spend_silver(int(recipe.silver)):
		return false
	for item: StringName in recipe.cost:
		GameState.remove_item(item, int(recipe.cost[item]))
	var it := trophy_item(recipe)
	var old := GameState.equip_item(it)
	if old:
		GameState.store_item(old)
	_select_slot_of(it)
	GameEvents.announce("무기 제작 · %s" % it.display_name(), "%s · %s" % [it.rarity_name(), it.class_label()],
		GameEvents.AnnounceKind.DISCOVERY)
	return true


func open_trophy_craft(npc: TownNpc) -> void:
	var entries: Array = []
	var full := GameState.warehouse_full()
	for i in TROPHY_RECIPES.size():
		var recipe: Dictionary = TROPHY_RECIPES[i]
		var it := trophy_item(recipe)
		var need: Array[String] = ["은화 %d" % int(recipe.silver)]
		var has_trophy := false
		for item: StringName in recipe.cost:
			need.append("%s %d (가진 %d)" % [ItemDB.name_of(item), int(recipe.cost[item]), GameState.item_count(item)])
			if (ItemDB.is_trophy(item) or ItemDB.is_core(item)) and GameState.item_count(item) > 0:
				has_trophy = true
		var detail := item_detail(it, GameState.equipped_item(it.slot())) + "\n필요: " + ", ".join(need)
		if not has_trophy:
			detail += "\n전리품을 얻는 곳: " + String(recipe.source)
		if full:
			detail += "\n창고가 가득 찼습니다. 지금 든 무기를 맡길 자리가 없습니다."
		var idx := i
		entries.append({"text": "%s  ·  %s  ·  %s" % [it.display_name(), it.class_label(), it.rarity_name()], "detail": detail,
			"color": it.color(), "enabled": can_craft_trophy(recipe) and not full, "keep_open": true,
			"action": func() -> void:
				if craft_trophy(idx):
					Sfx.play_ui(&"unlock")
					Sfx.play_ui(&"anvil_strike")
				open_trophy_craft(npc)})
	_menus().open_choice("무기 공방 · 전리품 제작",
		"희귀 몬스터의 전리품과 보스의 핵은 공방에서만 다룰 수 있지. 만든 무기는 바로 들고, 들던 무기는 창고에 맡긴다. (은화 %d)"
			% GameState.silver, entries)


func open_upgrade(npc: TownNpc) -> void:
	var entries: Array = []
	for s in [WeaponItem.Slot.PRIMARY, WeaponItem.Slot.SECONDARY, WeaponItem.Slot.MELEE]:
		var it := GameState.equipped_item(s)
		if it == null:
			continue
		var cost := upgrade_cost(it)
		if cost.is_empty():
			entries.append({"text": "%s (최대)" % it.display_name(), "color": it.color(), "enabled": false})
			continue
		var need: Array[String] = ["은화 %d" % int(cost.silver)]
		for item in cost.items:
			need.append("%s %d (가진 %d)" % [ItemDB.name_of(item), int(cost.items[item]), GameState.item_count(item)])
		var slot: int = s
		entries.append({"text": "%s  →  +%d  (피해 +8%%)" % [it.display_name(), it.upgrade + 1],
			"detail": "필요: " + ", ".join(need), "color": it.color(), "enabled": can_afford(cost), "keep_open": true,
			"action": func() -> void:
				if apply_upgrade(slot):
					Sfx.play_ui(&"unlock")
					GameEvents.notify("%s 강화" % GameState.equipped_item(slot).display_name(), GameEvents.NoticeKind.UNLOCK)
				open_upgrade(npc)})
	_menus().open_choice("무기 공방 · 강화", "들고 있는 무기를 벼립니다. 단계마다 피해가 8%씩 오릅니다(최대 +3).", entries)

class_name PlayerProgress
extends RefCounted
## 플레이어 성장(기획서 §10.1): 레벨, 경험치, 능력치.
## 레벨업은 HP·스태미나와 능력 포인트를 준다. 공격력은 레벨만으로 크게 늘지 않고(무기·빌드·약점 활용이 중심),
## 능력치 효과도 작게 잡아 플레이 방식을 조금씩 바꾸는 정도로 둔다.
## 능력치 이름과 분배 방식은 공명 장치의 "사용자 정보" 화면(VRMMO식 상태창)으로 보여 준다.

signal xp_changed
signal leveled_up(level: int, points: int)
signal stats_changed

enum Stat { VIT, END, STR, AGI, DEX, RES, LUC }

const STAT_COUNT := 7
const STAT_NAMES: Array[String] = ["체력", "지구력", "근력", "민첩", "기교", "공명", "행운"]
const STAT_KEYS: Array[String] = ["VIT", "END", "STR", "AGI", "DEX", "RES", "LUC"]
const STAT_DESCRIPTIONS: Array[String] = [
	"최대 HP가 늘어난다.",
	"최대 스태미나와 회복 속도가 늘어난다.",
	"근접 피해가 늘고, 방어할 때 스태미나를 덜 쓴다.",
	"이동이 빨라지고 회피 거리가 늘어난다.",
	"반동이 줄고 재장전이 빨라진다.",
	"최대 공명과 몬스터 스킬 위력, 공명 획득량이 늘어난다.",
	"재료·보급품이 더 잘 떨어지고 스킬 핵을 얻을 확률이 조금 오른다.",
]
const BASE_STAT := 5
const MAX_STAT := 60
const MAX_LEVEL := 30
const POINTS_PER_LEVEL := 3
const BASE_HP := 100.0
const BASE_STAMINA := 100.0
const BASE_RESONANCE := 100.0
const HP_PER_LEVEL := 6.0
const STAMINA_PER_LEVEL := 3.0

## 시작 성향(캐릭터 생성에서 고른다). 능력치 보너스와 짧은 설명.
const ORIGINS := {
	&"marksman": {"name": "사격 탐사자", "bonus": {Stat.DEX: 2, Stat.AGI: 1},
		"desc": "총기 다루기에 익숙하다. 반동 제어와 재장전이 빠르다."},
	&"blade": {"name": "근접 탐사자", "bonus": {Stat.STR: 2, Stat.AGI: 1},
		"desc": "칼을 먼저 뽑는다. 근접 피해와 기동이 좋다."},
	&"resonant": {"name": "공명 탐사자", "bonus": {Stat.RES: 2, Stat.LUC: 1},
		"desc": "공명 장치와 잘 맞는다. 몬스터 스킬을 자주, 세게 쓴다."},
	&"survivor": {"name": "생존 탐사자", "bonus": {Stat.VIT: 2, Stat.END: 1},
		"desc": "쉽게 쓰러지지 않는다. HP와 스태미나가 넉넉하다."},
}

var character_name: String = "탐사자"
## 시작 성향(캐릭터 생성에서 고른다). 비어 있으면 보너스 없음
var origin: StringName = &""
var level: int = 1
## 현재 레벨 안에서 모은 경험치
var xp: int = 0
var total_xp: int = 0
var unspent_points: int = 0
## 분배한 포인트(성향 보너스와 기본값 제외)
var allocated: Array[int] = [0, 0, 0, 0, 0, 0, 0]


static func xp_to_next(for_level: int) -> int:
	return int(round(45.0 * pow(float(for_level), 1.55))) + 35


func set_origin(id: StringName) -> void:
	if ORIGINS.has(id):
		origin = id
		stats_changed.emit()


func origin_name() -> String:
	return ORIGINS[origin].name if ORIGINS.has(origin) else ""


## 기본값 + 성향 보너스 + 분배한 포인트
func stat(s: int) -> int:
	var bonus: Dictionary = ORIGINS[origin].bonus if ORIGINS.has(origin) else {}
	return BASE_STAT + int(bonus.get(s, 0)) + allocated[s]


func _above_base(s: int) -> int:
	return stat(s) - BASE_STAT


## 경험치를 더한다. 오른 레벨 수를 돌려준다.
func add_xp(amount: int) -> int:
	if amount <= 0 or level >= MAX_LEVEL:
		return 0
	xp += amount
	total_xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		unspent_points += POINTS_PER_LEVEL
		gained += 1
		leveled_up.emit(level, POINTS_PER_LEVEL)
	if level >= MAX_LEVEL:
		xp = 0
	xp_changed.emit()
	if gained > 0:
		stats_changed.emit()
	return gained


## 능력 포인트를 쓴다(여러 개를 한꺼번에 확정할 때는 apply_allocation을 쓴다).
func allocate(s: int, points: int = 1) -> bool:
	if points <= 0 or points > unspent_points or stat(s) + points > MAX_STAT:
		return false
	allocated[s] += points
	unspent_points -= points
	stats_changed.emit()
	return true


## 분배 계획(능력치별 포인트 배열)을 한 번에 확정한다.
func apply_allocation(plan: Array) -> bool:
	var total := 0
	for i in STAT_COUNT:
		var n := int(plan[i]) if i < plan.size() else 0
		if n < 0 or stat(i) + n > MAX_STAT:
			return false
		total += n
	if total > unspent_points:
		return false
	for i in STAT_COUNT:
		allocated[i] += int(plan[i]) if i < plan.size() else 0
	unspent_points -= total
	stats_changed.emit()
	return true


## 분배를 되돌린다(퍼시에서 성장 선택 재설정, 기획서 §9.6). 돌려받은 포인트 수를 돌려준다.
func reset_allocation() -> int:
	var refunded := 0
	for i in STAT_COUNT:
		refunded += allocated[i]
		allocated[i] = 0
	unspent_points += refunded
	stats_changed.emit()
	return refunded


# --- 능력치 효과 ---

func max_hp() -> float:
	return BASE_HP + (level - 1) * HP_PER_LEVEL + _above_base(Stat.VIT) * 4.0


func max_stamina() -> float:
	return BASE_STAMINA + (level - 1) * STAMINA_PER_LEVEL + _above_base(Stat.END) * 3.0


func stamina_regen_mult() -> float:
	return 1.0 + _above_base(Stat.END) * 0.02


func melee_damage_mult() -> float:
	return 1.0 + _above_base(Stat.STR) * 0.015


func guard_cost_mult() -> float:
	return maxf(1.0 - _above_base(Stat.STR) * 0.01, 0.7)


func move_speed_mult() -> float:
	return minf(1.0 + _above_base(Stat.AGI) * 0.006, 1.15)


func dodge_distance_mult() -> float:
	return minf(1.0 + _above_base(Stat.AGI) * 0.01, 1.3)


func recoil_mult() -> float:
	return maxf(1.0 - _above_base(Stat.DEX) * 0.015, 0.6)


func reload_speed_mult() -> float:
	return minf(1.0 + _above_base(Stat.DEX) * 0.012, 1.4)


func max_resonance() -> float:
	return BASE_RESONANCE + _above_base(Stat.RES) * 3.0


func skill_power_mult() -> float:
	return 1.0 + _above_base(Stat.RES) * 0.015


func resonance_gain_mult() -> float:
	return 1.0 + _above_base(Stat.RES) * 0.01


func drop_chance_mult() -> float:
	return 1.0 + _above_base(Stat.LUC) * 0.02


func core_chance_bonus() -> float:
	return _above_base(Stat.LUC) * 0.0025


## 능력치 한 칸의 효과를 사람이 읽을 수 있는 짧은 글로
func stat_effect_text(s: int) -> String:
	var n := _above_base(s)
	match s:
		Stat.VIT:
			return "최대 HP +%d" % int(n * 4)
		Stat.END:
			return "최대 스태미나 +%d · 회복 +%d%%" % [int(n * 3), int(n * 2)]
		Stat.STR:
			return "근접 피해 +%.1f%% · 방어 소모 -%d%%" % [n * 1.5, int(round((1.0 - guard_cost_mult()) * 100.0))]
		Stat.AGI:
			return "이동 +%.1f%% · 회피 거리 +%d%%" % [(move_speed_mult() - 1.0) * 100.0, int(round((dodge_distance_mult() - 1.0) * 100.0))]
		Stat.DEX:
			return "반동 -%d%% · 재장전 +%d%%" % [int(round((1.0 - recoil_mult()) * 100.0)), int(round((reload_speed_mult() - 1.0) * 100.0))]
		Stat.RES:
			return "최대 공명 +%d · 스킬 위력 +%.1f%%" % [int(n * 3), n * 1.5]
		Stat.LUC:
			return "드롭 +%d%% · 스킬 핵 +%.2f%%p" % [int(n * 2), core_chance_bonus() * 100.0]
	return ""


# --- 저장 ---

func to_dict() -> Dictionary:
	return {
		"name": character_name, "origin": String(origin), "level": level, "xp": xp,
		"total_xp": total_xp, "unspent": unspent_points, "allocated": allocated.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	character_name = String(d.get("name", character_name))
	origin = StringName(d.get("origin", String(origin)))
	if not ORIGINS.has(origin):
		origin = &""
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(d.get("xp", 0)), 0)
	total_xp = maxi(int(d.get("total_xp", 0)), 0)
	unspent_points = maxi(int(d.get("unspent", 0)), 0)
	var a: Array = d.get("allocated", [])
	for i in STAT_COUNT:
		allocated[i] = maxi(int(a[i]), 0) if i < a.size() else 0
	xp_changed.emit()
	stats_changed.emit()

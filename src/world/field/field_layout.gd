class_name FieldLayout
extends RefCounted
## 퍼시 외곽권(기획서 §12 지역 1: 시작 숲, 첫 마을, 기본 시스템 학습)의 배치와 지형 규칙.
## 좌표는 지도 중심이 원점, -Z가 북쪽, 단위는 m. 물 높이는 0이다.
## 지형 높이·식생 밀도·지표 색을 한곳에서 계산해 지형 메시, 충돌, 식생 배치가 서로 어긋나지 않게 한다.

const HALF_SIZE := 256.0
const WATER_LEVEL := 0.0
const SEED := 7031

## 주요 장소(x, z)
const DROP_SITE := Vector2(-182, 28)          # 강하선 잔해(새 게임 시작 지점, 첫 안전 거점)
const TOWN_CENTER := Vector2(150, 136)        # 퍼시 마을
const TOWN_RADIUS := 46.0
const TOWN_HEIGHT := 11.0
const TOWN_GATE := Vector2(104, 136)          # 서쪽 정문
const OLD_TREE := Vector2(12, -34)            # 고목(랜드마크)
const WATCHTOWER := Vector2(78, -58)          # 무너진 감시탑(전망 지점)
const CAMP := Vector2(46, -138)               # 북쪽 야영지(안전 거점)
const SHADE_CENTER := Vector2(-72, -140)      # 그늘 숲(짙은 숲, 밤의 포식자 영역)
const SHADE_RADIUS := 96.0
const POND_CENTER := Vector2(-150, 172)       # 남서 늪 연못
const POND_RADIUS := 25.0
const MEADOW_CENTER := Vector2(150, -104)     # 북동 초원 언덕
const MEADOW_RADIUS := 78.0
const BRIDGE := Vector2(-24, 52)              # 강을 건너는 나무다리
const MAW_CENTER := Vector2(-196, 208)        # 늪턱 구렁(1지역 보스 전장): 남서 늪 끝의 물에 잠긴 구덩이
const MAW_RADIUS := 19.0                      # 물에 잠긴 평평한 바닥 반경
const MAW_BLEND := 12.0                       # 바닥에서 둘레 지형까지 이어지는 비탈 폭
const MAW_FLOOR := -0.4                       # 바닥 높이(물 높이보다 낮아 얕은 물이 고인다)

## 강하선 잔해 → 다리 → 퍼시 정문으로 이어지는 흙길
const ROAD: Array[Vector2] = [
	Vector2(-176, 30), Vector2(-150, 38), Vector2(-112, 46), Vector2(-70, 54),
	Vector2(-38, 53), Vector2(-10, 51), Vector2(24, 64), Vector2(58, 88),
	Vector2(84, 116), Vector2(104, 136), Vector2(150, 136),
]
## 퍼시에서 북쪽 야영지로 가는 샛길
const TRAIL: Array[Vector2] = [
	Vector2(58, 88), Vector2(66, 40), Vector2(70, -6), Vector2(62, -60),
	Vector2(52, -104), Vector2(46, -138),
]
## 북쪽 산에서 남쪽으로 흐르는 강(얕아서 걸어서 건널 수 있다)
const RIVER: Array[Vector2] = [
	Vector2(-44, -262), Vector2(-58, -190), Vector2(-34, -118), Vector2(-48, -44),
	Vector2(-24, 52), Vector2(-40, 120), Vector2(-14, 190), Vector2(-28, 262),
]
## 야외 무리: [x, z, 구성, 설정]. 구성은 [[종 id, 수], [종 id, 수, "night"|"day"], ...].
## 설정: ambush(매복), spread(배치 반경), cond(무리 전체가 "night"/"day"에만),
## drop(바닥을 찾는 높이: 탑 위에 세울 때), perch(높은 자리 반경: 저격수가 탑 위 가장자리를 지킨다).
## 시작 지점에서 멀어질수록 위험해진다(기획서 §4.3, §5.1). 지역마다 어울리는 종이 산다(§12, §14.5).
const ENCOUNTERS := [
	# 경계 숲(강하 지점 둘레, Lv 2~3): 살인토끼 매복, 뿔토끼, 밤에는 연쇄살인범토끼와 늑대
	[-128, 62, [[&"killer_rabbit", 3], [&"serial_rabbit", 1, "night"]], {"ambush": true}],
	[-150, 100, [[&"killer_rabbit", 3]], {"ambush": true}],
	[-84, 22, [[&"killer_rabbit", 4], [&"serial_rabbit", 1, "night"]], {"ambush": true}],
	[-160, -10, [[&"horn_rabbit", 2]], {}],
	[-110, 112, [[&"killer_rabbit", 2], [&"horn_rabbit", 1]], {"ambush": true}],
	[-205, 72, [[&"killer_rabbit", 3]], {"ambush": true}],
	[-60, 92, [[&"thorn_boar", 1]], {}],
	[-98, -22, [[&"ash_wolf", 3]], {"cond": "night"}],
	# 가운데(고목 언덕·다리 둘레, Lv 3~4)
	[14, 26, [[&"killer_rabbit", 4]], {"ambush": true}],
	[42, -12, [[&"horn_rabbit", 2]], {}],
	[-8, -62, [[&"thorn_boar", 2]], {}],
	[30, 94, [[&"goblin_scout", 1], [&"goblin_brute", 1], [&"goblin_thrower", 1]], {"spread": 3.5}],
	[72, 58, [[&"killer_rabbit", 3]], {"ambush": true}],
	[102, 18, [[&"ash_wolf", 3]], {}],
	[-32, 118, [[&"bog_toad", 1], [&"killer_rabbit", 2]], {"ambush": true}],
	# 무너진 감시탑의 고블린 초소(Lv 5~8): 탑 위의 외눈 저격수
	[78, -58, [[&"oneeye_sniper", 1]], {"spread": 0.0, "drop": 12.0, "perch": 2.55}],
	[92, -44, [[&"goblin_gunner", 2], [&"goblin_brute", 1], [&"goblin_shaman", 1]], {"spread": 3.5}],
	[60, -80, [[&"goblin_scout", 1], [&"goblin_thrower", 1]], {"spread": 3.0}],
	# 남쪽 고블린 야영지(Lv 5~7): 두목과 무리
	[40, 200, [[&"goblin_chief", 1], [&"goblin_brute", 2], [&"goblin_shaman", 1]], {"spread": 4.0}],
	[62, 184, [[&"goblin_gunner", 2], [&"goblin_thrower", 1]], {"spread": 3.5}],
	[18, 216, [[&"goblin_brute", 1], [&"goblin_scout", 2]], {"spread": 3.5}],
	[4, 168, [[&"goblin_scout", 1], [&"goblin_gunner", 1]], {"spread": 3.0}],
	[78, 226, [[&"goblin_thrower", 2], [&"goblin_brute", 1]], {"spread": 3.5}],
	# 북동 초원(Lv 5~8): 바위등 돌격수와 새끼, 멧돼지, 뿔토끼, 늑대 무리, 드문 황금뿔
	[150, -118, [[&"rock_charger", 1], [&"mossback_calf", 2]], {"spread": 5.0}],
	[190, -62, [[&"rock_charger", 1]], {}],
	[120, -150, [[&"rock_charger", 1], [&"mossback_calf", 1]], {"spread": 5.0}],
	[205, -152, [[&"goldhorn_charger", 1]], {"cond": "day"}],
	[130, -72, [[&"horn_rabbit", 3]], {}],
	[172, -28, [[&"thorn_boar", 2]], {}],
	[222, -100, [[&"thorn_boar", 1], [&"horn_rabbit", 2]], {}],
	[108, -108, [[&"ash_wolf", 4], [&"wolf_alpha", 1]], {"spread": 4.5}],
	[232, -202, [[&"ash_wolf", 3]], {}],
	# 북쪽 야영지 바깥
	[18, -182, [[&"killer_rabbit", 3]], {"ambush": true}],
	[82, -192, [[&"horn_rabbit", 2], [&"thorn_boar", 1]], {}],
	# 그늘 숲(Lv 5~7): 나무껍질 사마귀, 거미, 포자 모체, 밤의 늑대와 은갈기
	[-40, -112, [[&"bark_mantis", 1]], {}],
	[-102, -98, [[&"bark_mantis", 1]], {}],
	[-60, -182, [[&"cave_spider", 2]], {}],
	[-122, -162, [[&"spore_mother", 1], [&"bloat_pod", 3]], {"spread": 5.0}],
	[-20, -152, [[&"spore_spitter", 2], [&"bloat_pod", 2]], {"spread": 4.0}],
	[-88, -58, [[&"ash_wolf", 3]], {"cond": "night"}],
	[-132, -112, [[&"silvermane", 1]], {"cond": "night"}],
	[-30, -204, [[&"bark_mantis", 1], [&"cave_spider", 1]], {}],
	[-112, -204, [[&"cave_spider", 3]], {}],
	[-152, -60, [[&"thorn_boar", 2]], {}],
	# 북서 동굴 어귀: 박쥐와 거미
	[-196, -172, [[&"cave_bat", 5]], {"spread": 3.0}],
	[-214, -140, [[&"cave_spider", 2]], {}],
	[-182, -206, [[&"cave_bat", 4], [&"cave_spider", 1]], {"spread": 3.0}],
	# 남서 늪 연못: 포자 사수, 부푼 포자낭, 늪 두꺼비
	[-128, 150, [[&"spore_spitter", 2]], {}],
	[-146, 206, [[&"spore_spitter", 2], [&"bloat_pod", 2]], {"spread": 4.0}],
	[-150, 138, [[&"bog_toad", 2]], {}],
	[-188, 160, [[&"bog_toad", 1], [&"bloat_pod", 2]], {"spread": 3.5}],
	[-118, 198, [[&"bog_toad", 1]], {}],
	# 강가와 남쪽
	[-46, 2, [[&"bog_toad", 1]], {}],
	[-22, 232, [[&"bog_toad", 1], [&"thorn_boar", 1]], {}],
	[-96, -150, [[&"killer_rabbit", 4]], {"ambush": true}],
	# 동쪽(퍼시 둘레 바깥)
	[204, 60, [[&"horn_rabbit", 2]], {}],
	[232, 4, [[&"thorn_boar", 1], [&"ash_wolf", 2]], {}],
	[212, 232, [[&"ash_wolf", 3]], {}],
	[122, 232, [[&"killer_rabbit", 3]], {"ambush": true}],
]
const ROAD_HALF_WIDTH := 2.6
const RIVER_HALF_WIDTH := 5.0
const RIVER_DEPTH := 0.85
const POND_DEPTH := 1.1

var _n_base := FastNoiseLite.new()
var _n_mid := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()
var _n_biome := FastNoiseLite.new()


func _init() -> void:
	for n: FastNoiseLite in [_n_base, _n_mid, _n_detail, _n_biome]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_base.seed = SEED
	_n_base.frequency = 0.0042
	_n_base.fractal_octaves = 3
	_n_mid.seed = SEED + 1
	_n_mid.frequency = 0.016
	_n_mid.fractal_octaves = 2
	_n_detail.seed = SEED + 2
	_n_detail.frequency = 0.07
	_n_detail.fractal_type = FastNoiseLite.FRACTAL_NONE
	_n_biome.seed = SEED + 3
	_n_biome.frequency = 0.02
	_n_biome.fractal_octaves = 2
	_drop_level = _raw_height(DROP_SITE.x, DROP_SITE.y)
	_camp_level = _raw_height(CAMP.x, CAMP.y)


# --- 지형 높이 ---

var _drop_level: float
var _camp_level: float


## 평평하게 다지기 전의 자연 지형
func _raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := 7.0 + _n_base.get_noise_2d(x, z) * 9.0 + _n_mid.get_noise_2d(x, z) * 2.6
	# 북동 초원은 완만하게 굽이치는 언덕
	h += _falloff(p, MEADOW_CENTER, MEADOW_RADIUS) * (4.0 + _n_mid.get_noise_2d(x * 0.6, z * 0.6) * 5.0)
	# 감시탑 언덕과 고목 둔덕
	h += _bump(p, WATCHTOWER, 34.0) * 11.0
	h += _bump(p, OLD_TREE, 22.0) * 4.0
	# 북쪽 능선(지도 경계의 절벽)
	h += pow(clampf((-z - 196.0) / 60.0, 0.0, 1.0), 1.6) * 34.0
	# 가장자리 산: 보이지 않는 벽 대신 지형으로 지역을 닫는다
	var edge := HALF_SIZE - maxf(absf(x), absf(z))
	if edge < 44.0:
		var t := (44.0 - edge) / 44.0
		h += t * t * 46.0 + _n_mid.get_noise_2d(x * 2.0, z * 2.0) * 6.0 * t
	return h


## 큰 지형 + 평평한 장소(마을, 강하선 잔해, 야영지). 길은 이 높이를 따라간다.
func base_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := _raw_height(x, z)
	h = lerpf(h, TOWN_HEIGHT, _plateau(p, TOWN_CENTER, TOWN_RADIUS, 24.0))
	h = lerpf(h, _drop_level, _plateau(p, DROP_SITE, 17.0, 14.0))
	h = lerpf(h, _camp_level, _plateau(p, CAMP, 11.0, 10.0))
	return h


## 최종 높이: 기본 지형 + 잔 굴곡, 길 다지기, 강·연못 파기
func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := base_height(x, z)
	var town := _plateau(p, TOWN_CENTER, TOWN_RADIUS, 24.0)
	h += _n_detail.get_noise_2d(x, z) * 0.45 * (1.0 - town)
	# 길: 주변보다 살짝 낮고 평평하게
	var road := road_factor(p)
	if road > 0.0:
		var near := _nearest_on_paths(p)
		h = lerpf(h, _road_level(near) - 0.08, road)
	# 강: 둑을 따라 완만하게 파인다
	var dr := distance_to_river(p)
	if dr < RIVER_HALF_WIDTH + 12.0:
		var bank := smoothstep(RIVER_HALF_WIDTH + 12.0, RIVER_HALF_WIDTH * 0.6, dr)
		var bed := WATER_LEVEL - RIVER_DEPTH * smoothstep(RIVER_HALF_WIDTH + 1.0, 0.0, dr)
		h = lerpf(h, minf(h, bed + (dr / (RIVER_HALF_WIDTH + 1.0)) * 1.2), bank)
	# 연못
	var dp := p.distance_to(POND_CENTER) / POND_RADIUS
	if dp < 1.6:
		var pond_bed := WATER_LEVEL - POND_DEPTH * (1.0 - clampf(dp, 0.0, 1.0) * clampf(dp, 0.0, 1.0))
		h = lerpf(h, minf(h, pond_bed + maxf(dp - 1.0, 0.0) * 3.0), smoothstep(1.6, 0.9, dp))
	# 늪턱 구렁: 얕은 물이 고인 둥근 구덩이. 둘레 지형이 높은 남서쪽은 벽처럼 가파르고, 연못 쪽으로 트여 있다.
	var dm := p.distance_to(MAW_CENTER)
	if dm < MAW_RADIUS + MAW_BLEND:
		var floor_h := MAW_FLOOR + _n_detail.get_noise_2d(x * 1.7, z * 1.7) * 0.05
		h = lerpf(h, minf(h, floor_h), smoothstep(MAW_RADIUS + MAW_BLEND, MAW_RADIUS, dm))
	return h


## 길 위의 높이(주변의 큰 굴곡만 따른다)
func _road_level(p: Vector2) -> float:
	return base_height(p.x, p.y)


# --- 거리와 영역 ---

static func distance_to_polyline(p: Vector2, line: Array[Vector2]) -> float:
	var best := INF
	for i in line.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return best


static func closest_on_polyline(p: Vector2, line: Array[Vector2]) -> Vector2:
	var best := INF
	var out := p
	for i in line.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])
		var d := p.distance_squared_to(c)
		if d < best:
			best = d
			out = c
	return out


func distance_to_river(p: Vector2) -> float:
	return distance_to_polyline(p, RIVER)


func distance_to_road(p: Vector2) -> float:
	return minf(distance_to_polyline(p, ROAD), distance_to_polyline(p, TRAIL))


func _nearest_on_paths(p: Vector2) -> Vector2:
	var a := closest_on_polyline(p, ROAD)
	var b := closest_on_polyline(p, TRAIL)
	return a if p.distance_squared_to(a) <= p.distance_squared_to(b) else b


## 0..1. 길 한가운데서 1
func road_factor(p: Vector2) -> float:
	var d := distance_to_road(p)
	if p.distance_to(TOWN_CENTER) < TOWN_RADIUS - 6.0:
		return 0.0
	return smoothstep(ROAD_HALF_WIDTH + 3.5, ROAD_HALF_WIDTH, d)


## 0..1. 그늘 숲 한가운데서 1
func shade_factor(p: Vector2) -> float:
	var warp := _n_biome.get_noise_2d(p.x, p.y) * 22.0
	return smoothstep(SHADE_RADIUS + 18.0, SHADE_RADIUS - 30.0, p.distance_to(SHADE_CENTER) + warp)


func meadow_factor(p: Vector2) -> float:
	var warp := _n_biome.get_noise_2d(p.x + 400.0, p.y) * 18.0
	return smoothstep(MEADOW_RADIUS + 10.0, MEADOW_RADIUS - 30.0, p.distance_to(MEADOW_CENTER) + warp)


func in_town(p: Vector2, margin: float = 0.0) -> bool:
	return p.distance_to(TOWN_CENTER) < TOWN_RADIUS + margin


## 나무를 두지 않는 곳(길, 물가, 마을, 거점, 랜드마크 주변)
func is_clear_area(p: Vector2) -> bool:
	if distance_to_road(p) < ROAD_HALF_WIDTH + 3.5:
		return true
	if distance_to_river(p) < RIVER_HALF_WIDTH + 4.0:
		return true
	if p.distance_to(POND_CENTER) < POND_RADIUS + 5.0:
		return true
	if in_town(p, 10.0):
		return true
	for spot: Vector2 in [DROP_SITE, CAMP]:
		if p.distance_to(spot) < 20.0:
			return true
	if p.distance_to(OLD_TREE) < 16.0 or p.distance_to(WATCHTOWER) < 14.0:
		return true
	if p.distance_to(MAW_CENTER) < MAW_RADIUS + 7.0:
		return true
	return false


## 0..1 나무 밀도
func tree_density(p: Vector2) -> float:
	if is_clear_area(p):
		return 0.0
	var d := 0.34 + _n_biome.get_noise_2d(p.x * 1.7, p.y * 1.7) * 0.22
	d = lerpf(d, 0.95, shade_factor(p))
	d = lerpf(d, 0.05, meadow_factor(p))
	var edge := HALF_SIZE - maxf(absf(p.x), absf(p.y))
	if edge < 50.0:
		d = maxf(d, 0.55)
	# 길 가장자리는 조금 성기게
	d *= smoothstep(ROAD_HALF_WIDTH + 3.5, ROAD_HALF_WIDTH + 12.0, distance_to_road(p)) * 0.5 + 0.5
	return clampf(d, 0.0, 1.0)


## 0..1 풀 밀도
func grass_density(p: Vector2, h: float) -> float:
	if h < WATER_LEVEL + 0.25:
		return 0.0
	if road_factor(p) > 0.3:
		return 0.0
	if p.distance_to(TOWN_CENTER) < TOWN_RADIUS - 4.0:
		return 0.15
	var d := 0.75 + _n_biome.get_noise_2d(p.x * 2.3, p.y * 2.3) * 0.25
	d = lerpf(d, 0.25, shade_factor(p))
	d = lerpf(d, 1.0, meadow_factor(p))
	return clampf(d, 0.0, 1.0)


## 지표 색(지형 정점 색). 경사에 따른 바위색은 셰이더가 더한다.
func ground_color(p: Vector2, h: float) -> Color:
	var grass := Color(0.34, 0.47, 0.22)
	var v := _n_biome.get_noise_2d(p.x * 3.1, p.y * 3.1)
	grass = grass.lerp(Color(0.42, 0.52, 0.24), clampf(v * 0.5 + 0.5, 0.0, 1.0) * 0.6)
	var shade := shade_factor(p)
	grass = grass.lerp(Color(0.19, 0.26, 0.16), shade)
	grass = grass.lerp(Color(0.5, 0.58, 0.27), meadow_factor(p) * 0.7)
	if in_town(p, -4.0):
		grass = grass.lerp(Color(0.36, 0.36, 0.26), 0.5)
	# 길 색은 다져진 폭보다 좁고 또렷하게 칠한다.
	var road := 0.0
	if not in_town(p, -6.0):
		road = smoothstep(ROAD_HALF_WIDTH + 0.9, ROAD_HALF_WIDTH - 0.6, distance_to_road(p))
	var col := grass.lerp(Color(0.46, 0.37, 0.26), road)
	# 늪턱 구렁의 비탈: 젖은 진흙
	var dm := p.distance_to(MAW_CENTER)
	if dm < MAW_RADIUS + MAW_BLEND + 4.0:
		col = col.lerp(Color(0.25, 0.22, 0.15), smoothstep(MAW_RADIUS + MAW_BLEND + 4.0, MAW_RADIUS + 2.0, dm) * 0.7)
	# 물가 모래와 물속 진흙
	if h < WATER_LEVEL + 0.6:
		col = col.lerp(Color(0.53, 0.48, 0.36), smoothstep(WATER_LEVEL + 0.6, WATER_LEVEL + 0.1, h))
	if h < WATER_LEVEL - 0.1:
		col = col.lerp(Color(0.24, 0.21, 0.16), smoothstep(WATER_LEVEL - 0.1, WATER_LEVEL - 0.6, h))
	return col


## 지표 종류 비율(지형 셰이더가 결을 섞는다): r 흙길, g 젖은 진흙, b 낙엽 바닥, a 자갈·모래
func ground_weights(p: Vector2, h: float) -> Color:
	var road := 0.0
	if in_town(p, -6.0):
		road = 0.45
	else:
		road = smoothstep(ROAD_HALF_WIDTH + 1.4, ROAD_HALF_WIDTH - 0.8, distance_to_road(p))
	var wet := smoothstep(WATER_LEVEL + 0.8, WATER_LEVEL - 0.05, h)
	wet = maxf(wet, smoothstep(MAW_RADIUS + MAW_BLEND + 3.0, MAW_RADIUS + 3.0, p.distance_to(MAW_CENTER)) * 0.85)
	wet = maxf(wet, smoothstep(POND_RADIUS + 14.0, POND_RADIUS + 2.0, p.distance_to(POND_CENTER)) * 0.6)
	var litter := clampf(shade_factor(p) * 0.95 + tree_density(p) * 0.25, 0.0, 1.0) * (1.0 - road) * (1.0 - wet * 0.7)
	var sand := smoothstep(RIVER_HALF_WIDTH + 4.0, RIVER_HALF_WIDTH + 0.5, distance_to_river(p)) * (1.0 - wet * 0.5)
	return Color(road, wet, litter, sand)


# --- 내부 도우미 ---

static func _bump(p: Vector2, center: Vector2, radius: float) -> float:
	var d := p.distance_to(center) / radius
	return 0.0 if d >= 1.0 else 0.5 + 0.5 * cos(d * PI)


static func _falloff(p: Vector2, center: Vector2, radius: float) -> float:
	return smoothstep(radius, radius * 0.3, p.distance_to(center))


static func _plateau(p: Vector2, center: Vector2, radius: float, blend: float) -> float:
	return smoothstep(radius + blend, radius, p.distance_to(center))

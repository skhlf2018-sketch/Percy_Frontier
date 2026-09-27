class_name FieldWorld
extends GameWorld
## 퍼시 외곽권(기획서 §12 지역 1): 강하선 잔해에서 시작해 숲을 지나 퍼시 마을에 이르는 첫 지역.
## 지형·식생·마을·랜드마크·시간을 조립하고, 플레이어 위치에 따라 풀밭과 숲의 어둠을 갱신한다.

signal area_entered(area_id: StringName, area_name: String)

## 지역 이름(발견 알림과 지도에 쓴다)
const AREAS := {
	&"drop_site": "강하 지점",
	&"border_forest": "경계 숲",
	&"shade_forest": "그늘 숲",
	&"meadow": "북동 초원",
	&"percy": "퍼시",
	&"pond": "늪 연못",
	&"old_tree": "고목 언덕",
	&"watchtower": "감시탑 언덕",
	&"camp": "북쪽 야영지",
	&"river": "경계 강",
}

var layout: FieldLayout
var terrain: FieldTerrain
var scatter: FieldScatter
var grass: GrassField
var day_night: DayNight
var town: PercyTown
var landmarks: FieldLandmarks
var ambience: FieldAmbience

var _current_area: StringName = &""
var _area_timer: float = 0.0


func _ready() -> void:
	layout = FieldLayout.new()
	terrain = FieldTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(layout)
	scatter = FieldScatter.new()
	scatter.name = "Scatter"
	add_child(scatter)
	scatter.build(terrain, layout)
	grass = GrassField.new()
	grass.name = "Grass"
	add_child(grass)
	grass.setup(terrain, layout)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	town = PercyTown.new()
	town.name = "Percy"
	add_child(town)
	town.build(layout)
	landmarks = FieldLandmarks.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.build(terrain, layout)
	_place_inn()
	ambience = FieldAmbience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.setup(self)
	register_contents()


func _place_inn() -> void:
	var inn := SupplyPoint.new()
	inn.name = "Supply_inn"
	inn.show_beacon = false
	inn.prompt = "여관에서 휴식 · 저장"
	inn.respawn_offset = Vector3(0, 0, 1.5)
	inn.transform = town.spots["inn_door"]
	add_child(inn)


func default_respawn() -> Transform3D:
	return landmarks.spots["new_game"]


func track_player(player: Player) -> void:
	if player == null:
		return
	grass.focus = player
	ambience.player = player
	var p := Vector2(player.global_position.x, player.global_position.z)
	day_night.local_shade = layout.shade_factor(p)
	town.set_night_amount(1.0 - day_night.daylight())
	_area_timer -= get_process_delta_time()
	if _area_timer <= 0.0:
		_area_timer = 0.5
		var area := area_at(p)
		if area != _current_area:
			_current_area = area
			area_entered.emit(area, AREAS[area])


## 위치의 지역 이름 id
func area_at(p: Vector2) -> StringName:
	if layout.in_town(p, 4.0):
		return &"percy"
	if p.distance_to(FieldLayout.DROP_SITE) < 30.0:
		return &"drop_site"
	if p.distance_to(FieldLayout.CAMP) < 22.0:
		return &"camp"
	if p.distance_to(FieldLayout.OLD_TREE) < 26.0:
		return &"old_tree"
	if p.distance_to(FieldLayout.WATCHTOWER) < 30.0:
		return &"watchtower"
	if p.distance_to(FieldLayout.POND_CENTER) < FieldLayout.POND_RADIUS + 18.0:
		return &"pond"
	if layout.shade_factor(p) > 0.55:
		return &"shade_forest"
	if layout.meadow_factor(p) > 0.5:
		return &"meadow"
	if layout.distance_to_river(p) < 9.0:
		return &"river"
	return &"border_forest"


func current_area() -> StringName:
	return _current_area

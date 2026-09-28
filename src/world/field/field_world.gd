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
	&"maw_hollow": "늪턱 구렁",
}

var layout: FieldLayout
var terrain: FieldTerrain
var scatter: FieldScatter
var grass: GrassField
var day_night: DayNight
var town: PercyTown
var landmarks: FieldLandmarks
var ambience: FieldAmbience
var encounters_node: FieldEncounters
## 퍼시 주민: id → TownNpc
var npcs: Dictionary = {}
## 의뢰 물품 자리
var quest_items: Array[QuestItemSpot] = []
## 유니크 단서 자리와 유니크 사건
var clue_spots: Array[ClueSpot] = []
var predator_event: NightPredatorEvent
## 1지역 보스 전장(늪턱 구렁)
var mire_arena: MireArena

## 지도가 드러나는 반경(m)
const MAP_REVEAL_RADIUS := 44.0
## 지도에 이름을 적을 지역 자리
const AREA_LABELS := {
	&"drop_site": FieldLayout.DROP_SITE, &"border_forest": Vector2(-110, 70), &"shade_forest": FieldLayout.SHADE_CENTER,
	&"meadow": FieldLayout.MEADOW_CENTER, &"percy": FieldLayout.TOWN_CENTER, &"pond": FieldLayout.POND_CENTER,
	&"old_tree": FieldLayout.OLD_TREE, &"watchtower": FieldLayout.WATCHTOWER, &"camp": FieldLayout.CAMP,
	&"river": Vector2(-40, 150), &"maw_hollow": FieldLayout.MAW_CENTER,
}

var _current_area: StringName = &""
var _area_timer: float = 0.0
var _map_texture: ImageTexture


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
	_place_npcs()
	_place_quest_items()
	_place_clues()
	predator_event = NightPredatorEvent.new()
	predator_event.setup(self)
	add_child(predator_event)
	mire_arena = MireArena.new()
	mire_arena.setup(self)
	add_child(mire_arena)
	encounters_node = FieldEncounters.new()
	encounters_node.name = "Encounters"
	add_child(encounters_node)
	encounters_node.build(self)
	ambience = FieldAmbience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.setup(self)
	register_contents()
	GameState.quests_changed.connect(refresh_quest_items)
	GameState.inventory_changed.connect(refresh_quest_items)
	if GameState.quests.is_done(&"main_signal"):
		town.fix_tower()


func _place_inn() -> void:
	var inn := SupplyPoint.new()
	inn.name = "Supply_inn"
	inn.show_beacon = false
	inn.prompt = "여관에서 휴식 · 저장"
	inn.respawn_offset = Vector3(0, 0, 1.5)
	inn.transform = town.spots["inn_door"]
	add_child(inn)


func _place_npcs() -> void:
	for id: StringName in TownNpc.NPCS:
		var npc := TownNpc.new()
		npc.setup(id)
		npc.transform = town.spots[TownNpc.NPCS[id].spot]
		add_child(npc)
		npcs[id] = npc


func _place_quest_items() -> void:
	var basket := QuestItemSpot.new()
	basket.setup(&"herb_basket", &"herb_basket")
	basket.position = _shore_point(FieldLayout.POND_CENTER, Vector2(0.75, -0.66).normalized())
	basket.rotation.y = 0.8
	add_child(basket)
	quest_items.append(basket)


## 연못 가운데에서 dir 방향으로 나가다 물 밖으로 나온 첫 땅(조금 더 안쪽 뭍)
func _shore_point(from: Vector2, dir: Vector2) -> Vector3:
	var p := from
	for i in 80:
		p = from + dir * float(i)
		if terrain.height_at(p.x, p.y) > FieldLayout.WATER_LEVEL + 0.35:
			break
	p += dir * 2.0
	return terrain.point_at(p)


## 밤의 포식자 단서(기획서 §15.2: 존재·위치·조건 단서를 서로 다른 곳에). 네 번째 단서는 밤의 숲에서 직접 본다.
const CLUE_PLACES := {
	&"claw_marks": Vector2(-10, -116),
	&"night_tracks": Vector2(-44, -128),
	&"explorer_journal": FieldLayout.CAMP + Vector2(3.2, -2.6),
}


func _place_clues() -> void:
	for id: StringName in CLUE_PLACES:
		var spot := ClueSpot.new()
		spot.setup(id, self)
		var at: Vector2 = CLUE_PLACES[id]
		if id != &"explorer_journal":
			at = _clear_spot(at, 1.4)
		spot.position = terrain.point_at(at)
		# 발자국은 월드 방향(숲 한가운데 쪽)으로 이미 놓이므로 돌리지 않는다.
		if id != &"night_tracks":
			spot.rotation.y = atan2(FieldLayout.SHADE_CENTER.x - at.x, FieldLayout.SHADE_CENTER.y - at.y) + PI
		add_child(spot)
		clue_spots.append(spot)


## 나무·바위 충돌체가 없는 가까운 자리(단서가 나무에 파묻히지 않게)
func _clear_spot(at: Vector2, radius: float) -> Vector2:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return at
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = CombatLayers.WORLD
	for ring in 6:
		for k in maxi(ring * 6, 1):
			var a := TAU * float(k) / float(maxi(ring * 6, 1))
			var c := at + Vector2(cos(a), sin(a)) * ring * 2.0
			var h := terrain.height_at(c.x, c.y)
			q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, h + radius + 0.4, c.y))
			var hits := space.intersect_shape(q, 4)
			var blocked := false
			for hit in hits:
				if hit.collider.name != "TerrainBody":
					blocked = true
			if not blocked:
				return c
	return at


## 휴식하면 야외 무리와 함께 보스도 제자리에 잠든다(싸우는 중이 아닐 때).
func reset_all_encounters() -> void:
	super.reset_all_encounters()
	if mire_arena:
		mire_arena.reset_if_idle()


func refresh_quest_items() -> void:
	for it in quest_items:
		it.refresh()


## 의뢰 단계의 목표 지점(x, z). 주민과 대화하는 단계는 그 주민이 서 있는 곳을 가리킨다.
func quest_hint(step: Dictionary) -> Vector2:
	if step.is_empty():
		return Vector2.INF
	if step.get("type", &"") == &"talk" and npcs.has(step.get("target", &"")):
		var npc: TownNpc = npcs[step.target]
		return Vector2(npc.global_position.x, npc.global_position.z)
	return step.get("hint", Vector2.INF)


func default_respawn() -> Transform3D:
	return landmarks.spots["new_game"]


func track_player(player: Player) -> void:
	if player == null:
		return
	grass.focus = player
	ambience.player = player
	encounters_node.focus = player
	predator_event.player = player
	mire_arena.player = player
	day_night.night_vision = 1.0 if GameState.has_mark(&"predator_mark") else 0.0
	var p := Vector2(player.global_position.x, player.global_position.z)
	day_night.local_shade = layout.shade_factor(p)
	town.set_night_amount(1.0 - day_night.daylight())
	_area_timer -= get_process_delta_time()
	if _area_timer <= 0.0:
		_area_timer = 0.5
		GameState.reveal_map(p, MAP_REVEAL_RADIUS)
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
	if p.distance_to(FieldLayout.MAW_CENTER) < FieldLayout.MAW_RADIUS + FieldLayout.MAW_BLEND + 9.0:
		return &"maw_hollow"
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


## 지도 바탕 그림(지형 색, 음영, 물, 숲, 마을). 처음 부를 때 한 번 만든다(1픽셀 = 2m).
func map_texture() -> ImageTexture:
	if _map_texture:
		return _map_texture
	var n := FieldTerrain.CELLS
	var side := FieldTerrain.SIDE
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var water := Color(0.22, 0.42, 0.52)
	for zi in n:
		for xi in n:
			var h := terrain.heights[zi * side + xi]
			var col: Color
			if h < FieldLayout.WATER_LEVEL - 0.05:
				col = water.lerp(Color(0.12, 0.28, 0.38), clampf(-h, 0.0, 1.0))
			else:
				col = terrain.colors[zi * side + xi]
				# 북서쪽에서 빛이 드는 음영
				var h_nw := terrain.heights[maxi(zi - 1, 0) * side + maxi(xi - 1, 0)]
				col = col * clampf(1.0 + (h - h_nw) * 0.22, 0.62, 1.3)
			img.set_pixel(xi, zi, Color(col.r, col.g, col.b))
	# 숲: 나무 자리를 짙게
	for t in scatter.tree_positions:
		var px := int((t.x + FieldLayout.HALF_SIZE) / FieldTerrain.CELL)
		var pz := int((t.z + FieldLayout.HALF_SIZE) / FieldTerrain.CELL)
		if px >= 0 and pz >= 0 and px < n and pz < n:
			img.set_pixel(px, pz, img.get_pixel(px, pz).darkened(0.35))
	# 퍼시 목책 안쪽
	var tc := FieldLayout.TOWN_CENTER
	var r_px := int(PercyTown.PALISADE_RADIUS / FieldTerrain.CELL) + 2
	var cx := int((tc.x + FieldLayout.HALF_SIZE) / FieldTerrain.CELL)
	var cz := int((tc.y + FieldLayout.HALF_SIZE) / FieldTerrain.CELL)
	for zi in range(maxi(cz - r_px, 0), mini(cz + r_px, n)):
		for xi in range(maxi(cx - r_px, 0), mini(cx + r_px, n)):
			var p := Vector2(-FieldLayout.HALF_SIZE + (xi + 0.5) * FieldTerrain.CELL, -FieldLayout.HALF_SIZE + (zi + 0.5) * FieldTerrain.CELL)
			var d := p.distance_to(tc)
			if d < PercyTown.PALISADE_RADIUS + 1.0:
				var c := img.get_pixel(xi, zi)
				img.set_pixel(xi, zi, c.lerp(Color(0.78, 0.68, 0.52), 0.55) if d < PercyTown.PALISADE_RADIUS - 1.0 else Color(0.35, 0.24, 0.15))
	img.resize(n * 2, n * 2, Image.INTERPOLATE_BILINEAR)
	_map_texture = ImageTexture.create_from_image(img)
	return _map_texture

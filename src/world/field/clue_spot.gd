class_name ClueSpot
extends Interactable
## 유니크 단서가 남은 자리(기획서 §13.2 단서 단계, §15.2 추적 공정성). 조사하면(E) 탐사 기록에 단서가 남는다.
## 단서마다 모양이 다르다: 발톱 자국이 난 나무, 찢긴 탐사 일지, 숲 한가운데로 이어진 발자국(밤이면 희미하게 빛난다).
## 이름표는 조사하기 전까지 달지 않는다(정답을 미리 드러내지 않는다, §22.3).

var clue_id: StringName
var field: FieldWorld

var _glow: StandardMaterial3D
var _label: Label3D


func setup(id: StringName, f: FieldWorld) -> void:
	clue_id = id
	field = f
	name = "Clue_" + String(id)
	prompt = "조사한다"


func get_prompt(_player: Node) -> String:
	return "다시 살펴본다" if GameState.clues.has(clue_id) else "조사한다"


func _build() -> void:
	match clue_id:
		&"claw_marks":
			_build_claw_tree()
			_add_trigger_box(Vector3(2.2, 3.0, 2.2), Vector3(0, 1.5, 0))
		&"explorer_journal":
			_build_journal()
			_add_trigger_box(Vector3(1.4, 1.4, 1.4), Vector3(0, 0.6, 0))
		&"night_tracks":
			_build_tracks()
			_add_trigger_box(Vector3(2.4, 1.2, 2.4), Vector3(0, 0.4, 0))
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 44
	_label.pixel_size = 0.005
	_label.outline_size = 10
	_label.modulate = Color(0.75, 0.9, 1.0)
	_label.position = Vector3(0, 2.2 if clue_id == &"claw_marks" else 1.2, 0)
	_add_internal(_label)
	_refresh_label()


func _refresh_label() -> void:
	var found := GameState.clues.has(clue_id)
	_label.visible = found
	_label.text = "단서 · %s" % UniqueDB.clue_title(clue_id)


func interact(player: Node) -> void:
	var first := GameState.add_clue(clue_id)
	var fact := String(UniqueDB.clue(clue_id).fact)
	GameEvents.notify(fact, GameEvents.NoticeKind.ANALYSIS if first else GameEvents.NoticeKind.INFO)
	_refresh_label()
	super.interact(player)


func _process(_delta: float) -> void:
	if _glow and field:
		# 발자국은 밤에 희미하게 빛난다(밤사이 찍힌 흔적).
		var night := 1.0 - field.day_night.daylight()
		_glow.emission_energy_multiplier = 0.05 + night * 1.1


# --- 모양 ---

func _commit(b: MeshKit.Builder) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = MeshKit.solid_material()
	_add_internal(mi)
	return mi


## 줄기에 깊게 파인 발톱 자국이 난 죽은 나무
func _build_claw_tree() -> void:
	var b := MeshKit.Builder.new()
	var bark := Color(0.3, 0.24, 0.19, 0.0)
	b.frustum(Vector3(0, -0.3, 0), Vector3(0, 5.2, 0.1), 0.62, 0.34, 8, bark)
	b.frustum(Vector3(0, 3.6, 0.05), Vector3(1.4, 5.4, 0.3), 0.18, 0.06, 5, bark)
	b.frustum(Vector3(0, 4.4, 0.08), Vector3(-1.1, 6.0, -0.2), 0.14, 0.04, 5, bark)
	# 발톱 자국: 밝은 속살이 드러난 네 줄의 깊은 홈(사람 키의 두 배 높이까지)
	var raw := Color(0.86, 0.78, 0.62, 0.0)
	for i in 4:
		var x := -0.33 + i * 0.22
		var top := Vector3(x, 3.6 - absf(i - 1.5) * 0.12, 0.0)
		var bottom := Vector3(x + 0.22, 1.7, 0.0)
		var r_top := 0.62 - (top.y + 0.3) / 5.5 * 0.28
		var r_bot := 0.62 - (bottom.y + 0.3) / 5.5 * 0.28
		var a := Vector3(top.x, top.y, sqrt(maxf(r_top * r_top - top.x * top.x, 0.01)) + 0.01)
		var c := Vector3(bottom.x, bottom.y, sqrt(maxf(r_bot * r_bot - bottom.x * bottom.x, 0.01)) + 0.01)
		b.quad(a + Vector3(-0.055, 0, 0), a + Vector3(0.055, 0, 0), c + Vector3(0.055, 0, 0), c + Vector3(-0.055, 0, 0),
			raw, Vector3(0, 0, 1))
	# 둘레에 떨어진 나무껍질 조각
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 6:
		var p := Vector3(rng.randf_range(-1.2, 1.2), 0.03, rng.randf_range(0.6, 1.6))
		b.box(p, Vector3(0.25, 0.04, 0.12), Color(0.36, 0.28, 0.2), Basis(Vector3.UP, rng.randf() * TAU))
	_commit(b)
	_add_solid_box(Vector3(1.0, 5.0, 1.0), Vector3(0, 2.5, 0))


## 상자 위에 펼쳐진 찢긴 탐사 일지
func _build_journal() -> void:
	var b := MeshKit.Builder.new()
	b.box(Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.6), Color(0.46, 0.34, 0.2), Basis.IDENTITY, Color(0.5, 0.38, 0.24))
	var cover := Color(0.35, 0.2, 0.15)
	var basis := Basis(Vector3.UP, 0.4)
	b.box(Vector3(0, 0.62, 0), Vector3(0.44, 0.03, 0.3), cover, basis)
	b.box(Vector3(0.0, 0.645, 0.0), Vector3(0.4, 0.02, 0.27), Color(0.92, 0.88, 0.78), basis)
	# 찢겨 나간 종이 조각
	b.box(Vector3(0.45, 0.02, 0.35), Vector3(0.16, 0.01, 0.12), Color(0.9, 0.86, 0.76), Basis(Vector3.UP, 1.1))
	b.box(Vector3(-0.5, 0.02, 0.2), Vector3(0.12, 0.01, 0.1), Color(0.9, 0.86, 0.76), Basis(Vector3.UP, 2.3))
	_commit(b)
	_add_solid_box(Vector3(0.8, 0.6, 0.6), Vector3(0, 0.3, 0))


## 숲 한가운데 쪽으로 이어지는 커다란 발자국(이 노드가 첫 발자국, 나머지는 그늘 숲 한가운데 방향으로)
func _build_tracks() -> void:
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.06, 0.07, 0.09)
	_glow.emission_enabled = true
	_glow.emission = Color(0.3, 0.7, 1.0)
	_glow.emission_energy_multiplier = 0.1
	var b := MeshKit.Builder.new()
	var here := Vector2(global_position.x, global_position.z) if is_inside_tree() else Vector2.ZERO
	var to_center := (FieldLayout.SHADE_CENTER - here).normalized() if field else Vector2(0, -1)
	var side := Vector2(-to_center.y, to_center.x)
	for i in 9:
		var p2 := to_center * (i * 2.6) + side * (0.55 if i % 2 == 0 else -0.55)
		var ground := 0.0
		var n := Vector3.UP
		if field:
			var w := here + p2
			ground = field.terrain.height_at(w.x, w.y) - global_position.y
			n = field.terrain.normal_at(w.x, w.y)
		# 비탈에서도 묻히지 않게 지면 기울기를 따라 조금 띄운다.
		var center := Vector3(p2.x, ground, p2.y) + n * 0.07
		# 발바닥과 발가락 넷
		b.disc(center, 0.36, 9, Color(0.05, 0.05, 0.06, 0.0), n)
		for t in 4:
			var ang := -0.6 + t * 0.4
			var dir := to_center.rotated(ang)
			var toe_flat := Vector3(dir.x, 0.0, dir.y) * 0.52
			var toe := center + toe_flat - n * n.dot(toe_flat) + n * 0.01
			b.disc(toe, 0.13, 7, Color(0.05, 0.05, 0.06, 0.0), n)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = _glow
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_internal(mi)

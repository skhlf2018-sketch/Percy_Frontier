class_name QuestItemSpot
extends Interactable
## 의뢰 물품이 놓인 자리(늪 연못가의 약초 바구니 같은 것). 의뢰가 그 물품을 찾는 단계일 때만 보이고,
## 주우면 보관함에 들어가 의뢰가 넘어간다.

var item_id: StringName
var quest_id: StringName
## 이 단계일 때만 보인다.
var quest_step: int = 0

var _visual: Node3D


func setup(item: StringName, quest: StringName, step: int = 0) -> void:
	item_id = item
	quest_id = quest
	quest_step = step
	name = "QuestItem_" + String(item)
	label_text = ItemDB.name_of(item)
	prompt = "%s 줍기" % ItemDB.name_of(item)


func _build() -> void:
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * 1.5
	_add_internal(_visual)
	var b := MeshKit.Builder.new()
	var wicker := Color(0.62, 0.45, 0.26, 0.0)
	b.frustum(Vector3.ZERO, Vector3(0, 0.26, 0), 0.2, 0.28, 10, wicker)
	b.disc(Vector3(0, 0.02, 0), 0.2, 10, Color(wicker.darkened(0.3), 0.0), Vector3.UP)
	# 손잡이
	var segments := 8
	for i in segments:
		var a0 := PI * float(i) / segments
		var a1 := PI * float(i + 1) / segments
		b.frustum(Vector3(cos(a0) * 0.24, 0.26 + sin(a0) * 0.22, 0), Vector3(cos(a1) * 0.24, 0.26 + sin(a1) * 0.22, 0),
			0.018, 0.018, 5, Color(wicker.darkened(0.15), 0.0))
	# 담긴 약초
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 5:
		var p := Vector3(rng.randf_range(-0.12, 0.12), 0.27, rng.randf_range(-0.12, 0.12))
		b.blob(p, 0.07, Color(0.35, 0.62, 0.3, 0.0), 0.0, rng, 0.2, Vector3(1.0, 0.7, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.material_override = MeshKit.solid_material()
	_visual.add_child(mi)
	# 멀리서도 찾을 수 있게 은은한 빛 기둥
	var glow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.16
	cm.height = 3.2
	glow.mesh = cm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1.0, 0.88, 0.45, 0.32)
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.material_override = gm
	glow.position = Vector3(0, 1.6, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(glow)
	_add_trigger_box(Vector3(1.4, 1.4, 1.4), Vector3(0, 0.5, 0))
	_add_label(label_text, 1.2)
	refresh()


## 의뢰 상태에 맞춰 보이거나 숨긴다.
func refresh() -> void:
	var shown := GameState.quests.is_active(quest_id) and GameState.quests.step_of(quest_id) == quest_step \
		and GameState.item_count(item_id) == 0
	visible = shown
	collision_layer = CombatLayers.INTERACTABLE if shown else 0


func interact(player: Node) -> void:
	if not visible:
		return
	GameState.add_item(item_id, 1)
	Sfx.play_ui(&"pickup")
	GameEvents.notify("%s을(를) 주웠습니다." % ItemDB.name_of(item_id), GameEvents.NoticeKind.PICKUP)
	refresh()
	super.interact(player)

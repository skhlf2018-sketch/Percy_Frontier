class_name WeaponPickup
extends Interactable
## 바닥에 떨어진 무기 한 자루(고블린이 쓰던 무기, 플레이어가 내려놓은 무기).
## 무기는 칸마다 한 자루씩만 들 수 있어서(기획서 §11.5), 주우면 같은 칸에 들고 있던 무기를 그 자리에 내려놓는다.
## 희귀도 색 빛기둥·이름표로 한눈에 구분하고, 바라보면 HUD가 지금 든 무기와 비교해 보여 준다.

var item: WeaponItem

var _model: Node3D
var _beam_mat: StandardMaterial3D
var _light: OmniLight3D
var _label: Label3D
var _t: float = 0.0


## 무기를 바닥에 떨어뜨린다(지면을 찾아 내려놓는다).
static func drop(ctx: Node, weapon: WeaponItem, at: Vector3) -> WeaponPickup:
	if ctx == null or not ctx.is_inside_tree() or weapon == null:
		return null
	var tree := ctx.get_tree()
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	var p := WeaponPickup.new()
	p.item = weapon
	p.name = "WeaponPickup_%d" % weapon.uid
	root.add_child(p)
	var space := (ctx as Node3D).get_world_3d().direct_space_state if ctx is Node3D else null
	var ground := at
	if space:
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 6.0, CombatLayers.WORLD)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			ground = hit.position
	p.global_position = ground
	p.rotation.y = randf() * TAU
	return p


func _build() -> void:
	if item == null:
		return
	var col := item.color()
	prompt = "줍기"
	# 무기를 옆으로 눕혀 바닥에 둔다.
	_model = ViewmodelFactory.build_world(item.base_id, item.rarity)
	_model.rotation = Vector3(0.0, 0.0, PI * 0.5) if item.is_gun() else Vector3(PI * 0.5, 0.0, 0.0)
	_model.position = Vector3(0, 0.07, 0)
	_add_internal(_model)
	# 희귀도 빛기둥: 희귀할수록 높고 밝다.
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var h := 1.1 + 0.45 * item.rarity
	cm.top_radius = 0.02
	cm.bottom_radius = 0.1 + 0.02 * item.rarity
	cm.height = h
	cm.radial_segments = 10
	beam.mesh = cm
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.albedo_color = Color(col, 0.22 + 0.06 * item.rarity)
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = _beam_mat
	beam.position = Vector3(0, h * 0.5, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_internal(beam)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 0.5 + 0.2 * item.rarity
	_light.omni_range = 2.2 + 0.3 * item.rarity
	_light.position = Vector3(0, 0.4, 0)
	_add_internal(_light)
	_add_trigger_box(Vector3(1.4, 1.3, 1.4), Vector3(0, 0.6, 0))
	_label = Label3D.new()
	_label.text = "%s\n[%s · %s]" % [item.display_name(), item.rarity_name(), item.class_label()]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.outline_size = 10
	_label.modulate = col.lightened(0.2)
	_label.position = Vector3(0, 0.75, 0)
	_add_internal(_label)


func get_prompt(_player: Node) -> String:
	if item == null:
		return "줍기"
	var cur := GameState.equipped_item(item.slot())
	if cur:
		return "%s 줍기 — 지금 든 %s을(를) 여기 내려놓는다" % [item.display_name(), cur.display_name()]
	return "%s 줍기" % item.display_name()


func interact(player: Node) -> void:
	if item == null or not is_instance_valid(self) or is_queued_for_deletion():
		return
	var old := GameState.equip_item(item)
	Sfx.play_ui(&"unlock")
	GameEvents.notify("%s [%s]을(를) 들었다." % [item.display_name(), item.rarity_name()], GameEvents.NoticeKind.PICKUP)
	if old and player is Node3D:
		var p3 := player as Node3D
		var side := Vector3.ZERO
		if player is Player:
			side = (player as Player).look_basis() * Vector3(-0.7, 0.0, -0.9)
			side.y = 0.0
		WeaponPickup.drop(self, old, p3.global_position + side)
		GameEvents.notify("%s을(를) 내려놓았다." % old.display_name(), GameEvents.NoticeKind.INFO)
	item = null
	collision_layer = 0
	queue_free()
	super.interact(player)


func _process(delta: float) -> void:
	_t += delta
	if _beam_mat and item:
		_beam_mat.albedo_color.a = (0.2 + 0.06 * item.rarity) * (0.8 + 0.2 * sin(_t * 2.5))
	if _label:
		# 가까울 때만 이름표를 보인다(멀리서는 빛기둥으로 찾는다).
		var cam := get_viewport().get_camera_3d()
		_label.visible = cam != null and cam.global_position.distance_to(global_position) < 9.0

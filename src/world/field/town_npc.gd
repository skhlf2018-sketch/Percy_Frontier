class_name TownNpc
extends Interactable
## 퍼시 주민(기획서 §18.3). 다가가면 이름과 역할이 보이고, 상호작용(E)하면 대화가 열린다.
## 가까이 오면 플레이어 쪽으로 고개를 돌리고, 말하는 동안 손짓을 한다.

## 주민 정의: 이름, 역할, 서 있는 자리(마을 spots 이름), 외형
const NPCS := {
	&"clerk": {"name": "카일", "role": "의뢰 담당자", "spot": "clerk",
		"look": {"build": 1, "skin": 1, "hair_style": 0, "hair_color": 2, "outfit": 1, "accent": 2, "gear": 0}},
	&"innkeeper": {"name": "마르타", "role": "여관 「첫 등불」 주인", "spot": "innkeeper",
		"look": {"build": 2, "skin": 0, "hair_style": 1, "hair_color": 4, "outfit": 3, "accent": 4, "gear": 2}},
	&"merchant": {"name": "벤", "role": "잡화상", "spot": "merchant",
		"look": {"build": 2, "skin": 2, "hair_style": 4, "hair_color": 0, "outfit": 2, "accent": 0, "gear": 0}},
	&"smith": {"name": "도르가", "role": "대장장이 · 무기 공방", "spot": "smith",
		"look": {"build": 2, "skin": 3, "hair_style": 3, "hair_color": 0, "outfit": 4, "accent": 0, "gear": 1}},
	&"researcher": {"name": "이렌", "role": "공명 연구자", "spot": "researcher",
		"look": {"build": 1, "skin": 4, "hair_style": 2, "hair_color": 3, "outfit": 6, "accent": 1, "gear": 1}},
	&"guard": {"name": "하롤드", "role": "정문 경비", "spot": "gate_guard",
		"look": {"build": 2, "skin": 1, "hair_style": 4, "hair_color": 1, "outfit": 0, "accent": 3, "gear": 0}},
	&"hunter": {"name": "노라", "role": "사냥꾼", "spot": "hunter",
		"look": {"build": 1, "skin": 2, "hair_style": 1, "hair_color": 0, "outfit": 7, "accent": 2, "gear": 3}},
}

var npc_id: StringName
var display_name: String = ""
var role: String = ""
var model: HumanoidModel

var _player: Node3D
var _talk_left: float = 0.0


func setup(id: StringName) -> void:
	npc_id = id
	var d: Dictionary = NPCS[id]
	display_name = d.name
	role = d.role
	name = "Npc_" + String(id)
	label_text = "%s · %s" % [display_name, role]
	prompt = "%s와(과) 대화" % display_name


func _build() -> void:
	if npc_id == &"":
		return
	model = HumanoidModel.new(NPCS[npc_id].look)
	_add_internal(model)
	_add_solid_box(Vector3(0.6, 1.8, 0.6), Vector3(0, 0.9, 0))
	_add_trigger_box(Vector3(1.4, 2.0, 1.4), Vector3(0, 1.0, 0))
	_add_label(label_text, 2.25)


func interact(player: Node) -> void:
	_talk_left = 4.0
	if model:
		model.talking = true
	super.interact(player)


func _process(delta: float) -> void:
	if model == null:
		return
	if _talk_left > 0.0:
		_talk_left -= delta
		if _talk_left <= 0.0:
			model.talking = false
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group(&"player")
		_player = players[0] if players.size() > 0 else null
	if _player:
		var near := _player.global_position.distance_to(global_position) < 7.0
		model.look_target = _player if near else null

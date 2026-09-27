class_name ConsumableData
extends Resource
## 소모품(빠른 슬롯 8·9, 기획서 §9.1).

enum Effect { HEAL, CLEANSE }

@export var id: StringName
@export var display_name: String = ""
@export var short_name: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.HEAL
## 회복량(HEAL)
@export var amount: float = 45.0
## 회복에 걸리는 시간(HEAL) 또는 축적 면역 시간(CLEANSE)
@export var duration: float = 1.5
## 사용 동작 시간(사용 중에는 사격할 수 없다)
@export var use_time: float = 0.5
@export var max_carry: int = 5
@export var start_count: int = 3
@export var color: Color = Color(0.9, 0.3, 0.3)

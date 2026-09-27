class_name ItemRarity
extends RefCounted
## 장비 희귀도(기획서 §9.4). 몬스터 위협 등급과는 별개의 체계다.

enum Tier { STANDARD, IMPROVED, RARE, EPIC, LEGENDARY, UNIQUE }

const NAMES := ["표준", "개량", "희귀", "에픽", "전설", "유니크"]
const COLORS := [
	Color(0.82, 0.84, 0.86),
	Color(0.45, 0.85, 0.5),
	Color(0.35, 0.62, 1.0),
	Color(0.72, 0.45, 1.0),
	Color(1.0, 0.7, 0.25),
	Color(1.0, 0.36, 0.42),
]


static func tier_name(tier: int) -> String:
	return NAMES[clampi(tier, 0, NAMES.size() - 1)]


static func tier_color(tier: int) -> Color:
	return COLORS[clampi(tier, 0, COLORS.size() - 1)]

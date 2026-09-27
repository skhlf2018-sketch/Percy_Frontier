class_name DamageMath
extends RefCounted
## 피해 계산 규칙. 상태를 갖지 않는 순수 함수만 둔다.


## 부위 판정을 적용한다.
## 반환: { "damage": 본체 피해, "armor_damage": 장갑 내구 피해 }
## - 약점은 방어력을 무시한다(정밀 사격 보상).
## - 장갑이 남아 있으면 본체에는 일부만 전달되고 나머지는 장갑 내구를 깎는다.
static func resolve_zone(base: float, zone: int, zone_mult: float, armor_left: float,
		armor_pass: float, armor_damage_mult: float, defense: float) -> Dictionary:
	var out := {"damage": 0.0, "armor_damage": 0.0}
	var def_mult := 1.0 - clampf(defense, 0.0, 0.9)
	match zone:
		Hurtbox.Zone.WEAK_POINT:
			out.damage = base * zone_mult
		Hurtbox.Zone.ARMOR:
			if armor_left > 0.0:
				out.armor_damage = base * armor_damage_mult
				out.damage = base * armor_pass * def_mult
			else:
				out.damage = base * zone_mult * def_mult
		_:
			out.damage = base * zone_mult * def_mult
	return out


## 사거리 감쇠 배율. start까지 1.0, end 이후 min_mult.
static func falloff(distance: float, start: float, end: float, min_mult: float) -> float:
	if distance <= start:
		return 1.0
	if distance >= end or end <= start:
		return min_mult
	return lerpf(1.0, min_mult, (distance - start) / (end - start))


## 명중 결과에 따른 공명 획득량(기획서 §8.2: 약점 명중, 부위 파괴, 처치 등으로 얻는다).
## 처치 보상은 몬스터마다 다르므로 EnemyData.resonance_on_kill로 따로 준다.
static func resonance_for_hit(result: HitResult) -> float:
	if result == null:
		return 0.0
	var gain := 0.0
	match result.kind:
		DamageInfo.Kind.GUN:
			gain = 3.0 if result.is_weak_point() else 0.6
		DamageInfo.Kind.MELEE:
			gain = 5.0 if result.is_weak_point() else 3.0
		_:
			gain = 0.0
	gain *= result.resonance_mult
	if result.armor_broken:
		gain += 15.0
	return gain

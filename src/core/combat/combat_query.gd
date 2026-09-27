class_name CombatQuery
extends RefCounted
## 범위 공격·시야 판정 도우미.


## 반경 안의 적(피격 부위의 소유 개체)을 중복 없이 모은다.
## require_los가 true면 중심에서 대상까지 지형에 가리지 않은 대상만 돌려준다.
static func entities_in_radius(world: World3D, center: Vector3, radius: float,
		require_los: bool = true) -> Array[Node]:
	var out: Array[Node] = []
	if world == null or radius <= 0.0:
		return out
	var space := world.direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = CombatLayers.HURTBOX
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var seen := {}
	for hit in space.intersect_shape(q, 64):
		var hb := hit.collider as Hurtbox
		if hb == null or hb.entity == null or not is_instance_valid(hb.entity):
			continue
		if seen.has(hb.entity):
			continue
		seen[hb.entity] = true
		if hb.entity.has_method("is_alive") and not hb.entity.is_alive():
			continue
		if require_los and not has_line_of_sight(world, center, hb.global_position):
			continue
		out.append(hb.entity)
	return out


## 두 점 사이가 지형에 가리지 않았는지
static func has_line_of_sight(world: World3D, from: Vector3, to: Vector3) -> bool:
	if from.distance_squared_to(to) < 0.0001:
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to, CombatLayers.WORLD)
	return world.direct_space_state.intersect_ray(q).is_empty()


## 무작위 탄퍼짐 방향. spread_deg는 원뿔의 반각(도)이다.
static func spread_direction(forward: Vector3, basis: Basis, spread_deg: float) -> Vector3:
	if spread_deg <= 0.001:
		return forward
	var angle := deg_to_rad(spread_deg) * sqrt(randf())
	var theta := randf() * TAU
	var offset := (basis.x * cos(theta) + basis.y * sin(theta)) * tan(angle)
	return (forward + offset).normalized()

extends TestCase


func _rifle() -> WeaponData:
	return GameDB.weapon(&"rifle_bfa3")


func test_fire_consumes_round_and_sets_cooldown() -> void:
	var g := GunState.new(_rifle())
	assert_true(g.fire())
	assert_eq(g.mag, _rifle().magazine_size - 1)
	assert_false(g.can_fire(), "발사 간격 동안은 쏠 수 없다")
	var inv := AmmoInventory.new()
	g.tick(_rifle().seconds_per_shot() + 0.001, inv)
	assert_true(g.can_fire())


func test_cannot_fire_empty_magazine() -> void:
	var g := GunState.new(_rifle())
	g.mag = 0
	assert_false(g.fire())
	assert_true(g.is_empty())


func test_reload_takes_from_reserve() -> void:
	var inv := AmmoInventory.new()
	var g := GunState.new(_rifle())
	g.mag = 10
	var before := inv.get_count(&"rifle")
	assert_true(g.start_reload(inv))
	assert_near(g.reload_total, _rifle().reload_time)
	var finished := false
	for i in 200:
		if g.tick(1.0 / 60.0, inv):
			finished = true
			break
	assert_true(finished)
	assert_eq(g.mag, _rifle().magazine_size)
	assert_eq(inv.get_count(&"rifle"), before - (_rifle().magazine_size - 10))


func test_empty_reload_is_slower() -> void:
	var inv := AmmoInventory.new()
	var g := GunState.new(_rifle())
	g.mag = 0
	g.start_reload(inv)
	assert_near(g.reload_total, _rifle().empty_reload_time)


func test_partial_reload_when_reserve_low() -> void:
	var inv := AmmoInventory.new()
	inv.counts[&"rifle"] = 5
	var g := GunState.new(_rifle())
	g.mag = 0
	g.start_reload(inv)
	g.tick(10.0, inv)
	assert_eq(g.mag, 5)
	assert_eq(inv.get_count(&"rifle"), 0)


func test_cannot_reload_full_or_without_reserve() -> void:
	var inv := AmmoInventory.new()
	var g := GunState.new(_rifle())
	assert_false(g.can_reload(inv), "탄창이 가득 참")
	g.mag = 3
	inv.counts[&"rifle"] = 0
	assert_false(g.can_reload(inv), "예비 탄약 없음")


func test_heat_weapon_overheats_and_recovers() -> void:
	var data := GameDB.weapon(&"energy_re2")
	var inv := AmmoInventory.new()
	var g := GunState.new(data)
	var shots := 0
	while not g.overheated and shots < 100:
		assert_true(g.fire())
		shots += 1
		g.tick(data.seconds_per_shot(), inv)
	assert_true(g.overheated)
	assert_eq(shots, int(ceil(1.0 / data.heat_per_shot)))
	assert_false(g.can_fire())
	g.tick(data.overheat_lockout + 0.01, inv)
	assert_false(g.overheated)
	assert_true(g.can_fire())
	assert_false(g.can_reload(inv), "과열 무기는 재장전하지 않는다")


func test_spread_rules() -> void:
	var g := GunState.new(_rifle())
	var hip := g.spread_deg(0.0, 0.0, false)
	var ads := g.spread_deg(1.0, 0.0, false)
	var moving := g.spread_deg(0.0, 1.0, false)
	var air := g.spread_deg(0.0, 0.0, true)
	assert_lt(ads, hip)
	assert_gt(moving, hip)
	assert_gt(air, hip)
	g.fire()
	assert_gt(g.spread_deg(0.0, 0.0, false), hip, "연사하면 탄퍼짐이 커진다")


func test_cancel_reload() -> void:
	var inv := AmmoInventory.new()
	var g := GunState.new(_rifle())
	g.mag = 1
	g.start_reload(inv)
	g.cancel_reload()
	assert_false(g.reloading)
	g.tick(5.0, inv)
	assert_eq(g.mag, 1)

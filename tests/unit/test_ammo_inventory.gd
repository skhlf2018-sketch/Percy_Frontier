extends TestCase


func test_add_clamps_to_max() -> void:
	var inv := AmmoInventory.new()
	var max_shells := inv.get_max(&"shell")
	var added := inv.add(&"shell", 1000)
	assert_eq(inv.get_count(&"shell"), max_shells)
	assert_eq(added, max_shells - AmmoInventory.TYPES[&"shell"].start)


func test_take_is_limited_by_stock() -> void:
	var inv := AmmoInventory.new()
	inv.counts[&"pistol"] = 4
	assert_eq(inv.take(&"pistol", 10), 4)
	assert_eq(inv.get_count(&"pistol"), 0)


func test_unknown_type_is_ignored() -> void:
	var inv := AmmoInventory.new()
	assert_eq(inv.add(&"plasma", 10), 0)
	assert_eq(inv.get_count(&"plasma"), 0)


func test_emergency_only_raises_to_minimum() -> void:
	var inv := AmmoInventory.new()
	inv.counts[&"rifle"] = 0
	inv.counts[&"pistol"] = 150
	inv.ensure_emergency()
	assert_eq(inv.get_count(&"rifle"), AmmoInventory.TYPES[&"rifle"].emergency)
	assert_eq(inv.get_count(&"pistol"), 150, "이미 충분하면 건드리지 않는다")


func test_refill_to_start() -> void:
	var inv := AmmoInventory.new()
	inv.counts[&"sniper"] = 1
	inv.refill_to_start()
	assert_eq(inv.get_count(&"sniper"), AmmoInventory.TYPES[&"sniper"].start)


func test_every_gun_uses_known_ammo_type() -> void:
	for w: WeaponData in GameDB.WEAPONS:
		if w.uses_heat:
			assert_eq(w.ammo_type, &"", "%s 과열 무기는 탄약을 쓰지 않는다" % w.id)
		else:
			assert_true(AmmoInventory.TYPES.has(w.ammo_type), "%s 탄약 종류" % w.id)

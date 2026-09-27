extends TestCase


func test_every_recipe_synthesizes() -> void:
	for id in Sfx.RECIPES:
		var s: AudioStreamWAV = Sfx.get_stream(id)
		assert_not_null(s, String(id))
		if s:
			assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS)
			assert_gt(s.data.size(), 100, String(id))


func test_synthesis_is_normalized() -> void:
	var wav := Sfx.synthesize([{"t": "sine", "dur": 0.1, "f0": 440.0, "g": 5.0}])
	var peak := 0
	for i in range(0, wav.data.size(), 2):
		peak = maxi(peak, absi(wav.data.decode_s16(i)))
	assert_le(peak, 32767)
	assert_gt(peak, 20000)


func test_unknown_sound_warns_without_crash() -> void:
	Sfx.play(&"__missing__")

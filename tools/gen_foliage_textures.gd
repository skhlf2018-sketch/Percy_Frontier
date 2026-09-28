extends SceneTree
## 나무 텍스처(잎가지, 솔잎 가지, 나무껍질)를 만들어 assets/textures/foliage/에 저장한다.
##   godot --headless --script res://tools/gen_foliage_textures.gd


func _initialize() -> void:
	for k in FoliageTextures.KINDS:
		var t := Time.get_ticks_msec()
		var img := FoliageTextures.make_image(k)
		img.clear_mipmaps()
		img.save_png(FoliageTextures.path_of(k))
		print("저장: %s (%d ms)" % [FoliageTextures.path_of(k), Time.get_ticks_msec() - t])
	quit()

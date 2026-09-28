extends SceneTree
## 1인칭 무기·장비 표면 결 텍스처를 만들어 assets/textures/gear/에 저장한다.
##   godot --headless --script res://tools/gen_gear_textures.gd


func _initialize() -> void:
	for k in GearTextures.KINDS:
		var img := GearTextures.make_image(k)
		img.clear_mipmaps()
		img.save_png(GearTextures.path_of(k))
		print("저장: ", GearTextures.path_of(k))
	quit()

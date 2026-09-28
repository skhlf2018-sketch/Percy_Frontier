extends SceneTree
## 지표 결 텍스처를 만들어 assets/textures/terrain/에 저장한다(게임 시작 때 만드는 시간을 없앤다).
##   godot --headless --script res://tools/gen_terrain_textures.gd


func _initialize() -> void:
	for k in TerrainTextures.KINDS:
		var img := TerrainTextures.make_image(k)
		var path := TerrainTextures.path_of(k)
		img.save_png(path)
		print("저장: ", path)
	quit()

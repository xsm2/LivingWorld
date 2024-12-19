static func patch():
	var script_path = "res://world/player/RemotePlayerController.gd"
	var patched_script : GDScript = preload("res://world/player/RemotePlayerController.gd")

	if !patched_script.has_source_code():
		var file : File = File.new()
		var err = file.open(script_path, File.READ)
		if err != OK:
			push_error("Check that %s is included in Modified Files"% script_path)
			return
		patched_script.source_code = file.get_as_text()
		file.close()

	var code_lines:Array = patched_script.source_code.split("\n")

	var code_index = code_lines.find("""	Net.players.connect("player_info_changed", self, "_on_player_info_changed")""")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("connect"))

	# code_index = code_lines.find("		pawn.scale = Vector3(avatar.scale, avatar.scale, avatar.scale)")
	# if code_index > 0:
	# 	code_lines.insert(code_index+1,get_code("transform"))

	code_lines.insert(code_lines.size()-1,get_code("new_func"))

	patched_script.source_code = ""
	for line in code_lines:
		patched_script.source_code += line + "\n"

	var err = patched_script.reload()
	if err != OK:
		push_error("Failed to patch %s." % script_path)
		return

static func get_code(block:String)->String:
	var code_blocks:Dictionary = {}
	code_blocks["connect"] = """
	Net.avatars.connect("avatar_transformed",self,"_on_avatar_transformed")
	"""
	code_blocks["new_func"] = """
func _on_avatar_transformed(id,index,use_monster_form:bool):
	var pawn = get_parent()
	if id == self.id:
		if pawn and pawn.has_method("player_transform"):
			pawn.player_transform(use_monster_form,index)
	"""
	code_blocks["transform"] = """
		if avatar.transform_index >= 0 and avatar.use_monster_form:
			_on_avatar_transformed(id,avatar.use_monster_form,avatar.transform_index)	
	"""	
	return code_blocks[block]



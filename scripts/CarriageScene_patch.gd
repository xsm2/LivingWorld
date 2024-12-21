static func patch():
	var script_path = "res://world/maps/gauntlet/CarriageScene.gd"
	var patched_script : GDScript = preload("res://world/maps/gauntlet/CarriageScene.gd")

	if !patched_script.has_source_code():
		var file : File = File.new()
		var err = file.open(script_path, File.READ)
		if err != OK:
			push_error("Check that %s is included in Modified Files"% script_path)
			return
		patched_script.source_code = file.get_as_text()
		file.close()

	var code_lines:Array = patched_script.source_code.split("\n")

	var code_index = code_lines.find("	var rp = WorldPlayerFactory.create_remote_player(avatar.id)")
	if code_index > 0:
		code_lines[code_index] = get_code("replace_rp")

	

	patched_script.source_code = ""
	for line in code_lines:
		patched_script.source_code += line + "\n"

	var err = patched_script.reload()
	if err != OK:
		push_error("Failed to patch %s." % script_path)
		return

static func get_code(block:String)->String:
	var code_blocks:Dictionary = {}
	code_blocks["replace_rp"] = """
	var rp = create_modded_remote_player(avatar.id)
	var rp_info = Net.avatars.get_avatar_info(avatar.id)
	if rp_info.transform_index >= 0 and rp_info.use_monster_form:
		call_deferred("set_player_form",rp,0,rp_info.transform_index,rp_info.use_monster_form)		
	"""		
	return code_blocks[block]


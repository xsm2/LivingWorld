static func patch():
	var script_path = "res://nodes/actions/RaidBattleAction.gd"
	var patched_script : GDScript = preload("res://nodes/actions/RaidBattleAction.gd")

	if !patched_script.has_source_code():
		var file : File = File.new()
		var err = file.open(script_path, File.READ)
		if err != OK:
			push_error("Check that %s is included in Modified Files"% script_path)
			return
		patched_script.source_code = file.get_as_text()
		file.close()

	var code_lines:Array = patched_script.source_code.split("\n")

	var class_name_index = code_lines.find("class_name RaidBattleAction")
	if class_name_index >= 0:
		code_lines.remove(class_name_index)

	var code_index = code_lines.find("		_preprocess_raid_config(config)")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("config"))

	patched_script.source_code = ""
	for line in code_lines:
		patched_script.source_code += line + "\n"
	RaidBattleAction.source_code = patched_script.source_code
	var err = RaidBattleAction.reload()
	if err != OK:
		push_error("Failed to patch %s." % script_path)
		return

static func get_code(block:String)->String:
	var code_blocks:Dictionary = {}
	code_blocks["config"] = """
		var npcmanager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
		if (npcmanager.engaged_recruits_nearby(e) or npcmanager.has_active_follower()) and npcmanager.get_setting("JoinEncounters"):
			config["extra_fighters"] = npcmanager.get_extra_fighters(e)		
			if npcmanager.has_active_follower():
				var follower_fighter = npcmanager.get_follower_fighter()
				if follower_fighter:
					config["extra_fighters"].push_back(follower_fighter)
		config["extra_slots"] = npcmanager.get_extra_slots()
	"""

	return code_blocks[block]


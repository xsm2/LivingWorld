static func patch():
	var script_path = "res://global/network/NetRequestRaid.gd"
	var patched_script : GDScript = preload("res://global/network/NetRequestRaid.gd")

	if !patched_script.has_source_code():
		var file : File = File.new()
		var err = file.open(script_path, File.READ)
		if err != OK:
			push_error("Check that %s is included in Modified Files"% script_path)
			return
		patched_script.source_code = file.get_as_text()
		file.close()

	var code_lines:Array = patched_script.source_code.split("\n")

	# var code_index = code_lines.find("	var fighters_json = _serialize_enemies(battle_args.fighters)")
	# if code_index > 0:
	# 	code_lines.insert(code_index+1,get_code("add_allies"))

	var code_index = code_lines.find("var is_bootleg:bool")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("declare_fighters"))

	code_index = code_lines.find("""		"_remote_set_party", """)
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("register_remote"))

	code_index = code_lines.find("		fighters = fighters_json, ")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("add_allies2"))

	code_index = code_lines.find("			fighters = _deserialize_enemies(json.fighters), ")
	if code_index > 0:
		code_lines[code_index] = get_code("add_allies3")

	code_index = code_lines.find("		assert (f.team != 0)")
	if code_index > 0:
		code_lines[code_index] = get_code("replace_check")

	code_index = code_lines.find("		for enemy in battle_args.fighters:")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("analyse"))

	code_index = code_lines.find("""		Net.send_rpc(remote_id, self, "_remote_set_battle_args", [_get_battle_args_json()])""")
	if code_index > 0:
		code_lines.insert(code_index,get_code("send_fighters"))

	code_index = code_lines.find("""		Net.send_rpc(remote_id, self, "_remote_set_battle_args", [_get_battle_args_json()])""")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("readd_allies"))

	code_index = code_lines.find("		if json.title_banner:")
	if code_index > 0:
		code_lines.insert(code_index,get_code("deserialize_background"))

	code_lines.insert(code_lines.size()-1,get_code("new_funcs"))

	patched_script.source_code = ""
	for line in code_lines:
		patched_script.source_code += line + "\n"

	var err = patched_script.reload()
	if err != OK:
		push_error("Failed to patch %s." % script_path)
		return

static func get_code(block:String)->String:
	var code_blocks:Dictionary = {}
	code_blocks["send_fighters"] = """
		var extra_fighters_json = _serialize_allies(battle_args.get("extra_fighters",[]))
		for json in extra_fighters_json:
			Net.send_rpc(remote_id, self, "_remote_set_extra_fighters", [json])
	"""		
	code_blocks["register_remote"] = """
		"_remote_set_extra_fighters", 
	"""	
	code_blocks["declare_fighters"] = """
var extra_fighters:Array = []
	"""	
	code_blocks["deserialize_background"] = """
		var npcmanager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
		npcmanager.set_extra_slots(battle_args.get("extra_slots",0))
		battle_args.background = npcmanager.repack_background(battle_args.background)	
	"""
	code_blocks["readd_allies"] = """
		var npcmanager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
		if npcmanager.get_setting("JoinEncounters"):
			battle_args.fighters += battle_args.get("extra_fighters",[])			
		battle_args.background = npcmanager.repack_background(battle_args.background)	
	"""	
	code_blocks["add_allies3"] = """
			fighters = _deserialize_enemies(json.fighters) + extra_fighters,
			extra_slots = json.get("extra_slots",0),
	"""
	code_blocks["analyse"] = """
			if enemy.team != 1:continue
	"""	
	code_blocks["replace_check"] ="""
		if f.team == 0:continue
	"""
	code_blocks["add_allies2"] = """
		extra_slots = battle_args.get("extra_slots",0),		
	"""
	code_blocks["new_funcs"] = """
func _remote_set_extra_fighters(fsnap):
	var manager = load("res://mods/LivingWorld/scripts/NPCManager.gd")
	var fnode = FighterNode.new()
	fnode.team = 0
	
	for csnap in fsnap.characters:
		var c = Character.new()
		if not c.set_snapshot(csnap.character, SaveState.CURRENT_VERSION):
			close(ClosedReason.ERROR)
			push_error("Invalid ally character")
			for f in extra_fighters:f.queue_free()
			return
		var cnode = CharacterNode.new()
		cnode.character = c
		if csnap.get("battle_sprite","") != "":
			cnode.character.battle_sprite = load(csnap.battle_sprite) as PackedScene
		for field in EXTRA_CHARACTER_FIELDS:
			cnode.character.set(field, csnap[field])
		fnode.add_child(cnode)
	
	var ai = load(fsnap.ai.resource_path) as PackedScene
	if not ai:
		close(ClosedReason.ERROR)
		push_error("Invalid ally AI")
		for f in extra_fighters:f.queue_free()
		return
	
	ai = ai.instance()
	ai.ai_smartness = int(fsnap.ai.ai_smartness)
	ai.behavior_settings["allow_recording"] = fsnap.ai.get("allow_recording",false)
	ai.behavior_settings["use_items"] = fsnap.ai.get("use_items",false)
	ai.status_bubble_enabled = manager.get_setting("BackupStatus")
	fnode.add_child(ai)
	ai.fighter = fnode
	
	ai.die_fusion_stat = fsnap.die_fusion_stat
	ai.die_fusion_stat_key = fsnap.die_fusion_stat_key
	
	extra_fighters.push_back(fnode)

func _serialize_allies(fighters:Array)->Array:
	var manager = load("res://mods/LivingWorld/scripts/NPCManager.gd")
	var result = []
	
	for f in fighters:
		if f.team != 0:continue 
		
		var enemy = {
			characters = [], 
			die_fusion_stat = f.get_controller().die_fusion_stat, 
			die_fusion_stat_key = f.get_controller().die_fusion_stat_key,
		}
		for c in f.get_characters():
			var battle_sprite = ""
			if c.character.battle_sprite is PackedScene:
				battle_sprite = c.character.battle_sprite.resource_path
			var cdata = {
				character = c.character.get_snapshot(), 
				battle_sprite = battle_sprite,
			}
			for field in EXTRA_CHARACTER_FIELDS:
				cdata[field] = c.character.get(field)
			enemy.characters.push_back(cdata)
		
		enemy.ai = {
			resource_path = f.get_controller().filename, 
			ai_smartness = f.get_controller().ai_smartness,
			use_items = manager.get_setting("UseItems"),
			allow_recording = manager.get_setting("NPCRecording"),
		}
		result.push_back(enemy)
	
	return result
	"""
	return code_blocks[block]


static func patch():
	var script_path = "res://world/core/LevelMap.gd"
	var patched_script : GDScript = preload("res://world/core/LevelMap.gd")

	if !patched_script.has_source_code():
		var file : File = File.new()
		var err = file.open(script_path, File.READ)
		if err != OK:
			push_error("Check that %s is included in Modified Files"% script_path)
			return
		patched_script.source_code = file.get_as_text()
		file.close()

	var code_lines:Array = patched_script.source_code.split("\n")

	var class_name_index = code_lines.find("class_name LevelMap")
	if class_name_index >= 0:
		code_lines.remove(class_name_index)

	var code_index = code_lines.find("	if SaveState.party.is_partner_unlocked(SaveState.party.current_partner_id):")
	if code_index > 0:
		code_lines.insert(code_index-1,get_code("respawn_recruit"))


	code_index = code_lines.find("func set_region_settings(value:RegionSettings):")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("add_spawner"))

	code_lines.insert(code_lines.size()-1,get_code("setup_recruit_spawner"))

	code_index = code_lines.find("	var npc = WorldPlayerFactory.create_player(player_index)")
	if code_index > 0:
		code_lines[code_index] = get_code("change_player")

	code_index = code_lines.find("		var rp = WorldPlayerFactory.create_remote_player(avatar.id)")
	if code_index > 0:
		code_lines[code_index] = get_code("change_remoteplayer")		

	code_index = code_lines.find("		var rp = WorldPlayerFactory.create_remote_player(id)")
	if code_index > 0:
		code_lines[code_index] = get_code("change_remoteplayer2")		

	code_index = code_lines.find("	if warp_target:")
	if code_index > 0:
		code_lines.insert(code_index-1,get_code("warp_recruit"))


	patched_script.source_code = ""
	for line in code_lines:
		patched_script.source_code += line + "\n"
	LevelMap.source_code = patched_script.source_code
	var err = LevelMap.reload()
	if err != OK:
		push_error("Failed to patch %s." % script_path)
		return

static func get_code(block:String)->String:
	var code_blocks:Dictionary = {}
	code_blocks["warp_recruit"] = """

	if npc_manager.has_active_follower() and !has_node("FollowerRecruit"):
		npc_manager.spawn_recruit(self, npc_manager.get_current_follower())
	if npc_manager.has_active_follower() and has_node("FollowerRecruit"):
		var custom_recruit = get_node("FollowerRecruit")
		warp_entities.push_back(custom_recruit)
	"""

	code_blocks["change_player"] = """
	var npc = create_modded_player(player_index)
	var npc_manager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
	npc_manager.remove_duplicate_partner()
	npc.net_id = -1
	if npc_manager.is_player_transformed(player_index):
		call_deferred("set_player_form",npc,player_index)
	"""
	code_blocks["change_remoteplayer"] = """
		var rp = create_modded_remote_player(avatar.id)
		rp.net_id = avatar.id
		var rp_info = Net.avatars.get_avatar_info(avatar.id)
		print("Checking transform data: %s %s"%[rp_info.transform_index,rp_info.use_monster_form])		
		if rp_info.transform_index >= 0 and rp_info.use_monster_form:
			print("Transformation required")
			call_deferred("set_player_form",rp,0,rp_info.transform_index,rp_info.use_monster_form)
	"""
	code_blocks["change_remoteplayer2"] = """
		var rp = create_modded_remote_player(id)
		rp.net_id = id
		print("Checking transform data: %s %s"%[avatar.transform_index,avatar.use_monster_form])		
		if avatar.transform_index >= 0 and avatar.use_monster_form:
			call_deferred("set_player_form",rp,0,avatar.transform_index,avatar.use_monster_form)
	"""
	code_blocks["respawn_recruit"] = """
	var npc_manager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
	if has_node("FollowerRecruit") and !npc_manager.has_active_follower():
		var follower = get_node("FollowerRecruit")
		follower.get_parent().remove_child(follower)
		follower.queue_free()
	if has_node("FollowerRecruit") and npc_manager.has_active_follower():
			var follower = get_node("FollowerRecruit")
			if !npc_manager.compare_dictionaries(follower.get_data().recruit,npc_manager.get_current_follower()):
				follower.get_parent().remove_child(follower)
				follower.queue_free()
	if npc_manager.has_active_follower() and !has_node("FollowerRecruit"):
		npc_manager.spawn_recruit(self, npc_manager.get_current_follower(), npc_manager.get_follower_partner_id())
	"""

	code_blocks["add_spawner"] = """
	if value:
		call_deferred("setup_recruit_spawner",value.region_name)

	"""
	code_blocks["setup_recruit_spawner"] = """
func setup_recruit_spawner(current_regionname):
	var npc_manager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
	npc_manager.add_spawner(current_regionname,self)

func set_player_form(npc,playerindex,transform_index:int=-1,use_monster_form:bool=true):
	var npc_manager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
	npc_manager.set_player_form(npc,playerindex,transform_index,use_monster_form)

func create_modded_player(player_index:int):
	var npc = preload("res://mods/LivingWorld/nodes/PlayerMonster.tscn").instance()
	npc.character = SaveState.party.characters[player_index]

	if player_index == 0:
		npc.name = "Player"
		npc.add_to_group("player_character")
	else :
		npc.name = "Partner"

	WorldPlayerFactory.set_npc_to_player(npc, player_index)
	return npc

func create_modded_remote_player(id):
	var RemotePlayerController = load("res://world/player/RemotePlayerController.gd")
	var npc = preload("res://mods/LivingWorld/nodes/PlayerMonster.tscn").instance()	
	npc.add_to_group("remote_player")
	var rp_info = Net.players.get_player_info(id)
	npc.sprite_colors = rp_info.human_colors
	npc.sprite_part_names = rp_info.human_part_names
	var controller = RemotePlayerController.new()
	controller.id = id
	npc.add_child(controller)
	return npc

	"""

	return code_blocks[block]


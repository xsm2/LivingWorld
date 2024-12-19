static func patch():
	var script_path = "res://global/network/NetAvatars.gd"
	var patched_script : GDScript = preload("res://global/network/NetAvatars.gd")

	if !patched_script.has_source_code():
		var file : File = File.new()
		var err = file.open(script_path, File.READ)
		if err != OK:
			push_error("Check that %s is included in Modified Files"% script_path)
			return
		patched_script.source_code = file.get_as_text()
		file.close()

	var code_lines:Array = patched_script.source_code.split("\n")

	var code_index = code_lines.find("var local_avatar:AvatarInfo = AvatarInfo.new()")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("add_var"))

	code_index = code_lines.find("""	Net.rpc.register(self, ["_remote_player_warping", "_remote_player_warped", "_remote_avatar_movement", "_remote_avatar_scale"])""")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("add_register"))

	code_index = code_lines.find("		_on_scene_changed()")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("send_transform"))

	code_index = code_lines.find("	local_avatar.id = Net.local_id")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("add_local"))

	code_index = code_lines.find("	_send_avatar_scene(id)")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("sync_transform"))		

	code_lines.insert(code_lines.size()-1,get_code("add_newfunction"))

	patched_script.source_code = ""
	for line in code_lines:
		patched_script.source_code += line + "\n"

	var err = patched_script.reload()
	if err != OK:
		push_error("Failed to patch %s." % script_path)
		return

static func get_code(block:String)->String:
	var code_blocks:Dictionary = {}
	code_blocks["add_var"] = """
var npc_manager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
	"""
	code_blocks["add_register"] = """
	Net.rpc.register(self,["_remote_avatar_transformed"])
	"""
	code_blocks["sync_transform"] = """
	if npc_manager.get_use_transformation_form():
		_send_avatar_transformed(npc_manager.get_transformation_index(0),true)
	"""	
	code_blocks["add_newfunction"] = """

func local_avatar_transform(index:int,use_monster_form:bool):
	if not local_avatar:return 
	local_avatar.transform_index = index
	local_avatar.use_monster_form = use_monster_form
	_send_avatar_transformed(index,use_monster_form)

func _send_avatar_transformed(index:int,use_monster_form:bool):
	assert (is_enabled())
	Net.send_rpc(null,self,"_remote_avatar_transformed",[index,use_monster_form])

func _remote_avatar_transformed(index:int,use_monster_form:bool):
	var id = Net.rpc.sender_id
	if not avatars.has(id) or not is_enabled():return 
	var avatar = avatars[id]	
	avatar.transform_index = index
	avatar.use_monster_form = use_monster_form
	emit_signal("avatar_transformed",id,index,use_monster_form)
	"""
	code_blocks["add_register"] = """
	Net.rpc.register(self,["_remote_avatar_transformed"])
	"""		
	code_blocks["add_local"] = """
	local_avatar.transform_index = npc_manager.get_transformation_index(0)
	local_avatar.use_monster_form = npc_manager.get_use_transformation_form()
	"""		
	code_blocks["send_transform"] = """
		if npc_manager.is_player_transformed():
			_send_avatar_transformed(local_avatar.transform_index,local_avatar.use_monster_form)
	"""			
	return code_blocks[block]


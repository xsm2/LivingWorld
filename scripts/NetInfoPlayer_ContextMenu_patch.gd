static func patch():
	var script_path = "res://menus/net_multiplayer/NetInfoPlayer_ContextMenu.gd"
	var patched_script : GDScript = preload("res://menus/net_multiplayer/NetInfoPlayer_ContextMenu.gd")

	if !patched_script.has_source_code():
		var file : File = File.new()
		var err = file.open(script_path, File.READ)
		if err != OK:
			push_error("Check that %s is included in Modified Files"% script_path)
			return
		patched_script.source_code = file.get_as_text()
		file.close()

	var code_lines:Array = patched_script.source_code.split("\n")

	var code_index = code_lines.find("onready var battle_btn = $BattleButton")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("add_var"))

	code_index = code_lines.find("	set_player_id(player_id)")
	if code_index > 0:
		code_lines.insert(code_index+1,get_code("add_buttons"))

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
	code_blocks["add_var"] = """
var trade_cards_btn
var card_battle_btn
	"""			
	code_blocks["add_buttons"] = """
	if battle_btn:
		var parent = battle_btn.get_parent()
		if parent:
			trade_cards_btn = battle_btn.duplicate()
			if trade_cards_btn.is_connected("pressed",self,"_on_BattleButton_pressed"):
				trade_cards_btn.disconnect("pressed",self,"_on_BattleButton_pressed")			
			trade_cards_btn.text = "TRADE_CARDS_BTN"
			parent.add_child_below_node(battle_btn,trade_cards_btn)
			trade_cards_btn.connect("pressed",self,"_on_TradeCards_pressed")
			card_battle_btn = battle_btn.duplicate()
			if card_battle_btn.is_connected("pressed",self,"_on_BattleButton_pressed"):
				card_battle_btn.disconnect("pressed",self,"_on_BattleButton_pressed")				
			card_battle_btn.text = "CARD_BATTLE_BTN"
			parent.add_child_below_node(battle_btn,card_battle_btn)
			card_battle_btn.connect("pressed",self,"_on_CardBattle_pressed")	
		setup_focus()
	"""		
	code_blocks["new_funcs"] = """
func _on_TradeCards_pressed():
	if player_id == Net.local_id or Net.requests.has_outgoing_request_with(player_id):
		return 
	var mod = DLC.mods_by_id["LivingWorldMod"]
	if !mod:
		return
	
	Controls.set_disabled(self, true)
	var remote_player = Net.players.get_player_info(player_id)
	if Net.players.is_trade_banned(player_id):
		
		GlobalMessageDialog.clear_state()
		yield (GlobalMessageDialog.show_message(Loc.trf("ONLINE_REQUEST_UI_TRADE_RANGERID_ERROR", {
			remote_player = remote_player.player_name
		})), "completed")
		Controls.set_disabled(self, false)
		trade_cards_btn.grab_focus()
		return 
	var card = yield(mod.choose_card_for_trade(player_id),"completed")

	if not card or Net.requests.has_outgoing_request_with(player_id):
		Controls.set_disabled(self, false)
		trade_cards_btn.grab_focus()
		return 
	var request = Net.requests.open_request("trade_card", player_id)
	request.send_card(card)
	Controls.set_disabled(self, false)
	emit_signal("show_request", request)

func _on_CardBattle_pressed():
	pass
	"""
	return code_blocks[block]


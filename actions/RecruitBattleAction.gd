extends BattleAction
const manager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
func _run():
	var player_level = SaveState.party.player.level
	var random:Random = Random.new()
	var overspill_disabled:bool = !manager.get_setting("OverspillDamage")
	var pawn = get_pawn()
	var pawnconfig = pawn.get_node("EncounterConfig/CharacterConfig")
	pawnconfig.level_override = player_level - 15
	pawnconfig.disable_overspill_damage = overspill_disabled
	var e = get_encounter(self, encounter_name_override)
	if e == null:
		push_error("Couldn't find EncounterConfig for BattleAction")
		return false
	configure_music_overrides(e)
	var config = e.get_config()
	if has_party():
		var index:int = 0
		for char_config in get_party_configs():
			char_config.disable_overspill_damage = overspill_disabled
			char_config.level_override = player_level - 15
			config.fighters.push_back(char_config.generate_fighter(Random.new(), 6))
			index+=1
		if pawn.get_data().get_party_leader():

			var tape_limit = (6 / (pawn.get_data().get_party_leader().get_party_size() + 1))

			for fighter in config.fighters:
				if fighter.team < 1:
					continue
				var character_node = fighter.get_characters()[0]
				var count:int = 0
				while character_node.character.tapes.size() > tape_limit:
					character_node.character.tapes.erase(random.choice(character_node.character.tapes))
					count+=1
	var result = yield (_run_encounter(e, config), "completed")

	return _handle_battle_result(result)

func get_party_configs()->Array:
	var random:Random = Random.new()
	var configs:Array
	var pawn = get_pawn()
	var data_node = pawn.get_data()
	if data_node.is_leader:
		var party = data_node.get_party_data()
		for member in party:
			var parent = member.node.get_parent()
			var encounter = parent.get_node("EncounterConfig")
			var charconfig = encounter.get_node("CharacterConfig")
			configs.push_back(charconfig)
	else:
		var leader_node = data_node.get_party_leader()
		var party_lead = leader_node.get_parent()
		var e = party_lead.get_node("EncounterConfig")
		var lead_charconfig = e.get_node("CharacterConfig")
		configs.push_back(lead_charconfig)
		var party = leader_node.get_party_data()
		for member in party:
			if member.node == data_node:
				continue
			var parent = member.node.get_parent()
			var encounter = parent.get_node("EncounterConfig")
			var charconfig = encounter.get_node("CharacterConfig")
			configs.push_back(charconfig)

	return configs

func has_party()->bool:
	var pawn = get_pawn()
	var data_node = pawn.get_data()
	return data_node.has_party()

#Gramophone Music Player Mod Handler
func configure_music_overrides(encounter:EncounterConfig):
	if music_mod_override():
		encounter.music_override = load_music()
		encounter.music_vox_override = load_music()

func music_mod_override()->bool:
	if !DLC.mods_by_id.has("gramophone_music_mod"):
		return false
	if not SaveState.other_data.has("GramophonePlayerData"):
		return false
	if not SaveState.other_data.GramophonePlayerData.has("BattleData"):
		return false
	return true

func load_music():
	if SaveState.other_data.GramophonePlayerData.BattleData.altload or SaveState.other_data.GramophonePlayerData.BattleData.path == "mute":
		return load_external_ogg(SaveState.other_data.GramophonePlayerData.BattleData.path)
	else:
		return load(SaveState.other_data.GramophonePlayerData.BattleData.path)

func load_external_ogg(path):
	if path == "mute":
		return AudioStreamMP3.new()
	var ogg_file = File.new()
	var err = ogg_file.open(path, File.READ)
	if err != OK:
		return null
	var bytes = ogg_file.get_buffer(ogg_file.get_len())
	var stream = AudioStreamMP3.new()
	stream.data = bytes
	stream.loop = true
	ogg_file.close()
	return stream


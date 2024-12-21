extends "res://global/network/NetRequest.gd"
const card_template = preload("res://mods/LivingWorld/cardgame/CardTemplate.tscn")
const card_battle = preload("res://mods/LivingWorld/scenes/MiniGame.tscn")
var local_deck:Array
var remote_deck:Array
var npcmanager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
var jsonparser = preload("res://mods/LivingWorld/scripts/RangerDataParser.gd")
var match_seed = 0
var winning_team:int 
var remote_player_data = null
var barrier:NetBarrier
func _ready():
	Net.rpc.register(self, ["_remote_set_deck"])


func create(sender_id, recipient_id):
	.create(sender_id, recipient_id)
	
	autoacceptor_id = sender_id

func expects_local_response()->bool:
	if closed:
		return false
	if expects_accept():
		return true
	if local_id == sender_id:
		return false
	else :
		return local_deck == null and remote_deck != null


func set_deck():
	if !local_deck:
		var deck = npcmanager.get_player_deck()
		local_deck = _deserialize_deck(deck)
		if local_deck.empty():
			close(ClosedReason.ERROR)
			return 
		match_seed = randi() ^ SaveState.random_seed  
		var snapshot = jsonparser.get_player_snapshot()
		var player_data:Dictionary = {		
			"name":snapshot.name,
			"pronouns":snapshot.pronouns,
			"human_colors":snapshot.human_colors,
			"human_part_names":snapshot.human_part_names,}
		Net.send_rpc(remote_id, self, "_remote_set_deck", [deck,match_seed,player_data])
	
	if !remote_deck.empty():
		start_battle()

func _deserialize_deck(deck)->Array:
	var results:Array = []
	for data in deck:
		var card = card_template.instance()
		card.form = data.form
		card.holocard = data.holocard
		results.push_back(card.duplicate())
	return results

func _remote_set_deck(deck:Array, random_seed:int,rp_data):
	var id = Net.rpc.sender_id
	if id != remote_id:
		return 
	if remote_deck:
		close(ClosedReason.ERROR)
	match_seed = random_seed
	remote_deck = _deserialize_deck(deck)
	remote_player_data = rp_data
	if remote_deck.empty() and remote_player_data != null:
		close(ClosedReason.ERROR)
		return 
	
	if !local_deck.empty():
		start_battle()

func update_description():
	var remote_player = get_player_info(remote_id)
	
	if closed and closed_reason == ClosedReason.COMPLETE:
		if winning_team == 0:
			set_description(Loc.trf("ONLINE_REQUEST_CLOSED_COMPLETE_BATTLE_WIN", {
				remote_player = remote_player.player_name
			}))
		elif winning_team == 1 :
			set_description(Loc.trf("ONLINE_REQUEST_CLOSED_COMPLETE_BATTLE_LOSE", {
				remote_player = remote_player.player_name
			}))
		else:
			set_description(Loc.trf("ONLINE_REQUEST_CLOSED_COMPLETE_BATTLE_DRAW", {
				remote_player = remote_player.player_name
			}))			
		return 
	
	.update_description()
	
func is_acceptable()->bool:
	return true

func confirmed():
	set_deck()

func start_battle():
	if is_outgoing():
		var other_player = Net.players.get_player_info(remote_id)
		Net.activity.broadcast("ONLINE_NOTIFICATION_CARD_BATTLE_STARTING", {other_player = other_player.player_name}, [Net.local_id, remote_id])

	if not WorldSystem.is_saving_enabled():
		close(ClosedReason.ERROR)
		return 
	WorldSystem.push_flags(0)
	if is_outgoing():
		var remote_player = get_remote_player_info()
		emit_signal("notification", Loc.trgf("ONLINE_NOTIFICATION_REQUEST_BATTLE_START", remote_player.pronouns, {
			remote_player = get_remote_player_info().player_name
		}))
	var orig_music = MusicSystem.current_track
	var menu = card_battle.instance()
	_setup_barriers()
	menu.random = Random.new(match_seed)
	menu.is_remote_player = recipient_id == local_id
	menu.player_deck = local_deck.duplicate()
	menu.enemy_deck = remote_deck.duplicate()
	menu.player_data = jsonparser.get_player_snapshot()
	menu.enemy_data = remote_player_data
	menu.net_request = self	
	MenuHelper.add_child(menu)
	var result = yield (menu.run_menu(), "completed")
	menu.queue_free()
	WorldSystem.pop_flags()
	MusicSystem.play(orig_music)

func _setup_barriers():
	barrier = NetBarrier.new()
	barrier.name = "SyncCheck"
	barrier.participant_ids = [local_id, remote_id]
	barrier.timer = 75
	barrier.soft_timer = false
	add_child(barrier, true)	
extends "res://global/network/NetRequest.gd"

var sender_card = null
var recipient_card = null
var npcmanager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
func _ready():
	Net.rpc.register(self, ["_remote_send_card"])


func create(sender_id, recipient_id):
	.create(sender_id, recipient_id)
	
	autoacceptor_id = recipient_id

func get_local_card():
	if local_id == sender_id:
		return sender_card
	assert (local_id == recipient_id)
	if local_id == recipient_id:
		return recipient_card
	return null

func get_remote_card():
	if remote_id == sender_id:
		return sender_card
	assert (remote_id == recipient_id)
	if remote_id == recipient_id:
		return recipient_card
	return null

func send_card(card):
	if npcmanager.has_card(card):
		npcmanager.set_card_held_in_trade(card)

	if local_id == sender_id:
		sender_card = card
	elif local_id == recipient_id:
		recipient_card = card
	Net.send_rpc(remote_id, self, "_remote_send_card", [card])
	update_description()

func validate_card(card)->bool:
	var form = load(card.form)
	if !form:
		return false
	return true

func _remote_send_card(snapshot):
	if not validate_card(snapshot):
		close(ClosedReason.ERROR)
		return 

	if local_id == recipient_id:
		if sender_card == null:
			sender_card = snapshot
		else :
			close(ClosedReason.ERROR)
	elif local_id == sender_id:
		if recipient_card == null:
			recipient_card = snapshot
		else :
			close(ClosedReason.ERROR)
	update_description()

func update_description():
	var remote_player = get_player_info(remote_id)
	var species1 = sender_card.name if sender_card else ""
	var species2 = recipient_card.name if recipient_card else ""
	
	if closed and closed_reason == ClosedReason.COMPLETE:
		set_description(Loc.trgf("ONLINE_REQUEST_CLOSED_COMPLETE_TRADE_CARD", remote_player.pronouns, {
			remote_player = remote_player.player_name, 
			species1 = species1 if is_outgoing() else species2, 
			species2 = species2 if is_outgoing() else species1
		}))
		return 
	
	if not closed and not accepted_local:
		if sender_card and not recipient_card:
			if is_outgoing():
				set_description(Loc.trf("ONLINE_REQUEST_SENT_CARD_TRADE", {
					remote_player = remote_player.player_name, 
					species1 = species1
				}))
			elif is_incoming():
				set_description(Loc.trf("ONLINE_REQUEST_RECEIVED_CARD_TRADE", {
					action = title, 
					remote_player = remote_player.player_name, 
					species1 = species1
				}))
			return 
		elif sender_card and recipient_card:
			if is_outgoing():
				set_description(Loc.trf("ONLINE_REQUEST_SENT_CARD_TRADE2", {
					remote_player = remote_player.player_name, 
					species1 = species1, 
					species2 = species2
				}))
			elif is_incoming():
				set_description(Loc.trf("ONLINE_REQUEST_RECEIVED_TRADE2", {
					remote_player = remote_player.player_name, 
					species1 = species1, 
					species2 = species2
				}))
			return 
	
	.update_description()

func expects_local_response()->bool:
	if closed:
		return false
	if expects_accept():
		return true
	if local_id == sender_id:
		return recipient_card != null and not accepted_local
	else :
		return sender_card != null and recipient_card == null

func is_acceptable()->bool:
	return sender_card and recipient_card

func aborted():
	
	var card = null
	if local_id == sender_id and sender_card:
		card = sender_card
	elif local_id == recipient_id and recipient_card:
		card = recipient_card
	if card:
		npcmanager.remove_card_held_in_trade(card)

func confirmed():
	assert (sender_card != null and recipient_card != null)
	var old_card = sender_card if local_id == sender_id else recipient_card
	var new_card = recipient_card if local_id == sender_id else sender_card
	if old_card:
		npcmanager.remove_card_from_collection(old_card)
		npcmanager.remove_card_held_in_trade(old_card)
	if new_card:
		npcmanager.add_card_to_collection(new_card)
	SaveSystem.save()
	.confirmed()
	
	if is_outgoing():
		Net.activity.traded(remote_id)

func traded(other_player_id):
	var other_player = Net.players.get_player_info(other_player_id)
	if other_player:
		Net.activity.broadcast("ONLINE_NOTIFICATION_TRADED_CARDS", {other_player = other_player.player_name}, [Net.local_id, other_player_id])


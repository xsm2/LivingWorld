extends "res://menus/net_multiplayer/NetInfoRequest.gd"

onready var remote_card_label = get_node("%RemoteCardLabel")
onready var local_card_btn = get_node("%LocalCardButton")
onready var remote_card_btn = get_node("%RemoteCardButton")

func _ready():
	refresh()

func refresh():
	.refresh()
	
	if not remote_card_label:
		return 
	
	var remote_player = Net.players.get_player_info(request.remote_id)
	remote_card_label.text = Loc.trgf("ONLINE_REQUEST_UI_TRADE_TAPE_LABEL_REMOTE", remote_player.pronouns, {
		remote_player = remote_player.player_name
	})
	
	set_card(local_card_btn,request.get_local_card())
	set_card(remote_card_btn,request.get_remote_card())	

func set_card(button,card):
	if card == null:
		button.hide_card()
		return
	button.holocard = card.holocard
	button.set_card_info(card.form)	
	button.set_card()
	button.set_holoeffect()
	button.show_card()

func _create_actions():
	._create_actions()
	
	actions.accept.label = "ONLINE_REQUEST_UI_TRADE_ACCEPT_OFFER"
	
	actions.offer_card = RequestAction.new()
	actions.offer_card.index = 0
	actions.offer_card.label = "ONLINE_REQUEST_UI_TRADE_CARD_MAKE_OFFER"
	actions.offer_card.executed = Bind.new(self, "_on_offer_card_action_executed")

func _update_actions():
	._update_actions()
	
	
	var local_card = request.get_local_card()
	
	actions.offer_card.enabled = local_card == null

func _on_offer_card_action_executed():
	var mod = DLC.mods_by_id["LivingWorldMod"]
	var card = yield (mod.choose_card_for_trade(request.remote_id), "completed")
	if not card:return 
	request.send_card(card)

func get_cards()->Array:
	var cards = []
	var local_card = request.get_local_card()
	var remote_card = request.get_remote_card()
	if local_card:
		cards.push_back(local_card)
	if remote_card:
		cards.push_back(remote_card)
	return cards

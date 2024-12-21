extends "res://menus/net_multiplayer/NetInfoRequest.gd"


func _ready():
	refresh()

func _create_actions():
	._create_actions()
	
	actions.accept.label = "ONLINE_REQUEST_UI_CARD_BATTLE_ACCEPT"

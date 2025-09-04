extends CheckConditionAction

export var species:Resource 

var manager = preload("res://mods/LivingWorld/scripts/NPCManager.gd")
func conditions_met()->bool:
	if root == null:
		setup()
	var pawn = get_pawn()
	var player_index = pawn.player_index
	var index = get_index() - 1
	if manager.get_transformation_index(player_index) == index:
		return false
	if species != null and !SaveState.species_collection.has_obtained_species(species):
		return manager.get_setting("UnlockTransform")
	return check_conditions(self)

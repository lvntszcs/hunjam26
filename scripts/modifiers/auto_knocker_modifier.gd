class_name AutoKnockerModifier
extends Modifier
## The Knocker's knocking machine (kopogtató gép): left at the door, it knocks
## in his place, as if someone were there.
##
## - Granny looks through the peephole first: the machine gives itself away,
##   stops and breaks (the knocking stops).
## - Granny opens the door to the knocking without looking first: she loses a
##   life (opening the door with nobody in the doorway always costs her one).


func activate(game: Node, _player: PlayerController) -> bool:
	return game.place_knocking_machine()

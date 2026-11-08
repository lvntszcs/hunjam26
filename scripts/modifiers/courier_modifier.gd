class_name CourierModifier
extends Modifier
## The Knocker's courier (futár): knocks on a neighbour's door, more dully
## than the Knocker (heard through the wall).
##
## - Granny opens her door to it: she loses a life (nobody is at her door).
## - She doesn't: the courier leaves after a few seconds (Courier.stay_time).


func activate(game: Node, _player: PlayerController) -> bool:
	return game.send_courier()

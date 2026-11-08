class_name FlipflopModifier
extends Modifier
## Granny's flip-flop (papucs): her next door opening is powered up, she holds
## a flip-flop in her hand until then.
##
## - The Knocker is in the doorway: he gets it, minus two lives.
## - Nobody is there: the flip-flop breaks (and the empty doorway costs her a
##   life as usual).
## - He hides in the bush: she throws the flip-flop into it like a boomerang;
##   he loses a life (and she doesn't).


func activate(game: Node, _player: PlayerController) -> bool:
	return game.ready_flipflop()

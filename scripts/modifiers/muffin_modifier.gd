class_name MuffinModifier
extends Modifier
## Granny's muffin (süti): she brings out the deadly smelling cupcake and opens
## the door.
##
## - The Knocker is in the smell's range (anywhere in the corridor, not
##   disguised): the aroma draws him to the door and he is caught (minus one
##   life).
## - Nobody is there: Granny loses a life.


func activate(game: Node, _player: PlayerController) -> bool:
	return game.serve_muffin()

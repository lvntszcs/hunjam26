class_name BushModifier
extends Modifier
## The Knocker's bush (tuja): he dresses up as a potted thuja at the door,
## which saves him one life.
##
## If Granny opens the door and would catch him, he loses nothing, but she
## does: there is "nobody in the corridor", only a bush. The disguise lasts
## until the door closes again (or he knocks again, which drops it). It can
## be put on anywhere, also far from the door, and isn't seen through the
## peephole.
##
## The card only counts as used once Granny opens the door on the bush: if he
## knocks it off before that, he can put it on again.


func activate(game: Node, _player: PlayerController) -> bool:
	return game.disguise_knocker()


func spent_on_activate() -> bool:
	return false

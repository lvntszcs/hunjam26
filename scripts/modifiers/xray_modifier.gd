class_name XrayModifier
extends Modifier
## Granny's X-ray goggles: the wall and the door blink see-through for a
## while, so she can see who is out there (Main's see-through effect).


func activate(game: Node, _player: PlayerController) -> bool:
	game.start_see_through()
	return true

class_name Modifier
extends Resource
## A modifier card: picked on the card screen before a round, then used once
## during that round with D-pad up (Q on the keyboard).
##
## Each modifier belongs to one side (Granny or the Knocker) and only shows up
## in that side's row. Only the player who picked the card can use it, and
## only once per round (Main keeps track; see Main.use_modifier).
##
## To add one: extend this script, override [method activate], save a
## resource of it (modifiers/*.tres) with its card picture, and put it in the
## CardChoose node's [member CardChooser.granny_modifiers] or
## [member CardChooser.knocker_modifiers].

enum Owner { GRANNY, KNOCKER }

## Shown in logs / debug.
@export var display_name := "Modifier"
## The card picture (full-screen art with the card in the middle).
@export var card_texture: Texture2D
## Whose card it is.
@export var owner: Owner = Owner.GRANNY


## True if a player playing [param role] may use this modifier.
func fits(role: Role) -> bool:
	if owner == Owner.GRANNY:
		return role is InsideRole
	return role is OutsideRole


## Does what the modifier does. [param game] is Main (the scene root), which
## offers the effects modifiers use; [param player] is who used it.
## Returns false if it could not take effect now (the card is then not used
## up). Override this.
func activate(_game: Node, _player: PlayerController) -> bool:
	return true

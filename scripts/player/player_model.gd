class_name PlayerModel
extends Resource
## Data of one player, independent of which role they currently play.

signal health_changed(current: int, maximum: int)
signal defeated

@export var display_name := "Player"
@export_range(1, 10) var max_health := 3

var health := 0


## Restores full health (e.g. at the start of a match).
func reset() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func take_damage(amount: int = 1) -> void:
	if is_defeated():
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if is_defeated():
		defeated.emit()


func is_defeated() -> bool:
	return health <= 0

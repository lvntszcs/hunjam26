extends CanvasLayer
## Draws one portrait per remaining health point for each role.

@export var resident_portrait: Texture2D
@export var knocker_portrait: Texture2D

var _players: Array[PlayerController]

@onready var _resident_icons: HBoxContainer = %ResidentIcons
@onready var _knocker_icons: HBoxContainer = %KnockerIcons


func setup(players: Array[PlayerController]) -> void:
	_players = players
	for controller in _players:
		controller.role_changed.connect(func(_role: Role) -> void: _refresh())
		if controller.model:
			controller.model.health_changed.connect(
				func(_current: int, _maximum: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var resident_health := 0
	var knocker_health := 0
	for controller in _players:
		if not controller.model:
			continue
		if controller.role is InsideRole:
			resident_health = controller.model.health
		elif controller.role is OutsideRole:
			knocker_health = controller.model.health
	_show_health(_resident_icons, resident_portrait, resident_health)
	_show_health(_knocker_icons, knocker_portrait, knocker_health)


func _show_health(row: HBoxContainer, portrait: Texture2D, health: int) -> void:
	while row.get_child_count() < health:
		var icon := TextureRect.new()
		icon.texture = portrait
		icon.custom_minimum_size = Vector2(44, 46)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	for i in row.get_child_count():
		var icon := row.get_child(i) as TextureRect
		icon.visible = i < health

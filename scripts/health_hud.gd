extends CanvasLayer
## Draws one portrait per remaining health point for each role, and under it
## the role's round wins in the best-of match (see [method show_wins]).

@export var resident_portrait: Texture2D
@export var knocker_portrait: Texture2D
## A round not (yet) won / won.
@export var round_empty_texture: Texture2D
@export var round_won_texture: Texture2D
@export var round_icon_size := Vector2(26, 26)

var _players: Array[PlayerController]

@onready var _resident_icons: HBoxContainer = %ResidentIcons
@onready var _knocker_icons: HBoxContainer = %KnockerIcons
@onready var _resident_wins: HBoxContainer = %ResidentWins
@onready var _knocker_wins: HBoxContainer = %KnockerWins


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


## Shows [param slots] round circles per side, [param resident_wins] /
## [param knocker_wins] of them filled. The circles nearest the screen edge
## (the wall) fill first: the resident's from the left, the knocker's from the
## right.
func show_wins(resident_wins: int, knocker_wins: int, slots: int) -> void:
	_show_rounds(_resident_wins, slots, resident_wins, false)
	_show_rounds(_knocker_wins, slots, knocker_wins, true)


func _show_rounds(row: HBoxContainer, slots: int, wins: int, from_right: bool) -> void:
	while row.get_child_count() < slots:
		var icon := TextureRect.new()
		icon.custom_minimum_size = round_icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var count := row.get_child_count()
	for i in count:
		var icon := row.get_child(i) as TextureRect
		icon.visible = i < slots
		var from_wall := (slots - 1 - i) if from_right else i
		icon.texture = round_won_texture if from_wall < wins else round_empty_texture

extends Node2D
# PiecePair.gd - Manages a pair of falling pieces

var piece1
var piece2
var grid_position = Vector2.ZERO
var piece_rotation = 0  # 0, 1, 2, 3 for different orientations

@onready var piece_scene = preload("res://scenes/Piece.tscn")

func _ready():
	create_pieces()

func create_pieces():
	piece1 = piece_scene.instantiate()
	piece2 = piece_scene.instantiate()
	
	# Random colors
	piece1.set_color(GameState.colors[randi() % GameState.colors.size()])
	piece2.set_color(GameState.colors[randi() % GameState.colors.size()])
	
	add_child(piece1)
	add_child(piece2)
	
	update_piece_positions()

func update_piece_positions():
	match piece_rotation:
		0:  # Vertical, piece1 on top
			piece1.position = Vector2(0, 0)
			piece2.position = Vector2(0, 32)
		1:  # Horizontal, piece1 on left
			piece1.position = Vector2(0, 0)
			piece2.position = Vector2(32, 0)
		2:  # Vertical, piece2 on top
			piece1.position = Vector2(0, 32)
			piece2.position = Vector2(0, 0)
		3:  # Horizontal, piece2 on left
			piece1.position = Vector2(32, 0)
			piece2.position = Vector2(0, 0)

func rotate_pieces():
	piece_rotation = (piece_rotation + 1) % 4
	update_piece_positions()

func set_grid_position(pos):
	grid_position = pos

func set_pixel_position(pos):
	position = pos

func get_piece_positions(base_pos):
	var positions = []
	match piece_rotation:
		0:  # Vertical, piece1 on top
			positions.append(base_pos)
			positions.append(base_pos + Vector2(0, 1))
		1:  # Horizontal, piece1 on left
			positions.append(base_pos)
			positions.append(base_pos + Vector2(1, 0))
		2:  # Vertical, piece2 on top
			positions.append(base_pos + Vector2(0, 1))
			positions.append(base_pos)
		3:  # Horizontal, piece2 on left
			positions.append(base_pos + Vector2(1, 0))
			positions.append(base_pos)
	return positions

func get_pieces():
	match piece_rotation:
		0, 1:
			return [piece1, piece2]
		2, 3:
			return [piece2, piece1]

extends Node2D
# PiecePair.gd - Manages a pair of falling pieces

var piece1
var piece2
var grid_position = Vector2.ZERO
var piece_rotation = 0  # 0, 1, 2, 3 for different orientations

const piece_scene = preload("res://scenes/Piece.tscn")

func _ready():
	# DON'T create pieces automatically anymore!
	# Pieces will be created explicitly via set_piece_data_from_index()
	pass

func create_pieces():
	# DEPRECATED - kept only for backwards compatibility with single player
	# This should only be called by single player mode
	if piece1 and piece2:
		return  # Already created
	
	piece1 = piece_scene.instantiate()
	piece2 = piece_scene.instantiate()
	
	# Get piece data from GameState's shared sequence (legacy method)
	var piece_data = GameState.get_next_piece_pair_data()
	
	# Set piece1 type
	match piece_data.piece1.type:
		"bomb":
			piece1.set_as_bomb()
		"bubble":
			piece1.set_as_bubble()
		"normal":
			piece1.set_color(piece_data.piece1.color)
	
	# Set piece2 type
	match piece_data.piece2.type:
		"bomb":
			piece2.set_as_bomb()
		"bubble":
			piece2.set_as_bubble()
		"normal":
			piece2.set_color(piece_data.piece2.color)
	
	add_child(piece1)
	add_child(piece2)
	
	update_piece_positions()
	


func update_piece_positions():
	match piece_rotation:
		0:  # Vertical, piece1 on top
			piece1.position = Vector2(0, 0)
			piece2.position = Vector2(0, 64)
		1:  # Horizontal, piece1 on left
			piece1.position = Vector2(0, 0)
			piece2.position = Vector2(64, 0)
		2:  # Vertical, piece2 on top
			piece1.position = Vector2(0, 64)
			piece2.position = Vector2(0, 0)
		3:  # Horizontal, piece2 on left
			piece1.position = Vector2(64, 0)
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
		2:  # Vertical, piece1 on bottom (piece2 on top)
			positions.append(base_pos + Vector2(0, 1))
			positions.append(base_pos)
		3:  # Horizontal, piece1 on right (piece2 on left)
			positions.append(base_pos + Vector2(1, 0))
			positions.append(base_pos)
	return positions

func get_pieces():
	# Always return pieces in the same order regardless of rotation
	return [piece1, piece2]
	
func set_piece_data_from_index(index: int):
	"""Create pieces from a specific index in the shared sequence"""
	var piece_data = GameState.get_piece_pair_data_at_index(index)
	
	# Create piece1 and piece2 if they don't exist
	if not piece1:
		piece1 = piece_scene.instantiate()
		add_child(piece1)
	if not piece2:
		piece2 = piece_scene.instantiate()
		add_child(piece2)
	
	# Set piece1 type
	match piece_data.piece1.type:
		"bomb":
			piece1.set_as_bomb()
		"bubble":
			piece1.set_as_bubble()
		"normal":
			piece1.set_color(piece_data.piece1.color)
	
	# Set piece2 type
	match piece_data.piece2.type:
		"bomb":
			piece2.set_as_bomb()
		"bubble":
			piece2.set_as_bubble()
		"normal":
			piece2.set_color(piece_data.piece2.color)
	
	update_piece_positions()

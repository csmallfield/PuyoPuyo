extends Node2D
# PiecePair.gd - Manages a pair of falling pieces with bomb support

const BombController = preload("res://scripts/BombController.gd")

var piece1
var piece2
var grid_position = Vector2.ZERO
var piece_rotation = 0

const piece_scene = preload("res://scenes/Piece.tscn")

func _ready():
	pass

func create_pieces():
	# DEPRECATED - kept for backwards compatibility
	if piece1 and piece2:
		return
	
	piece1 = piece_scene.instantiate()
	piece2 = piece_scene.instantiate()
	
	var piece_data = GameState.get_next_piece_pair_data()
	
	# Set piece1 type
	match piece_data.piece1.type:
		"bomb":
			var bomb_orientation = BombController.get_bomb_orientation_from_rotation(piece_rotation)
			piece1.set_as_bomb(piece_data.piece1.bomb_type, bomb_orientation)
		"bubble":
			piece1.set_as_bubble()
		"normal":
			piece1.set_color(piece_data.piece1.color)
	
	# Set piece2 type
	match piece_data.piece2.type:
		"bomb":
			var bomb_orientation = BombController.get_bomb_orientation_from_rotation(piece_rotation)
			piece2.set_as_bomb(piece_data.piece2.bomb_type, bomb_orientation)
		"bubble":
			piece2.set_as_bubble()
		"normal":
			piece2.set_color(piece_data.piece2.color)
	
	add_child(piece1)
	add_child(piece2)
	
	update_piece_positions()

func update_piece_positions():
	match piece_rotation:
		0:
			piece1.position = Vector2(0, 0)
			piece2.position = Vector2(0, 64)
		1:
			piece1.position = Vector2(0, 0)
			piece2.position = Vector2(64, 0)
		2:
			piece1.position = Vector2(0, 64)
			piece2.position = Vector2(0, 0)
		3:
			piece1.position = Vector2(64, 0)
			piece2.position = Vector2(0, 0)

func rotate_pieces():
	piece_rotation = (piece_rotation + 1) % 4
	update_piece_positions()
	
	# Update bomb orientations for line bombs
	var bomb_orientation = BombController.get_bomb_orientation_from_rotation(piece_rotation)
	
	if piece1 and piece1.is_bomb() and piece1.get_bomb_type() == BombController.BombType.LINE:
		piece1.update_bomb_orientation(bomb_orientation)
	
	if piece2 and piece2.is_bomb() and piece2.get_bomb_type() == BombController.BombType.LINE:
		piece2.update_bomb_orientation(bomb_orientation)

func set_grid_position(pos):
	grid_position = pos

func set_pixel_position(pos):
	position = pos

func get_piece_positions(base_pos):
	var positions = []
	match piece_rotation:
		0:
			positions.append(base_pos)
			positions.append(base_pos + Vector2(0, 1))
		1:
			positions.append(base_pos)
			positions.append(base_pos + Vector2(1, 0))
		2:
			positions.append(base_pos + Vector2(0, 1))
			positions.append(base_pos)
		3:
			positions.append(base_pos + Vector2(1, 0))
			positions.append(base_pos)
	return positions

func get_pieces():
	return [piece1, piece2]
	
func set_piece_data_from_index(index: int):
	"""Create pieces from a specific index in the shared sequence"""
	var piece_data = GameState.get_piece_pair_data_at_index(index)
	
	if not piece1:
		piece1 = piece_scene.instantiate()
		add_child(piece1)
	if not piece2:
		piece2 = piece_scene.instantiate()
		add_child(piece2)
	
	# Get orientation for bombs
	var bomb_orientation = BombController.get_bomb_orientation_from_rotation(piece_rotation)
	
	# Set piece1 type
	match piece_data.piece1.type:
		"bomb":
			piece1.set_as_bomb(piece_data.piece1.bomb_type, bomb_orientation)
		"bubble":
			piece1.set_as_bubble()
		"normal":
			piece1.set_color(piece_data.piece1.color)
	
	# Set piece2 type
	match piece_data.piece2.type:
		"bomb":
			piece2.set_as_bomb(piece_data.piece2.bomb_type, bomb_orientation)
		"bubble":
			piece2.set_as_bubble()
		"normal":
			piece2.set_color(piece_data.piece2.color)
	
	update_piece_positions()

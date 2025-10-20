extends Node
# AIController.gd - Basic AI opponent

var grid = null
var move_timer = 0.0
var move_delay = 0.5  # AI makes a decision every 0.5 seconds
var decision_made = false

func _process(delta):
	if not grid or not grid.current_piece_pair or not grid.is_processing():
		decision_made = false
		return
	
	# Wait for the move delay
	move_timer += delta
	
	if move_timer >= move_delay and not decision_made:
		make_move()
		move_timer = 0.0

func make_move():
	"""AI makes a decision about what to do with current piece"""
	if not grid or not grid.current_piece_pair:
		return
	
	decision_made = true
	
	# Simple AI: analyze all possible placements and pick the best
	var best_score = -999999
	var best_column = 0
	var best_rotation = 0
	
	# Try all 4 rotations
	for rot in range(4):
		# Try all columns
		for col in range(GameState.grid_width):
			var score = evaluate_placement(col, rot)
			if score > best_score:
				best_score = score
				best_column = col
				best_rotation = rot
	
	# Execute the best move
	execute_move(best_column, best_rotation)

func evaluate_placement(column: int, rotation: int) -> float:
	"""Evaluate how good a placement would be"""
	# This is a simple heuristic - we can improve it later
	
	# Simulate the piece at this position
	var test_position = Vector2(column, 0)
	
	# Check if placement is even valid
	grid.current_piece_pair.piece_rotation = rotation
	grid.current_piece_pair.update_piece_positions()
	
	if not grid.can_place_piece_pair(grid.current_piece_pair, test_position):
		return -999999  # Invalid placement
	
	# Calculate score based on:
	# 1. How low the piece lands
	# 2. Avoid making columns too high
	
	var score = 0.0
	
	# Penalize height - prefer lower columns
	var column_height = get_column_height(column)
	score -= column_height * 10
	
	# Small random factor to add variety
	score += randf() * 5
	
	return score

func get_column_height(column: int) -> int:
	"""Get the current height of a column"""
	for y in range(GameState.grid_height):
		if grid.grid_data[y][column] != null:
			return GameState.grid_height - y
	return 0

func execute_move(target_column: int, target_rotation: int):
	"""Execute the chosen move"""
	if not grid or not grid.current_piece_pair:
		return
	
	# Set rotation
	var current_rotation = grid.current_piece_pair.piece_rotation
	var rotations_needed = (target_rotation - current_rotation) % 4
	
	for i in range(rotations_needed):
		grid.rotate_piece()
		await get_tree().create_timer(0.1).timeout
	
	# Move to target column
	var current_column = int(grid.current_piece_pair.grid_position.x)
	var columns_to_move = target_column - current_column
	
	if columns_to_move > 0:
		for i in range(columns_to_move):
			grid.move_piece_horizontal(1)
			await get_tree().create_timer(0.1).timeout
	elif columns_to_move < 0:
		for i in range(abs(columns_to_move)):
			grid.move_piece_horizontal(-1)
			await get_tree().create_timer(0.1).timeout
	
	# Fast drop
	await get_tree().create_timer(0.2).timeout
	grid.fast_drop_piece()
	
	# Reset decision flag for next piece
	decision_made = false

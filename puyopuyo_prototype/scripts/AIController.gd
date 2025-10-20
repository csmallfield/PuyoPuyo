extends Node
# AIController.gd - Configurable AI opponent with difficulty levels

# ============================================
# AI CONFIGURATION
# ============================================

enum Difficulty {
	LEVEL_0,  # Basic height-only AI (original)
	LEVEL_1,  # Color-aware AI with grouping
	LEVEL_2,  # Chain setup AI (future)
	LEVEL_3,  # Strategic chain AI (future)
}

# Main difficulty setting
var ai_difficulty = Difficulty.LEVEL_1

# Feature flags - can be toggled individually for testing
var use_color_adjacency = true
var use_group_potential = true
var use_height_variance = true
var use_special_piece_strategy = true
var use_center_preference = true

# Future features (for Level 2+)
var use_next_piece_lookahead = false
var use_chain_detection = false
var use_defensive_play = false

# Scoring weights - can be tuned per difficulty level
var weight_color_adjacency = 50.0
var weight_group_of_three = 200.0
var weight_group_of_two = 80.0
var weight_height_penalty = 8.0
var weight_height_variance = 25.0
var weight_center_preference = 5.0
var weight_random_variety = 15.0

# AI behavior settings
var move_delay = 0.8  # Time between AI decisions
var move_animation_speed = 0.17  # Speed of AI movements

# ============================================
# RUNTIME VARIABLES
# ============================================

var grid = null
var move_timer = 0.0
var decision_made = false

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	configure_difficulty(ai_difficulty)

func configure_difficulty(difficulty: Difficulty):
	"""Configure AI behavior based on difficulty level"""
	ai_difficulty = difficulty
	
	match difficulty:
		Difficulty.LEVEL_0:
			configure_level_0()
		Difficulty.LEVEL_1:
			configure_level_1()
		Difficulty.LEVEL_2:
			configure_level_2()
		Difficulty.LEVEL_3:
			configure_level_3()

func configure_level_0():
	"""Basic AI - only considers height"""
	use_color_adjacency = false
	use_group_potential = false
	use_height_variance = false
	use_special_piece_strategy = false
	use_center_preference = false
	use_next_piece_lookahead = false
	use_chain_detection = false
	
	weight_height_penalty = 10.0
	weight_random_variety = 10.0
	
	move_delay = 0.5
	move_animation_speed = 0.15

func configure_level_1():
	"""Color-aware AI with grouping strategy"""
	use_color_adjacency = true
	use_group_potential = true
	use_height_variance = true
	use_special_piece_strategy = true
	use_center_preference = true
	use_next_piece_lookahead = false
	use_chain_detection = false
	
	weight_color_adjacency = 50.0
	weight_group_of_three = 200.0
	weight_group_of_two = 80.0
	weight_height_penalty = 8.0
	weight_height_variance = 25.0
	weight_center_preference = 5.0
	weight_random_variety = 10.0
	
	move_delay = 0.7
	move_animation_speed = 0.15

func configure_level_2():
	"""Chain-aware AI (future implementation)"""
	configure_level_1()  # Start with Level 1 settings
	
	use_next_piece_lookahead = true
	use_chain_detection = true
	
	# Increase strategic weights
	weight_group_of_three = 300.0
	weight_color_adjacency = 70.0
	
	move_delay = 0.4
	move_animation_speed = 0.08

func configure_level_3():
	"""Advanced strategic AI (future implementation)"""
	configure_level_2()  # Start with Level 2 settings
	
	use_defensive_play = true
	
	# Even more strategic
	weight_group_of_three = 400.0
	
	move_delay = 0.3
	move_animation_speed = 0.05

# ============================================
# CORE AI LOGIC
# ============================================

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
	
	# Analyze all possible placements and pick the best
	var best_score = -999999
	var best_column = 0
	var best_rotation = 0
	
	# Store original rotation to restore later
	var original_rotation = grid.current_piece_pair.piece_rotation
	
	# Try all 4 rotations
	for rot in range(4):
		# Set the rotation for testing
		grid.current_piece_pair.piece_rotation = rot
		grid.current_piece_pair.update_piece_positions()
		
		# Try all columns
		for col in range(GameState.grid_width):
			var score = evaluate_placement(col, rot)
			if score > best_score:
				best_score = score
				best_column = col
				best_rotation = rot
	
	# Restore original rotation
	grid.current_piece_pair.piece_rotation = original_rotation
	grid.current_piece_pair.update_piece_positions()
	
	# Execute the best move
	execute_move(best_column, best_rotation)

func evaluate_placement(column: int, rotation: int) -> float:
	"""Evaluate how good a placement would be based on configured features"""
	
	# Get the piece positions for this placement
	var test_position = Vector2(column, 0)
	var piece_positions = grid.current_piece_pair.get_piece_positions(test_position)
	var pieces = grid.current_piece_pair.get_pieces()
	
	# Check if placement is even valid
	if not grid.can_place_piece_pair(grid.current_piece_pair, test_position):
		return -999999  # Invalid placement
	
	# Find where pieces would actually land
	var landing_positions = []
	for i in range(piece_positions.size()):
		var pos = piece_positions[i]
		# Drop each piece to find landing position
		var landing_y = find_landing_y(pos.x, pos.y)
		landing_positions.append(Vector2(pos.x, landing_y))
	
	# Calculate score based on enabled features
	var score = 0.0
	
	# LEVEL 1+ FEATURES
	if use_color_adjacency:
		score += evaluate_color_adjacency(landing_positions, pieces)
	
	if use_group_potential:
		score += evaluate_group_potential(landing_positions, pieces)
	
	if use_special_piece_strategy:
		score += evaluate_special_pieces(landing_positions, pieces)
	
	if use_center_preference:
		score += evaluate_center_preference(landing_positions)
	
	# LEVEL 0+ FEATURES (always used)
	score += evaluate_height_penalty(landing_positions)
	
	if use_height_variance:
		score += evaluate_height_variance(landing_positions)
	
	# LEVEL 2+ FEATURES (future)
	if use_next_piece_lookahead:
		# score += evaluate_next_piece(landing_positions, pieces)
		pass
	
	if use_chain_detection:
		# score += evaluate_chain_potential(landing_positions, pieces)
		pass
	
	# Random variety factor
	score += randf() * weight_random_variety
	
	return score

# ============================================
# EVALUATION FUNCTIONS
# ============================================

func evaluate_color_adjacency(landing_positions: Array, pieces: Array) -> float:
	"""Reward placing pieces next to same-colored pieces"""
	var score = 0.0
	
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		# Skip bombs and bubbles for color matching
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var color = piece.color
		
		# Check all 4 adjacent positions
		var adjacent_positions = [
			Vector2(pos.x + 1, pos.y),  # Right
			Vector2(pos.x - 1, pos.y),  # Left
			Vector2(pos.x, pos.y - 1),  # Up
			Vector2(pos.x, pos.y + 1)   # Down
		]
		
		for adj_pos in adjacent_positions:
			# Check bounds
			if adj_pos.x < 0 or adj_pos.x >= GameState.grid_width:
				continue
			if adj_pos.y < 0 or adj_pos.y >= GameState.grid_height:
				continue
			
			# Check if there's a piece there (or will be from this placement)
			var existing_piece = get_piece_at_position(adj_pos, landing_positions, pieces)
			
			if existing_piece and not existing_piece.is_bomb and not existing_piece.is_bubble:
				if existing_piece.color == color:
					score += weight_color_adjacency
	
	return score

func evaluate_group_potential(landing_positions: Array, pieces: Array) -> float:
	"""Huge bonus for creating groups of 3 (one away from a match)"""
	var score = 0.0
	
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		# Skip bombs and bubbles
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var color = piece.color
		
		# Count connected same-color pieces
		var group_size = count_connected_group(pos, color, landing_positions, pieces)
		
		# Reward based on group size
		if group_size >= 3:
			score += weight_group_of_three
		elif group_size == 2:
			score += weight_group_of_two
	
	return score

func evaluate_height_penalty(landing_positions: Array) -> float:
	"""Penalize placing in tall columns"""
	var score = 0.0
	
	for pos in landing_positions:
		var column_height = GameState.grid_height - pos.y
		score -= column_height * weight_height_penalty
	
	return score

func evaluate_height_variance(landing_positions: Array) -> float:
	"""Penalize creating columns much taller than average"""
	var score = 0.0
	
	# Calculate average height
	var total_height = 0
	var column_heights = []
	
	for x in range(GameState.grid_width):
		var height = get_column_height(x)
		column_heights.append(height)
		total_height += height
	
	var avg_height = total_height / float(GameState.grid_width)
	
	# Check if this placement creates very tall columns
	for pos in landing_positions:
		var new_height = GameState.grid_height - pos.y
		var height_diff = new_height - avg_height
		
		if height_diff > 3:
			score -= (height_diff - 3) * weight_height_variance
	
	return score

func evaluate_special_pieces(landing_positions: Array, pieces: Array) -> float:
	"""Smart placement for bombs and bubbles"""
	var score = 0.0
	
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		if piece.is_bomb:
			# Bombs should be placed near common colors
			score += evaluate_bomb_placement(pos)
		elif piece.is_bubble:
			# Bubbles should be placed adjacent to color groups
			score += evaluate_bubble_placement(pos)
	
	return score

func evaluate_bomb_placement(bomb_pos: Vector2) -> float:
	"""Evaluate bomb placement - prefer next to most common color"""
	var score = 0.0
	
	# Find the most common color on the board
	var color_counts = {}
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid.grid_data[y][x]
			if piece and not piece.is_bomb and not piece.is_bubble:
				var color = piece.color
				if not color_counts.has(color):
					color_counts[color] = 0
				color_counts[color] += 1
	
	# Check adjacent positions for common colors
	var adjacent_positions = [
		Vector2(bomb_pos.x + 1, bomb_pos.y),
		Vector2(bomb_pos.x - 1, bomb_pos.y),
		Vector2(bomb_pos.x, bomb_pos.y - 1),
		Vector2(bomb_pos.x, bomb_pos.y + 1)
	]
	
	for adj_pos in adjacent_positions:
		if adj_pos.x < 0 or adj_pos.x >= GameState.grid_width or adj_pos.y < 0 or adj_pos.y >= GameState.grid_height:
			continue
		
		var piece = grid.grid_data[adj_pos.y][adj_pos.x]
		if piece and not piece.is_bomb and not piece.is_bubble:
			var count = color_counts.get(piece.color, 0)
			score += count * 5  # Reward being next to common colors
	
	return score

func evaluate_bubble_placement(bubble_pos: Vector2) -> float:
	"""Evaluate bubble placement - prefer next to existing groups"""
	var score = 0.0
	
	# Bubbles are best placed adjacent to color groups
	var adjacent_positions = [
		Vector2(bubble_pos.x + 1, bubble_pos.y),
		Vector2(bubble_pos.x - 1, bubble_pos.y),
		Vector2(bubble_pos.x, bubble_pos.y - 1),
		Vector2(bubble_pos.x, bubble_pos.y + 1)
	]
	
	for adj_pos in adjacent_positions:
		if adj_pos.x < 0 or adj_pos.x >= GameState.grid_width or adj_pos.y < 0 or adj_pos.y >= GameState.grid_height:
			continue
		
		var piece = grid.grid_data[adj_pos.y][adj_pos.x]
		if piece and not piece.is_bomb and not piece.is_bubble:
			# Check if this color has nearby friends
			var nearby_same_color = count_nearby_same_color(adj_pos, piece.color)
			if nearby_same_color >= 2:
				score += 40  # Good spot - next to a forming group
	
	return score

func evaluate_center_preference(landing_positions: Array) -> float:
	"""Slight bonus for keeping center columns available"""
	var score = 0.0
	var center = GameState.grid_width / 2
	
	for pos in landing_positions:
		var distance_from_center = abs(pos.x - center)
		# Small bonus for being near center (gives flexibility)
		score += (3 - distance_from_center) * weight_center_preference
	
	return score

# ============================================
# HELPER FUNCTIONS
# ============================================

func find_landing_y(x: int, start_y: int) -> int:
	"""Find where a piece would land if dropped in column x"""
	var landing_y = start_y
	
	# Drop until we hit something
	while landing_y + 1 < GameState.grid_height:
		if grid.grid_data[landing_y + 1][x] != null:
			break
		landing_y += 1
	
	return landing_y

func count_connected_group(start_pos: Vector2, color: Color, landing_positions: Array, pieces: Array) -> int:
	"""Count how many same-colored pieces are connected to this position"""
	var visited = {}
	var stack = [start_pos]
	var count = 0
	
	while stack.size() > 0:
		var pos = stack.pop_back()
		
		# Skip if already visited
		if visited.has(pos):
			continue
		
		# Skip if out of bounds
		if pos.x < 0 or pos.x >= GameState.grid_width or pos.y < 0 or pos.y >= GameState.grid_height:
			continue
		
		# Check if there's a same-color piece here
		var piece_here = get_piece_at_position(pos, landing_positions, pieces)
		if not piece_here or piece_here.is_bomb or piece_here.is_bubble:
			continue
		if piece_here.color != color:
			continue
		
		# Mark as visited and count it
		visited[pos] = true
		count += 1
		
		# Add adjacent positions to check
		stack.append(Vector2(pos.x + 1, pos.y))
		stack.append(Vector2(pos.x - 1, pos.y))
		stack.append(Vector2(pos.x, pos.y + 1))
		stack.append(Vector2(pos.x, pos.y - 1))
	
	return count

func get_piece_at_position(pos: Vector2, landing_positions: Array, pieces: Array):
	"""Get the piece at a position, checking both grid and landing pieces"""
	# First check if it's one of the landing pieces
	for i in range(landing_positions.size()):
		if landing_positions[i] == pos:
			return pieces[i]
	
	# Otherwise check the grid
	if pos.y >= 0 and pos.y < GameState.grid_height and pos.x >= 0 and pos.x < GameState.grid_width:
		return grid.grid_data[pos.y][pos.x]
	
	return null

func count_nearby_same_color(pos: Vector2, color: Color) -> int:
	"""Count same-colored pieces adjacent to this position"""
	var count = 0
	var adjacent_positions = [
		Vector2(pos.x + 1, pos.y),
		Vector2(pos.x - 1, pos.y),
		Vector2(pos.x, pos.y - 1),
		Vector2(pos.x, pos.y + 1)
	]
	
	for adj_pos in adjacent_positions:
		if adj_pos.x < 0 or adj_pos.x >= GameState.grid_width or adj_pos.y < 0 or adj_pos.y >= GameState.grid_height:
			continue
		
		var piece = grid.grid_data[adj_pos.y][adj_pos.x]
		if piece and not piece.is_bomb and not piece.is_bubble and piece.color == color:
			count += 1
	
	return count

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
		if not grid or not grid.current_piece_pair:  # Add check in loop
			return
		grid.rotate_piece()
		await get_tree().create_timer(move_animation_speed).timeout
	
	# Move to target column
	if not grid or not grid.current_piece_pair:  # Add check before getting position
		return
	var current_column = int(grid.current_piece_pair.grid_position.x)
	var columns_to_move = target_column - current_column
	
	if columns_to_move > 0:
		for i in range(columns_to_move):
			if not grid or not grid.current_piece_pair:  # Add check in loop
				return
			grid.move_piece_horizontal(1)
			await get_tree().create_timer(move_animation_speed).timeout
	elif columns_to_move < 0:
		for i in range(abs(columns_to_move)):
			if not grid or not grid.current_piece_pair:  # Add check in loop
				return
			grid.move_piece_horizontal(-1)
			await get_tree().create_timer(move_animation_speed).timeout
	
	# Fast drop
	await get_tree().create_timer(0.2).timeout
	if not grid or not grid.current_piece_pair:  # Add check before fast drop
		return
	grid.fast_drop_piece()
	
	# Reset decision flag for next piece
	decision_made = false

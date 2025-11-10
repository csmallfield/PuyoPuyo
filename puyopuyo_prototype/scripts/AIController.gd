extends Node
# AIController.gd - Configurable AI opponent with difficulty levels
# IMPROVED VERSION with better survival instincts and balanced difficulty

# ============================================
# AI CONFIGURATION
# ============================================

enum Difficulty {
	LEVEL_0,  # Playable basic AI
	LEVEL_1,  # Competent AI with color awareness
	LEVEL_2,  # Challenging AI with chain setup
	LEVEL_3,  # Very challenging strategic AI
}

enum DangerState {
	SAFE,      # 0-50% full - normal play
	CAUTION,   # 50-70% full - be more careful
	DANGER,    # 70-85% full - focus on survival
	CRITICAL   # 85%+ full - emergency clearing only
}

# Main difficulty setting (only used if not configured externally)
var ai_difficulty = Difficulty.LEVEL_1  # Default to Level 1

# Feature flags - will be set by configure_difficulty()
var use_color_adjacency = false
var use_group_potential = false
var use_height_variance = false
var use_special_piece_strategy = false
var use_center_preference = false
var use_next_piece_lookahead = false
var use_chain_detection = false
var use_defensive_play = false

# Scoring weights - will be set by configure_difficulty()
var weight_color_adjacency = 0.0
var weight_group_of_three = 0.0
var weight_group_of_two = 0.0
var weight_height_penalty = 0.0
var weight_height_variance = 0.0
var weight_center_preference = 0.0
var weight_random_variety = 0.0

# Survival weights (universal, but scaled by difficulty)
var weight_spawn_zone_penalty = 2000.0  # Massive penalty for spawn zone
var weight_critical_height = 500.0     # Exponential height danger penalty
var weight_immediate_clear_bonus = 300.0  # Bonus for immediate matches

# Danger thresholds by difficulty
var danger_threshold_caution = 0.5    # When to start being careful
var danger_threshold_danger = 0.7     # When to get defensive
var danger_threshold_critical = 0.85  # When to panic

# AI behavior settings - will be set by configure_difficulty()
var move_delay = 0.5
var move_animation_speed = 0.1

# ============================================
# RUNTIME VARIABLES
# ============================================

var grid = null
var move_timer = 0.0
var decision_made = false

# ============================================
# INITIALIZATION
# ============================================
var _has_been_configured = false

func _ready():
	# Only configure if not already configured externally
	if not _has_been_configured:
		configure_difficulty(ai_difficulty)

func configure_difficulty(difficulty: Difficulty):
	"""Configure AI behavior based on difficulty level"""
	_has_been_configured = true  # Mark as configured
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
			
	print("=================================")
	print("AI Difficulty: Level ", ai_difficulty)
	print("Color Adjacency: ", use_color_adjacency)
	print("Group Potential: ", use_group_potential)
	print("Chain Detection: ", use_chain_detection)
	print("Defensive Play: ", use_defensive_play)
	print("Height Penalty Base: ", weight_height_penalty)
	print("Move Delay: ", move_delay)
	print("=================================")

func configure_level_0():
	"""Playable Basic AI - simple but not stupid"""
	use_color_adjacency = true  # ADD: Light color awareness
	use_group_potential = false
	use_height_variance = true
	use_special_piece_strategy = false
	use_center_preference = true
	use_next_piece_lookahead = false
	use_chain_detection = false
	use_defensive_play = false
	
	weight_color_adjacency = 20.0  # Light color bonus
	weight_height_penalty = 15.0   # Strong height avoidance
	weight_height_variance = 20.0
	weight_center_preference = 8.0
	weight_random_variety = 5.0    # Reduced randomness
	
	# Earlier danger detection for beginner
	danger_threshold_caution = 0.45
	danger_threshold_danger = 0.65
	danger_threshold_critical = 0.80
	
	move_delay = 1.2  # Faster than before (was 2.0)
	move_animation_speed = 0.8

func configure_level_1():
	"""Competent AI - color-aware with good survival instincts"""
	use_color_adjacency = true
	use_group_potential = true
	use_height_variance = true
	use_special_piece_strategy = true
	use_center_preference = true
	use_next_piece_lookahead = false
	use_chain_detection = false
	use_defensive_play = false
	
	weight_color_adjacency = 50.0
	weight_group_of_three = 200.0
	weight_group_of_two = 80.0
	weight_height_penalty = 15.0   # FIXED: Was 8.0, now higher
	weight_height_variance = 25.0
	weight_center_preference = 5.0
	weight_random_variety = 8.0
	
	# Standard danger thresholds
	danger_threshold_caution = 0.50
	danger_threshold_danger = 0.70
	danger_threshold_critical = 0.85
	
	move_delay = 1.0
	move_animation_speed = 0.6

func configure_level_2():
	"""Challenging AI - chain-aware with balanced offense/defense"""
	use_color_adjacency = true
	use_group_potential = true
	use_height_variance = true
	use_special_piece_strategy = true
	use_center_preference = true
	use_next_piece_lookahead = true
	use_chain_detection = true
	use_defensive_play = false
	
	# Increase strategic weights but KEEP height penalty reasonable
	weight_color_adjacency = 70.0
	weight_group_of_three = 400.0
	weight_group_of_two = 100.0
	weight_height_penalty = 12.0   # FIXED: Was 6.0, increased
	weight_height_variance = 20.0
	weight_center_preference = 8.0
	weight_random_variety = 2.0
	
	# Earlier danger detection
	danger_threshold_caution = 0.45
	danger_threshold_danger = 0.65
	danger_threshold_critical = 0.82
	
	move_delay = 0.75
	move_animation_speed = 0.3

func configure_level_3():
	"""Very Challenging AI - strategic but knows when to survive"""
	use_color_adjacency = true
	use_group_potential = true
	use_height_variance = true
	use_special_piece_strategy = true
	use_center_preference = true
	use_next_piece_lookahead = true
	use_chain_detection = true
	use_defensive_play = true
	
	# Maximum strategic weights BUT reasonable height penalty
	weight_color_adjacency = 80.0
	weight_group_of_three = 500.0
	weight_group_of_two = 120.0
	weight_height_penalty = 8.0    # FIXED: Was 1.0! Now reasonable
	weight_height_variance = 15.0
	weight_center_preference = 10.0
	weight_random_variety = 0.5
	
	# Very early danger detection
	danger_threshold_caution = 0.40
	danger_threshold_danger = 0.60
	danger_threshold_critical = 0.78
	
	move_delay = 0.2
	move_animation_speed = 0.05

# ============================================
# CORE AI LOGIC
# ============================================

func _process(delta):
	if not grid or not grid.current_piece_pair or not grid.is_grid_active():
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
	
	# Get current danger state
	var danger_state = get_danger_state()
	
	# Calculate base score
	var score = 0.0
	
	# === UNIVERSAL SURVIVAL FEATURES (always active) ===
	
	# 1. Spawn zone protection (rows 0-2)
	score += evaluate_spawn_zone_penalty(landing_positions)
	
	# 2. Critical height danger (exponential scaling)
	score += evaluate_critical_height_danger(landing_positions)
	
	# 3. Immediate clearing opportunity (bonus in danger states)
	score += evaluate_immediate_clearing_opportunity(landing_positions, pieces, danger_state)
	
	# 4. Base height penalty (always applies)
	score += evaluate_height_penalty(landing_positions)
	
	# === APPLY DANGER STATE MULTIPLIERS ===
	var danger_multiplier = get_danger_multiplier(danger_state)
	
	# If in CRITICAL state, massively boost survival and reduce strategy
	if danger_state == DangerState.CRITICAL:
		# Survival features already applied above with huge weights
		# Reduce strategic features to 10% of normal
		var strategy_reduction = 0.1
		weight_color_adjacency *= strategy_reduction
		weight_group_of_three *= strategy_reduction
		weight_group_of_two *= strategy_reduction
	
	# === STRATEGIC FEATURES (scaled by danger) ===
	
	# LEVEL 0+ FEATURES
	if use_color_adjacency:
		score += evaluate_color_adjacency(landing_positions, pieces) * (1.0 / danger_multiplier)
	
	if use_group_potential:
		score += evaluate_group_potential(landing_positions, pieces) * (1.0 / danger_multiplier)
	
	if use_special_piece_strategy:
		score += evaluate_special_pieces(landing_positions, pieces) * (1.0 / danger_multiplier)
		if use_defensive_play:
			score += evaluate_advanced_bomb_strategy(landing_positions, pieces) * (1.0 / danger_multiplier)
	
	if use_center_preference:
		score += evaluate_center_preference(landing_positions)
	
	if use_height_variance:
		score += evaluate_height_variance(landing_positions) * danger_multiplier
	
	# LEVEL 2+ FEATURES
	if use_next_piece_lookahead:
		score += evaluate_next_piece_lookahead(landing_positions, pieces) * (1.0 / danger_multiplier)
	
	if use_chain_detection:
		# Only pursue chains if not in danger
		if danger_state == DangerState.SAFE or danger_state == DangerState.CAUTION:
			score += evaluate_chain_potential(landing_positions, pieces)
		
		if use_defensive_play and (danger_state == DangerState.SAFE):
			score += evaluate_stair_pattern(landing_positions, pieces)
	
	# LEVEL 3+ FEATURES
	if use_defensive_play:
		score += evaluate_color_distribution(landing_positions, pieces) * (1.0 / danger_multiplier)
		score += evaluate_defensive_positioning(landing_positions, pieces) * danger_multiplier
	
	# Random variety factor (reduced in danger)
	score += randf() * weight_random_variety * (1.0 / danger_multiplier)
	
	# Restore original weights if we modified them
	if danger_state == DangerState.CRITICAL:
		configure_difficulty(ai_difficulty)  # Reset weights
	
	return score

# ============================================
# NEW SURVIVAL EVALUATION FUNCTIONS
# ============================================

func get_danger_state() -> DangerState:
	"""Determine current board danger level based on fullness"""
	var total_height = 0.0
	var max_height = 0
	
	for x in range(GameState.grid_width):
		var col_height = get_column_height(x)
		total_height += col_height
		if col_height > max_height:
			max_height = col_height
	
	var avg_height = total_height / float(GameState.grid_width)
	var board_fullness = avg_height / float(GameState.grid_height)
	
	# Check if any column is in spawn zone (critical danger)
	if max_height >= GameState.grid_height - GameState.playfield_start_row:
		return DangerState.CRITICAL
	
	# Use difficulty-specific thresholds
	if board_fullness >= danger_threshold_critical:
		return DangerState.CRITICAL
	elif board_fullness >= danger_threshold_danger:
		return DangerState.DANGER
	elif board_fullness >= danger_threshold_caution:
		return DangerState.CAUTION
	else:
		return DangerState.SAFE

func get_danger_multiplier(danger_state: DangerState) -> float:
	"""Get multiplier for danger-scaled features"""
	match danger_state:
		DangerState.SAFE:
			return 1.0
		DangerState.CAUTION:
			return 2.0
		DangerState.DANGER:
			return 5.0
		DangerState.CRITICAL:
			return 10.0
	return 1.0

func evaluate_spawn_zone_penalty(landing_positions: Array) -> float:
	"""Massive penalty for placing pieces in spawn zone (rows 0-2)"""
	var penalty = 0.0
	
	for pos in landing_positions:
		var row = int(pos.y)
		
		if row < GameState.playfield_start_row:
			# In spawn zone - massive penalty
			penalty -= weight_spawn_zone_penalty
		elif row < GameState.playfield_start_row + 3:
			# Just below spawn zone - significant penalty scaled by proximity
			var proximity = GameState.playfield_start_row + 3 - row
			penalty -= weight_spawn_zone_penalty * 0.3 * proximity
	
	return penalty

func evaluate_critical_height_danger(landing_positions: Array) -> float:
	"""Exponential penalty for pieces approaching game over"""
	var penalty = 0.0
	
	for pos in landing_positions:
		var height_from_top = int(pos.y)
		var distance_from_spawn = height_from_top - GameState.playfield_start_row
		
		# Only penalize if getting close to spawn zone
		if distance_from_spawn < 6:
			# Exponential scaling: closer to spawn = much worse
			var danger_ratio = 1.0 - (float(distance_from_spawn) / 6.0)
			var exponential_penalty = pow(danger_ratio, 3) * weight_critical_height
			penalty -= exponential_penalty
	
	return penalty

func evaluate_immediate_clearing_opportunity(landing_positions: Array, pieces: Array, danger_state: DangerState) -> float:
	"""Bonus for placements that would immediately trigger a match"""
	var bonus = 0.0
	
	# In danger states, prioritize immediate clearing
	var danger_bonus_multiplier = 1.0
	match danger_state:
		DangerState.CAUTION:
			danger_bonus_multiplier = 1.5
		DangerState.DANGER:
			danger_bonus_multiplier = 3.0
		DangerState.CRITICAL:
			danger_bonus_multiplier = 5.0
		_:
			danger_bonus_multiplier = 1.0
	
	# Check if placing these pieces would complete a match
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		# Skip bombs and bubbles
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var color = piece.color
		
		# Count connected same-color pieces including this placement
		var group_size = count_connected_group(pos, color, landing_positions, pieces)
		
		# Immediate match (4+) gets big bonus, scaled by danger
		if group_size >= 4:
			bonus += weight_immediate_clear_bonus * danger_bonus_multiplier
			
			# Extra bonus if this would clear multiple groups
			if group_size >= 6:
				bonus += weight_immediate_clear_bonus * 0.5 * danger_bonus_multiplier

	return bonus

# ============================================
# EXISTING EVALUATION FUNCTIONS (kept for compatibility)
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
	
func evaluate_chain_potential(landing_positions: Array, pieces: Array) -> float:
	"""Evaluate if this placement could trigger a chain reaction"""
	if not use_chain_detection:
		return 0.0
	
	var score = 0.0
	
	# For each piece we're placing
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		# Skip bombs and bubbles
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var color = piece.color
		
		# Check if placing this piece completes a match
		var match_size = count_connected_group(pos, color, landing_positions, pieces)
		
		if match_size >= 4:
			# Now check if clearing this match would cause pieces above to fall
			# and create another match (chain detection)
			var chain_potential = detect_chain_after_clear(pos, color, landing_positions, pieces)
			
			if chain_potential > 0:
				score += 500.0 * chain_potential  # HUGE bonus for chain setups
	
	return score

func detect_chain_after_clear(clear_pos: Vector2, clear_color: Color, landing_positions: Array, pieces: Array) -> int:
	"""Detect if clearing a match at this position would cause a chain"""
	var chain_count = 0
	
	# Get all positions that would be cleared
	var positions_to_clear = get_positions_in_match(clear_pos, clear_color, landing_positions, pieces)
	
	# Check positions above the cleared area
	for clear_position in positions_to_clear:
		# Look at pieces above this cleared position
		for check_y in range(int(clear_position.y) - 1, -1, -1):
			var check_pos = Vector2(clear_position.x, check_y)
			var piece_above = get_piece_at_position(check_pos, landing_positions, pieces)
			
			if piece_above and not piece_above.is_bomb and not piece_above.is_bubble:
				# Simulate this piece falling down
				var fall_to_y = find_fall_position_after_clear(check_pos, positions_to_clear)
				var fallen_pos = Vector2(check_pos.x, fall_to_y)
				
				# Check if this fallen piece would form a new match
				var new_match_size = count_connected_group_after_fall(fallen_pos, piece_above.color, positions_to_clear, landing_positions, pieces)
				
				if new_match_size >= 4:
					chain_count += 1
					break
	
	return min(chain_count, 2)  # Cap detection at 2-chains for performance

func get_positions_in_match(start_pos: Vector2, color: Color, landing_positions: Array, pieces: Array) -> Array:
	"""Get all positions that are part of a match group"""
	var positions = []
	var visited = {}
	var stack = [start_pos]
	
	while stack.size() > 0:
		var pos = stack.pop_back()
		
		if visited.has(pos):
			continue
		
		if pos.x < 0 or pos.x >= GameState.grid_width or pos.y < 0 or pos.y >= GameState.grid_height:
			continue
		
		var piece_here = get_piece_at_position(pos, landing_positions, pieces)
		if not piece_here or piece_here.is_bomb or piece_here.is_bubble:
			continue
		if piece_here.color != color:
			continue
		
		visited[pos] = true
		positions.append(pos)
		
		# Add adjacent positions
		stack.append(Vector2(pos.x + 1, pos.y))
		stack.append(Vector2(pos.x - 1, pos.y))
		stack.append(Vector2(pos.x, pos.y + 1))
		stack.append(Vector2(pos.x, pos.y - 1))
	
	return positions

func find_fall_position_after_clear(pos: Vector2, cleared_positions: Array) -> int:
	"""Find where a piece would fall after certain positions are cleared"""
	var fall_y = int(pos.y)
	
	# Move down until we hit something that isn't being cleared
	while fall_y + 1 < GameState.grid_height:
		var check_pos = Vector2(pos.x, fall_y + 1)
		
		# Check if this position is being cleared
		var is_cleared = false
		for cleared in cleared_positions:
			if cleared == check_pos:
				is_cleared = true
				break
		
		if is_cleared:
			fall_y += 1
			continue
		
		# Check if there's a piece here
		if grid.grid_data[fall_y + 1][int(pos.x)] != null:
			break
		
		fall_y += 1
	
	return fall_y

func count_connected_group_after_fall(fallen_pos: Vector2, color: Color, cleared_positions: Array, landing_positions: Array, pieces: Array) -> int:
	"""Count connected group size after pieces have fallen"""
	var visited = {}
	var stack = [fallen_pos]
	var count = 0
	
	while stack.size() > 0:
		var pos = stack.pop_back()
		
		if visited.has(pos):
			continue
		
		if pos.x < 0 or pos.x >= GameState.grid_width or pos.y < 0 or pos.y >= GameState.grid_height:
			continue
		
		# Skip if this position was cleared
		var is_cleared = false
		for cleared in cleared_positions:
			if cleared == pos:
				is_cleared = true
				break
		if is_cleared:
			continue
		
		var piece_here = get_piece_at_position(pos, landing_positions, pieces)
		if not piece_here or piece_here.is_bomb or piece_here.is_bubble:
			continue
		if piece_here.color != color:
			continue
		
		visited[pos] = true
		count += 1
		
		stack.append(Vector2(pos.x + 1, pos.y))
		stack.append(Vector2(pos.x - 1, pos.y))
		stack.append(Vector2(pos.x, pos.y + 1))
		stack.append(Vector2(pos.x, pos.y - 1))
	
	return count

func evaluate_next_piece_lookahead(landing_positions: Array, pieces: Array) -> float:
	"""Evaluate how well this placement sets up for the next piece"""
	if not use_next_piece_lookahead:
		return 0.0
	
	var score = 0.0
	
	# Get the next piece from the grid
	if not grid.next_piece_pair:
		return 0.0
	
	var next_pieces = grid.next_piece_pair.get_pieces()
	
	# For each piece we're placing now
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var current_color = piece.color
		
		# Check if next pieces match this color
		for next_piece in next_pieces:
			if next_piece.is_bomb or next_piece.is_bubble:
				continue
			
			if next_piece.color == current_color:
				# Good! Next piece can connect with this one
				score += 30.0
				
				# Even better if we're building a group
				var group_size = count_connected_group(pos, current_color, landing_positions, pieces)
				if group_size == 2:
					score += 50.0  # Next piece could complete a trio
				elif group_size == 3:
					score += 100.0  # Next piece could trigger a match!
	
	return score

func evaluate_color_distribution(landing_positions: Array, pieces: Array) -> float:
	"""Analyze color distribution on board and prioritize abundant colors"""
	if not use_defensive_play:
		return 0.0
	
	var score = 0.0
	
	# Count colors on the board
	var color_counts = {}
	var total_pieces = 0
	
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid.grid_data[y][x]
			if piece and not piece.is_bomb and not piece.is_bubble:
				var color_key = str(piece.color)
				if not color_counts.has(color_key):
					color_counts[color_key] = 0
				color_counts[color_key] += 1
				total_pieces += 1
	
	# If board is mostly empty, no strong preference
	if total_pieces < 10:
		return 0.0
	
	# For each piece we're placing
	for i in range(landing_positions.size()):
		var piece = pieces[i]
		
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var color_key = str(piece.color)
		var count = color_counts.get(color_key, 0)
		
		# Bonus for matching abundant colors (easier to make matches)
		if count > total_pieces * 0.25:  # If color is >25% of board
			score += 40.0
		elif count > total_pieces * 0.15:  # If color is >15% of board
			score += 20.0
	
	return score

func evaluate_stair_pattern(landing_positions: Array, pieces: Array) -> float:
	"""Detect and reward building stair-step chain patterns"""
	if not use_chain_detection:
		return 0.0
	
	var score = 0.0
	
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var color = piece.color
		var stair_potential = 0
		
		# Check left column
		if pos.x > 0:
			for check_y in range(GameState.grid_height):
				if grid.grid_data[check_y][int(pos.x) - 1] != null:
					var left_piece = grid.grid_data[check_y][int(pos.x) - 1]
					if not left_piece.is_bomb and not left_piece.is_bubble:
						if left_piece.color == color:
							var left_height = GameState.grid_height - check_y
							var current_height = GameState.grid_height - int(pos.y)
							var height_diff = abs(left_height - current_height)
							
							if height_diff >= 1 and height_diff <= 2:
								stair_potential += 1
		
		# Check right column
		if pos.x < GameState.grid_width - 1:
			for check_y in range(GameState.grid_height):
				if grid.grid_data[check_y][int(pos.x) + 1] != null:
					var right_piece = grid.grid_data[check_y][int(pos.x) + 1]
					if not right_piece.is_bomb and not right_piece.is_bubble:
						if right_piece.color == color:
							var right_height = GameState.grid_height - check_y
							var current_height = GameState.grid_height - int(pos.y)
							var height_diff = abs(right_height - current_height)
							
							if height_diff >= 1 and height_diff <= 2:
								stair_potential += 1
		
		if stair_potential > 0:
			score += stair_potential * 80.0
	
	return score

func evaluate_defensive_positioning(landing_positions: Array, pieces: Array) -> float:
	"""Penalize placements that create dangerous board states"""
	if not use_defensive_play:
		return 0.0
	
	var score = 0.0
	
	# Get average board height
	var total_height = 0
	var max_height = 0
	
	for x in range(GameState.grid_width):
		var height = get_column_height(x)
		total_height += height
		if height > max_height:
			max_height = height
	
	var avg_height = total_height / float(GameState.grid_width)
	
	# If board is getting dangerous (>60% full), play more defensively
	if avg_height > GameState.grid_height * 0.6:
		# Strongly penalize any placement that goes high
		for pos in landing_positions:
			var placement_height = GameState.grid_height - int(pos.y)
			if placement_height > GameState.grid_height * 0.7:
				score -= 150.0
	
	# Penalize if this creates an isolated high column
	for pos in landing_positions:
		var col = int(pos.x)
		var new_height = GameState.grid_height - int(pos.y)
		
		# Check neighboring columns
		var left_height = get_column_height(col - 1) if col > 0 else new_height
		var right_height = get_column_height(col + 1) if col < GameState.grid_width - 1 else new_height
		
		# If this creates a spike (>4 rows taller than neighbors)
		if new_height > left_height + 4 or new_height > right_height + 4:
			score -= 100.0
	
	return score

func evaluate_advanced_bomb_strategy(landing_positions: Array, pieces: Array) -> float:
	"""Smarter bomb placement considering board state"""
	var score = 0.0
	
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		if not piece.is_bomb:
			continue
		
		# Count colors on board to find most abundant
		var color_counts = {}
		for y in range(GameState.grid_height):
			for x in range(GameState.grid_width):
				var grid_piece = grid.grid_data[y][x]
				if grid_piece and not grid_piece.is_bomb and not grid_piece.is_bubble:
					var color_key = str(grid_piece.color)
					if not color_counts.has(color_key):
						color_counts[color_key] = 0
					color_counts[color_key] += 1
		
		# Find most common color
		var max_count = 0
		for color_key in color_counts.keys():
			if color_counts[color_key] > max_count:
				max_count = color_counts[color_key]
		
		# Prefer placing bomb adjacent to most common color
		var adjacent_positions = [
			Vector2(pos.x + 1, pos.y),
			Vector2(pos.x - 1, pos.y),
			Vector2(pos.x, pos.y - 1),
			Vector2(pos.x, pos.y + 1)
		]
		
		for adj_pos in adjacent_positions:
			if adj_pos.x < 0 or adj_pos.x >= GameState.grid_width:
				continue
			if adj_pos.y < 0 or adj_pos.y >= GameState.grid_height:
				continue
			
			var adj_piece = grid.grid_data[int(adj_pos.y)][int(adj_pos.x)]
			if adj_piece and not adj_piece.is_bomb and not adj_piece.is_bubble:
				var adj_color_key = str(adj_piece.color)
				var adj_color_count = color_counts.get(adj_color_key, 0)
				
				# Big bonus if next to abundant color
				if adj_color_count >= max_count * 0.8:
					score += 100.0
				
				# Also consider if this color has nearby clusters
				var cluster_size = count_nearby_same_color(adj_pos, adj_piece.color)
				score += cluster_size * 20.0
	
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
	if column < 0 or column >= GameState.grid_width:
		return 0
	
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
		if not grid or not grid.current_piece_pair:
			return
		grid.rotate_piece()
		await get_tree().create_timer(move_animation_speed, false).timeout
	
	# Move to target column
	if not grid or not grid.current_piece_pair:
		return
	var current_column = int(grid.current_piece_pair.grid_position.x)
	var columns_to_move = target_column - current_column
	
	if columns_to_move > 0:
		for i in range(columns_to_move):
			if not grid or not grid.current_piece_pair:
				return
			grid.move_piece_horizontal(1)
			await get_tree().create_timer(move_animation_speed, false).timeout
	elif columns_to_move < 0:
		for i in range(abs(columns_to_move)):
			if not grid or not grid.current_piece_pair:
				return
			grid.move_piece_horizontal(-1)
			await get_tree().create_timer(move_animation_speed, false).timeout
	
	# Fast drop
	await get_tree().create_timer(0.2, false).timeout
	if not grid or not grid.current_piece_pair:
		return
	grid.fast_drop_piece()
	
	# Reset decision flag for next piece
	decision_made = false

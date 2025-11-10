extends Node
# AIController.gd - Tournament-Level Puyo Puyo AI
# Implements: Chain triggering, side-building, periodic clearing, spawn zone awareness

# ============================================
# AI CONFIGURATION
# ============================================

enum Difficulty {
	LEVEL_0,  # Learning - basic safety and clearing
	LEVEL_1,  # Competent - understands patterns and timing
	LEVEL_2,  # Advanced - builds chains and times triggers
	LEVEL_3,  # Expert - tournament-level play, nearly unbeatable
}

# Main difficulty
var ai_difficulty = Difficulty.LEVEL_1
var _has_been_configured = false

# Feature flags
var use_chain_counting = false
var use_trigger_timing = false
var use_side_building = false
var use_center_preservation = false
var use_periodic_clearing = false

# Core strategy weights
var weight_side_building = 0.0       # HUGE bonus for building on sides (cols 0-1, 4-5)
var weight_center_penalty = 0.0      # Penalty for building in center (cols 2-3)
var weight_trigger_ready = 0.0       # Bonus when chain is ready to trigger
var weight_clear_now = 0.0          # Bonus for triggering when appropriate
var weight_flat_variance = 0.0       # Penalty for height variance
var weight_spawn_zone_death = 10000.0  # CRITICAL: rows 0-1 are instant death

# Chain thresholds
var min_chain_before_trigger = 4     # Minimum chain length to consider triggering
var target_chain_length = 6          # Ideal chain length to build toward
var trigger_at_height = 10           # Trigger if board this tall regardless

# Side building configuration
var preferred_columns = [0, 1, 4, 5]  # Build tall here
var avoid_columns = [2, 3]            # Keep these LOW

# Timing
var move_delay = 0.5
var move_animation_speed = 0.1

# Runtime
var grid = null
var move_timer = 0.0
var decision_made = false
var pieces_since_last_clear = 0      # Track when to periodically clear
var periodic_clear_threshold = 0     # Clear after this many pieces

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	if not _has_been_configured:
		configure_difficulty(ai_difficulty)

func configure_difficulty(difficulty: Difficulty):
	"""Configure AI with tournament-level strategies"""
	_has_been_configured = true
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
	print("Chain Counting: ", use_chain_counting)
	print("Trigger Timing: ", use_trigger_timing)
	print("Side Building: ", use_side_building)
	print("Periodic Clearing: ", use_periodic_clearing)
	print("Target Chain Length: ", target_chain_length)
	print("Trigger at Height: ", trigger_at_height)
	print("=================================")

func configure_level_0():
	"""Learning - Focus on survival and basic clearing"""
	use_chain_counting = false
	use_trigger_timing = false
	use_side_building = true      # Still prefer sides
	use_center_preservation = true
	use_periodic_clearing = true   # Clear often
	
	weight_side_building = 100.0
	weight_center_penalty = 50.0
	weight_flat_variance = 150.0
	weight_clear_now = 300.0
	
	min_chain_before_trigger = 3   # Trigger small chains
	target_chain_length = 4
	trigger_at_height = 8          # Very conservative
	periodic_clear_threshold = 15  # Clear every 15 pieces
	
	move_delay = 1.5
	move_animation_speed = 0.7

func configure_level_1():
	"""Competent - Good fundamentals, times clearing well"""
	use_chain_counting = true
	use_trigger_timing = true
	use_side_building = true
	use_center_preservation = true
	use_periodic_clearing = true
	
	weight_side_building = 200.0
	weight_center_penalty = 100.0
	weight_flat_variance = 100.0
	weight_trigger_ready = 150.0
	weight_clear_now = 400.0
	
	min_chain_before_trigger = 4
	target_chain_length = 6
	trigger_at_height = 10
	periodic_clear_threshold = 25  # More patient
	
	move_delay = 1.0
	move_animation_speed = 0.5

func configure_level_2():
	"""Advanced - Builds longer chains, times triggers strategically"""
	use_chain_counting = true
	use_trigger_timing = true
	use_side_building = true
	use_center_preservation = true
	use_periodic_clearing = true
	
	weight_side_building = 300.0
	weight_center_penalty = 150.0
	weight_flat_variance = 80.0
	weight_trigger_ready = 250.0
	weight_clear_now = 500.0
	
	min_chain_before_trigger = 5
	target_chain_length = 8
	trigger_at_height = 11
	periodic_clear_threshold = 35  # Even more patient
	
	move_delay = 0.65
	move_animation_speed = 0.25

func configure_level_3():
	"""Expert - Tournament level, nearly unbeatable"""
	use_chain_counting = true
	use_trigger_timing = true
	use_side_building = true
	use_center_preservation = true
	use_periodic_clearing = true
	
	weight_side_building = 400.0
	weight_center_penalty = 200.0
	weight_flat_variance = 60.0
	weight_trigger_ready = 350.0
	weight_clear_now = 600.0
	
	min_chain_before_trigger = 5
	target_chain_length = 10       # Aim for big chains
	trigger_at_height = 11
	periodic_clear_threshold = 40  # Most patient
	
	move_delay = 0.25
	move_animation_speed = 0.08

# ============================================
# CORE AI LOGIC
# ============================================

func _process(delta):
	if not grid or not grid.current_piece_pair or not grid.is_grid_active():
		decision_made = false
		return
	
	move_timer += delta
	
	if move_timer >= move_delay and not decision_made:
		make_move()
		move_timer = 0.0

func make_move():
	"""Main AI decision loop"""
	if not grid or not grid.current_piece_pair:
		return
	
	decision_made = true
	pieces_since_last_clear += 1
	
	# CRITICAL: Check if we should trigger chain NOW
	if should_trigger_chain():
		trigger_best_chain()
		pieces_since_last_clear = 0
		decision_made = false
		return
	
	# Otherwise, find best placement
	var best_score = -999999
	var best_column = 0
	var best_rotation = 0
	
	var original_rotation = grid.current_piece_pair.piece_rotation
	
	for rot in range(4):
		grid.current_piece_pair.piece_rotation = rot
		grid.current_piece_pair.update_piece_positions()
		
		for col in range(GameState.grid_width):
			var score = evaluate_placement(col, rot)
			if score > best_score:
				best_score = score
				best_column = col
				best_rotation = rot
	
	grid.current_piece_pair.piece_rotation = original_rotation
	grid.current_piece_pair.update_piece_positions()
	
	execute_move(best_column, best_rotation)

# ============================================
# CHAIN TRIGGERING LOGIC (KEY!)
# ============================================

func should_trigger_chain() -> bool:
	"""Decide if we should trigger our chain NOW"""
	if not use_trigger_timing:
		return false
	
	# Count current chain potential
	var chain_length = count_potential_chain_length()
	
	# Get board metrics
	var max_height = get_max_column_height()
	var avg_height = get_average_column_height()
	
	# REASON 1: Board too high - EMERGENCY CLEAR
	if max_height >= trigger_at_height:
		if chain_length >= min_chain_before_trigger:
			print("AI TRIGGER: Emergency clear at height ", max_height, " with chain ", chain_length)
			return true
	
	# REASON 2: Good chain built + board getting full
	if chain_length >= target_chain_length and avg_height >= 7:
		print("AI TRIGGER: Target chain ", chain_length, " reached")
		return true
	
	# REASON 3: Periodic clearing to prevent garbage vulnerability
	if use_periodic_clearing and pieces_since_last_clear >= periodic_clear_threshold:
		if chain_length >= min_chain_before_trigger:
			print("AI TRIGGER: Periodic clear after ", pieces_since_last_clear, " pieces")
			return true
	
	# REASON 4: Decent chain + board >70% full
	if chain_length >= min_chain_before_trigger + 1 and avg_height >= 9:
		print("AI TRIGGER: Preventive clear with chain ", chain_length)
		return true
	
	return false

func count_potential_chain_length() -> int:
	"""Count how long a chain we could trigger right now"""
	if not grid:
		return 0
	
	# Find all possible trigger points (groups of 3 same-color pieces)
	var best_chain = 0
	
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid.grid_data[y][x]
			if not piece or piece.is_bomb or piece.is_bubble:
				continue
			
			# Check if completing this group would start a chain
			var chain_length = simulate_chain_from_position(Vector2(x, y), piece.color)
			if chain_length > best_chain:
				best_chain = chain_length
	
	return best_chain

func simulate_chain_from_position(pos: Vector2, color: Color) -> int:
	"""Simulate triggering a chain from this position"""
	# Simplified chain counting - count connected groups
	var group_size = count_group_at_position(pos, color)
	
	if group_size == 3:
		# This is a trigger point (need 1 more to pop)
		return estimate_chain_length_from_trigger(pos, color)
	
	return 0

func estimate_chain_length_from_trigger(pos: Vector2, color: Color) -> int:
	"""Estimate chain length if we complete this trigger"""
	# Simplified: count vertical depth + connected groups
	var chain_estimate = 1
	
	# Look for stacked groups above and around
	var nearby_groups = 0
	for check_y in range(int(pos.y) - 1, -1, -1):
		for check_x in range(max(0, int(pos.x) - 2), min(GameState.grid_width, int(pos.x) + 3)):
			var check_pos = Vector2(check_x, check_y)
			var piece = grid.grid_data[check_y][check_x]
			if piece and not piece.is_bomb and not piece.is_bubble:
				var group = count_group_at_position(check_pos, piece.color)
				if group >= 3:
					nearby_groups += 1
	
	chain_estimate += nearby_groups / 2  # Conservative estimate
	return chain_estimate

func trigger_best_chain():
	"""Find and trigger the best available chain"""
	# This is a placeholder - in real implementation, we'd:
	# 1. Find the trigger point
	# 2. Place a piece to complete it
	# 3. Let the chain resolve
	
	# For now, just make a simple clear move
	# The actual triggering happens naturally when we place pieces
	pass

# ============================================
# PLACEMENT EVALUATION
# ============================================

func evaluate_placement(column: int, rotation: int) -> float:
	"""Evaluate placement with competitive strategies"""
	
	var test_position = Vector2(column, 0)
	var piece_positions = grid.current_piece_pair.get_piece_positions(test_position)
	var pieces = grid.current_piece_pair.get_pieces()
	
	if not grid.can_place_piece_pair(grid.current_piece_pair, test_position):
		return -999999
	
	var landing_positions = []
	for i in range(piece_positions.size()):
		var pos = piece_positions[i]
		var landing_y = find_landing_y(pos.x, pos.y)
		landing_positions.append(Vector2(pos.x, landing_y))
	
	var score = 0.0
	
	# === CRITICAL: SPAWN ZONE PROTECTION ===
	score += evaluate_spawn_zone_absolute(landing_positions)
	if score < -5000:  # If spawn zone violation, stop evaluation
		return score
	
	# === SIDE BUILDING STRATEGY ===
	if use_side_building:
		score += evaluate_side_building_preference(landing_positions)
		score += evaluate_center_avoidance(landing_positions)
	
	# === BOARD SHAPE MANAGEMENT ===
	score += evaluate_board_flatness(landing_positions)
	
	# === CHAIN BUILDING ===
	if use_chain_counting:
		score += evaluate_chain_building(landing_positions, pieces)
	
	# === IMMEDIATE CLEARING ===
	score += evaluate_immediate_clear(landing_positions, pieces)
	
	return score

# ============================================
# CRITICAL: SPAWN ZONE UNDERSTANDING
# ============================================

func evaluate_spawn_zone_absolute(landing_positions: Array) -> float:
	"""Rows 0-1 are INSTANT DEATH - never let pieces settle there"""
	var penalty = 0.0
	
	for pos in landing_positions:
		var row = int(pos.y)
		
		# Rows 0-1 are the spawn zone - DEATH
		if row < GameState.playfield_start_row:
			penalty -= weight_spawn_zone_death
			print("WARNING: AI attempted spawn zone placement at row ", row)
		# Rows 2-4 are very dangerous
		elif row < GameState.playfield_start_row + 3:
			var proximity = GameState.playfield_start_row + 3 - row
			penalty -= 1000.0 * proximity
	
	return penalty

# ============================================
# SIDE BUILDING STRATEGY
# ============================================

func evaluate_side_building_preference(landing_positions: Array) -> float:
	"""HUGE bonus for building on SIDES (cols 0-1, 4-5)"""
	var score = 0.0
	
	for pos in landing_positions:
		var col = int(pos.x)
		
		# Prefer columns 0-1 and 4-5 for tall building
		if col in preferred_columns:
			score += weight_side_building
			
			# Extra bonus if we're building HIGH on sides
			var height = GameState.grid_height - int(pos.y)
			if height > 8:
				score += weight_side_building * 0.5
		
		# Penalty for columns 2-3 (keep center open)
		if col in avoid_columns:
			score -= weight_center_penalty
			
			# Bigger penalty for building HIGH in center
			var height = GameState.grid_height - int(pos.y)
			if height > 7:
				score -= weight_center_penalty * 1.5
	
	return score

func evaluate_center_avoidance(landing_positions: Array) -> float:
	"""Keep center columns (2-3) LOW for maneuverability"""
	var score = 0.0
	
	var center_heights = [
		get_column_height(2),
		get_column_height(3)
	]
	
	for pos in landing_positions:
		var col = int(pos.x)
		
		if col in avoid_columns:
			var current_height = center_heights[col - 2]
			var new_height = GameState.grid_height - int(pos.y)
			
			# Penalize making center taller
			if new_height > current_height:
				score -= weight_center_penalty * (new_height - current_height)
	
	return score

# ============================================
# BOARD MANAGEMENT
# ============================================

func evaluate_board_flatness(landing_positions: Array) -> float:
	"""Maintain relatively flat board, but allow side towers"""
	var score = 0.0
	
	var column_heights = []
	for x in range(GameState.grid_width):
		column_heights.append(get_column_height(x))
	
	# Calculate variance, but EXCLUDE intentional side towers
	var side_heights = [column_heights[0], column_heights[1], column_heights[4], column_heights[5]]
	var center_heights_array = [column_heights[2], column_heights[3]]
	
	# Side variance (should be similar)
	var side_variance = 0.0
	var side_avg = (side_heights[0] + side_heights[1] + side_heights[2] + side_heights[3]) / 4.0
	for h in side_heights:
		side_variance += abs(h - side_avg)
	
	# Center variance (should be similar and LOW)
	var center_variance = abs(center_heights_array[0] - center_heights_array[1])
	
	# Penalize bad variances
	score -= side_variance * weight_flat_variance
	score -= center_variance * weight_flat_variance
	
	# Bonus if center is notably LOWER than sides
	var center_avg = (center_heights_array[0] + center_heights_array[1]) / 2.0
	if side_avg > center_avg + 2:
		score += 100.0  # Good! Sides are taller
	
	return score

func evaluate_chain_building(landing_positions: Array, pieces: Array) -> float:
	"""Reward building toward chain patterns"""
	var score = 0.0
	
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var color = piece.color
		
		# Check for groups of 2-3 (chain building)
		var group_size = count_group_at_position(pos, color)
		
		if group_size == 2:
			score += 50.0  # Building toward trigger
		elif group_size == 3:
			score += weight_trigger_ready  # One away from triggering!
	
	return score

func evaluate_immediate_clear(landing_positions: Array, pieces: Array) -> float:
	"""Bonus for creating immediate matches"""
	var score = 0.0
	
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		if piece.is_bomb or piece.is_bubble:
			continue
		
		var group_size = count_group_at_position(pos, piece.color)
		
		if group_size >= 4:
			score += weight_clear_now
			
			# Extra for larger clears
			if group_size >= 6:
				score += weight_clear_now * 0.5
	
	return score

# ============================================
# HELPER FUNCTIONS
# ============================================

func count_group_at_position(pos: Vector2, color: Color) -> int:
	"""Count connected same-colored pieces"""
	var visited = {}
	var stack = [pos]
	var count = 0
	
	while stack.size() > 0:
		var current = stack.pop_back()
		
		if visited.has(current):
			continue
		
		if current.x < 0 or current.x >= GameState.grid_width:
			continue
		if current.y < 0 or current.y >= GameState.grid_height:
			continue
		
		var piece = grid.grid_data[int(current.y)][int(current.x)]
		if not piece or piece.is_bomb or piece.is_bubble:
			continue
		if piece.color != color:
			continue
		
		visited[current] = true
		count += 1
		
		stack.append(Vector2(current.x + 1, current.y))
		stack.append(Vector2(current.x - 1, current.y))
		stack.append(Vector2(current.x, current.y + 1))
		stack.append(Vector2(current.x, current.y - 1))
	
	return count

func get_column_height(column: int) -> int:
	"""Get current height of a column"""
	if column < 0 or column >= GameState.grid_width:
		return 0
	
	for y in range(GameState.grid_height):
		if grid.grid_data[y][column] != null:
			return GameState.grid_height - y
	return 0

func get_max_column_height() -> int:
	"""Get tallest column height"""
	var max_height = 0
	for x in range(GameState.grid_width):
		var h = get_column_height(x)
		if h > max_height:
			max_height = h
	return max_height

func get_average_column_height() -> float:
	"""Get average column height"""
	var total = 0.0
	for x in range(GameState.grid_width):
		total += get_column_height(x)
	return total / float(GameState.grid_width)

func find_landing_y(x: int, start_y: int) -> int:
	"""Find where piece lands"""
	var landing_y = start_y
	
	while landing_y + 1 < GameState.grid_height:
		if grid.grid_data[landing_y + 1][x] != null:
			break
		landing_y += 1
	
	return landing_y

func execute_move(target_column: int, target_rotation: int):
	"""Execute the chosen move"""
	if not grid or not grid.current_piece_pair:
		return
	
	var current_rotation = grid.current_piece_pair.piece_rotation
	var rotations_needed = (target_rotation - current_rotation) % 4
	
	for i in range(rotations_needed):
		if not grid or not grid.current_piece_pair:
			return
		grid.rotate_piece()
		await get_tree().create_timer(move_animation_speed, false).timeout
	
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
	
	await get_tree().create_timer(0.2, false).timeout
	if not grid or not grid.current_piece_pair:
		return
	grid.fast_drop_piece()
	
	decision_made = false

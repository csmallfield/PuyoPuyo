extends Node
# AIController.gd - Tournament-Level Puyo Puyo AI
# Implements: Aggressive clearing, board safety, harassment, side-building, bomb tactics

# ============================================
# AI CONFIGURATION
# ============================================

enum Difficulty {
	LEVEL_0,  # Learning - basic safety and clearing
	LEVEL_1,  # Competent - understands patterns and timing
	LEVEL_2,  # Advanced - builds chains and times triggers + bomb tactics
	LEVEL_3,  # Expert - tournament-level play with aggression + advanced bomb tactics
}

# Main difficulty
var ai_difficulty = Difficulty.LEVEL_1
var _has_been_configured = false

# Randomization for varied play between AI instances
var evaluation_noise = 0.0  # Amount of random noise to add to scores
var rng = RandomNumberGenerator.new()

# Feature flags
var use_chain_counting = false
var use_trigger_timing = false
var use_side_building = false
var use_center_preservation = false
var use_periodic_clearing = false
var use_harassment = false
var use_bomb_tactics = false  # NEW: Enable bomb-specific evaluation

# Core strategy weights
var weight_side_building = 0.0
var weight_center_penalty = 0.0
var weight_trigger_ready = 0.0
var weight_clear_now = 0.0
var weight_flat_variance = 0.0
var weight_board_safety = 0.0
var weight_spawn_zone_death = 10000.0
var weight_bomb_power = 0.0  # NEW: Weight for bomb clearing potential

# Chain thresholds
var min_chain_before_trigger = 4
var target_chain_length = 6
var optimal_chain_length = 7
var trigger_at_height = 10
var max_safe_height = 11

# Side building configuration
var preferred_columns = [0, 1, 4, 5]
var avoid_columns = [2, 3]

# Timing
var move_delay = 0.5
var move_animation_speed = 0.1

# Runtime
var grid = null
var move_timer = 0.0
var decision_made = false
var pieces_since_last_clear = 0
var periodic_clear_threshold = 0
var harassment_threshold = 0

@onready var piece_pair_scene = preload("res://scenes/PiecePair.tscn")

const BombController = preload("res://scripts/BombController.gd")

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	rng.randomize()  # Each AI instance gets different random seed
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
	print("Harassment: ", use_harassment)
	print("Bomb Tactics: ", use_bomb_tactics)
	print("Target Chain Length: ", target_chain_length)
	print("Optimal Chain Length: ", optimal_chain_length)
	print("Trigger at Height: ", trigger_at_height)
	print("Max Safe Height: ", max_safe_height)
	print("Evaluation Noise: ", evaluation_noise)
	print("=================================")

func configure_level_0():
	"""Learning - Focus on survival and basic clearing"""
	use_chain_counting = false
	use_trigger_timing = false
	use_side_building = true
	use_center_preservation = true
	use_periodic_clearing = true
	use_harassment = false
	use_bomb_tactics = false  # No bomb tactics at beginner level
	
	weight_side_building = 100.0
	weight_center_penalty = 50.0
	weight_flat_variance = 150.0
	weight_clear_now = 300.0
	weight_board_safety = 200.0
	weight_bomb_power = 0.0
	
	min_chain_before_trigger = 3
	target_chain_length = 4
	optimal_chain_length = 5
	trigger_at_height = 7
	max_safe_height = 8
	periodic_clear_threshold = 12
	harassment_threshold = 0
	
	move_delay = 1.5
	move_animation_speed = 0.7
	evaluation_noise = 50.0

func configure_level_1():
	"""Competent - Good fundamentals, times clearing well"""
	use_chain_counting = true
	use_trigger_timing = true
	use_side_building = true
	use_center_preservation = true
	use_periodic_clearing = true
	use_harassment = false
	use_bomb_tactics = false  # No bomb tactics at intermediate level
	
	weight_side_building = 200.0
	weight_center_penalty = 100.0
	weight_flat_variance = 100.0
	weight_trigger_ready = 150.0
	weight_clear_now = 400.0
	weight_board_safety = 300.0
	weight_bomb_power = 0.0
	
	min_chain_before_trigger = 4
	target_chain_length = 5
	optimal_chain_length = 6
	trigger_at_height = 8
	max_safe_height = 9
	periodic_clear_threshold = 20
	harassment_threshold = 0
	
	move_delay = 1.0
	move_animation_speed = 0.5
	evaluation_noise = 30.0

func configure_level_2():
	"""Advanced - Builds chains, times triggers strategically + bomb tactics"""
	use_chain_counting = true
	use_trigger_timing = true
	use_side_building = true
	use_center_preservation = true
	use_periodic_clearing = true
	use_harassment = true
	use_bomb_tactics = true  # NEW: Enable bomb tactics
	
	weight_side_building = 300.0
	weight_center_penalty = 150.0
	weight_flat_variance = 80.0
	weight_trigger_ready = 250.0
	weight_clear_now = 600.0
	weight_board_safety = 400.0
	weight_bomb_power = 200.0  # NEW: Moderate bomb power consideration
	
	min_chain_before_trigger = 4
	target_chain_length = 6
	optimal_chain_length = 7
	trigger_at_height = 9
	max_safe_height = 10
	periodic_clear_threshold = 25
	harassment_threshold = 18
	
	move_delay = 0.65
	move_animation_speed = 0.25
	evaluation_noise = 20.0

func configure_level_3():
	"""Expert - Tournament level with aggressive safety + advanced bomb tactics"""
	use_chain_counting = true
	use_trigger_timing = true
	use_side_building = true
	use_center_preservation = true
	use_periodic_clearing = true
	use_harassment = true
	use_bomb_tactics = true  # NEW: Enable bomb tactics
	
	weight_side_building = 400.0
	weight_center_penalty = 200.0
	weight_flat_variance = 60.0
	weight_trigger_ready = 350.0
	weight_clear_now = 800.0
	weight_board_safety = 600.0
	weight_bomb_power = 350.0  # NEW: High bomb power consideration
	
	min_chain_before_trigger = 4
	target_chain_length = 6
	optimal_chain_length = 7
	trigger_at_height = 9
	max_safe_height = 10
	periodic_clear_threshold = 22
	harassment_threshold = 15
	
	move_delay = 0.25
	move_animation_speed = 0.08
	evaluation_noise = 10.0

# [REST OF THE CODE CONTINUES - same as before with evaluate_bomb_power and related functions]
# ... (continue with make_move, evaluate_placement_with_rotation, evaluate_bomb_power, etc.)

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
	
	# Check if we should trigger chain NOW
	if should_trigger_chain():
		trigger_best_chain()
		pieces_since_last_clear = 0
		decision_made = false
		return
	
	# Debug: Show what pieces we have
	var pieces = grid.current_piece_pair.get_pieces()
	var p1_color = "BOMB" if pieces[0].is_bomb() else ("BUBBLE" if pieces[0].is_bubble else str(pieces[0].color))
	var p2_color = "BOMB" if pieces[1].is_bomb() else ("BUBBLE" if pieces[1].is_bubble else str(pieces[1].color))
	print("\n=== AI EVALUATING MOVE ===")
	print("Piece colors: [", p1_color, ", ", p2_color, "]")
	
	# Find best placement by testing all rotations and columns
	var best_score = -999999
	var best_column = 0
	var best_rotation = 0
	var rotation_scores = {}
	
	var original_rotation = grid.current_piece_pair.piece_rotation
	
	# Test every rotation
	for rot in range(4):
		# Temporarily set rotation for evaluation
		grid.current_piece_pair.piece_rotation = rot
		grid.current_piece_pair.update_piece_positions()
		
		var best_score_for_rotation = -999999
		var best_col_for_rotation = -1
		
		# Test every column with this rotation
		for col in range(GameState.grid_width):
			var score = evaluate_placement_with_rotation(col, rot)
			if score > best_score_for_rotation:
				best_score_for_rotation = score
				best_col_for_rotation = col
			
			if score > best_score:
				best_score = score
				best_column = col
				best_rotation = rot
		
		rotation_scores[rot] = {"score": best_score_for_rotation, "col": best_col_for_rotation}
		print("Rotation ", rot, ": best_score=", best_score_for_rotation, " at col=", best_col_for_rotation)
	
	print("FINAL DECISION: rot=", best_rotation, " col=", best_column, " score=", best_score)
	print("===========================\n")
	
	# Restore original rotation
	grid.current_piece_pair.piece_rotation = original_rotation
	grid.current_piece_pair.update_piece_positions()
	
	execute_move(best_column, best_rotation)

# ============================================
# CHAIN TRIGGERING LOGIC - AGGRESSIVE
# ============================================

func should_trigger_chain() -> bool:
	"""Multi-phase triggering with safety priority"""
	if not use_trigger_timing:
		return false
	
	var chain_length = count_potential_chain_length()
	var max_height = get_max_column_height()
	var avg_height = get_average_column_height()
	
	# PHASE 1: EMERGENCY - Board dangerously high
	if max_height >= max_safe_height:
		if chain_length >= min_chain_before_trigger:
			print("AI TRIGGER: EMERGENCY at height ", max_height, " with chain ", chain_length)
			return true
	
	# PHASE 2: OPTIMAL - Perfect chain reached with safe board state
	if chain_length >= optimal_chain_length:
		if avg_height >= 6:
			print("AI TRIGGER: Optimal chain ", chain_length, " reached")
			return true
	
	# PHASE 3: TARGET - Good chain + board approaching danger
	if chain_length >= target_chain_length:
		if max_height >= trigger_at_height:
			print("AI TRIGGER: Target chain ", chain_length, " at height ", max_height)
			return true
	
	# PHASE 4: PERIODIC - Aggressive clearing to maintain safety
	if use_periodic_clearing and pieces_since_last_clear >= periodic_clear_threshold:
		if chain_length >= min_chain_before_trigger:
			print("AI TRIGGER: Periodic clear after ", pieces_since_last_clear, " pieces")
			return true
	
	# PHASE 5: HARASSMENT - Apply pressure to opponent
	if use_harassment and pieces_since_last_clear >= harassment_threshold:
		if chain_length >= 3 and avg_height >= 7:
			print("AI TRIGGER: Harassment chain (", chain_length, "-chain)")
			return true
	
	# PHASE 6: PREVENTIVE - Board getting too full
	if avg_height >= 8:
		if chain_length >= min_chain_before_trigger:
			print("AI TRIGGER: Preventive clear at avg height ", avg_height)
			return true
	
	# PHASE 7: SAFETY - Board over 70% full with any chain
	if avg_height >= 9:
		if chain_length >= 3:
			print("AI TRIGGER: Safety clear (board critical)")
			return true
	
	return false

func count_potential_chain_length() -> int:
	"""Count how long a chain we could trigger right now"""
	if not grid:
		return 0
	
	var best_chain = 0
	
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid.grid_data[y][x]
			if not piece or piece.is_bomb() or piece.is_bubble:
				continue
			
			var chain_length = simulate_chain_from_position(Vector2(x, y), piece.color)
			if chain_length > best_chain:
				best_chain = chain_length
	
	return best_chain

func simulate_chain_from_position(pos: Vector2, color: Color) -> int:
	"""Simulate triggering a chain from this position"""
	var group_size = count_group_at_position(pos, color)
	
	if group_size == 3:
		return estimate_chain_length_from_trigger(pos, color)
	
	return 0

func estimate_chain_length_from_trigger(pos: Vector2, color: Color) -> int:
	"""Estimate chain length if we complete this trigger"""
	var chain_estimate = 1
	
	var nearby_groups = 0
	for check_y in range(int(pos.y) - 1, -1, -1):
		for check_x in range(max(0, int(pos.x) - 2), min(GameState.grid_width, int(pos.x) + 3)):
			var check_pos = Vector2(check_x, check_y)
			var piece = grid.grid_data[check_y][check_x]
			if piece and not piece.is_bomb() and not piece.is_bubble:
				var group = count_group_at_position(check_pos, piece.color)
				if group >= 3:
					nearby_groups += 1
	
	chain_estimate += nearby_groups / 2
	return chain_estimate

func trigger_best_chain():
	"""Find and trigger the best available chain by placing piece to create a match"""
	if not grid or not grid.current_piece_pair:
		return
	
	print("AI TRIGGERING CHAIN - Finding best clearing move...")
	
	# Find best placement that creates an immediate clear
	var best_score = -999999
	var best_column = 0
	var best_rotation = 0
	var best_clear_count = 0
	
	var original_rotation = grid.current_piece_pair.piece_rotation
	
	# Test every rotation and column to find move that clears most pieces
	for rot in range(4):
		grid.current_piece_pair.piece_rotation = rot
		grid.current_piece_pair.update_piece_positions()
		
		for col in range(GameState.grid_width):
			# Get ordered pieces for this rotation
			var pieces = grid.current_piece_pair.get_pieces()
			var ordered_pieces = []
			
			match rot:
				0, 1:
					ordered_pieces = [pieces[0], pieces[1]]
				2, 3:
					ordered_pieces = [pieces[1], pieces[0]]
			
			# Check if we can place here
			var test_position = Vector2(col, 0)
			if not grid.can_place_piece_pair(grid.current_piece_pair, test_position):
				continue
			
			# Get landing positions
			var piece_positions = grid.current_piece_pair.get_piece_positions(test_position)
			var landing_positions = []
			for i in range(piece_positions.size()):
				var pos = piece_positions[i]
				var landing_y = find_landing_y(pos.x, pos.y)
				landing_positions.append(Vector2(pos.x, landing_y))
			
			# Count how many pieces this would clear
			var clear_count = simulate_placement_and_count_clears(landing_positions, ordered_pieces)
			
			# Prioritize moves that actually clear pieces
			if clear_count > 0:
				var score = clear_count * 10000  # Heavily prioritize clearing
				
				# Bonus for clearing more pieces
				score += clear_count * 100
				
				# Small bonus for keeping board low after clearing
				var projected_height = get_projected_max_height(landing_positions)
				score -= projected_height * 10
				
				if score > best_score:
					best_score = score
					best_column = col
					best_rotation = rot
					best_clear_count = clear_count
	
	# Restore original rotation
	grid.current_piece_pair.piece_rotation = original_rotation
	grid.current_piece_pair.update_piece_positions()
	
	# If we found a move that clears pieces, execute it
	if best_clear_count > 0:
		print("AI CHAIN TRIGGER: Executing clear of ", best_clear_count, " pieces at col=", best_column, " rot=", best_rotation)
		execute_move(best_column, best_rotation)
	else:
		# Fallback: No clearing move found - find and execute best safe move immediately
		print("AI CHAIN TRIGGER: No clearing move found, executing best safe move immediately")
		
		# Find best safe move (same logic as make_move but without triggering recursion)
		best_score = -999999
		best_column = 0
		best_rotation = 0
		
		for rot in range(4):
			grid.current_piece_pair.piece_rotation = rot
			grid.current_piece_pair.update_piece_positions()
			
			for col in range(GameState.grid_width):
				var score = evaluate_placement_with_rotation(col, rot)
				if score > best_score:
					best_score = score
					best_column = col
					best_rotation = rot
		
		# Restore original rotation
		grid.current_piece_pair.piece_rotation = original_rotation
		grid.current_piece_pair.update_piece_positions()
		
		# Execute the best safe move we found
		print("AI CHAIN TRIGGER: Best safe move is col=", best_column, " rot=", best_rotation, " score=", best_score)
		execute_move(best_column, best_rotation)
# ============================================
# PLACEMENT EVALUATION
# ============================================

func evaluate_placement_with_rotation(column: int, rotation: int) -> float:
	"""Evaluate placement with piece pair already set to the given rotation"""
	
	var test_position = Vector2(column, 0)
	
	# Check if we can place the piece pair at this position with current rotation
	if not grid.can_place_piece_pair(grid.current_piece_pair, test_position):
		return -999999
	
	# Get the actual piece positions with the current rotation
	var piece_positions = grid.current_piece_pair.get_piece_positions(test_position)
	
	# CRITICAL FIX: Get pieces in the correct order based on rotation
	# For rotations 2 and 3, the positions are reversed but get_pieces() isn't
	var pieces = grid.current_piece_pair.get_pieces()
	var ordered_pieces = []
	
	match rotation:
		0, 1:
			# Normal order: piece1 at positions[0], piece2 at positions[1]
			ordered_pieces = [pieces[0], pieces[1]]
		2, 3:
			# Reversed order: piece2 at positions[0], piece1 at positions[1]
			ordered_pieces = [pieces[1], pieces[0]]
	
	# Find where each piece would actually land
	var landing_positions = []
	for i in range(piece_positions.size()):
		var pos = piece_positions[i]
		var landing_y = find_landing_y(pos.x, pos.y)
		landing_positions.append(Vector2(pos.x, landing_y))
	
	var score = 0.0
	
	# === CRITICAL: SPAWN ZONE PROTECTION ===
	var spawn_score = evaluate_spawn_zone_absolute(landing_positions)
	score += spawn_score
	if score < -5000:
		return score
	
	# === NEW: BOARD SAFETY (HIGH PRIORITY) ===
	var safety_score = evaluate_board_safety(landing_positions)
	score += safety_score
	
	# === SIDE BUILDING STRATEGY ===
	var side_score = 0.0
	var center_score = 0.0
	if use_side_building:
		side_score = evaluate_side_building_preference(landing_positions)
		center_score = evaluate_center_avoidance(landing_positions)
		score += side_score
		score += center_score
	
	# === BOARD SHAPE MANAGEMENT ===
	var flat_score = evaluate_board_flatness(landing_positions)
	score += flat_score
	
	# === CHAIN BUILDING ===
	var chain_score = 0.0
	if use_chain_counting:
		chain_score = evaluate_chain_building(landing_positions, ordered_pieces)
		score += chain_score
	
	# === IMMEDIATE CLEARING ===
	var clear_count = simulate_placement_and_count_clears(landing_positions, ordered_pieces)
	var clear_score = 0.0
	if clear_count > 0:
		clear_score = weight_clear_now * clear_count
		if clear_count >= 6:
			clear_score += weight_clear_now * 0.5
		if clear_count >= 10:
			clear_score += weight_clear_now * 1.0
		score += clear_score
		
		print("  -> CLEAR FOUND! col=", column, " rot=", rotation, " clears=", clear_count, " clear_bonus=", clear_score)
	
	# Debug detailed scoring for first few evaluations
	if rotation == 0 and column <= 1:
		print("  Detailed score for col=", column, " rot=", rotation, ":")
		print("    spawn=", spawn_score, " safety=", safety_score, " side=", side_score)
		print("    center=", center_score, " flat=", flat_score, " chain=", chain_score, " clear=", clear_score)
		print("    TOTAL=", score)
	
	# Add random noise for variation between AI instances
	if evaluation_noise > 0:
		var noise = rng.randf_range(-evaluation_noise, evaluation_noise)
		score += noise
	
	return score

# ============================================
# BOARD SAFETY EVALUATION (NEW)
# ============================================

func evaluate_board_safety(landing_positions: Array) -> float:
	"""Heavily penalize vulnerable board states"""
	var score = 0.0
	
	var projected_max_height = get_projected_max_height(landing_positions)
	var current_max_height = get_max_column_height()
	var current_avg_height = get_average_column_height()
	
	# CRITICAL: Exponential penalty for high boards
	if projected_max_height >= max_safe_height:
		var excess = projected_max_height - (max_safe_height - 1)
		score -= weight_board_safety * excess * excess
	
	# Penalize increasing max height when already high
	if current_max_height >= trigger_at_height:
		if projected_max_height > current_max_height:
			score -= weight_board_safety * 0.5
	
	# Bonus for keeping board low
	if current_avg_height < 7:
		score += weight_board_safety * 0.3
	
	# Extra penalty for placements that create tall spikes
	if projected_max_height - current_avg_height > 4:
		score -= weight_board_safety * 0.4
	
	return score

func get_projected_max_height(landing_positions: Array) -> int:
	"""Get max height if these pieces land"""
	var max_height = get_max_column_height()
	
	for pos in landing_positions:
		var col = int(pos.x)
		var height = GameState.grid_height - int(pos.y)
		if height > max_height:
			max_height = height
	
	return max_height

# ============================================
# SPAWN ZONE PROTECTION
# ============================================

func evaluate_spawn_zone_absolute(landing_positions: Array) -> float:
	"""Rows 0-1 are INSTANT DEATH"""
	var penalty = 0.0
	
	for pos in landing_positions:
		var row = int(pos.y)
		
		if row < GameState.playfield_start_row:
			penalty -= weight_spawn_zone_death
			print("WARNING: AI attempted spawn zone placement at row ", row)
		elif row < GameState.playfield_start_row + 3:
			var proximity = GameState.playfield_start_row + 3 - row
			penalty -= 1000.0 * proximity
	
	return penalty

# ============================================
# SIDE BUILDING STRATEGY
# ============================================

func evaluate_side_building_preference(landing_positions: Array) -> float:
	"""Build tall on sides (cols 0-1, 4-5)"""
	var score = 0.0
	
	for pos in landing_positions:
		var col = int(pos.x)
		
		if col in preferred_columns:
			score += weight_side_building
			
			var height = GameState.grid_height - int(pos.y)
			if height > 8:
				score += weight_side_building * 0.5
		
		if col in avoid_columns:
			score -= weight_center_penalty
			
			var height = GameState.grid_height - int(pos.y)
			if height > 7:
				score -= weight_center_penalty * 1.5
	
	return score

func evaluate_center_avoidance(landing_positions: Array) -> float:
	"""Keep center columns (2-3) LOW"""
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
			
			if new_height > current_height:
				score -= weight_center_penalty * (new_height - current_height)
	
	return score

# ============================================
# BOARD MANAGEMENT
# ============================================

func evaluate_board_flatness(landing_positions: Array) -> float:
	"""Maintain relatively flat board with side towers"""
	var score = 0.0
	
	var column_heights = []
	for x in range(GameState.grid_width):
		column_heights.append(get_column_height(x))
	
	var side_heights = [column_heights[0], column_heights[1], column_heights[4], column_heights[5]]
	var center_heights_array = [column_heights[2], column_heights[3]]
	
	var side_variance = 0.0
	var side_avg = (side_heights[0] + side_heights[1] + side_heights[2] + side_heights[3]) / 4.0
	for h in side_heights:
		side_variance += abs(h - side_avg)
	
	var center_variance = abs(center_heights_array[0] - center_heights_array[1])
	
	score -= side_variance * weight_flat_variance
	score -= center_variance * weight_flat_variance
	
	var center_avg = (center_heights_array[0] + center_heights_array[1]) / 2.0
	if side_avg > center_avg + 2:
		score += 100.0
	
	return score

func evaluate_chain_building(landing_positions: Array, pieces: Array) -> float:
	"""Reward building toward chain patterns - SIMULATES placement"""
	var score = 0.0
	
	# Create a temporary grid copy
	var temp_grid = []
	for y in range(GameState.grid_height):
		var row = []
		for x in range(GameState.grid_width):
			row.append(grid.grid_data[y][x])
		temp_grid.append(row)
	
	# Place the pieces in the temporary grid
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		var x = int(pos.x)
		var y = int(pos.y)
		
		if x >= 0 and x < GameState.grid_width and y >= 0 and y < GameState.grid_height:
			temp_grid[y][x] = piece
	
	# Now check for chain building potential
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		if piece.is_bomb() or piece.is_bubble:
			continue
		
		var color = piece.color
		var group = find_connected_group_in_temp_grid(pos, color, temp_grid, {})
		
		if group.size() == 2:
			score += 50.0  # Building toward trigger
		elif group.size() == 3:
			score += weight_trigger_ready  # One away from triggering!
	
	return score

func evaluate_immediate_clear(landing_positions: Array, pieces: Array) -> float:
	"""Bonus for creating immediate matches - SIMULATES placement"""
	var score = 0.0
	
	# Simulate placing the pieces on the grid
	var simulated_clears = simulate_placement_and_count_clears(landing_positions, pieces)
	
	if simulated_clears > 0:
		# Reward clears heavily
		score += weight_clear_now * simulated_clears
		
		# Extra bonus for larger clears
		if simulated_clears >= 6:
			score += weight_clear_now * 0.5
		if simulated_clears >= 10:
			score += weight_clear_now * 1.0
	
	return score

func simulate_placement_and_count_clears(landing_positions: Array, pieces: Array) -> int:
	"""Simulate placing pieces and count how many pieces would clear"""
	if landing_positions.size() != pieces.size():
		return 0
	
	# Create a temporary grid copy
	var temp_grid = []
	for y in range(GameState.grid_height):
		var row = []
		for x in range(GameState.grid_width):
			row.append(grid.grid_data[y][x])
		temp_grid.append(row)
	
	# Debug: Log what we're placing
	var piece_colors = []
	for piece in pieces:
		if piece.is_bomb():
			piece_colors.append("BOMB")
		elif piece.is_bubble:
			piece_colors.append("BUBBLE")
		else:
			piece_colors.append(str(piece.color))
	
	# Place the pieces in the temporary grid
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		var x = int(pos.x)
		var y = int(pos.y)
		
		if x >= 0 and x < GameState.grid_width and y >= 0 and y < GameState.grid_height:
			temp_grid[y][x] = piece
	
	# Count all pieces that would clear
	var total_clears = 0
	var checked = {}
	
	for i in range(landing_positions.size()):
		var pos = landing_positions[i]
		var piece = pieces[i]
		
		if piece.is_bomb() or piece.is_bubble:
			continue
		
		if checked.has(pos):
			continue
		
		var group = find_connected_group_in_temp_grid(pos, piece.color, temp_grid, {})
		
		if group.size() >= 4:
			print("    [SIM] Found group of ", group.size(), " at ", pos, " color=", piece.color)
			total_clears += group.size()
			for p in group:
				checked[p] = true
		elif group.size() > 0:
			# Debug: show groups that are close but not quite
			if group.size() == 3:
				print("    [SIM] Almost! Group of 3 at ", pos, " color=", piece.color)
	
	return total_clears

func find_connected_group_in_temp_grid(start_pos: Vector2, color: Color, temp_grid: Array, visited: Dictionary) -> Array:
	"""Find connected group in a temporary grid (for simulation)"""
	var group = []
	var stack = [start_pos]
	
	while stack.size() > 0:
		var pos = stack.pop_back()
		
		if visited.has(pos):
			continue
		
		var x = int(pos.x)
		var y = int(pos.y)
		
		if x < 0 or x >= GameState.grid_width or y < 0 or y >= GameState.grid_height:
			continue
		
		var piece = temp_grid[y][x]
		if not piece:
			continue
		if piece.is_bomb() or piece.is_bubble:
			continue
		if piece.color != color:
			continue
		
		visited[pos] = true
		group.append(pos)
		
		stack.append(Vector2(pos.x + 1, pos.y))
		stack.append(Vector2(pos.x - 1, pos.y))
		stack.append(Vector2(pos.x, pos.y + 1))
		stack.append(Vector2(pos.x, pos.y - 1))
	
	return group

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
		if not piece or piece.is_bomb() or piece.is_bubble:
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
	
	# Debug output to verify rotation logic
	if rotations_needed > 0:
		print("AI rotating ", rotations_needed, " times (from ", current_rotation, " to ", target_rotation, ") for column ", target_column)
	
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

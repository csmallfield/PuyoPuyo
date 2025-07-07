extends Node2D
# Grid.gd - Manages the game grid and piece placement

signal game_over
signal chain_bonus(chain_count)  # New signal for chain bonus notification

const CELL_SIZE = 64
const LANDING_GRACE_PERIOD = 0.25
const BOMB_SHAKE_INTENSITY = 8.0
const Piece = preload("res://scenes/Piece.tscn")

var grid_data = []
var current_piece_pair = null
var next_piece_pair = null
var fall_timer = 0.0
var clearing_matches = false

# Chain tracking for cascade bonuses
var current_chain_count = 0
var is_cascading = false

# Landing grace period variables
var landing_grace_timer = 0.0
var is_in_grace_period = false
var piece_has_landed = false

# Camera shake variables
var original_position = Vector2.ZERO
var shake_timer = 0.0
var shake_duration = 0.0
var is_shaking = false

@onready var piece_pair_scene = preload("res://scenes/PiecePair.tscn")

func _ready():
	initialize_grid()
	original_position = Vector2(400, 100)
	position = original_position

func _draw():
	# Draw grid lines
	var grid_color = Color.GRAY
	grid_color.a = 0.3
	
	# Vertical lines - draw at cell boundaries
	for x in range(GameState.grid_width + 1):
		var start_pos = Vector2(x * CELL_SIZE, 0)
		var end_pos = Vector2(x * CELL_SIZE, GameState.grid_height * CELL_SIZE)
		draw_line(start_pos, end_pos, grid_color, 1)
	
	# Horizontal lines - draw at cell boundaries
	for y in range(GameState.grid_height + 1):
		var start_pos = Vector2(0, y * CELL_SIZE)
		var end_pos = Vector2(GameState.grid_width * CELL_SIZE, y * CELL_SIZE)
		draw_line(start_pos, end_pos, grid_color, 1)
	
	# Draw border box
	var border_color = Color.WHITE
	var border_width = 3
	var rect = Rect2(0, 0, GameState.grid_width * CELL_SIZE, GameState.grid_height * CELL_SIZE)
	draw_rect(rect, border_color, false, border_width)

func _process(delta):
	if GameState.current_state != GameState.State.PLAYING:
		return
	
	# Handle camera shake
	if is_shaking:
		shake_timer += delta
		if shake_timer >= shake_duration:
			# Shake finished
			is_shaking = false
			position = original_position
		else:
			# Apply shake offset
			var shake_strength = (1.0 - (shake_timer / shake_duration)) * BOMB_SHAKE_INTENSITY
			var shake_offset = Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)
			position = original_position + shake_offset
		
	if current_piece_pair and not clearing_matches:
		# Handle landing grace period
		if is_in_grace_period:
			landing_grace_timer += delta
			# If grace period expires, lock the piece
			if landing_grace_timer >= LANDING_GRACE_PERIOD:
				force_place_piece()
		else:
			# Normal falling behavior
			fall_timer += delta
			if fall_timer >= GameState.get_fall_speed():
				fall_timer = 0.0
				move_piece_down()

func initialize_grid():
	grid_data = []
	for y in range(GameState.grid_height):
		var row = []
		for x in range(GameState.grid_width):
			row.append(null)
		grid_data.append(row)

func start_game():
	initialize_grid()
	clear_all_pieces()
	spawn_new_piece_pair()

func clear_all_pieces():
	for child in get_children():
		if child.get_script() != null and child.has_method("set_color"):
			child.queue_free()

func spawn_new_piece_pair():
	if next_piece_pair:
		current_piece_pair = next_piece_pair
	else:
		current_piece_pair = piece_pair_scene.instantiate()
		add_child(current_piece_pair)
	
	# Reset landing state for new piece
	reset_landing_state()
	
	# Position at top center
	var start_pos = Vector2(GameState.grid_width / 2, 0)
	current_piece_pair.set_grid_position(start_pos)
	current_piece_pair.set_pixel_position(grid_to_pixel(start_pos))
	
	# Check for game over
	if not can_place_piece_pair(current_piece_pair, start_pos):
		emit_signal("game_over")
		return
	
	# Prepare next piece
	next_piece_pair = piece_pair_scene.instantiate()
	add_child(next_piece_pair)
	next_piece_pair.set_pixel_position(Vector2(500, 100))

func start_camera_shake(duration: float):
	is_shaking = true
	shake_timer = 0.0
	shake_duration = duration

func reset_landing_state():
	is_in_grace_period = false
	piece_has_landed = false
	landing_grace_timer = 0.0

func start_grace_period():
	if not is_in_grace_period:  # Only start grace period once
		is_in_grace_period = true
		landing_grace_timer = 0.0
		piece_has_landed = true

func _input(event):
	if GameState.current_state != GameState.State.PLAYING or not current_piece_pair:
		return
		
	if event.is_action_pressed("move_left"):
		move_piece_horizontal(-1)
		# Reset grace timer on movement
		if is_in_grace_period:
			landing_grace_timer = 0.0
	elif event.is_action_pressed("move_right"):
		move_piece_horizontal(1)
		# Reset grace timer on movement
		if is_in_grace_period:
			landing_grace_timer = 0.0
	elif event.is_action_pressed("rotate_piece"):
		rotate_piece()
		# Reset grace timer on rotation
		if is_in_grace_period:
			landing_grace_timer = 0.0
	elif event.is_action_pressed("move_down"):
		move_piece_down()
	elif event.is_action_pressed("fast_drop"):
		fast_drop_piece()

func move_piece_horizontal(direction):
	var new_pos = current_piece_pair.grid_position + Vector2(direction, 0)
	if can_place_piece_pair(current_piece_pair, new_pos):
		current_piece_pair.set_grid_position(new_pos)
		current_piece_pair.set_pixel_position(grid_to_pixel(new_pos))
		
		# Check if piece can now fall again after horizontal movement
		var can_fall = can_place_piece_pair(current_piece_pair, new_pos + Vector2(0, 1))
		if can_fall and is_in_grace_period:
			# Reset landing state since piece can fall again
			reset_landing_state()

func move_piece_down():
	var new_pos = current_piece_pair.grid_position + Vector2(0, 1)
	if can_place_piece_pair(current_piece_pair, new_pos):
		current_piece_pair.set_grid_position(new_pos)
		current_piece_pair.set_pixel_position(grid_to_pixel(new_pos))
		
		# If we were in grace period but can now fall, reset it
		if is_in_grace_period:
			reset_landing_state()
	else:
		# Piece has hit something - start grace period if not already started
		if not piece_has_landed:
			start_grace_period()

func fast_drop_piece():
	# Fast drop immediately ends grace period and places piece
	if is_in_grace_period:
		force_place_piece()
		return
	
	# Keep moving down until we can't anymore
	while true:
		var new_pos = current_piece_pair.grid_position + Vector2(0, 1)
		if can_place_piece_pair(current_piece_pair, new_pos):
			current_piece_pair.set_grid_position(new_pos)
			current_piece_pair.set_pixel_position(grid_to_pixel(new_pos))
		else:
			# Can't move down anymore, place the piece immediately
			place_piece_pair()
			break

func force_place_piece():
	# Force placement regardless of grace period
	place_piece_pair()

func rotate_piece():
	current_piece_pair.rotate_pieces()
	# Check if rotation is valid, if not, rotate back
	if not can_place_piece_pair(current_piece_pair, current_piece_pair.grid_position):
		current_piece_pair.rotate_pieces()
		current_piece_pair.rotate_pieces()
		current_piece_pair.rotate_pieces()  # Rotate back 3 times = 1 back

func can_place_piece_pair(piece_pair, pos):
	var positions = piece_pair.get_piece_positions(pos)
	for piece_pos in positions:
		if piece_pos.x < 0 or piece_pos.x >= GameState.grid_width:
			return false
		if piece_pos.y >= GameState.grid_height:
			return false
		if piece_pos.y >= 0 and grid_data[piece_pos.y][piece_pos.x] != null:
			return false
	return true

func place_piece_pair():
	var positions = current_piece_pair.get_piece_positions(current_piece_pair.grid_position)
	var pieces = current_piece_pair.get_pieces()
	
	# Reset landing state
	reset_landing_state()
	
	# Initialize chain tracking for new turn
	current_chain_count = 0
	is_cascading = false
	
	# Place pieces in grid and remove from piece pair
	for i in range(positions.size()):
		var pos = positions[i]
		var piece = pieces[i]
		if pos.y >= 0:
			# Remove piece from current parent and add to grid
			piece.get_parent().remove_child(piece)
			add_child(piece)
			
			# Store in grid data and set position immediately (no animation for placement)
			grid_data[pos.y][pos.x] = piece
			piece.set_position_immediately(grid_to_pixel(pos))
	
	current_piece_pair.queue_free()
	current_piece_pair = null
	
	# Apply gravity with smooth animations FIRST
	apply_gravity()
	
	# Wait for gravity animations to complete
	await get_tree().create_timer(0.4).timeout
	
	# THEN activate any bombs that have settled
	await activate_bombs_after_gravity()
	
	# Finally check for matches (this will handle cascading)
	check_and_clear_matches()

func activate_bombs_after_gravity():
	# Find all bombs on the board
	var bombs_to_activate = []
	
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid_data[y][x]
			if piece != null and piece.is_bomb:
				bombs_to_activate.append(Vector2(x, y))
	
	# If any bombs found, activate them all with dramatic effect
	if bombs_to_activate.size() > 0:
		await activate_bombs_with_effects(bombs_to_activate)
		
		# Apply gravity again to fill the gaps
		apply_gravity()
		# Wait for gravity animations to complete
		await get_tree().create_timer(0.4).timeout

func activate_bombs_with_effects(bomb_positions: Array):
	print("Activating ", bomb_positions.size(), " bombs with effects")
	
	# Collect all pieces that will be affected by all bombs
	var all_affected_pieces = []
	var all_affected_positions = []
	
	# Process each bomb to find what it affects
	for bomb_pos in bomb_positions:
		var affected_pieces = get_bomb_affected_pieces(bomb_pos)
		
		# Add bomb itself to affected pieces
		affected_pieces.append(bomb_pos)
		
		# Merge with total affected pieces (avoid duplicates)
		for piece_pos in affected_pieces:
			if not piece_pos in all_affected_positions:
				all_affected_positions.append(piece_pos)
				all_affected_pieces.append(grid_data[piece_pos.y][piece_pos.x])
	
	# Phase 1: Blink effect on all affected pieces
	await create_blink_effect(all_affected_pieces)
	
	# Phase 2: Explosion effect with camera shake
	start_camera_shake(0.4)
	await create_explosion_effect(all_affected_positions)
	
	# Calculate and award points
	var pieces_cleared = all_affected_positions.size()
	if pieces_cleared > 0:
		var bomb_points = pieces_cleared * 10
		GameState.add_score(bomb_points)
		print("Bombs cleared ", pieces_cleared, " pieces for ", bomb_points, " points")

func get_bomb_affected_pieces(bomb_pos: Vector2) -> Array:
	print("Analyzing bomb at position: ", bomb_pos)
	
	# Find target color using priority: down, up, left, right
	var target_color = null
	var target_is_bubble = false
	var check_positions = [
		bomb_pos + Vector2(0, 1),   # Down
		bomb_pos + Vector2(0, -1),  # Up
		bomb_pos + Vector2(-1, 0),  # Left
		bomb_pos + Vector2(1, 0)    # Right
	]
	
	for check_pos in check_positions:
		# Check bounds
		if check_pos.x >= 0 and check_pos.x < GameState.grid_width and check_pos.y >= 0 and check_pos.y < GameState.grid_height:
			var adjacent_piece = grid_data[check_pos.y][check_pos.x]
			if adjacent_piece != null and not adjacent_piece.is_bomb:
				target_color = adjacent_piece.color
				target_is_bubble = adjacent_piece.is_bubble
				break
	
	# If no target found, bomb affects nothing
	if target_color == null:
		print("Bomb found no target")
		return []
	
	print("Bomb targeting color: ", target_color, " (is_bubble: ", target_is_bubble, ")")
	
	# Find all pieces of the target color/type
	var affected_positions = []
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid_data[y][x]
			if piece != null and not piece.is_bomb:
				# Include if it matches the target (either color match or both are bubbles)
				if (target_is_bubble and piece.is_bubble) or (not target_is_bubble and not piece.is_bubble and piece.color == target_color):
					affected_positions.append(Vector2(x, y))
	
	return affected_positions

func create_blink_effect(affected_pieces: Array):
	var blink_duration = 0.3
	var blink_count = 3
	var blink_interval = blink_duration / (blink_count * 2)
	
	# Store original colors
	var original_colors = []
	for piece in affected_pieces:
		if piece != null:
			original_colors.append(piece.color)
	
	# Blink sequence
	for blink in range(blink_count):
		# Flash to white
		for i in range(affected_pieces.size()):
			var piece = affected_pieces[i]
			if piece != null:
				piece.modulate = Color.WHITE
		
		await get_tree().create_timer(blink_interval).timeout
		
		# Flash back to original
		for i in range(affected_pieces.size()):
			var piece = affected_pieces[i]
			if piece != null:
				piece.modulate = Color(original_colors[i])
		
		await get_tree().create_timer(blink_interval).timeout

func create_explosion_effect(affected_positions: Array):
	var explosion_duration = 0.3
	var tweens = []
	
	# Create explosion animation for all affected pieces
	for pos in affected_positions:
		var piece = grid_data[pos.y][pos.x]
		if piece != null:
			var tween = create_tween()
			tweens.append(tween)
			
			# Scale up larger than normal matches, then down to 0
			tween.tween_property(piece, "scale", Vector2(2.0, 2.0), explosion_duration * 0.4)
			tween.tween_property(piece, "scale", Vector2(0, 0), explosion_duration * 0.6)
			
			# Add more dramatic rotation
			tween.parallel().tween_property(piece, "rotation", PI * 1.0, explosion_duration)
	
	# Wait for all animations to complete
	if tweens.size() > 0:
		await tweens[0].finished
	
	# Remove all affected pieces
	for pos in affected_positions:
		if grid_data[pos.y][pos.x] != null:
			grid_data[pos.y][pos.x].queue_free()
			grid_data[pos.y][pos.x] = null

func is_animating():
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid_data[y][x]
			if piece != null and piece.is_animating:
				return true
	return false

func check_and_clear_matches():
	while is_animating():
		await get_tree().create_timer(0.05).timeout

	clearing_matches = true
	var matches_found = false
	var visited = {}
	var match_groups = []  # Store each match group separately for individual scoring
	
	# Find all colored matches (4+ connected same-color pieces)
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var pos = Vector2(x, y)
			
			# Skip if empty, already visited, is a bubble piece, or is a bomb
			if grid_data[y][x] == null or visited.has(pos) or grid_data[y][x].is_bubble or grid_data[y][x].is_bomb:
				continue
				
			# Find connected group of same color
			var group = find_connected_group(pos, grid_data[y][x].color, visited)
			
			# If group has 4 or more pieces, mark for clearing
			if group.size() >= 4:
				matches_found = true
				match_groups.append(group)
	
	if matches_found:
		# Increment chain count for cascade bonus
		current_chain_count += 1
		is_cascading = true
		
		# Calculate scores for each match group
		var total_base_score = 0
		var all_pieces_to_clear = []
		var all_bubbles_to_clear = []
		
		# Process each match group individually
		for group in match_groups:
			# Calculate match size bonus: 100 + (pieces_over_4 * 10)
			var match_size = group.size()
			var match_score = 100 + ((match_size - 4) * 10)
			total_base_score += match_score
			
			print("Match of ", match_size, " pieces scores ", match_score, " points")
			
			# Add to clearing list
			all_pieces_to_clear.append_array(group)
			
			# Find bubbles adjacent to this match group
			for clear_pos in group:
				var adjacent_positions = [
					clear_pos + Vector2(1, 0),   # Right
					clear_pos + Vector2(-1, 0),  # Left
					clear_pos + Vector2(0, 1),   # Down
					clear_pos + Vector2(0, -1)   # Up
				]
				
				for adj_pos in adjacent_positions:
					# Check bounds
					if adj_pos.x >= 0 and adj_pos.x < GameState.grid_width and adj_pos.y >= 0 and adj_pos.y < GameState.grid_height:
						var adj_piece = grid_data[adj_pos.y][adj_pos.x]
						if adj_piece != null and adj_piece.is_bubble and not adj_pos in all_bubbles_to_clear:
							all_bubbles_to_clear.append(adj_pos)
		
		# Add bubble bonus to total
		var bubble_bonus = all_bubbles_to_clear.size() * 50
		total_base_score += bubble_bonus
		
		# Add chain cascade bonus: 100 * chain_number
		var chain_bonus = current_chain_count * 100
		total_base_score += chain_bonus
		
		print("Chain ", current_chain_count, " - Base score: ", total_base_score, " (includes ", chain_bonus, " chain bonus)")
		
		# Show chain bonus notification if 2+ chains
		if current_chain_count >= 2:
			emit_signal("chain_bonus", current_chain_count)
		
		# Clear pieces with animations
		await clear_group(all_pieces_to_clear)
		await clear_group(all_bubbles_to_clear)
		
		# Award points (will be multiplied by level multiplier in GameState)
		GameState.add_score(total_base_score)
		
		# Apply gravity after clearing
		apply_gravity()
		
		# Wait for gravity animations to complete then check for chain reactions
		await get_tree().create_timer(0.4).timeout
		check_and_clear_matches()  # Recursive call for chains
	else:
		# No matches found, end cascading and spawn next piece
		clearing_matches = false
		is_cascading = false
		current_chain_count = 0
		spawn_new_piece_pair()

func find_connected_group(start_pos, color, visited):
	var group = []
	var stack = [start_pos]
	
	while stack.size() > 0:
		var pos = stack.pop_back()
		
		# Skip if already visited
		if visited.has(pos):
			continue
			
		# Skip if out of bounds
		if pos.x < 0 or pos.x >= GameState.grid_width or pos.y < 0 or pos.y >= GameState.grid_height:
			continue
			
		# Skip if empty, wrong color, is a bubble piece, or is a bomb
		if grid_data[pos.y][pos.x] == null or grid_data[pos.y][pos.x].color != color or grid_data[pos.y][pos.x].is_bubble or grid_data[pos.y][pos.x].is_bomb:
			continue
		
		# Mark as visited and add to group
		visited[pos] = true
		group.append(pos)
		
		# Add adjacent positions (only orthogonal, not diagonal)
		stack.append(pos + Vector2(1, 0))   # Right
		stack.append(pos + Vector2(-1, 0))  # Left  
		stack.append(pos + Vector2(0, 1))   # Down
		stack.append(pos + Vector2(0, -1))  # Up
	
	return group

func clear_group(group):
	# Start pop animations for all pieces in the group
	var pop_duration = 0.25
	var tweens = []
	
	for pos in group:
		var piece = grid_data[pos.y][pos.x]
		if piece:
			# Create a tween for this piece
			var tween = create_tween()
			tweens.append(tween)
			
			# Scale up quickly, then down to 0
			tween.tween_property(piece, "scale", Vector2(1.5, 1.5), pop_duration * 0.3)
			tween.tween_property(piece, "scale", Vector2(0, 0), pop_duration * 0.7)
			
			# Add a slight rotation for extra juice
			tween.parallel().tween_property(piece, "rotation", PI * 0.5, pop_duration)
	
	# Wait for all animations to complete
	if tweens.size() > 0:
		await tweens[0].finished
	
	# Now actually remove the pieces
	for pos in group:
		if grid_data[pos.y][pos.x]:
			grid_data[pos.y][pos.x].queue_free()
			grid_data[pos.y][pos.x] = null

func apply_gravity():
	var something_fell = true
	
	# Keep applying gravity until nothing moves
	while something_fell:
		something_fell = false
		
		# Go through each column from bottom to top
		for x in range(GameState.grid_width):
			for y in range(GameState.grid_height - 2, -1, -1):  # Start from second-to-last row
				if grid_data[y][x] != null:
					# Check if this piece can fall
					var target_y = y
					
					# Find the lowest position this piece can fall to
					while target_y + 1 < GameState.grid_height and grid_data[target_y + 1][x] == null:
						target_y += 1
					
					# If the piece can fall, move it
					if target_y != y:
						var piece = grid_data[y][x]
						grid_data[y][x] = null
						grid_data[target_y][x] = piece
						piece.animate_to_position(grid_to_pixel(Vector2(x, target_y)))
						something_fell = true

func grid_to_pixel(grid_pos):
	return Vector2(grid_pos.x * CELL_SIZE + CELL_SIZE/2, grid_pos.y * CELL_SIZE + CELL_SIZE/2)

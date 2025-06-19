extends Node2D
# Grid.gd - Manages the game grid and piece placement

signal game_over

const CELL_SIZE = 32
const Piece = preload("res://scenes/Piece.tscn")
var grid_data = []
var current_piece_pair = null
var next_piece_pair = null
var fall_timer = 0.0
var clearing_matches = false

@onready var piece_pair_scene = preload("res://scenes/PiecePair.tscn")

func _ready():
	initialize_grid()
	position = Vector2(200, 50)  # Offset from screen edge

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
		
	if current_piece_pair and not clearing_matches:
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
	next_piece_pair.set_pixel_position(Vector2(250, 50))  # Show next piece area

func _input(event):
	if GameState.current_state != GameState.State.PLAYING or not current_piece_pair:
		return
		
	if event.is_action_pressed("move_left"):
		move_piece_horizontal(-1)
	elif event.is_action_pressed("move_right"):
		move_piece_horizontal(1)
	elif event.is_action_pressed("rotate_piece"):
		rotate_piece()
	elif event.is_action_pressed("move_down"):
		move_piece_down()
	elif event.is_action_pressed("fast_drop"):
		fast_drop_piece()

func move_piece_horizontal(direction):
	var new_pos = current_piece_pair.grid_position + Vector2(direction, 0)
	if can_place_piece_pair(current_piece_pair, new_pos):
		current_piece_pair.set_grid_position(new_pos)
		current_piece_pair.set_pixel_position(grid_to_pixel(new_pos))

func move_piece_down():
	var new_pos = current_piece_pair.grid_position + Vector2(0, 1)
	if can_place_piece_pair(current_piece_pair, new_pos):
		current_piece_pair.set_grid_position(new_pos)
		current_piece_pair.set_pixel_position(grid_to_pixel(new_pos))
	else:
		place_piece_pair()

func fast_drop_piece():
	# Keep moving down until we can't anymore
	while true:
		var new_pos = current_piece_pair.grid_position + Vector2(0, 1)
		if can_place_piece_pair(current_piece_pair, new_pos):
			current_piece_pair.set_grid_position(new_pos)
			current_piece_pair.set_pixel_position(grid_to_pixel(new_pos))
		else:
			# Can't move down anymore, place the piece
			place_piece_pair()
			break

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
	var bombs_to_activate = []
	
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
			
			# Check if this piece is a bomb
			if piece.is_bomb:
				bombs_to_activate.append(pos)
	
	current_piece_pair.queue_free()
	current_piece_pair = null
	
	# Activate bombs first (before gravity)
	for bomb_pos in bombs_to_activate:
		activate_bomb(bomb_pos)
	
	# Apply gravity with smooth animations
	apply_gravity()
	
	# Wait longer for animations to complete before checking matches
	await get_tree().create_timer(0.4).timeout
	check_and_clear_matches()

func activate_bomb(bomb_pos):
	print("Activating bomb at position: ", bomb_pos)
	
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
	
	# If no target found, bomb does nothing (shouldn't happen with proper placement)
	if target_color == null:
		print("Bomb found no target - removing bomb only")
		grid_data[bomb_pos.y][bomb_pos.x].queue_free()
		grid_data[bomb_pos.y][bomb_pos.x] = null
		return
	
	print("Bomb targeting color: ", target_color, " (is_bubble: ", target_is_bubble, ")")
	
	# Clear all pieces of the target color/type from the board
	var pieces_cleared = 0
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid_data[y][x]
			if piece != null:
				# Clear if it matches the target (either color match or both are bubbles)
				if (target_is_bubble and piece.is_bubble) or (not target_is_bubble and not piece.is_bubble and piece.color == target_color):
					piece.queue_free()
					grid_data[y][x] = null
					pieces_cleared += 1
	
	# Remove the bomb itself
	grid_data[bomb_pos.y][bomb_pos.x].queue_free()
	grid_data[bomb_pos.y][bomb_pos.x] = null
	
	# Add score for pieces cleared by bomb (small amount per piece)
	if pieces_cleared > 0:
		var bomb_points = pieces_cleared * 10  # 10 points per piece cleared
		GameState.add_score(bomb_points)
		print("Bomb cleared ", pieces_cleared, " pieces for ", bomb_points, " points")

func check_and_clear_matches():
	clearing_matches = true
	var matches_found = false
	var visited = {}
	var pieces_to_clear = []
	
	# First pass: Find all colored matches (4+ connected same-color pieces)
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
				pieces_to_clear.append_array(group)
	
	# Second pass: Find bubbles adjacent to clearing pieces
	if matches_found:
		var bubbles_to_clear = []
		
		for clear_pos in pieces_to_clear:
			# Check all 4 adjacent positions for bubbles
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
					if adj_piece != null and adj_piece.is_bubble and not adj_pos in bubbles_to_clear:
						bubbles_to_clear.append(adj_pos)
		
		# Clear colored matches and adjacent bubbles
		clear_group(pieces_to_clear)
		clear_group(bubbles_to_clear)
		
		# Calculate base score (before multiplier)
		var base_points = 100 + bubbles_to_clear.size() * 50
		GameState.add_score(base_points)
		
		# Apply gravity after clearing
		apply_gravity()
		
		# Wait longer for animations to complete then check for chain reactions
		await get_tree().create_timer(0.5).timeout
		check_and_clear_matches()  # Recursive call for chains
	else:
		# No matches found, spawn next piece
		clearing_matches = false
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

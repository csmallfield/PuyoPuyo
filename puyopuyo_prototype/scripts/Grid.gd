extends Node2D
# Grid.gd - Manages the game grid and piece placement with bomb system

const BombController = preload("res://scripts/BombController.gd")

signal game_over
signal chain_bonus(chain_count)

const CELL_SIZE = 64
const LANDING_GRACE_PERIOD = 0.25
const BOMB_SHAKE_INTENSITY = 8.0
const Piece = preload("res://scenes/Piece.tscn")

var grid_data = []
var current_piece_pair = null
var next_piece_pair = null
var fall_timer = 0.0
var clearing_matches = false

var my_fall_speed = 1.0 

# Chain tracking
var current_chain_count = 0
var is_cascading = false

# Event tracking
var has_sent_attack = false  # Track first attack
var event_notification = null  # Reference to notification system

# Landing grace period
var landing_grace_timer = 0.0
var is_in_grace_period = false
var piece_has_landed = false

# Smooth falling
var smooth_fall_target_y = 0.0
var is_smooth_falling = false

# Camera shake
var original_position = Vector2.ZERO
var shake_timer = 0.0
var shake_duration = 0.0
var is_shaking = false
var enable_camera_shake = true

var enable_input = true

# Garbage/Nuisance system
signal garbage_sent(nuisance_points)
var incoming_garbage_points = 0
var pending_garbage_drop = false

# Piece sequence tracking
var my_sequence_index = 0

@onready var piece_pair_scene = preload("res://scenes/PiecePair.tscn")

func _ready():
	current_piece_pair = null
	next_piece_pair = null
	
	initialize_grid()
	original_position = Vector2(500, -10)
	position = original_position
	
	# Create event notification system
	var EventNotification = preload("res://scripts/EventNotification.gd")
	event_notification = EventNotification.new()
	add_child(event_notification)
	event_notification.position = Vector2(GameState.grid_width * CELL_SIZE / 2, GameState.grid_height * CELL_SIZE / 2)

func _draw():
	var playfield_start = GameState.playfield_start_row
	
	# Draw SPAWN ZONE grid lines (dimmed)
	var spawn_color = Color.GRAY
	spawn_color.a = 0.15
	
	for x in range(GameState.grid_width + 1):
		var start_pos = Vector2(x * CELL_SIZE, 0)
		var end_pos = Vector2(x * CELL_SIZE, playfield_start * CELL_SIZE)
		draw_line(start_pos, end_pos, spawn_color, 1)
	
	for y in range(playfield_start + 1):
		var start_pos = Vector2(0, y * CELL_SIZE)
		var end_pos = Vector2(GameState.grid_width * CELL_SIZE, y * CELL_SIZE)
		draw_line(start_pos, end_pos, spawn_color, 1)
	
	# Draw PLAYFIELD grid lines
	var grid_color = Color.GRAY
	grid_color.a = 0.3
	
	for x in range(GameState.grid_width + 1):
		var start_pos = Vector2(x * CELL_SIZE, playfield_start * CELL_SIZE)
		var end_pos = Vector2(x * CELL_SIZE, GameState.grid_height * CELL_SIZE)
		draw_line(start_pos, end_pos, grid_color, 1)
	
	for y in range(playfield_start, GameState.grid_height + 1):
		var start_pos = Vector2(0, y * CELL_SIZE)
		var end_pos = Vector2(GameState.grid_width * CELL_SIZE, y * CELL_SIZE)
		draw_line(start_pos, end_pos, grid_color, 1)
	
	# Draw border box
	var border_color = Color.WHITE
	var border_width = 3
	var playfield_y_start = playfield_start * CELL_SIZE
	var playfield_height = (GameState.grid_height - playfield_start) * CELL_SIZE
	var rect = Rect2(0, playfield_y_start, GameState.grid_width * CELL_SIZE, playfield_height)
	draw_rect(rect, border_color, false, border_width)

func _process(delta):
	if GameState.current_state != GameState.State.PLAYING:
		return
	
	# Handle camera shake
	if is_shaking:
		shake_timer += delta
		if shake_timer >= shake_duration:
			is_shaking = false
			position = original_position
		else:
			var shake_strength = (1.0 - (shake_timer / shake_duration)) * BOMB_SHAKE_INTENSITY
			var shake_offset = Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)
			position = original_position + shake_offset
		
	if current_piece_pair and not clearing_matches:
		if is_in_grace_period:
			landing_grace_timer += delta
			if landing_grace_timer >= LANDING_GRACE_PERIOD:
				force_place_piece()
		else:
			smooth_fall_piece(delta)

func smooth_fall_piece(delta):
	var pixels_per_second = CELL_SIZE / my_fall_speed
	var fall_distance = pixels_per_second * delta
	
	var current_pixel_pos = current_piece_pair.position
	var current_grid_pos = current_piece_pair.grid_position
	
	var in_spawn_zone = current_grid_pos.y < GameState.playfield_start_row
	
	var next_grid_pos = Vector2(current_grid_pos.x, current_grid_pos.y + 1)
	var can_fall_to_next = can_place_piece_pair(current_piece_pair, next_grid_pos)
	
	if can_fall_to_next:
		var target_pixel_y = current_pixel_pos.y + fall_distance
		var next_cell_center_y = next_grid_pos.y * CELL_SIZE + CELL_SIZE/2
		
		if target_pixel_y >= next_cell_center_y:
			current_piece_pair.set_grid_position(next_grid_pos)
			current_piece_pair.set_pixel_position(Vector2(current_pixel_pos.x, target_pixel_y))
		else:
			current_piece_pair.set_pixel_position(Vector2(current_pixel_pos.x, target_pixel_y))
		
		if is_in_grace_period:
			reset_landing_state()
	else:
		if in_spawn_zone:
			print("Game Over: Piece stuck in spawn zone at row ", current_grid_pos.y)
			emit_signal("game_over")
			return
		
		var current_cell_center_y = current_grid_pos.y * CELL_SIZE + CELL_SIZE/2
		
		if current_pixel_pos.y < current_cell_center_y:
			var distance_to_center = current_cell_center_y - current_pixel_pos.y
			var move_amount = min(fall_distance, distance_to_center)
			current_piece_pair.set_pixel_position(Vector2(current_pixel_pos.x, current_pixel_pos.y + move_amount))
		else:
			current_piece_pair.set_pixel_position(Vector2(current_pixel_pos.x, current_cell_center_y))
		
		if not piece_has_landed:
			start_grace_period()

func initialize_grid():
	grid_data = []
	for y in range(GameState.grid_height):
		var row = []
		for x in range(GameState.grid_width):
			row.append(null)
		grid_data.append(row)

func start_game():
	if current_piece_pair and is_instance_valid(current_piece_pair):
		current_piece_pair.queue_free()
		current_piece_pair = null
	if next_piece_pair and is_instance_valid(next_piece_pair):
		next_piece_pair.queue_free()
		next_piece_pair = null
	
	initialize_grid()
	clear_all_pieces()
	my_sequence_index = 0
	has_sent_attack = false  # NEW: Reset first attack tracking
	spawn_new_piece_pair()
	
func set_fall_speed(speed: float):
	my_fall_speed = speed

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
		current_piece_pair.set_piece_data_from_index(my_sequence_index)
		my_sequence_index += 1
	
	reset_landing_state()
	
	var start_pos = Vector2(GameState.grid_width / 2, 0)
	current_piece_pair.set_grid_position(start_pos)
	current_piece_pair.set_pixel_position(grid_to_pixel(start_pos))
	
	if not can_place_piece_pair(current_piece_pair, start_pos):
		emit_signal("game_over")
		return
	
	# NEW: Check for danger conditions
	check_danger_warning()
	
	next_piece_pair = piece_pair_scene.instantiate()
	next_piece_pair.set_piece_data_from_index(my_sequence_index)
	my_sequence_index += 1
	
	add_child(next_piece_pair)
	next_piece_pair.set_pixel_position(Vector2(500, 100))

func start_camera_shake(duration: float):
	if not enable_camera_shake:
		return
	
	is_shaking = true
	shake_timer = 0.0
	shake_duration = duration

func reset_landing_state():
	is_in_grace_period = false
	piece_has_landed = false
	landing_grace_timer = 0.0

func start_grace_period():
	if not is_in_grace_period:
		is_in_grace_period = true
		landing_grace_timer = 0.0
		piece_has_landed = true

func _input(event):
	if not enable_input:
		return
		
	if GameState.current_state != GameState.State.PLAYING or not current_piece_pair:
		return
		
	if event.is_action_pressed("move_left"):
		move_piece_horizontal(-1)
		if is_in_grace_period:
			landing_grace_timer = 0.0
	elif event.is_action_pressed("move_right"):
		move_piece_horizontal(1)
		if is_in_grace_period:
			landing_grace_timer = 0.0
	elif event.is_action_pressed("rotate_piece"):
		rotate_piece()
		if is_in_grace_period:
			landing_grace_timer = 0.0
	elif event.is_action_pressed("move_down"):
		move_piece_down()
	elif event.is_action_pressed("fast_drop"):
		fast_drop_piece()

func move_piece_horizontal(direction):
	if not current_piece_pair:
		return
	
	var new_pos = current_piece_pair.grid_position + Vector2(direction, 0)
	if can_place_piece_pair(current_piece_pair, new_pos):
		current_piece_pair.set_grid_position(new_pos)
		
		var current_pixel_pos = current_piece_pair.position
		var new_pixel_x = new_pos.x * CELL_SIZE + CELL_SIZE/2
		current_piece_pair.set_pixel_position(Vector2(new_pixel_x, current_pixel_pos.y))
		
		AudioManager.play_piece_move()
		
		var can_fall = can_place_piece_pair(current_piece_pair, new_pos + Vector2(0, 1))
		if can_fall and is_in_grace_period:
			reset_landing_state()

func move_piece_down():
	if not current_piece_pair:
		return
	
	var current_pixel_pos = current_piece_pair.position
	var new_pixel_y = current_pixel_pos.y + CELL_SIZE
	
	var new_grid_y = int((new_pixel_y - CELL_SIZE/2) / CELL_SIZE)
	var test_pos = Vector2(current_piece_pair.grid_position.x, new_grid_y)
	
	if can_place_piece_pair(current_piece_pair, test_pos):
		current_piece_pair.set_grid_position(test_pos)
		current_piece_pair.set_pixel_position(Vector2(current_pixel_pos.x, new_pixel_y))
		
		if is_in_grace_period:
			reset_landing_state()
	else:
		var locked_y = current_piece_pair.grid_position.y * CELL_SIZE + CELL_SIZE/2
		current_piece_pair.set_pixel_position(Vector2(current_pixel_pos.x, locked_y))
		
		if not piece_has_landed:
			start_grace_period()

func fast_drop_piece():
	if not current_piece_pair:
		return
	
	AudioManager.play_piece_hard_drop()
	
	if is_in_grace_period:
		force_place_piece()
		return
	
	var current_x = current_piece_pair.grid_position.x
	var test_y = current_piece_pair.grid_position.y
	
	while current_piece_pair:
		var test_pos = Vector2(current_x, test_y + 1)
		if can_place_piece_pair(current_piece_pair, test_pos):
			test_y += 1
		else:
			break
	
	if current_piece_pair:
		var final_pos = Vector2(current_x, test_y)
		current_piece_pair.set_grid_position(final_pos)
		current_piece_pair.set_pixel_position(grid_to_pixel(final_pos))
		place_piece_pair()

func force_place_piece():
	place_piece_pair()

func rotate_piece():
	if not current_piece_pair:
		return
	
	current_piece_pair.rotate_pieces()
	if not can_place_piece_pair(current_piece_pair, current_piece_pair.grid_position):
		current_piece_pair.rotate_pieces()
		current_piece_pair.rotate_pieces()
		current_piece_pair.rotate_pieces()
	else:
		AudioManager.play_piece_rotate()

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
	
	AudioManager.play_piece_land()
	
	reset_landing_state()
	
	current_chain_count = 0
	is_cascading = false
	
	# Get piece pair rotation for line bombs
	var piece_pair_rotation = current_piece_pair.piece_rotation
	var bomb_orientation = BombController.get_bomb_orientation_from_rotation(piece_pair_rotation)
	
	# Place pieces in grid
	for i in range(positions.size()):
		var pos = positions[i]
		var piece = pieces[i]
		if pos.y >= 0:
			piece.get_parent().remove_child(piece)
			add_child(piece)
			
			# Set line bomb orientation if applicable
			if piece.is_bomb() and piece.get_bomb_type() == BombController.BombType.LINE:
				piece.update_bomb_orientation(bomb_orientation)
			
			grid_data[pos.y][pos.x] = piece
			piece.set_position_immediately(grid_to_pixel(pos))
	
	current_piece_pair.queue_free()
	current_piece_pair = null
	
	# DROP GARBAGE if pending
	if pending_garbage_drop:
		await drop_garbage()
	
	# DECREMENT TIME BOMBS (every turn)
	var exploding_time_bombs = BombController.decrement_time_bombs(grid_data)
	if exploding_time_bombs.size() > 0:
		await activate_time_bombs(exploding_time_bombs)
	
	# Apply gravity
	apply_gravity()
	await get_tree().create_timer(0.4).timeout
	
	# Activate any bombs that settled
	await activate_bombs_after_gravity()
	
	# Check for matches
	check_and_clear_matches()

func activate_time_bombs(bomb_positions: Array):
	"""Activate time bombs that have reached zero"""
	print("Activating ", bomb_positions.size(), " time bombs")
	
	AudioManager.play_bomb_warning()
	
	var all_affected_pieces = []
	var all_affected_positions = []
	
	for bomb_pos in bomb_positions:
		var bomb_piece = grid_data[int(bomb_pos.y)][int(bomb_pos.x)]
		if bomb_piece and bomb_piece.is_bomb():
			var bomb_type = bomb_piece.get_bomb_type()
			var bomb_orientation = bomb_piece.bomb_orientation
			
			var affected = BombController.get_affected_positions(
				bomb_type,
				bomb_pos,
				grid_data,
				bomb_orientation
			)
			
			# Add bomb itself
			affected.append(bomb_pos)
			
			for piece_pos in affected:
				if not piece_pos in all_affected_positions:
					all_affected_positions.append(piece_pos)
					all_affected_pieces.append(grid_data[int(piece_pos.y)][int(piece_pos.x)])
	
	await create_blink_effect(all_affected_pieces)
	
	AudioManager.play_bomb_explode()
	start_camera_shake(0.4)
	await create_explosion_effect(all_affected_positions)
	
	var pieces_cleared = all_affected_positions.size()
	if pieces_cleared > 0:
		var bomb_points = pieces_cleared * 10
		GameState.add_score(bomb_points)
		print("Time bombs cleared ", pieces_cleared, " pieces for ", bomb_points, " points")

func activate_bombs_after_gravity():
	"""Find and activate all bombs that have landed"""
	var bombs_to_activate = []
	
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var piece = grid_data[y][x]
			if piece != null and piece.is_bomb():
				# Don't activate time bombs (they activate on countdown)
				if piece.get_bomb_type() != BombController.BombType.TIME:
					bombs_to_activate.append(Vector2(x, y))
	
	if bombs_to_activate.size() > 0:
		await activate_bombs_with_effects(bombs_to_activate)
		
		apply_gravity()
		await get_tree().create_timer(0.4).timeout

func activate_bombs_with_effects(bomb_positions: Array):
	"""Activate bombs with visual effects"""
	print("Activating ", bomb_positions.size(), " bombs with effects")
	
	AudioManager.play_bomb_warning()
	
	var all_affected_pieces = []
	var all_affected_positions = []
	
	for bomb_pos in bomb_positions:
		var bomb_piece = grid_data[int(bomb_pos.y)][int(bomb_pos.x)]
		if bomb_piece and bomb_piece.is_bomb():
			var bomb_type = bomb_piece.get_bomb_type()
			var bomb_orientation = bomb_piece.bomb_orientation
			
			var affected = BombController.get_affected_positions(
				bomb_type,
				bomb_pos,
				grid_data,
				bomb_orientation
			)
			
			# Add bomb itself to affected
			affected.append(bomb_pos)
			
			# Merge with total affected pieces
			for piece_pos in affected:
				if not piece_pos in all_affected_positions:
					all_affected_positions.append(piece_pos)
					all_affected_pieces.append(grid_data[int(piece_pos.y)][int(piece_pos.x)])
	
	# Blink effect
	await create_blink_effect(all_affected_pieces)
	
	# Explosion effect
	AudioManager.play_bomb_explode()
	start_camera_shake(0.4)
	await create_explosion_effect(all_affected_positions)
	
	# Award points
	var pieces_cleared = all_affected_positions.size()
	if pieces_cleared > 0:
		var bomb_points = pieces_cleared * 10
		GameState.add_score(bomb_points)
		print("Bombs cleared ", pieces_cleared, " pieces for ", bomb_points, " points")

func create_blink_effect(affected_pieces: Array):
	var blink_duration = 0.3
	var blink_count = 3
	var blink_interval = blink_duration / (blink_count * 2)
	
	var original_colors = []
	for piece in affected_pieces:
		if piece != null:
			original_colors.append(piece.color)
	
	for blink in range(blink_count):
		for i in range(affected_pieces.size()):
			var piece = affected_pieces[i]
			if piece != null:
				piece.modulate = Color.WHITE
		
		await get_tree().create_timer(blink_interval).timeout
		
		for i in range(affected_pieces.size()):
			var piece = affected_pieces[i]
			if piece != null:
				piece.modulate = Color(original_colors[i])
		
		await get_tree().create_timer(blink_interval).timeout

func create_explosion_effect(affected_positions: Array):
	var explosion_duration = 0.3
	var tweens = []
	
	for pos in affected_positions:
		var piece = grid_data[int(pos.y)][int(pos.x)]
		if piece != null:
			var tween = create_tween()
			tweens.append(tween)
			
			tween.tween_property(piece, "scale", Vector2(2.0, 2.0), explosion_duration * 0.4)
			tween.tween_property(piece, "scale", Vector2(0, 0), explosion_duration * 0.6)
			tween.parallel().tween_property(piece, "rotation", PI * 1.0, explosion_duration)
	
	if tweens.size() > 0:
		await tweens[0].finished
	
	for pos in affected_positions:
		if grid_data[int(pos.y)][int(pos.x)] != null:
			grid_data[int(pos.y)][int(pos.x)].queue_free()
			grid_data[int(pos.y)][int(pos.x)] = null

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
	var match_groups = []
	
	# Find all colored matches (4+ connected same-color pieces)
	# Skip time bombs - they can't be cleared by matches
	for y in range(GameState.grid_height):
		for x in range(GameState.grid_width):
			var pos = Vector2(x, y)
			
			if grid_data[y][x] == null or visited.has(pos) or grid_data[y][x].is_bubble:
				continue
			
			# Skip ALL bombs from normal matching
			if grid_data[y][x].is_bomb():
				continue
				
			var group = find_connected_group(pos, grid_data[y][x].color, visited)
			
			if group.size() >= 4:
				matches_found = true
				match_groups.append(group)
	
	if matches_found:
		current_chain_count += 1
		is_cascading = true
		
		# NEW: Show chain notification
		if event_notification:
			event_notification.show_chain_notification(current_chain_count)
		
		if current_chain_count >= 2:
			AudioManager.play_chain_sound(current_chain_count)
		
		var total_base_score = 0
		var total_pieces_cleared = 0
		var all_pieces_to_clear = []
		var all_bubbles_to_clear = []
		
		for group in match_groups:
			var match_size = group.size()
			var match_score = 100 + ((match_size - 4) * 10)
			total_base_score += match_score
			total_pieces_cleared += match_size
			
			print("Match of ", match_size, " pieces scores ", match_score, " points")
			
			all_pieces_to_clear.append_array(group)
			
			# Find bubbles adjacent to matches
			for clear_pos in group:
				var adjacent_positions = [
					clear_pos + Vector2(1, 0),
					clear_pos + Vector2(-1, 0),
					clear_pos + Vector2(0, 1),
					clear_pos + Vector2(0, -1)
				]
				
				for adj_pos in adjacent_positions:
					if adj_pos.x >= 0 and adj_pos.x < GameState.grid_width and adj_pos.y >= 0 and adj_pos.y < GameState.grid_height:
						var adj_piece = grid_data[int(adj_pos.y)][int(adj_pos.x)]
						if adj_piece != null and adj_piece.is_bubble and not adj_pos in all_bubbles_to_clear:
							all_bubbles_to_clear.append(adj_pos)
		
		var bubble_bonus = all_bubbles_to_clear.size() * 50
		total_base_score += bubble_bonus
		total_pieces_cleared += all_bubbles_to_clear.size()
		
		var chain_bonus = current_chain_count * 100
		total_base_score += chain_bonus
		
		print("Chain ", current_chain_count, " - Base score: ", total_base_score, " (includes ", chain_bonus, " chain bonus)")
		
		if current_chain_count >= 2:
			emit_signal("chain_bonus", current_chain_count)
		
		calculate_and_send_garbage(total_pieces_cleared, current_chain_count)
		
		await clear_group(all_pieces_to_clear)
		
		if all_bubbles_to_clear.size() > 0:
			AudioManager.play_bubble_pop()
			await clear_group(all_bubbles_to_clear)
		
		GameState.add_score(total_base_score)
		
		AudioManager.play_pieces_fall()
		apply_gravity()
		
		await get_tree().create_timer(0.4).timeout
		
		AudioManager.play_pieces_settle()
		
		check_and_clear_matches()
	else:
		clearing_matches = false
		is_cascading = false
		current_chain_count = 0
		
		# NEW: Check for All Clear bonus
		if is_board_empty():
			award_all_clear_bonus()
		
		if check_spawn_zone_overflow():
			return
		
		spawn_new_piece_pair()

func calculate_and_send_garbage(pieces_cleared: int, chain_number: int):
	var base_points = pieces_cleared * GameState.nuisance_points_per_piece
	var chain_multiplier = GameState.get_chain_multiplier(chain_number)
	var nuisance_generated = base_points * chain_multiplier
	
	print("Generated ", nuisance_generated, " nuisance points (", pieces_cleared, " pieces × ", chain_multiplier, "x chain)")
	
	if incoming_garbage_points > 0:
		if nuisance_generated >= incoming_garbage_points:
			var leftover = nuisance_generated - incoming_garbage_points
			print("Offset: Cleared ", incoming_garbage_points, " incoming garbage, sending ", leftover, " to opponent")
			incoming_garbage_points = 0
			pending_garbage_drop = false
			
			if leftover > 0:
				AudioManager.play_attack_sent()
				
				# NEW: Check for first attack bonus
				if not has_sent_attack:
					has_sent_attack = true
					award_first_attack_bonus()
				
				emit_signal("garbage_sent", leftover)
		else:
			incoming_garbage_points -= nuisance_generated
			print("Offset: Reduced incoming garbage to ", incoming_garbage_points)
	else:
		print("Sending ", nuisance_generated, " nuisance points to opponent")
		AudioManager.play_attack_sent()
		
		# NEW: Check for first attack bonus
		if not has_sent_attack:
			has_sent_attack = true
			award_first_attack_bonus()
		
		emit_signal("garbage_sent", nuisance_generated)

func receive_garbage(nuisance_points: int):
	incoming_garbage_points += nuisance_points
	pending_garbage_drop = true
	print("Received ", nuisance_points, " nuisance points. Total incoming: ", incoming_garbage_points)
	AudioManager.play_garbage_incoming()
	
	# NEW: Show garbage warning notification
	var garbage_rows = int(incoming_garbage_points / GameState.nuisance_points_per_garbage_row)
	if garbage_rows > 0 and event_notification:
		event_notification.show_garbage_warning(garbage_rows)

func drop_garbage():
	if incoming_garbage_points <= 0:
		pending_garbage_drop = false
		return
	
	var garbage_count = int(incoming_garbage_points / GameState.nuisance_points_per_garbage_row) * GameState.grid_width
	var leftover_points = incoming_garbage_points % GameState.nuisance_points_per_garbage_row
	
	incoming_garbage_points = leftover_points
	
	if garbage_count <= 0:
		pending_garbage_drop = false
		return
	
	print("Dropping ", garbage_count, " garbage bubbles")
	
	var garbage_rows = garbage_count / GameState.grid_width
	AudioManager.play_garbage_drop(garbage_rows)
	
	var full_rows = garbage_count / GameState.grid_width
	var remaining_bubbles = garbage_count % GameState.grid_width
	
	var available_columns = []
	for x in range(GameState.grid_width):
		available_columns.append(x)
	available_columns.shuffle()
	
	for x in range(GameState.grid_width):
		var bubbles_in_column = full_rows
		
		if x < remaining_bubbles:
			bubbles_in_column += 1
		
		for i in range(bubbles_in_column):
			var bubble = Piece.instantiate()
			add_child(bubble)
			bubble.set_as_bubble()
			
			var drop_y = -1
			for y in range(GameState.grid_height):
				if grid_data[y][x] == null:
					drop_y = y
					break
			
			if drop_y >= 0:
				grid_data[drop_y][x] = bubble
				bubble.set_position_immediately(grid_to_pixel(Vector2(x, drop_y)))
	
	pending_garbage_drop = false
	
	apply_gravity()
	await get_tree().create_timer(0.4).timeout
	
func get_garbage_meter_fill() -> float:
	if incoming_garbage_points <= 0:
		return 0.0
	
	var rows_worth = float(incoming_garbage_points) / float(GameState.nuisance_points_per_garbage_row)
	return min(rows_worth / 10.0, 1.0)

func get_garbage_row_count() -> int:
	return int(incoming_garbage_points / GameState.nuisance_points_per_garbage_row)

func find_connected_group(start_pos, color, visited):
	var group = []
	var stack = [start_pos]
	
	while stack.size() > 0:
		var pos = stack.pop_back()
		
		if visited.has(pos):
			continue
			
		if pos.x < 0 or pos.x >= GameState.grid_width or pos.y < 0 or pos.y >= GameState.grid_height:
			continue
			
		# Skip bombs and bubbles
		if grid_data[int(pos.y)][int(pos.x)] == null or grid_data[int(pos.y)][int(pos.x)].color != color:
			continue
		if grid_data[int(pos.y)][int(pos.x)].is_bubble or grid_data[int(pos.y)][int(pos.x)].is_bomb():
			continue
		
		visited[pos] = true
		group.append(pos)
		
		stack.append(pos + Vector2(1, 0))
		stack.append(pos + Vector2(-1, 0))
		stack.append(pos + Vector2(0, 1))
		stack.append(pos + Vector2(0, -1))
	
	return group

func clear_group(group):
	var group_size = group.size()
	if group_size > 0:
		AudioManager.play_match_pop(group_size)
	
	var pop_duration = 0.25
	var tweens = []
	
	for pos in group:
		var piece = grid_data[int(pos.y)][int(pos.x)]
		if piece:
			var tween = create_tween()
			tweens.append(tween)
			
			tween.tween_property(piece, "scale", Vector2(1.5, 1.5), pop_duration * 0.3)
			tween.tween_property(piece, "scale", Vector2(0, 0), pop_duration * 0.7)
			tween.parallel().tween_property(piece, "rotation", PI * 0.5, pop_duration)
	
	if tweens.size() > 0:
		await tweens[0].finished
	
	for pos in group:
		if grid_data[int(pos.y)][int(pos.x)]:
			grid_data[int(pos.y)][int(pos.x)].queue_free()
			grid_data[int(pos.y)][int(pos.x)] = null

func apply_gravity():
	var something_fell = true
	
	while something_fell:
		something_fell = false
		
		for x in range(GameState.grid_width):
			for y in range(GameState.grid_height - 2, -1, -1):
				if grid_data[y][x] != null:
					var target_y = y
					
					while target_y + 1 < GameState.grid_height and grid_data[target_y + 1][x] == null:
						target_y += 1
					
					if target_y != y:
						var piece = grid_data[y][x]
						grid_data[y][x] = null
						grid_data[target_y][x] = piece
						piece.animate_to_position(grid_to_pixel(Vector2(x, target_y)))
						something_fell = true

func grid_to_pixel(grid_pos):
	return Vector2(grid_pos.x * CELL_SIZE + CELL_SIZE/2, grid_pos.y * CELL_SIZE + CELL_SIZE/2)

func is_grid_active():
	return GameState.current_state == GameState.State.PLAYING and not clearing_matches

func check_spawn_zone_overflow():
	for y in range(GameState.playfield_start_row):
		for x in range(GameState.grid_width):
			if grid_data[y][x] != null:
				print("Game Over: Piece in spawn zone at row ", y, " col ", x)
				emit_signal("game_over")
				return true
	return false
	
func is_board_empty() -> bool:
	"""Check if the board is completely empty"""
	for y in range(GameState.playfield_start_row, GameState.grid_height):
		for x in range(GameState.grid_width):
			if grid_data[y][x] != null:
				return false
	return true

func award_first_attack_bonus():
	"""Award bonus for first attack"""
	var bonus_points = 1000
	GameState.add_score(bonus_points)
	print("First Attack Bonus: ", bonus_points, " points!")
	
	if event_notification:
		event_notification.show_first_attack_notification()

func award_all_clear_bonus():
	"""Award bonus for clearing the entire board"""
	var bonus_points = 2000
	GameState.add_score(bonus_points)
	print("All Clear Bonus: ", bonus_points, " points!")
	
	if event_notification:
		event_notification.show_all_clear_notification()
		
func check_danger_warning():
	"""Check if board is in danger and show warning"""
	var max_height = get_max_column_height()
	var avg_height = get_average_column_height()
	
	# Show danger warning if board is getting critically full
	if max_height >= 11 or avg_height >= 10:
		if event_notification:
			event_notification.show_danger_warning()
			
func get_max_column_height() -> int:
	"""Get the maximum column height on the board"""
	var max_h = 0
	for x in range(GameState.grid_width):
		var h = 0
		for y in range(GameState.grid_height):
			if grid_data[y][x] != null:
				h = GameState.grid_height - y
				break
		if h > max_h:
			max_h = h
	return max_h

func get_average_column_height() -> float:
	"""Get the average column height"""
	var total = 0.0
	for x in range(GameState.grid_width):
		for y in range(GameState.grid_height):
			if grid_data[y][x] != null:
				total += GameState.grid_height - y
				break
	return total / float(GameState.grid_width)

extends Node
# GameState.gd - Manages overall game state and settings

signal game_over
signal score_changed(new_score)
signal level_changed(new_level)

enum State {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

var current_state = State.MENU
var score = 0
var level = 1
var lines_cleared = 0
var base_score = 0  # Score before multiplier

# Game settings
var grid_width = 6
var grid_height = 14  # Total height including 2-row spawn zone
var playfield_start_row = 2  # Main playfield starts at row 2 (rows 0-1 are spawn zone)
var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
var bubble_color = Color.GRAY
var bomb_color = Color.BLACK
var bubble_spawn_chance = 0.15  # 15% chance for one piece in a pair to be a bubble
var bomb_spawn_chance = 0.02  # 2% chance for one piece in a pair to be a bomb 

var allow_bubble_pieces = true  # Toggle to disable bubbles in piece pairs

# Game mode presets
enum GameMode {
	SINGLE_PLAYER,
	VS_MODE
}

var current_game_mode = GameMode.SINGLE_PLAYER


# Speed level system - easily tunable arrays
var level_thresholds = [
	0,      # Level 1
	3000,    # Level 2 - harder to reach
	6000,   # Level 3
	10000,   # Level 4
	14000,   # Level 5
	18000,   # Level 6
	21000,  # Level 7
	35000,  # Level 8
	50000,  # Level 9
	75000   # Level 10
]

var level_speeds = [
	1.00,    # Level 1
	0.75,   # Level 2 - faster jump
	0.55,   # Level 3
	0.4,    # Level 4
	0.3,    # Level 5
	0.22,   # Level 6
	0.16,   # Level 7
	0.12,   # Level 8
	0.09,   # Level 9
	0.07    # Level 10 - extremely fast!
]

var level_multipliers = [
	1.0,    # Level 1
	1.2,    # Level 2
	1.5,    # Level 3
	1.8,    # Level 4
	2.2,    # Level 5
	2.6,    # Level 6
	3.0,    # Level 7
	3.5,    # Level 8
	4.0,    # Level 9
	5.0     # Level 10
]

# Animation settings
var piece_fall_speed = 400.0  # pixels per second for smooth falling
var use_sprites = true  # Set to true to use sprite files instead of generated circles
var sprite_paths = {
	Color.RED: "res://assets/red_piece.png",
	Color.BLUE: "res://assets/blue_piece.png", 
	Color.GREEN: "res://assets/green_piece.png",
	Color.YELLOW: "res://assets/yellow_piece.png",
	Color.GRAY: "res://assets/bubble_piece.png",
	Color.BLACK: "res://assets/bomb_piece.png"
}

# Piece sequence management for VS mode
var piece_sequence = []  # Queue of pre-generated piece pairs
var sequence_index = 0   # Current position in sequence
var generate_ahead = 50  # How many pieces to generate ahead

# Nuisance/Garbage system settings
var nuisance_points_per_piece = 8
var nuisance_points_per_garbage_row = 75

# Level-up attack system (VS mode)
var enable_level_up_attacks = true  # Toggle level-up garbage on/off
var level_up_attack_multiplier = 30  # Base nuisance points per level

# Chain multipliers - exponential scaling for powerful chains
var chain_multipliers = [
	0, 1, 2, 4, 8, 16, 30, 42, 56 #Need a lot of chains
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_score(points):
	# Add base points and calculate multiplied score
	base_score += points
	var multiplied_points = points * get_current_multiplier()
	score += multiplied_points
	
	# Check for level up
	check_level_progression()
	
	emit_signal("score_changed", score)

func check_level_progression():
	# Find the appropriate level based on score
	var new_level = 1
	for i in range(level_thresholds.size() - 1, -1, -1):
		if score >= level_thresholds[i]:
			new_level = i + 1
			break
	
	# If level changed, emit signal
	if new_level != level:
		level = new_level
		emit_signal("level_changed", level)

func reset_game():
	score = 0
	base_score = 0
	level = 1
	lines_cleared = 0
	current_state = State.PLAYING
	emit_signal("score_changed", score)
	emit_signal("level_changed", level)
	start_piece_sequence()

func configure_for_game_mode(mode: GameMode):
	"""Configure piece generation for different game modes"""
	current_game_mode = mode
	
	match mode:
		GameMode.SINGLE_PLAYER:
			configure_single_player_mode()
		GameMode.VS_MODE:
			configure_vs_mode()

func configure_single_player_mode():
	"""Standard single player settings"""
	allow_bubble_pieces = true
	bubble_spawn_chance = 0.15  # 15%
	bomb_spawn_chance = 0.02    # 2%

func configure_vs_mode():
	"""VS mode settings - no bubbles in pairs, more bombs"""
	allow_bubble_pieces = false  # Bubbles only come from garbage
	bubble_spawn_chance = 0.0    # No bubbles in piece generation
	bomb_spawn_chance = 0.05     # 5% chance (increased from 2%)


func set_state(new_state):
	current_state = new_state
	if new_state == State.GAME_OVER:
		emit_signal("game_over")

func get_fall_speed():
	# Return the speed for the current level
	if level <= level_speeds.size():
		return level_speeds[level - 1]
	else:
		return level_speeds[level_speeds.size() - 1]  # Cap at max speed

func get_current_multiplier():
	# Return the multiplier for the current level
	if level <= level_multipliers.size():
		return level_multipliers[level - 1]
	else:
		return level_multipliers[level_multipliers.size() - 1]  # Cap at max multiplier

func get_chain_multiplier(chain_count: int) -> int:
	"""Get the multiplier for a given chain count"""
	if chain_count < chain_multipliers.size():
		return chain_multipliers[chain_count]
	else:
		return chain_multipliers[chain_multipliers.size() - 1]  # Cap at max

func get_level_up_attack_nuisance(level: int) -> int:
	"""Calculate nuisance points to send when leveling up"""
	if not enable_level_up_attacks:
		return 0
	
	# Scale linearly with level
	return level * level_up_attack_multiplier

func get_next_level_threshold():
	# Return points needed for next level
	if level < level_thresholds.size():
		return level_thresholds[level]
	else:
		return -1  # Max level reached

func get_points_to_next_level():
	# Return how many points until next level
	var next_threshold = get_next_level_threshold()
	if next_threshold > 0:
		return next_threshold - score
	else:
		return 0  # Max level reached

func get_speed_display_text():
	# Return a formatted string showing the current speed
	var speed = get_fall_speed()
	return "Speed: " + str(speed) + "s"

func get_level_display_text():
	# Return a formatted string showing the current level
	return "Level " + str(level)
	
func start_piece_sequence():
	"""Initialize a new piece sequence for a game"""
	piece_sequence = []
	sequence_index = 0
	generate_piece_sequence()

func generate_piece_sequence():
	"""Generate a batch of piece pairs ahead of time"""
	for i in range(generate_ahead):
		var piece_data = generate_piece_pair_data()
		piece_sequence.append(piece_data)

func generate_piece_pair_data():
	"""Generate data for one piece pair (colors and special types)"""
	var pair_data = {
		"piece1": {},
		"piece2": {}
	}
	
	# Generate piece1
	var rand1 = randf()
	var piece1_is_bomb = rand1 < bomb_spawn_chance
	
	if piece1_is_bomb:
		pair_data.piece1.type = "bomb"
		pair_data.piece1.color = bomb_color
	else:
		var piece1_is_bubble = allow_bubble_pieces and (randf() < bubble_spawn_chance)
		if piece1_is_bubble:
			pair_data.piece1.type = "bubble"
			pair_data.piece1.color = bubble_color
		else:
			pair_data.piece1.type = "normal"
			pair_data.piece1.color = colors[randi() % colors.size()]
	
	# Generate piece2 (ensure no bomb+bomb pairs)
	var piece2_is_bomb = false
	if not piece1_is_bomb:
		var rand2 = randf()
		piece2_is_bomb = rand2 < bomb_spawn_chance
	
	if piece2_is_bomb:
		pair_data.piece2.type = "bomb"
		pair_data.piece2.color = bomb_color
	else:
		var piece2_is_bubble = allow_bubble_pieces and (randf() < bubble_spawn_chance)
		if piece2_is_bubble:
			pair_data.piece2.type = "bubble"
			pair_data.piece2.color = bubble_color
		else:
			pair_data.piece2.type = "normal"
			pair_data.piece2.color = colors[randi() % colors.size()]
	
	return pair_data

func get_next_piece_pair_data():
	"""Get the next piece pair from the sequence"""
	# If we're running low, generate more
	if sequence_index >= piece_sequence.size() - 10:
		generate_piece_sequence()
	
	var data = piece_sequence[sequence_index]
	sequence_index += 1
	return data
	
func get_piece_pair_data_at_index(index: int):
	"""Get a specific piece pair from the sequence by index"""
	# If we need more pieces, generate them
	while index >= piece_sequence.size():
		generate_piece_sequence()
	
	return piece_sequence[index]

func reset_piece_sequence():
	"""Reset the piece sequence (for new games)"""
	piece_sequence = []
	sequence_index = 0

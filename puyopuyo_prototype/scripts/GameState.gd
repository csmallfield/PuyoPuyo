extends Node
# GameState.gd - Manages overall game state and settings (Multi-Player Support)

signal game_over
signal player_score_changed(player_id, new_score)
signal player_level_changed(player_id, new_level)
signal round_ended(winner_player_id)

enum State {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

enum GameMode {
	SINGLE_PLAYER,
	VS_AI,
	VS_HUMAN  # For future network play
}

var current_state = State.MENU
var current_game_mode = GameMode.SINGLE_PLAYER

# Multi-player data - arrays indexed by player_id
var player_scores = []
var player_levels = []
var player_base_scores = []  # Score before multiplier
var lines_cleared = []

# Single player compatibility (player 0)
var score: int:
	get:
		if player_scores.size() > 0:
			return player_scores[0]
		return 0
var level: int:
	get:
		if player_levels.size() > 0:
			return player_levels[0]
		return 1
var base_score: int:
	get:
		if player_base_scores.size() > 0:
			return player_base_scores[0]
		return 0

# Game settings
var grid_width = 6
var grid_height = 12
var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
var bubble_color = Color.GRAY
var bomb_color = Color.BLACK
var bubble_spawn_chance = 0.15  # 15% chance for one piece in a pair to be a bubble
var bomb_spawn_chance = 0.02  # 2% chance for one piece in a pair to be a bomb 

# Speed level system - easily tunable arrays
var level_thresholds = [
	0,      # Level 1
	500,    # Level 2
	1200,   # Level 3
	2000,   # Level 4
	3000,   # Level 5
	4500,   # Level 6
	6500,   # Level 7
	9000,   # Level 8
	12000,  # Level 9
	16000   # Level 10
]

var level_speeds = [
	1.0,    # Level 1
	0.85,   # Level 2
	0.7,    # Level 3
	0.55,   # Level 4
	0.45,   # Level 5
	0.35,   # Level 6
	0.28,   # Level 7
	0.22,   # Level 8
	0.18,   # Level 9
	0.15    # Level 10
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

# AI Configuration
var ai_think_time_min = 0.3  # Minimum time AI takes to decide
var ai_think_time_max = 0.8  # Maximum time AI takes to decide  
var ai_move_speed = 0.15     # Time between AI input actions
var ai_reaction_delay = 0.2  # Delay before AI starts moving new piece

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

# Initialize players for different game modes
func initialize_players(game_mode: GameMode):
	current_game_mode = game_mode
	
	var player_count = 1
	if game_mode == GameMode.VS_AI or game_mode == GameMode.VS_HUMAN:
		player_count = 2
	
	# Initialize player arrays
	player_scores.clear()
	player_levels.clear()
	player_base_scores.clear()
	lines_cleared.clear()
	
	for i in range(player_count):
		player_scores.append(0)
		player_levels.append(1)
		player_base_scores.append(0)
		lines_cleared.append(0)

# Multi-player score management
func add_score_for_player(player_id: int, points: int):
	if player_id >= player_scores.size():
		print("Error: Invalid player_id ", player_id)
		return
	
	# Add base points and calculate multiplied score
	player_base_scores[player_id] += points
	var multiplied_points = points * get_current_multiplier_for_player(player_id)
	player_scores[player_id] += multiplied_points
	
	# Check for level up
	check_level_progression_for_player(player_id)
	
	emit_signal("player_score_changed", player_id, player_scores[player_id])

# Backward compatibility method
func add_score(points: int):
	add_score_for_player(0, points)

func check_level_progression_for_player(player_id: int):
	if player_id >= player_scores.size():
		return
	
	# Find the appropriate level based on score
	var new_level = 1
	for i in range(level_thresholds.size() - 1, -1, -1):
		if player_scores[player_id] >= level_thresholds[i]:
			new_level = i + 1
			break
	
	# If level changed, emit signal
	if new_level != player_levels[player_id]:
		player_levels[player_id] = new_level
		emit_signal("player_level_changed", player_id, new_level)

func reset_game():
	# Reset for current game mode
	if current_game_mode == GameMode.SINGLE_PLAYER:
		initialize_players(GameMode.SINGLE_PLAYER)
	else:
		# Reset multi-player scores but keep player count
		var player_count = player_scores.size()
		for i in range(player_count):
			player_scores[i] = 0
			player_base_scores[i] = 0
			player_levels[i] = 1
			lines_cleared[i] = 0
			emit_signal("player_score_changed", i, 0)
			emit_signal("player_level_changed", i, 1)
	
	current_state = State.PLAYING

func set_state(new_state):
	current_state = new_state
	if new_state == State.GAME_OVER:
		emit_signal("game_over")

# Round management for VS modes
func end_round(winner_player_id: int):
	current_state = State.GAME_OVER
	emit_signal("round_ended", winner_player_id)

# Player-specific getters
func get_fall_speed_for_player(player_id: int) -> float:
	if player_id >= player_levels.size():
		return level_speeds[0]
	
	var level = player_levels[player_id]
	if level <= level_speeds.size():
		return level_speeds[level - 1]
	else:
		return level_speeds[level_speeds.size() - 1]

func get_current_multiplier_for_player(player_id: int) -> float:
	if player_id >= player_levels.size():
		return level_multipliers[0]
	
	var level = player_levels[player_id]
	if level <= level_multipliers.size():
		return level_multipliers[level - 1]
	else:
		return level_multipliers[level_multipliers.size() - 1]

func get_next_level_threshold_for_player(player_id: int) -> int:
	if player_id >= player_levels.size():
		return level_thresholds[1] if level_thresholds.size() > 1 else -1
	
	var level = player_levels[player_id]
	if level < level_thresholds.size():
		return level_thresholds[level]
	else:
		return -1  # Max level reached

func get_points_to_next_level_for_player(player_id: int) -> int:
	var next_threshold = get_next_level_threshold_for_player(player_id)
	if next_threshold > 0 and player_id < player_scores.size():
		return next_threshold - player_scores[player_id]
	else:
		return 0  # Max level reached

# Backward compatibility methods
func get_fall_speed() -> float:
	return get_fall_speed_for_player(0)

func get_current_multiplier() -> float:
	return get_current_multiplier_for_player(0)

func get_next_level_threshold() -> int:
	return get_next_level_threshold_for_player(0)

func get_points_to_next_level() -> int:
	return get_points_to_next_level_for_player(0)

func get_speed_display_text_for_player(player_id: int) -> String:
	var speed = get_fall_speed_for_player(player_id)
	return "Speed: " + str(speed) + "s"

func get_level_display_text_for_player(player_id: int) -> String:
	if player_id >= player_levels.size():
		return "Level 1"
	return "Level " + str(player_levels[player_id])

# Backward compatibility methods
func get_speed_display_text() -> String:
	return get_speed_display_text_for_player(0)

func get_level_display_text() -> String:
	return get_level_display_text_for_player(0)

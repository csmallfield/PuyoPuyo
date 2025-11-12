extends Node
# GameState.gd - Manages overall game state and settings

const BombController = preload("res://scripts/BombController.gd")

signal game_over
signal score_changed(new_score)
signal level_changed(new_level)

enum State {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

enum BombScenario {
	SINGLE,      # One specific bomb type
	ALL_BOMBS,   # Any bomb type can appear
	LINE_CROSS   # Only line or cross bombs
}

var current_state = State.MENU
var score = 0
var level = 1
var lines_cleared = 0
var base_score = 0

# Game settings
var grid_width = 6
var grid_height = 14
var playfield_start_row = 2
var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
var bubble_color = Color.GRAY
var bomb_color = Color.BLACK
var bubble_spawn_chance = 0.15
var bomb_spawn_chance = 0.05

var allow_bubble_pieces = true

# Bomb type selection
var bomb_scenario = BombScenario.SINGLE
var current_bomb_type = BombController.BombType.NORMAL

# Bomb cooldown system (only affects bombs, not bubbles)
var bomb_cooldown_pieces = 15  # Minimum pieces between bombs
var bomb_guarantee_pieces = 50  # Force spawn if no bomb in this many pieces
var pieces_since_last_bomb = 0  # Counter for cooldown tracking

# Game mode presets
enum GameMode {
	SINGLE_PLAYER,
	VS_MODE
}

var current_game_mode = GameMode.SINGLE_PLAYER

# Speed level system
var level_thresholds = [
	0, 3000, 6000, 10000, 14000, 18000, 21000, 35000, 50000, 75000
]

var level_speeds = [
	1.00, 0.75, 0.55, 0.4, 0.3, 0.22, 0.16, 0.12, 0.09, 0.07
]

var level_multipliers = [
	1.0, 1.2, 1.5, 1.8, 2.2, 2.6, 3.0, 3.5, 4.0, 5.0
]

# Animation settings
var piece_fall_speed = 400.0
var use_sprites = true
#var sprite_paths = {
#	Color.RED: "res://assets/red_piece.png",
#	Color.BLUE: "res://assets/blue_piece.png", 
#	Color.GREEN: "res://assets/green_piece.png",
#	Color.YELLOW: "res://assets/yellow_piece.png",
#	Color.GRAY: "res://assets/bubble_piece.png",
#	Color.BLACK: "res://assets/bomb_piece.png"
#}

# Piece sequence management
var piece_sequence = []
var sequence_index = 0
var generate_ahead = 50

# Nuisance/Garbage system
var nuisance_points_per_piece = 8
var nuisance_points_per_garbage_row = 75

# Level-up attack system
var enable_level_up_attacks = true
var level_up_attack_multiplier = 30

# Chain multipliers
var chain_multipliers = [
	0, 1, 2, 4, 8, 16, 30, 42, 56
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_score(points):
	base_score += points
	var multiplied_points = points * get_current_multiplier()
	score += multiplied_points
	
	check_level_progression()
	emit_signal("score_changed", score)

func check_level_progression():
	var new_level = 1
	for i in range(level_thresholds.size() - 1, -1, -1):
		if score >= level_thresholds[i]:
			new_level = i + 1
			break
	
	if new_level != level:
		level = new_level
		emit_signal("level_changed", level)

func reset_game():
	score = 0
	base_score = 0
	level = 1
	lines_cleared = 0
	current_state = State.PLAYING
	pieces_since_last_bomb = 0  # Reset bomb cooldown counter
	emit_signal("score_changed", score)
	emit_signal("level_changed", level)
	start_piece_sequence()

func configure_for_game_mode(mode: GameMode):
	current_game_mode = mode
	
	match mode:
		GameMode.SINGLE_PLAYER:
			configure_single_player_mode()
		GameMode.VS_MODE:
			configure_vs_mode()

func configure_single_player_mode():
	allow_bubble_pieces = true
	bubble_spawn_chance = 0.15
	bomb_spawn_chance = 0.08
	bomb_cooldown_pieces = 15
	bomb_guarantee_pieces = 25

func configure_vs_mode():
	allow_bubble_pieces = false
	bubble_spawn_chance = 0.0
	bomb_spawn_chance = 0.15
	bomb_cooldown_pieces = 12  # Faster bomb spawning in VS mode
	bomb_guarantee_pieces = 20

func set_bomb_mode(mode_index: int):
	"""Set bomb mode based on cycle index (0-7)"""
	match mode_index:
		0:  # No Bombs
			bomb_scenario = BombScenario.SINGLE
			current_bomb_type = BombController.BombType.NONE
		1:  # Color Bomb
			bomb_scenario = BombScenario.SINGLE
			current_bomb_type = BombController.BombType.NORMAL
		2:  # Line Bomb
			bomb_scenario = BombScenario.SINGLE
			current_bomb_type = BombController.BombType.LINE
		3:  # Time Bomb
			bomb_scenario = BombScenario.SINGLE
			current_bomb_type = BombController.BombType.TIME
		4:  # Cross Bomb
			bomb_scenario = BombScenario.SINGLE
			current_bomb_type = BombController.BombType.CROSS
		5:  # Area Bomb
			bomb_scenario = BombScenario.SINGLE
			current_bomb_type = BombController.BombType.AREA
		6:  # All Bombs
			bomb_scenario = BombScenario.ALL_BOMBS
			current_bomb_type = BombController.BombType.NORMAL  # Fallback
		7:  # Line & Cross
			bomb_scenario = BombScenario.LINE_CROSS
			current_bomb_type = BombController.BombType.LINE  # Fallback
	
	print("Bomb mode set to: ", get_bomb_mode_name(mode_index))

func get_bomb_mode_name(mode_index: int) -> String:
	"""Get display name for bomb mode cycle"""
	match mode_index:
		0: return "No Bombs"
		1: return "Color Bomb"
		2: return "Line Bomb"
		3: return "Time Bomb"
		4: return "Cross Bomb"
		5: return "Area Bomb"
		6: return "All Bombs"
		7: return "Line & Cross"
		_: return "Unknown"

func set_bomb_scenario(scenario: int):
	"""Set the bomb scenario for the game session"""
	bomb_scenario = scenario
	print("Bomb scenario set to: ", get_bomb_scenario_name(scenario))

func set_bomb_type(bomb_type: int):
	"""Set the current bomb type for the game session (only used in SINGLE scenario)"""
	current_bomb_type = bomb_type
	print("Bomb type set to: ", BombController.get_bomb_type_name(bomb_type))

func get_bomb_scenario_name(scenario: int) -> String:
	match scenario:
		BombScenario.SINGLE:
			return "Single Type"
		BombScenario.ALL_BOMBS:
			return "All Bombs"
		BombScenario.LINE_CROSS:
			return "Line & Cross"
		_:
			return "Unknown"

func get_random_bomb_type_for_scenario() -> int:
	"""Get a random bomb type based on current scenario"""
	match bomb_scenario:
		BombScenario.SINGLE:
			return current_bomb_type
		BombScenario.ALL_BOMBS:
			# Random from all bomb types (excluding NONE)
			var types = [
				BombController.BombType.NORMAL,
				BombController.BombType.LINE,
				BombController.BombType.TIME,
				BombController.BombType.CROSS,
				BombController.BombType.AREA
			]
			return types[randi() % types.size()]
		BombScenario.LINE_CROSS:
			# Random between LINE and CROSS only
			var types = [
				BombController.BombType.LINE,
				BombController.BombType.CROSS
			]
			return types[randi() % types.size()]
	
	return current_bomb_type

func set_state(new_state):
	current_state = new_state
	if new_state == State.GAME_OVER:
		emit_signal("game_over")

func get_fall_speed():
	if level <= level_speeds.size():
		return level_speeds[level - 1]
	else:
		return level_speeds[level_speeds.size() - 1]

func get_current_multiplier():
	if level <= level_multipliers.size():
		return level_multipliers[level - 1]
	else:
		return level_multipliers[level_multipliers.size() - 1]

func get_chain_multiplier(chain_count: int) -> int:
	if chain_count < chain_multipliers.size():
		return chain_multipliers[chain_count]
	else:
		return chain_multipliers[chain_multipliers.size() - 1]

func get_level_up_attack_nuisance(level: int) -> int:
	if not enable_level_up_attacks:
		return 0
	return level * level_up_attack_multiplier

func get_next_level_threshold():
	if level < level_thresholds.size():
		return level_thresholds[level]
	else:
		return -1

func get_points_to_next_level():
	var next_threshold = get_next_level_threshold()
	if next_threshold > 0:
		return next_threshold - score
	else:
		return 0

func get_speed_display_text():
	var speed = get_fall_speed()
	return "Speed: " + str(speed) + "s"

func get_level_display_text():
	return "Level " + str(level)
	
func start_piece_sequence():
	piece_sequence = []
	sequence_index = 0
	pieces_since_last_bomb = 0  # Reset cooldown counter
	generate_piece_sequence()

func generate_piece_sequence():
	for i in range(generate_ahead):
		var piece_data = generate_piece_pair_data()
		piece_sequence.append(piece_data)

func generate_piece_pair_data():
	var pair_data = {
		"piece1": {},
		"piece2": {}
	}
	
	# Increment counter for cooldown tracking
	pieces_since_last_bomb += 1
	
	# Determine if we should try to spawn a bomb (COOLDOWN SYSTEM)
	var can_spawn_bomb = bomb_scenario != BombScenario.SINGLE or current_bomb_type != BombController.BombType.NONE
	var bomb_spawn_allowed = false
	
	if can_spawn_bomb:
		if pieces_since_last_bomb < bomb_cooldown_pieces:
			# Still in cooldown - no bombs allowed
			bomb_spawn_allowed = false
		elif pieces_since_last_bomb >= bomb_guarantee_pieces:
			# Past guarantee threshold - force spawn a bomb
			bomb_spawn_allowed = true
			print("Bomb cooldown: Guaranteed spawn at ", pieces_since_last_bomb, " pieces")
		else:
			# In normal window - use random chance
			bomb_spawn_allowed = randf() < bomb_spawn_chance
	
	# Generate piece1
	var piece1_is_bomb = bomb_spawn_allowed
	
	if piece1_is_bomb:
		pair_data.piece1.type = "bomb"
		pair_data.piece1.bomb_type = get_random_bomb_type_for_scenario()
		pair_data.piece1.color = bomb_color
		pieces_since_last_bomb = 0  # Reset counter
		print("Bomb cooldown: Bomb spawned (", BombController.get_bomb_type_name(pair_data.piece1.bomb_type), "), counter reset")
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
	if not piece1_is_bomb and bomb_spawn_allowed:
		# If piece1 wasn't a bomb but we can spawn one, try piece2
		piece2_is_bomb = true
	
	if piece2_is_bomb:
		pair_data.piece2.type = "bomb"
		pair_data.piece2.bomb_type = get_random_bomb_type_for_scenario()
		pair_data.piece2.color = bomb_color
		pieces_since_last_bomb = 0  # Reset counter
		print("Bomb cooldown: Bomb spawned (piece2, ", BombController.get_bomb_type_name(pair_data.piece2.bomb_type), "), counter reset")
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
	if sequence_index >= piece_sequence.size() - 10:
		generate_piece_sequence()
	
	var data = piece_sequence[sequence_index]
	sequence_index += 1
	return data
	
func get_piece_pair_data_at_index(index: int):
	while index >= piece_sequence.size():
		generate_piece_sequence()
	
	return piece_sequence[index]

func reset_piece_sequence():
	piece_sequence = []
	sequence_index = 0
	pieces_since_last_bomb = 0  # Reset cooldown counter

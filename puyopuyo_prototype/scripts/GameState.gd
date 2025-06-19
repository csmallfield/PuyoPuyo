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
var piece_fall_speed = 200.0  # pixels per second for smooth falling
var use_sprites = true  # Set to true to use sprite files instead of generated circles
var sprite_paths = {
	Color.RED: "res://assets/red_piece.png",
	Color.BLUE: "res://assets/blue_piece.png", 
	Color.GREEN: "res://assets/green_piece.png",
	Color.YELLOW: "res://assets/yellow_piece.png",
	Color.GRAY: "res://assets/bubble_piece.png",
	Color.BLACK: "res://assets/bomb_piece.png"
}

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

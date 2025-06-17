extends Node
# GameState.gd - Manages overall game state and settings

signal game_over
signal score_changed(new_score)

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

# Game settings
var grid_width = 6
var grid_height = 12
var fall_speed = 1.0
var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
var bubble_color = Color.GRAY
var bubble_spawn_chance = 0.15  # 15% chance for one piece in a pair to be a bubble

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_score(points):
	score += points
	emit_signal("score_changed", score)

func reset_game():
	score = 0
	level = 1
	lines_cleared = 0
	current_state = State.PLAYING
	emit_signal("score_changed", score)

func set_state(new_state):
	current_state = new_state
	if new_state == State.GAME_OVER:
		emit_signal("game_over")

func get_fall_speed():
	return max(0.1, fall_speed - (level * 0.1))

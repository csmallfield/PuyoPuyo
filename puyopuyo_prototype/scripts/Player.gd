extends Node
# Player.gd - Abstract player behavior for human vs AI

enum PlayerType {
	HUMAN,
	AI
}

signal input_action(action_name)

var player_type: PlayerType = PlayerType.HUMAN
var player_id: int = 0
var grid_reference = null
var ai_controller = null

# AI timing parameters
var ai_think_time_min = 0.3
var ai_think_time_max = 0.8
var ai_move_speed = 0.15
var ai_reaction_delay = 0.2

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(player_type == PlayerType.HUMAN)

func initialize(type: PlayerType, id: int, grid_ref = null):
	player_type = type
	player_id = id
	grid_reference = grid_ref
	
	if player_type == PlayerType.AI:
		# Create AI controller when we need it
		create_ai_controller()
	
	set_process_input(player_type == PlayerType.HUMAN)

func create_ai_controller():
	# We'll implement this in Phase 3
	# For now, just prepare the structure
	pass

func _input(event):
	# Only process input for human players
	if player_type != PlayerType.HUMAN:
		return
		
	if GameState.current_state != GameState.State.PLAYING:
		return
	
	# Forward human input as signals
	if event.is_action_pressed("move_left"):
		emit_signal("input_action", "move_left")
	elif event.is_action_pressed("move_right"):
		emit_signal("input_action", "move_right")
	elif event.is_action_pressed("rotate_piece"):
		emit_signal("input_action", "rotate_piece")
	elif event.is_action_pressed("move_down"):
		emit_signal("input_action", "move_down")
	elif event.is_action_pressed("fast_drop"):
		emit_signal("input_action", "fast_drop")

func start_turn_for_new_piece():
	# Called when a new piece spawns for this player
	if player_type == PlayerType.AI:
		# AI will start thinking about this piece
		start_ai_thinking()

func start_ai_thinking():
	# Placeholder for AI decision making
	# We'll implement this in Phase 3
	if ai_controller:
		ai_controller.start_thinking_about_piece()

func get_player_display_name() -> String:
	match player_type:
		PlayerType.HUMAN:
			return "Human Player"
		PlayerType.AI:
			return "AI Player"
	return "Unknown Player"

# Method for AI to simulate input
func simulate_input_action(action_name: String):
	if player_type == PlayerType.AI:
		emit_signal("input_action", action_name)

extends Control
# Main.gd - Main game controller

@onready var grid = $Grid
@onready var score_label = $UI/ScoreLabel
@onready var game_over_panel = $UI/GameOverPanel

func _ready():
	# Connect signals
	GameState.connect("score_changed", _on_score_changed)
	GameState.connect("game_over", _on_game_over)
	grid.connect("game_over", _on_grid_game_over)
	
	# Start the game
	start_new_game()

func _input(event):
	if event.is_action_pressed("restart") and GameState.current_state == GameState.State.GAME_OVER:
		start_new_game()

func start_new_game():
	game_over_panel.hide()
	GameState.reset_game()
	grid.start_game()

func _on_score_changed(new_score):
	score_label.text = "Score: " + str(new_score)

func _on_game_over():
	game_over_panel.show()

func _on_grid_game_over():
	GameState.set_state(GameState.State.GAME_OVER)

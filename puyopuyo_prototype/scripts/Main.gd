extends Control
# Main.gd - Main game controller

@onready var grid = $Grid
@onready var score_label = $UI/ScoreLabel
@onready var level_label = $UI/LevelLabel
@onready var speed_label = $UI/SpeedLabel
@onready var multiplier_label = $UI/MultiplierLabel
@onready var next_level_label = $UI/NextLevelLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var level_up_notification = $UI/LevelUpNotification
@onready var level_up_text = $UI/LevelUpNotification/LevelUpText
@onready var pause_panel = $UI/PausePanel
@onready var pause_restart_button = $UI/PausePanel/VBoxContainer/RestartButton

func _ready():
	# Connect signals
	GameState.connect("score_changed", _on_score_changed)
	GameState.connect("level_changed", _on_level_changed)
	GameState.connect("game_over", _on_game_over)
	grid.connect("game_over", _on_grid_game_over)
	
	# Connect pause screen restart button
	pause_restart_button.connect("pressed", _on_pause_restart_pressed)
	
	# Hide notifications initially
	level_up_notification.modulate.a = 0.0
	pause_panel.hide()
	
	# Start the game
	start_new_game()

func _input(event):
	if event.is_action_pressed("restart") and GameState.current_state == GameState.State.GAME_OVER:
		start_new_game()
	elif event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause():
	if GameState.current_state == GameState.State.PLAYING:
		# Pause the game
		GameState.set_state(GameState.State.PAUSED)
		pause_panel.show()
		get_tree().paused = true
	elif GameState.current_state == GameState.State.PAUSED:
		# Unpause the game
		GameState.set_state(GameState.State.PLAYING)
		pause_panel.hide()
		get_tree().paused = false

func start_new_game():
	game_over_panel.hide()
	pause_panel.hide()
	get_tree().paused = false
	
	# Force immediate cleanup of any lingering piece pairs
	if grid.current_piece_pair:
		grid.current_piece_pair.queue_free()
		grid.current_piece_pair = null
	if grid.next_piece_pair:
		grid.next_piece_pair.queue_free()
		grid.next_piece_pair = null
	
	GameState.reset_game()
	grid.start_game()
	update_ui()
	

func update_ui():
	# Update all UI elements
	score_label.text = "Score: " + str(GameState.score)
	level_label.text = GameState.get_level_display_text()
	speed_label.text = GameState.get_speed_display_text()
	multiplier_label.text = "x" + str(GameState.get_current_multiplier())
	
	# Update next level progress
	var points_to_next = GameState.get_points_to_next_level()
	if points_to_next > 0:
		next_level_label.text = "Next level in: " + str(points_to_next) + " points"
	else:
		next_level_label.text = "MAX LEVEL!"

func _on_score_changed(new_score):
	update_ui()

func _on_level_changed(new_level):
	update_ui()
	show_level_up_notification(new_level)

func show_level_up_notification(level):
	# Skip notification for level 1 (game start)
	if level == 1:
		return
		
	level_up_text.text = "LEVEL " + str(level) + "!"
	
	# Create a tween for the notification animation
	var tween = create_tween()
	
	# Fade in
	tween.tween_property(level_up_notification, "modulate:a", 1.0, 0.3)
	
	# Hold
	tween.tween_interval(1.5)
	
	# Fade out
	tween.tween_property(level_up_notification, "modulate:a", 0.0, 0.5)

func _on_game_over():
	game_over_panel.show()

func _on_grid_game_over():
	GameState.set_state(GameState.State.GAME_OVER)

func _on_pause_restart_pressed():
	# Unpause and start a new game
	start_new_game()

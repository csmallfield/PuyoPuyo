extends Control
# Main.gd - Main game controller

const BombController = preload("res://scripts/BombController.gd")

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
@onready var game_over_restart_button = $UI/GameOverPanel/VBoxContainer/RestartButtonSP
@onready var game_over_menu_button = $UI/GameOverPanel/VBoxContainer/MenuButtonSP
@onready var pause_resume_button = $UI/PausePanel/VBoxContainer/ResumeButton
@onready var pause_restart_button = $UI/PausePanel/VBoxContainer/RestartButton
@onready var pause_menu_button = $UI/PausePanel/VBoxContainer/PauseMenuButton
@onready var music_player = $MusicPlayer
@onready var bomb_type_label: Label = $UI/PausePanel/VBoxContainer/BombTypeLabel
@onready var change_bomb_type_button: Button = $UI/PausePanel/VBoxContainer/ChangeBombTypeButton

func _ready():
	# Connect signals
	GameState.connect("score_changed", _on_score_changed)
	GameState.connect("level_changed", _on_level_changed)
	GameState.connect("game_over", _on_game_over)
	
	if grid:
		grid.connect("game_over", _on_grid_game_over)
		grid.connect("chain_bonus", _on_chain_bonus)
	
	# Connect bomb type button
	if change_bomb_type_button:
		change_bomb_type_button.connect("pressed", _on_change_bomb_type_pressed)
	
	# Connect pause screen buttons
	if pause_resume_button:
		pause_resume_button.connect("pressed", _on_pause_resume_pressed)
	if pause_restart_button:
		pause_restart_button.connect("pressed", _on_pause_restart_pressed)
	if pause_menu_button:
		pause_menu_button.connect("pressed", _on_pause_menu_pressed)
	
	# Connect game over buttons
	if game_over_restart_button:
		game_over_restart_button.connect("pressed", _on_game_over_restart_pressed)
	if game_over_menu_button:
		game_over_menu_button.connect("pressed", _on_game_over_menu_pressed)
	
	# Hide notifications initially
	level_up_notification.modulate.a = 0.0
	pause_panel.hide()
	
	# Start the game
	start_new_game()

func _on_change_bomb_type_pressed():
	var next_type = (GameState.current_bomb_type + 1) % 6
	GameState.set_bomb_type(next_type)
	bomb_type_label.text = get_bomb_type_text(GameState.current_bomb_type)
	AudioManager.play_difficulty_change()

func get_bomb_type_text(bomb_type: int) -> String:
	return "Bomb Type: " + BombController.get_bomb_type_name(bomb_type)

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
		
		# Play pause sound
		AudioManager.play_pause()
		
		# Grab focus on resume button
		if pause_resume_button:
			await get_tree().create_timer(0.01).timeout
			pause_resume_button.grab_focus()
	elif GameState.current_state == GameState.State.PAUSED:
		# Unpause the game
		GameState.set_state(GameState.State.PLAYING)
		pause_panel.hide()
		get_tree().paused = false
		
		# Play unpause sound
		AudioManager.play_unpause()

func start_new_game():
	game_over_panel.hide()
	pause_panel.hide()
	get_tree().paused = false
	
	# Configure for single player mode BEFORE resetting game
	GameState.configure_for_game_mode(GameState.GameMode.SINGLE_PLAYER)
	
	GameState.reset_game()
	
	# Set initial fall speed for level 1 and start game
	if grid:
		grid.set_fall_speed(GameState.level_speeds[0])
		grid.start_game()
	
	update_ui()
	
	# Play game start sound
	AudioManager.play_game_start()
	
	# Start music with adjusted volume
	if music_player:
		music_player.volume_db = -12
		music_player.play()

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
	
	# Update grid fall speed when level changes
	if grid and is_instance_valid(grid):
		var speed_index = min(new_level - 1, GameState.level_speeds.size() - 1)
		grid.set_fall_speed(GameState.level_speeds[speed_index])
		print("Level ", new_level, " - Speed set to: ", GameState.level_speeds[speed_index])

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

func _on_chain_bonus(chain_count):
	# Show chain bonus notification using the same system as level up
	level_up_text.text = str(chain_count) + "x Chain Bonus!"
	
	# Create a tween for the chain bonus notification animation
	var tween = create_tween()
	
	# Fade in quickly
	tween.tween_property(level_up_notification, "modulate:a", 1.0, 0.2)
	
	# Hold for shorter time than level up
	tween.tween_interval(1.0)
	
	# Fade out
	tween.tween_property(level_up_notification, "modulate:a", 0.0, 0.3)

func _on_game_over():
	# Play game over sound
	AudioManager.play_game_over()
	
	game_over_panel.show()
	
	# Stop music on game over
	if music_player:
		music_player.stop()
	
	# Grab focus on the restart button after a brief delay
	if game_over_restart_button:
		await get_tree().create_timer(0.1).timeout
		game_over_restart_button.grab_focus()

func _on_grid_game_over():
	GameState.set_state(GameState.State.GAME_OVER)

func _on_pause_resume_pressed():
	# Resume the game (same as pressing P)
	AudioManager.play_button_click()
	toggle_pause()

func _on_pause_restart_pressed():
	AudioManager.play_button_click()
	# Unpause first, then restart
	if GameState.current_state == GameState.State.PAUSED:
		get_tree().paused = false
	start_new_game()

func _on_pause_menu_pressed():
	AudioManager.play_button_click()
	# Stop music when returning to menu
	if music_player:
		music_player.stop()
	
	# Unpause first, then go to menu
	if GameState.current_state == GameState.State.PAUSED:
		get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_game_over_restart_pressed():
	AudioManager.play_button_click()
	start_new_game()

func _on_game_over_menu_pressed():
	AudioManager.play_button_click()
	# Stop music when returning to menu
	if music_player:
		music_player.stop()
	
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

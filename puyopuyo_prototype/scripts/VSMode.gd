extends Control
# VSMode.gd - VS AI mode controller with garbage system and AI vs AI debug mode

const BombController = preload("res://scripts/BombController.gd")
const Grid = preload("res://scenes/Grid.tscn")
const AIController = preload("res://scripts/AIController.gd")

@onready var player_grid_container = $GameContainer/PlayerSide/PlayerGridContainer
@onready var ai_grid_container = $GameContainer/AISide/AIGridContainer
@onready var player_score_label = $GameContainer/PlayerSide/PlayerScoreLabel
@onready var ai_score_label = $GameContainer/AISide/AIScoreLabel
@onready var player_garbage_meter = $GameContainer/PlayerSide/GarbageMeter
@onready var ai_garbage_meter = $GameContainer/AISide/GarbageMeter
@onready var result_panel = $ResultPanel
@onready var result_label = $ResultPanel/VBoxContainer/ResultLabel
@onready var result_restart_button = $ResultPanel/VBoxContainer/RestartButton
@onready var result_menu_button = $ResultPanel/VBoxContainer/MenuButton

@onready var player_level_label: Label = $GameContainer/PlayerSide/LevelLabel
@onready var ai_level_label: Label = $GameContainer/AISide/LevelLabel
@onready var player_name_label: Label = $GameContainer/PlayerSide/PlayerLabel

# Pause panel elements
@onready var pause_panel = $PausePanel
@onready var bomb_type_label: Label = $PausePanel/VBoxContainer/BombTypeLabel
@onready var change_bomb_type_button: Button = $PausePanel/VBoxContainer/ChangeBombTypeButton
@onready var pause_resume_button = $PausePanel/VBoxContainer/ResumeButton
@onready var pause_restart_button = $PausePanel/VBoxContainer/RestartButton
@onready var pause_menu_button = $PausePanel/VBoxContainer/PauseMenuButton
@onready var music_player = $MusicPlayer

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var timer_label: Label = $TimerLabel


# NEW: Debug mode controls
@onready var debug_mode_label: Label = $PausePanel/VBoxContainer/DebugModeLabel
@onready var debug_mode_button: Button = $PausePanel/VBoxContainer/DebugModeButton
@onready var player_difficulty_label: Label = $PausePanel/VBoxContainer/PlayerDifficultyLabel
@onready var player_difficulty_button: Button = $PausePanel/VBoxContainer/PlayerDifficultyButton
@onready var opponent_difficulty_label: Label = $PausePanel/VBoxContainer/OpponentDifficultyLabel
@onready var opponent_difficulty_button: Button = $PausePanel/VBoxContainer/OpponentDifficultyButton

var player_grid = null
var ai_grid = null
var ai_controller = null
var player_ai_controller = null  # NEW: AI controller for player side
var game_active = false
var is_paused = false
var match_start_time = 0.0
# Track scores separately for each player
var player_score = 0
var ai_score = 0
var last_global_score = 0

# Track levels separately for each player
var player_level = 1
var ai_level = 1

# Garbage meter flash effect
var player_meter_flash_timer = 0.0
var ai_meter_flash_timer = 0.0
var meter_flash_duration = 0.5

# First attack tracking
var player_has_sent_attack = false
var ai_has_sent_attack = false

# AI difficulty settings
var opponent_ai_difficulty = AIController.Difficulty.LEVEL_1
var player_ai_difficulty = AIController.Difficulty.LEVEL_1

# NEW: Debug mode flag
var debug_ai_vs_ai_mode = false

func _ready():
	# Allow input processing even when paused (for pause toggle)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set process mode to WHEN_PAUSED for panels to work during pause
	pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	result_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Connect result panel buttons
	result_restart_button.connect("pressed", _on_result_restart_pressed)
	result_menu_button.connect("pressed", _on_result_menu_pressed)
	
	# Connect pause panel buttons
	pause_resume_button.connect("pressed", _on_pause_resume_pressed)
	pause_restart_button.connect("pressed", _on_pause_restart_pressed)
	pause_menu_button.connect("pressed", _on_pause_menu_pressed)
	
	# Connect bomb type button
	if change_bomb_type_button:
		change_bomb_type_button.connect("pressed", _on_change_bomb_type_pressed)
	
	# NEW: Connect debug mode buttons
	if debug_mode_button:
		debug_mode_button.connect("pressed", _on_toggle_debug_mode_pressed)
	if player_difficulty_button:
		player_difficulty_button.connect("pressed", _on_change_player_ai_difficulty_pressed)
	if opponent_difficulty_button:
		opponent_difficulty_button.connect("pressed", _on_change_opponent_ai_difficulty_pressed)
	
	# Connect to GameState score changes
	GameState.connect("score_changed", _on_global_score_changed)
	
	# Initialize UI
	update_debug_mode_ui()
	
	# Start the game
	start_new_game()

func start_new_game():
	# Clear any existing grids
	if player_grid:
		player_grid.queue_free()
	if ai_grid:
		ai_grid.queue_free()
	if ai_controller:
		ai_controller.queue_free()
	if player_ai_controller:
		player_ai_controller.queue_free()
		player_ai_controller = null
	
	# Configure for VS mode BEFORE resetting game
	GameState.configure_for_game_mode(GameState.GameMode.VS_MODE)
	
	# Reset GameState
	GameState.reset_game()
	
	# Reset scores and levels
	player_score = 0
	ai_score = 0
	last_global_score = 0
	player_level = 1
	ai_level = 1
	player_has_sent_attack = false
	ai_has_sent_attack = false
	
	# Create player grid
	player_grid = Grid.instantiate()
	player_grid_container.add_child(player_grid)
	player_grid.position = Vector2(192, 0)
	player_grid.enable_input = false  # Always false - we control input in _input
	player_grid.enable_camera_shake = false
	player_grid.connect("game_over", _on_player_game_over)
	player_grid.connect("garbage_sent", _on_player_sends_garbage)
	player_grid.set_meta("owner_type", "player")
	player_grid.set_fall_speed(GameState.level_speeds[0])
	player_grid.process_mode = Node.PROCESS_MODE_PAUSABLE 
	
	# Create AI grid
	ai_grid = Grid.instantiate()
	ai_grid_container.add_child(ai_grid)
	ai_grid.position = Vector2(192, 0)
	ai_grid.enable_input = false
	ai_grid.enable_camera_shake = false
	ai_grid.connect("game_over", _on_ai_game_over)
	ai_grid.connect("garbage_sent", _on_ai_sends_garbage)
	ai_grid.set_meta("owner_type", "ai")
	ai_grid.set_fall_speed(GameState.level_speeds[0])
	ai_grid.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Create opponent AI controller
	ai_controller = AIController.new()
	ai_controller.grid = ai_grid
	ai_controller.configure_difficulty(opponent_ai_difficulty)
	add_child(ai_controller)
	ai_controller.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# NEW: Create player AI controller if in debug mode
	if debug_ai_vs_ai_mode:
		player_ai_controller = AIController.new()
		player_ai_controller.grid = player_grid
		player_ai_controller.configure_difficulty(player_ai_difficulty)
		add_child(player_ai_controller)
		player_ai_controller.process_mode = Node.PROCESS_MODE_PAUSABLE
		print("DEBUG MODE: Player side controlled by AI (Level ", player_ai_difficulty, ")")
	
	# Start both grids
	player_grid.start_game()
	ai_grid.start_game()
	
	# Hide panels
	result_panel.hide()
	pause_panel.hide()
	dim_overlay.hide()
	
	# Reset garbage meters
	player_garbage_meter.value = 0
	ai_garbage_meter.value = 0
	
	game_active = true
	is_paused = false
	
	# Update UI
	update_score_labels()
	update_level_labels()
	update_player_label()
	
	# Play game start sound
	AudioManager.play_game_start()
	
	# Start music with adjusted volume
	if music_player:
		music_player.volume_db = -12
		music_player.play()

func update_player_label():
	"""Update the player label to show AI status in debug mode"""
	if debug_ai_vs_ai_mode:
		player_name_label.text = "AI (Level " + str(player_ai_difficulty) + ")"
	else:
		player_name_label.text = "PLAYER"

func _on_player_sends_garbage(nuisance_points: int):
	"""Player sent garbage to AI"""
	var side_name = "Player" if not debug_ai_vs_ai_mode else ("AI-P L" + str(player_ai_difficulty))
	print(side_name, " sends ", nuisance_points, " nuisance points to opponent")
	if ai_grid:
		ai_grid.receive_garbage(nuisance_points)
		# Trigger flash effect on AI meter
		ai_meter_flash_timer = meter_flash_duration

func _on_ai_sends_garbage(nuisance_points: int):
	"""AI sent garbage to player"""
	print("AI-O L", opponent_ai_difficulty, " sends ", nuisance_points, " nuisance points to player side")
	if player_grid:
		player_grid.receive_garbage(nuisance_points)
		# Trigger flash effect on player meter
		player_meter_flash_timer = meter_flash_duration

func _on_global_score_changed(new_score):
	# This is a workaround: we track which grid just scored
	# by checking which one is currently clearing matches
	var score_delta = new_score - last_global_score
	last_global_score = new_score
	
	if score_delta > 0:
		# Check which grid is clearing (has clearing_matches = true)
		if player_grid and player_grid.clearing_matches:
			player_score += score_delta
			check_player_level_up()
		elif ai_grid and ai_grid.clearing_matches:
			ai_score += score_delta
			check_ai_level_up()

func _process(delta):
	if game_active and not is_paused:
		update_score_labels()
		update_level_labels()
		update_garbage_meters(delta)
		update_timer_label()

func update_score_labels():
	player_score_label.text = "Score: " + str(player_score)
	ai_score_label.text = "Score: " + str(ai_score)

func update_garbage_meters(delta):
	"""Update garbage meter displays with flash effect"""
	# Update player meter
	if player_grid:
		var fill = player_grid.get_garbage_meter_fill()
		player_garbage_meter.value = fill
		
		# Flash effect when garbage is high
		if player_meter_flash_timer > 0:
			player_meter_flash_timer -= delta
			# Alternate between red and white
			var flash_alpha = abs(sin(player_meter_flash_timer * 10))
			player_garbage_meter.modulate = Color(1.0, flash_alpha, flash_alpha)
		else:
			# Normal color based on fill level
			if fill > 0.5:
				player_garbage_meter.modulate = Color(1.0, 0.3, 0.3)  # Red warning
			elif fill > 0:
				player_garbage_meter.modulate = Color(1.0, 0.7, 0.3)  # Orange caution
			else:
				player_garbage_meter.modulate = Color(0.5, 0.5, 0.5)  # Gray empty
	
	# Update AI meter
	if ai_grid:
		var fill = ai_grid.get_garbage_meter_fill()
		ai_garbage_meter.value = fill
		
		# Flash effect when garbage is high
		if ai_meter_flash_timer > 0:
			ai_meter_flash_timer -= delta
			var flash_alpha = abs(sin(ai_meter_flash_timer * 10))
			ai_garbage_meter.modulate = Color(1.0, flash_alpha, flash_alpha)
		else:
			if fill > 0.5:
				ai_garbage_meter.modulate = Color(1.0, 0.3, 0.3)
			elif fill > 0:
				ai_garbage_meter.modulate = Color(1.0, 0.7, 0.3)
			else:
				ai_garbage_meter.modulate = Color(0.5, 0.5, 0.5)

func update_timer_label():
	"""Update the timer display"""
	if not timer_label or not game_active:
		return
	
	var elapsed_seconds = (Time.get_ticks_msec() / 1000.0) - match_start_time
	var minutes = int(elapsed_seconds) / 60
	var seconds = int(elapsed_seconds) % 60
	
	timer_label.text = "%d:%02d" % [minutes, seconds]

func check_player_level_up():
	"""Check if player should level up based on score"""
	var new_level = calculate_level_from_score(player_score)
	
	if new_level != player_level:
		var old_level = player_level
		player_level = new_level
		var side_name = "Player" if not debug_ai_vs_ai_mode else ("AI-P L" + str(player_ai_difficulty))
		print(side_name, " leveled up from ", old_level, " to ", player_level)
		
		# Update fall speed
		if player_grid:
			var speed_index = min(player_level - 1, GameState.level_speeds.size() - 1)
			var new_speed = GameState.level_speeds[speed_index]
			player_grid.set_fall_speed(new_speed)
			print(side_name, " speed set to: ", new_speed)
		
		# Send level-up attack to opponent
		var level_up_garbage = GameState.get_level_up_attack_nuisance(player_level)
		if level_up_garbage > 0 and ai_grid:
			print(side_name, " level-up attack: sending ", level_up_garbage, " nuisance points to opponent")
			ai_grid.receive_garbage(level_up_garbage)
			ai_meter_flash_timer = meter_flash_duration  # Flash the AI's garbage meter
		
		update_level_labels()

func check_ai_level_up():
	"""Check if AI should level up based on score"""
	var new_level = calculate_level_from_score(ai_score)
	
	if new_level != ai_level:
		var old_level = ai_level
		ai_level = new_level
		print("AI-O L", opponent_ai_difficulty, " leveled up from ", old_level, " to ", ai_level)
		
		# Update fall speed
		if ai_grid:
			var speed_index = min(ai_level - 1, GameState.level_speeds.size() - 1)
			var new_speed = GameState.level_speeds[speed_index]
			ai_grid.set_fall_speed(new_speed)
			print("AI-O speed set to: ", new_speed)
		
		# Send level-up attack to opponent
		var level_up_garbage = GameState.get_level_up_attack_nuisance(ai_level)
		if level_up_garbage > 0 and player_grid:
			print("AI-O level-up attack: sending ", level_up_garbage, " nuisance points to player side")
			player_grid.receive_garbage(level_up_garbage)
			player_meter_flash_timer = meter_flash_duration  # Flash the player's garbage meter
		
		update_level_labels()

func calculate_level_from_score(score: int) -> int:
	"""Calculate level based on score using GameState thresholds"""
	var level = 1
	
	for i in range(GameState.level_thresholds.size() - 1, -1, -1):
		if score >= GameState.level_thresholds[i]:
			level = i + 1
			break
	
	return level

func update_level_labels():
	"""Update level display labels"""
	player_level_label.text = "Level " + str(player_level)
	ai_level_label.text = "Level " + str(ai_level)

func get_difficulty_text(difficulty: int, label: String = "AI") -> String:
	"""Get display text for AI difficulty"""
	match difficulty:
		AIController.Difficulty.LEVEL_0:
			return label + ": Level 0 - Beginner"
		AIController.Difficulty.LEVEL_1:
			return label + ": Level 1 - Intermediate"
		AIController.Difficulty.LEVEL_2:
			return label + ": Level 2 - Advanced"
		AIController.Difficulty.LEVEL_3:
			return label + ": Level 3 - Expert"
		_:
			return label + ": Level 1"

func get_bomb_type_text(mode_index: int) -> String:
	return "Bomb Type: " + GameState.get_bomb_mode_name(mode_index)

func _input(event):
	# Handle pause
	if event.is_action_pressed("pause") and game_active:
		toggle_pause()
		return
	
	if not game_active or is_paused:
		return
	
	# NEW: Only route input to player grid if NOT in debug mode
	if not debug_ai_vs_ai_mode and player_grid and player_grid.current_piece_pair:
		if event.is_action_pressed("move_left"):
			player_grid.move_piece_horizontal(-1)
		elif event.is_action_pressed("move_right"):
			player_grid.move_piece_horizontal(1)
		elif event.is_action_pressed("rotate_piece"):
			player_grid.rotate_piece()
		elif event.is_action_pressed("move_down"):
			player_grid.move_piece_down()
		elif event.is_action_pressed("fast_drop"):
			player_grid.fast_drop_piece()

func toggle_pause():
	if not game_active:
		return
	
	if not is_paused:
		# Pause the game using Godot's pause system
		is_paused = true
		dim_overlay.show()
		pause_panel.show()
		get_tree().paused = true
		
		# Play pause sound
		AudioManager.play_pause()
		
		# Grab focus on resume button
		await get_tree().create_timer(0.01).timeout
		pause_resume_button.grab_focus()
	else:
		# Unpause the game
		is_paused = false
		pause_panel.hide()
		dim_overlay.hide()
		get_tree().paused = false
		
		# Play unpause sound
		AudioManager.play_unpause()

func _on_pause_resume_pressed():
	AudioManager.play_button_click()
	toggle_pause()

func _on_pause_restart_pressed():
	AudioManager.play_button_click()
	# Unpause first if needed
	if is_paused:
		is_paused = false
		get_tree().paused = false
	start_new_game()

func _on_pause_menu_pressed():
	AudioManager.play_button_click()
	# Stop music when returning to menu
	if music_player:
		music_player.stop()
	
	# Unpause first if needed
	if is_paused:
		is_paused = false
		get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# NEW: Debug mode toggle
func _on_toggle_debug_mode_pressed():
	debug_ai_vs_ai_mode = not debug_ai_vs_ai_mode
	update_debug_mode_ui()
	AudioManager.play_difficulty_change()
	
	print("DEBUG MODE: AI vs AI ", "ENABLED" if debug_ai_vs_ai_mode else "DISABLED")

# NEW: Update debug mode UI
func update_debug_mode_ui():
	if debug_mode_label:
		debug_mode_label.text = "DEBUG: AI vs AI Mode " + ("ON" if debug_ai_vs_ai_mode else "OFF")
	
	# Show/hide player AI difficulty controls based on debug mode
	if player_difficulty_label:
		player_difficulty_label.visible = debug_ai_vs_ai_mode
		player_difficulty_label.text = get_difficulty_text(player_ai_difficulty, "Player AI")
	if player_difficulty_button:
		player_difficulty_button.visible = debug_ai_vs_ai_mode
	
	# Update opponent label
	if opponent_difficulty_label:
		opponent_difficulty_label.text = get_difficulty_text(opponent_ai_difficulty, "Opponent AI")

# NEW: Change player AI difficulty
func _on_change_player_ai_difficulty_pressed():
	# Cycle to next difficulty (0 → 1 → 2 → 3 → 0)
	player_ai_difficulty = (player_ai_difficulty + 1) % 4
	
	# Update label
	if player_difficulty_label:
		player_difficulty_label.text = get_difficulty_text(player_ai_difficulty, "Player AI")
	
	# Reconfigure player AI if it exists
	if player_ai_controller:
		player_ai_controller.configure_difficulty(player_ai_difficulty)
		print("Player AI difficulty changed to Level ", player_ai_difficulty)
	
	# Play sound
	AudioManager.play_difficulty_change()

# NEW: Change opponent AI difficulty (renamed from _on_change_difficulty_pressed)
func _on_change_opponent_ai_difficulty_pressed():
	# Cycle to next difficulty (0 → 1 → 2 → 3 → 0)
	opponent_ai_difficulty = (opponent_ai_difficulty + 1) % 4
	
	# Update label
	if opponent_difficulty_label:
		opponent_difficulty_label.text = get_difficulty_text(opponent_ai_difficulty, "Opponent AI")
	
	# Reconfigure AI with new difficulty
	if ai_controller:
		ai_controller.configure_difficulty(opponent_ai_difficulty)
		print("Opponent AI difficulty changed to Level ", opponent_ai_difficulty)
	
	# Play sound
	AudioManager.play_difficulty_change()

func _on_change_bomb_type_pressed():
	# Cycle through 0-7 (8 total options)
	var current_mode = get_current_bomb_mode_index()
	var next_mode = (current_mode + 1) % 8
	
	GameState.set_bomb_mode(next_mode)
	bomb_type_label.text = get_bomb_type_text(next_mode)
	AudioManager.play_difficulty_change()

func get_current_bomb_mode_index() -> int:
	"""Get current mode index based on scenario and bomb type"""
	if GameState.bomb_scenario == GameState.BombScenario.ALL_BOMBS:
		return 6
	elif GameState.bomb_scenario == GameState.BombScenario.LINE_CROSS:
		return 7
	else:
		# Single bomb type scenario
		match GameState.current_bomb_type:
			BombController.BombType.NONE: return 0
			BombController.BombType.NORMAL: return 1
			BombController.BombType.LINE: return 2
			BombController.BombType.TIME: return 3
			BombController.BombType.CROSS: return 4
			BombController.BombType.AREA: return 5
	return 0

func _on_player_game_over():
	if not game_active:
		return
	
	game_active = false
	
	# Pause the game completely
	get_tree().paused = true
	
	# Play defeat sound (player lost)
	AudioManager.play_defeat()
	
	# Stop music on game over
	if music_player:
		music_player.stop()
	
	# NEW: Update result label based on debug mode
	if debug_ai_vs_ai_mode:
		result_label.text = "OPPONENT AI WINS!\n(Level " + str(opponent_ai_difficulty) + ")"
	else:
		result_label.text = "AI WINS!"
	
	result_panel.show()
	
	# Grab focus on restart button (use timer that works when paused)
	await get_tree().create_timer(0.1, true).timeout
	result_restart_button.grab_focus()

func _on_ai_game_over():
	if not game_active:
		return
	
	game_active = false
	
	# Pause the game completely
	get_tree().paused = true
	
	# Play victory sound (player won)
	AudioManager.play_victory()
	
	# Stop music on game over
	if music_player:
		music_player.stop()
	
	# NEW: Update result label based on debug mode
	if debug_ai_vs_ai_mode:
		result_label.text = "PLAYER AI WINS!\n(Level " + str(player_ai_difficulty) + ")"
	else:
		result_label.text = "YOU WIN!"
	
	result_panel.show()
	
	# Grab focus on restart button (use timer that works when paused)
	await get_tree().create_timer(0.1, true).timeout
	result_restart_button.grab_focus()

func _on_result_restart_pressed():
	AudioManager.play_button_click()
	# Unpause before restarting
	get_tree().paused = false
	start_new_game()

func _on_result_menu_pressed():
	AudioManager.play_button_click()
	# Stop music when returning to menu
	if music_player:
		music_player.stop()
	
	# Unpause before changing scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

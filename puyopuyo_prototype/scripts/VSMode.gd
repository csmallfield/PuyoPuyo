extends Control
# VSMode.gd - VS AI mode controller with garbage system

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

# Pause panel elements
@onready var pause_panel = $PausePanel
@onready var pause_resume_button = $PausePanel/VBoxContainer/ResumeButton
@onready var pause_restart_button = $PausePanel/VBoxContainer/RestartButton
@onready var pause_menu_button = $PausePanel/VBoxContainer/PauseMenuButton

var player_grid = null
var ai_grid = null
var ai_controller = null
var game_active = false
var is_paused = false

# Track scores separately for each player
var player_score = 0
var ai_score = 0
var last_global_score = 0

# Garbage meter flash effect
var player_meter_flash_timer = 0.0
var ai_meter_flash_timer = 0.0
var meter_flash_duration = 0.5

# AI difficulty setting
var ai_difficulty_level = AIController.Difficulty.LEVEL_1

const Grid = preload("res://scenes/Grid.tscn")
const AIController = preload("res://scripts/AIController.gd")

func _ready():
	# Set process mode to always so pause doesn't affect this
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect result panel buttons
	result_restart_button.connect("pressed", _on_result_restart_pressed)
	result_menu_button.connect("pressed", _on_result_menu_pressed)
	
	# Connect pause panel buttons
	pause_resume_button.connect("pressed", _on_pause_resume_pressed)
	pause_restart_button.connect("pressed", _on_pause_restart_pressed)
	pause_menu_button.connect("pressed", _on_pause_menu_pressed)
	
	# Connect to GameState score changes
	GameState.connect("score_changed", _on_global_score_changed)
	
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
	
	# Configure for VS mode BEFORE resetting game
	GameState.configure_for_game_mode(GameState.GameMode.VS_MODE)
	
	# Reset GameState
	GameState.reset_game()
	
	# Reset scores
	player_score = 0
	ai_score = 0
	last_global_score = 0
	
	# Create player grid
	player_grid = Grid.instantiate()
	player_grid_container.add_child(player_grid)
	player_grid.position = Vector2(192, 0)
	player_grid.enable_input = false
	player_grid.enable_camera_shake = false
	player_grid.connect("game_over", _on_player_game_over)
	player_grid.connect("garbage_sent", _on_player_sends_garbage)  # NEW
	player_grid.set_meta("owner_type", "player")
	
	# Create AI grid
	ai_grid = Grid.instantiate()
	ai_grid_container.add_child(ai_grid)
	ai_grid.position = Vector2(192, 0)
	ai_grid.enable_input = false
	ai_grid.enable_camera_shake = false
	ai_grid.connect("game_over", _on_ai_game_over)
	ai_grid.connect("garbage_sent", _on_ai_sends_garbage)  # NEW
	ai_grid.set_meta("owner_type", "ai")
	
	# Create AI controller
	ai_controller = AIController.new()
	ai_controller.grid = ai_grid
	ai_controller.configure_difficulty(ai_difficulty_level)
	add_child(ai_controller)
	
	# Start both grids
	player_grid.start_game()
	ai_grid.start_game()
	
	# Hide panels
	result_panel.hide()
	pause_panel.hide()
	
	# Reset garbage meters
	player_garbage_meter.value = 0
	ai_garbage_meter.value = 0
	
	game_active = true
	is_paused = false
	
	# Update UI
	update_score_labels()

func _on_player_sends_garbage(nuisance_points: int):
	"""Player sent garbage to AI"""
	print("Player sends ", nuisance_points, " nuisance points to AI")
	if ai_grid:
		ai_grid.receive_garbage(nuisance_points)
		# Trigger flash effect on AI meter
		ai_meter_flash_timer = meter_flash_duration

func _on_ai_sends_garbage(nuisance_points: int):
	"""AI sent garbage to player"""
	print("AI sends ", nuisance_points, " nuisance points to Player")
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
		elif ai_grid and ai_grid.clearing_matches:
			ai_score += score_delta

func _process(delta):
	if game_active and not is_paused:
		update_score_labels()
		update_garbage_meters(delta)

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

func _input(event):
	# Handle pause
	if event.is_action_pressed("pause") and game_active:
		toggle_pause()
		return
	
	if not game_active or is_paused:
		return
	
	# Route input only to player grid
	if player_grid and player_grid.current_piece_pair:
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
		# Pause the game
		is_paused = true
		pause_panel.show()
		
		# Stop grid processing
		if player_grid:
			player_grid.set_process(false)
		if ai_grid:
			ai_grid.set_process(false)
		if ai_controller:
			ai_controller.set_process(false)
		
		# Grab focus on resume button
		await get_tree().create_timer(0.01).timeout
		pause_resume_button.grab_focus()
	else:
		# Unpause the game
		is_paused = false
		pause_panel.hide()
		
		# Resume grid processing
		if player_grid:
			player_grid.set_process(true)
		if ai_grid:
			ai_grid.set_process(true)
		if ai_controller:
			ai_controller.set_process(true)

func _on_pause_resume_pressed():
	toggle_pause()

func _on_pause_restart_pressed():
	# Unpause first if needed
	if is_paused:
		is_paused = false
		if player_grid:
			player_grid.set_process(true)
		if ai_grid:
			ai_grid.set_process(true)
		if ai_controller:
			ai_controller.set_process(true)
	start_new_game()

func _on_pause_menu_pressed():
	# Unpause first if needed
	if is_paused:
		is_paused = false
		if player_grid:
			player_grid.set_process(true)
		if ai_grid:
			ai_grid.set_process(true)
		if ai_controller:
			ai_controller.set_process(true)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_player_game_over():
	if not game_active:
		return
	
	game_active = false
	
	# Stop both grids
	if player_grid:
		player_grid.set_process(false)
	if ai_grid:
		ai_grid.set_process(false)
	if ai_controller:
		ai_controller.set_process(false)
	
	result_label.text = "AI WINS!"
	result_panel.show()
	
	# Grab focus on restart button
	await get_tree().create_timer(0.1).timeout
	result_restart_button.grab_focus()

func _on_ai_game_over():
	if not game_active:
		return
	
	game_active = false
	
	# Stop both grids
	if player_grid:
		player_grid.set_process(false)
	if ai_grid:
		ai_grid.set_process(false)
	if ai_controller:
		ai_controller.set_process(false)
	
	result_label.text = "YOU WIN!"
	result_panel.show()
	
	# Grab focus on restart button
	await get_tree().create_timer(0.1).timeout
	result_restart_button.grab_focus()

func _on_result_restart_pressed():
	start_new_game()

func _on_result_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

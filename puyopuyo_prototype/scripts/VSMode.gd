extends Control
# VSMode.gd - VS AI mode controller

@onready var player_grid_container = $GameContainer/PlayerSide/PlayerGridContainer
@onready var ai_grid_container = $GameContainer/AISide/AIGridContainer
@onready var player_score_label = $GameContainer/PlayerSide/PlayerScoreLabel
@onready var ai_score_label = $GameContainer/AISide/AIScoreLabel
@onready var result_panel = $ResultPanel
@onready var result_label = $ResultPanel/VBoxContainer/ResultLabel
@onready var result_restart_button = $ResultPanel/VBoxContainer/RestartButton
@onready var result_menu_button = $ResultPanel/VBoxContainer/MenuButton

@onready var pause_panel: Panel = $PausePanel
@onready var pause_resume_button: Button = $PausePanel/VBoxContainer/ResumeButton
@onready var pause_restart_button: Button = $PausePanel/VBoxContainer/RestartButton
@onready var pause_menu_button: Button = $PausePanel/VBoxContainer/PauseMenuButton


var player_grid = null
var ai_grid = null
var ai_controller = null
var game_active = false
var is_paused = false

# Track scores separately for each player
var player_score = 0
var ai_score = 0
var last_global_score = 0

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
	player_grid.set_meta("owner_type", "player")
	
	# Create AI grid
	ai_grid = Grid.instantiate()
	ai_grid_container.add_child(ai_grid)
	ai_grid.position = Vector2(192, 0)
	ai_grid.enable_input = false
	ai_grid.enable_camera_shake = false
	ai_grid.connect("game_over", _on_ai_game_over)
	ai_grid.set_meta("owner_type", "ai")
	
	# Create AI controller
	ai_controller = AIController.new()
	ai_controller.grid = ai_grid
	add_child(ai_controller)
	
	# Start both grids
	player_grid.start_game()
	ai_grid.start_game()
	
	# Hide panels
	result_panel.hide()
	pause_panel.hide()
	
	game_active = true
	is_paused = false
	
	# Update UI
	update_score_labels()

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

func _process(_delta):
	if game_active and not is_paused:
		update_score_labels()

func update_score_labels():
	player_score_label.text = "Score: " + str(player_score)
	ai_score_label.text = "Score: " + str(ai_score)

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

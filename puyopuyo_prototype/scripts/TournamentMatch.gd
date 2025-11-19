extends Control
# TournamentMatch.gd - Phase 3 Tournament Match with Timer and Overtime Mode

const BombController = preload("res://scripts/BombController.gd")
const Grid = preload("res://scenes/Grid.tscn")
const AIController = preload("res://scripts/AIController.gd")

# Grid containers
@onready var player_grid_container = $GameContainer/PlayerSide/PlayerGridContainer
@onready var ai_grid_container = $GameContainer/AISide/AIGridContainer

# UI Labels
@onready var player_label = $GameContainer/PlayerSide/PlayerLabel
@onready var ai_label = $GameContainer/AISide/AILabel
@onready var player_score_label = $GameContainer/PlayerSide/PlayerScoreLabel
@onready var ai_score_label = $GameContainer/AISide/AIScoreLabel
@onready var player_garbage_meter = $GameContainer/PlayerSide/GarbageMeter
@onready var ai_garbage_meter = $GameContainer/AISide/GarbageMeter

# Tournament UI
@onready var series_score_label = $UI/SeriesScorePanel/SeriesScoreLabel
@onready var round_indicator = $UI/RoundIndicator
@onready var timer_label = $UI/TimerLabel  # NEW: Timer display
@onready var opponent_portrait_small = $UI/OpponentInfoPanel/OpponentPortrait
@onready var opponent_name_label = $UI/OpponentInfoPanel/OpponentName
@onready var continues_label = $UI/ContinuesLabel

# Overlays
@onready var round_result_overlay = $UI/RoundResultOverlay
@onready var round_result_label = $UI/RoundResultOverlay/ResultLabel
@onready var round_result_sublabel = $UI/RoundResultOverlay/SubLabel

@onready var continue_overlay = $UI/ContinueOverlay
@onready var continue_label = $UI/ContinueOverlay/ContinueLabel
@onready var continue_yes_button = $UI/ContinueOverlay/VBoxContainer/YesButton
@onready var continue_no_button = $UI/ContinueOverlay/VBoxContainer/NoButton

# Pause
@onready var pause_panel = $MenuLayer/PausePanel
@onready var pause_resume_button = $MenuLayer/PausePanel/VBoxContainer/ResumeButton
@onready var pause_restart_button = $MenuLayer/PausePanel/VBoxContainer/RestartButton
@onready var pause_menu_button = $MenuLayer/PausePanel/VBoxContainer/PauseMenuButton
@onready var music_player = $MusicPlayer

@onready var quit_confirm_panel: Panel = $MenuLayer/QuitConfirmPanel
@onready var confirm_yes_button: Button = $MenuLayer/QuitConfirmPanel/VBoxContainer/ConfirmYesButton
@onready var confirm_no_button: Button = $MenuLayer/QuitConfirmPanel/VBoxContainer/ConfirmNoButton

@onready var dim_overlay: ColorRect = $MenuLayer/DimOverlay

# Debug
@onready var debug_autowin_button: Button = $MenuLayer/PausePanel/VBoxContainer/Autowin

# State variables
var player_grid = null
var ai_grid = null
var ai_controller = null
var game_active = false
var is_paused = false
var round_active = false

var player_round_wins = 0
var ai_round_wins = 0
var current_round = 1

var player_round_score = 0
var ai_round_score = 0
var round_start_time = 0.0
var last_global_score = 0

var current_opponent = null

var player_meter_flash_timer = 0.0
var ai_meter_flash_timer = 0.0
var meter_flash_duration = 0.5

# NEW: Overtime mode variables
var overtime_enabled = true  # Can be toggled in settings later
var overtime_threshold = 180.0  # 3 minutes in seconds
var overtime_active = false
var overtime_interval = 10.0  # Spawn bubbles every 10 seconds
var overtime_timer = 0.0

func _ready():
	# Allow input processing even when paused (for pause toggle)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set process modes for overlays
	round_result_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	continue_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	quit_confirm_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Connect buttons
	continue_yes_button.connect("pressed", _on_continue_yes_pressed)
	continue_no_button.connect("pressed", _on_continue_no_pressed)
	pause_resume_button.connect("pressed", _on_pause_resume_pressed)
	pause_restart_button.connect("pressed", _on_pause_restart_pressed)
	pause_menu_button.connect("pressed", _on_pause_menu_pressed)
	
	# Set quit confirm panel to process when paused
	quit_confirm_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	quit_confirm_panel.hide()

	# Connect confirmation buttons
	if confirm_yes_button:
		confirm_yes_button.connect("pressed", _on_confirm_quit_yes)
	if confirm_no_button:
		confirm_no_button.connect("pressed", _on_confirm_quit_no)
	
	#Debug Button Connect
	# Connect debug button
	if debug_autowin_button:
		debug_autowin_button.connect("pressed", _on_debug_autowin_pressed)
	
	# Connect to GameState
	GameState.connect("score_changed", _on_score_changed)
	
	# Get current opponent
	current_opponent = TournamentManager.get_current_opponent()
	
	if not current_opponent:
		push_error("No opponent in TournamentManager!")
		return
	
	# Initialize UI
	setup_opponent_info()
	load_opponent_music() 
	update_series_score()
	update_round_indicator()
	update_continues_label()
	update_timer_label(0.0)  # NEW: Initialize timer
	
	# Hide overlays
	round_result_overlay.hide()
	continue_overlay.hide()
	pause_panel.hide()
	
	# Start first round
	start_new_round()
	
func _on_debug_autowin_pressed():
	"""DEBUG: Instantly win the current round"""
	AudioManager.play_button_click()
	
	print("DEBUG: Auto-winning round for player")
	
	# Unpause
	is_paused = false
	pause_panel.hide()
	get_tree().paused = false
	
	# Force AI to lose
	if ai_grid:
		# Trigger game over on AI grid
		ai_grid.emit_signal("game_over")

func setup_opponent_info():
	"""Setup opponent info panel"""
	opponent_name_label.text = current_opponent.opponent_name
	ai_label.text = current_opponent.opponent_name.to_upper()
	
	# Load portrait
	if current_opponent.portrait_path and current_opponent.portrait_path != "":
		var texture = load(current_opponent.portrait_path)
		if texture:
			opponent_portrait_small.texture = texture
	
	print("=== TOURNAMENT MATCH ===")
	print("Opponent: ", current_opponent.opponent_name)
	print("Difficulty: ", TournamentManager.get_difficulty_name())
	print("Overtime Mode: ", "ENABLED" if overtime_enabled else "DISABLED")
	print("========================")

func load_opponent_music():
	"""Load and set the opponent's unique music track"""
	if not current_opponent or not music_player:
		print("✗ No opponent or music player")
		return
	
	var music_path = current_opponent.music_track_path
	
	# Stop any currently playing music
	if music_player.playing:
		music_player.stop()
	
	# Check if opponent has a music track defined
	if music_path and music_path != "":
		var music_track = load(music_path)
		
		if music_track:
			print("✓ Loaded opponent music: ", music_path)
			music_player.stream = music_track
			print("  Stream assigned to player")
		else:
			print("✗ Failed to load music from ", music_path)
	else:
		print("⚠ No music track defined for opponent - keeping default")
		
func start_new_round():
	"""Start new round"""
	print("\n=== ROUND ", current_round, " START ===")
	
	# Clean up old grids
	if player_grid:
		player_grid.queue_free()
	if ai_grid:
		ai_grid.queue_free()
	if ai_controller:
		ai_controller.queue_free()
		
	if current_round == 1:
		load_opponent_music()
	
	# Configure game for VS mode
	GameState.configure_for_game_mode(GameState.GameMode.VS_MODE)
	
	# Set bomb mode based on opponent
	var bomb_mode = current_opponent.get_bomb_type(TournamentManager.current_difficulty)
	GameState.set_bomb_mode(bomb_mode)
	
	# Reset state
	GameState.reset_game()
	player_round_score = 0
	ai_round_score = 0
	last_global_score = 0
	round_start_time = Time.get_ticks_msec() / 1000.0
	
	# NEW: Reset overtime state
	overtime_active = false
	overtime_timer = 0.0
	
	# Create player grid
	player_grid = Grid.instantiate()
	player_grid_container.add_child(player_grid)
	player_grid.position = Vector2(192, 0)
	player_grid.enable_input = false
	player_grid.enable_camera_shake = false
	player_grid.connect("game_over", _on_player_loses_round)
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
	ai_grid.connect("game_over", _on_ai_loses_round)
	ai_grid.connect("garbage_sent", _on_ai_sends_garbage)
	ai_grid.set_meta("owner_type", "ai")
	ai_grid.set_fall_speed(GameState.level_speeds[0])
	ai_grid.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Create AI controller with opponent difficulty
	ai_controller = AIController.new()
	ai_controller.grid = ai_grid
	var ai_difficulty = current_opponent.get_ai_difficulty(TournamentManager.current_difficulty)
	ai_controller.configure_difficulty(ai_difficulty)
	add_child(ai_controller)
	ai_controller.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Start both grids
	player_grid.start_game()
	ai_grid.start_game()
	
	# Reset garbage meters
	player_garbage_meter.value = 0
	ai_garbage_meter.value = 0
	
	# Update UI
	update_round_indicator()
	update_score_labels()
	
	game_active = true
	round_active = true
	
	AudioManager.play_game_start()
	
	if music_player and music_player.stream:
		music_player.volume_db = -12
		music_player.play()
		print("▶ Music started playing")
	else:
		print("✗ Music player has no stream!")

func _process(delta):
	if game_active and round_active and not is_paused:
		update_score_labels()
		update_garbage_meters(delta)
		
		# NEW: Update timer and check for overtime
		var elapsed_time = get_round_elapsed_time()
		update_timer_label(elapsed_time)
		
		if overtime_enabled:
			check_and_handle_overtime(delta, elapsed_time)

# NEW: Get round elapsed time
func get_round_elapsed_time() -> float:
	"""Get elapsed time for current round in seconds"""
	return (Time.get_ticks_msec() / 1000.0) - round_start_time

# NEW: Update timer label
func update_timer_label(elapsed_seconds: float):
	"""Update the timer display"""
	if not timer_label:
		return
	
	var minutes = int(elapsed_seconds) / 60
	var seconds = int(elapsed_seconds) % 60
	
	# Change color when approaching overtime
	if overtime_enabled and elapsed_seconds >= overtime_threshold - 30.0:
		# Flash red when close to overtime
		if overtime_active:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		else:
			var flash = abs(sin(elapsed_seconds * 3.0))
			timer_label.add_theme_color_override("font_color", Color(1.0, flash * 0.5, 0.0, 1.0))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
	
	timer_label.text = "%d:%02d" % [minutes, seconds]

# NEW: Overtime mode handling
func check_and_handle_overtime(delta: float, elapsed_time: float):
	"""Check if overtime should activate and handle overtime spawning"""
	if not overtime_active and elapsed_time >= overtime_threshold:
		activate_overtime()
	
	if overtime_active:
		overtime_timer += delta
		
		# Spawn bubble row every 10 seconds
		if overtime_timer >= overtime_interval:
			overtime_timer -= overtime_interval
			spawn_overtime_bubbles()

# NEW: Activate overtime mode
func activate_overtime():
	"""Activate overtime mode - start spawning pressure bubbles"""
	overtime_active = true
	overtime_timer = 0.0
	
	print("=== OVERTIME ACTIVATED ===")
	print("Bubble rows will spawn every ", overtime_interval, " seconds")
	
	# Visual/audio feedback
	AudioManager.play_danger_warning()
	
	# Flash the timer
	if timer_label:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0, 1.0))
	
	# Show warning notification on both grids
	if player_grid and player_grid.event_notification:
		player_grid.event_notification.show_notification("OVERTIME!", player_grid.event_notification.NotificationType.DANGER, 2.0)
	
	if ai_grid and ai_grid.event_notification:
		ai_grid.event_notification.show_notification("OVERTIME!", ai_grid.event_notification.NotificationType.DANGER, 2.0)

# NEW: Spawn overtime bubble rows
func spawn_overtime_bubbles():
	"""Request overtime bubble rows to spawn on next turn"""
	print("Overtime: Requesting bubble row spawn on next turn")
	
	# Play warning sound
	AudioManager.play_garbage_incoming()
	
	# Request spawn on player grid
	if player_grid:
		player_grid.request_overtime_bubble_spawn()
	
	# Request spawn on AI grid
	if ai_grid:
		ai_grid.request_overtime_bubble_spawn()

func _input(event):
	if event.is_action_pressed("pause") and game_active:
		toggle_pause()
		return
	
	if not game_active or is_paused or not round_active:
		return
	
	# Player input
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
			
func _on_player_loses_round():
	"""Player lost this round"""
	if not round_active:
		return
	
	round_active = false
	ai_round_wins += 1
	
	print("Round ", current_round, " - AI wins!")
	
	var match_over = TournamentManager.opponent_wins_round()
	update_series_score()
	
	if match_over:
		show_match_defeat_overlay()
	else:
		show_round_result_overlay(false)

func _on_ai_loses_round():
	"""AI lost this round"""
	if not round_active:
		return
	
	round_active = false
	player_round_wins += 1
	
	print("Round ", current_round, " - Player wins!")
	
	# Calculate round time and speed bonus
	var round_time = get_round_elapsed_time()
	var speed_bonus = TournamentManager.calculate_speed_bonus(round_time)
	
	print("Round time: ", round_time, "s - Speed bonus: ", speed_bonus)
	
	# Add score to tournament
	TournamentManager.add_score(player_round_score + speed_bonus)
	
	var match_over = TournamentManager.player_wins_round()
	update_series_score()
	
	if match_over:
		show_match_victory_overlay()
	else:
		show_round_result_overlay(true)

func show_round_result_overlay(player_won: bool):
	"""Show round result and continue to next round"""
	get_tree().paused = true 
	
	if player_won:
		round_result_label.text = "ROUND WIN!"
		round_result_sublabel.text = "You won round " + str(current_round)
		AudioManager.play_victory()
	else:
		round_result_label.text = "ROUND LOST"
		round_result_sublabel.text = "Opponent won round " + str(current_round)
		AudioManager.play_defeat()
	
	round_result_overlay.modulate.a = 0.0
	round_result_overlay.show()
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(round_result_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(round_result_overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		round_result_overlay.hide()
		get_tree().paused = false
		current_round += 1
		start_new_round()
	)

func show_match_victory_overlay():
	"""Player won the match - proceed to next opponent"""
	get_tree().paused = true
	
	round_result_label.text = "MATCH WIN!"
	round_result_sublabel.text = "Defeated " + current_opponent.opponent_name + "!"
	
	AudioManager.play_victory()
	
	round_result_overlay.modulate.a = 0.0
	round_result_overlay.show()
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(round_result_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.5)
	tween.tween_property(round_result_overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		round_result_overlay.hide()
		get_tree().paused = false
		proceed_to_next_opponent()
	)

func show_match_defeat_overlay():
	"""Player lost the match - show continue prompt"""
	get_tree().paused = true
	game_active = false
	
	AudioManager.play_defeat()
	
	if TournamentManager.can_continue():
		show_continue_prompt()
	else:
		show_game_over()
		
func show_continue_prompt():
	"""Show continue prompt overlay"""
	var continues = TournamentManager.continues_remaining
	continue_label.text = "Continue?\n\n" + str(continues) + " continues remaining"
	
	continue_overlay.modulate.a = 0.0
	continue_overlay.show()
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(continue_overlay, "modulate:a", 1.0, 0.3)
	
	await get_tree().create_timer(0.1, true).timeout
	continue_yes_button.grab_focus()

func _on_continue_yes_pressed():
	"""Player chose to continue"""
	AudioManager.play_button_click()
	
	if TournamentManager.use_continue():
		print("Continue used. Remaining: ", TournamentManager.continues_remaining)
		
		# Reset match state
		player_round_wins = 0
		ai_round_wins = 0
		current_round = 1
		
		update_series_score()
		update_continues_label()
		
		continue_overlay.hide()
		get_tree().paused = false
		game_active = true
		
		start_new_round()
	else:
		show_game_over()

func _on_continue_no_pressed():
	"""Player chose not to continue"""
	AudioManager.play_button_click()
	
	# Reset tournament state before showing game over
	TournamentManager.reset_tournament()
	
	show_game_over()

func show_game_over():
	"""Show game over and return to menu"""
	continue_overlay.hide()
	
	# Ensure tournament is reset (in case called from elsewhere)
	TournamentManager.reset_tournament()
	
	round_result_label.text = "GAME OVER"
	round_result_sublabel.text = "Tournament ended"
	
	round_result_overlay.modulate.a = 0.0
	round_result_overlay.show()
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(round_result_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(round_result_overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		get_tree().paused = false
		if music_player:
			music_player.stop()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)

func proceed_to_next_opponent():
	"""Move to next opponent or victory screen"""
	TournamentManager.complete_opponent()
	
	if TournamentManager.is_tournament_complete():
		print("TOURNAMENT COMPLETE!")
		get_tree().change_scene_to_file("res://scenes/TournamentVictory.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/TournamentIntro.tscn")

func update_series_score():
	"""Update the series score display"""
	series_score_label.text = str(player_round_wins) + " - " + str(ai_round_wins)

func update_round_indicator():
	"""Update round indicator"""
	round_indicator.text = "ROUND " + str(current_round)

func update_continues_label():
	"""Update continues remaining label"""
	continues_label.text = "Continues: " + str(TournamentManager.continues_remaining)

func update_score_labels():
	"""Update score labels"""
	player_score_label.text = "Score: " + str(player_round_score)
	ai_score_label.text = "Score: " + str(ai_round_score)

func _on_score_changed(new_score):
	"""Track which grid scored"""
	var score_delta = new_score - last_global_score
	last_global_score = new_score
	
	if score_delta > 0:
		if player_grid and player_grid.clearing_matches:
			player_round_score += score_delta
		elif ai_grid and ai_grid.clearing_matches:
			ai_round_score += score_delta

func _on_player_sends_garbage(nuisance_points: int):
	"""Player sent garbage to AI"""
	if ai_grid:
		ai_grid.receive_garbage(nuisance_points)
		ai_meter_flash_timer = meter_flash_duration

func _on_ai_sends_garbage(nuisance_points: int):
	"""AI sent garbage to player"""
	if player_grid:
		player_grid.receive_garbage(nuisance_points)
		player_meter_flash_timer = meter_flash_duration
		
func update_garbage_meters(delta):
	"""Update garbage meter displays with flash effect"""
	# Player meter
	if player_grid:
		var fill = player_grid.get_garbage_meter_fill()
		player_garbage_meter.value = fill
		
		if player_meter_flash_timer > 0:
			player_meter_flash_timer -= delta
			var flash_alpha = abs(sin(player_meter_flash_timer * 10))
			player_garbage_meter.modulate = Color(1.0, flash_alpha, flash_alpha)
		else:
			if fill > 0.5:
				player_garbage_meter.modulate = Color(1.0, 0.3, 0.3)
			elif fill > 0:
				player_garbage_meter.modulate = Color(1.0, 0.7, 0.3)
			else:
				player_garbage_meter.modulate = Color(0.5, 0.5, 0.5)
	
	# AI meter
	if ai_grid:
		var fill = ai_grid.get_garbage_meter_fill()
		ai_garbage_meter.value = fill
		
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

func toggle_pause():
	"""Toggle pause state"""
	if not is_paused:
		is_paused = true
		dim_overlay.show()
		pause_panel.show()
		get_tree().paused = true
		AudioManager.play_pause()
		await get_tree().create_timer(0.01).timeout
		pause_resume_button.grab_focus()
	else:
		is_paused = false
		dim_overlay.hide()
		pause_panel.hide()
		get_tree().paused = false
		AudioManager.play_unpause()

func _on_pause_resume_pressed():
	AudioManager.play_button_click()
	toggle_pause()

func _on_pause_restart_pressed():
	AudioManager.play_button_click()
	if is_paused:
		get_tree().paused = false
	# Reset to beginning of match
	player_round_wins = 0
	ai_round_wins = 0
	current_round = 1
	TournamentManager.reset_match_state()
	update_series_score()
	start_new_round()

func _on_pause_menu_pressed():
	"""Show quit confirmation"""
	AudioManager.play_button_click()
	
	# Hide pause panel, show confirmation
	pause_panel.hide()
	quit_confirm_panel.show()
	
	await get_tree().create_timer(0.01, true).timeout
	confirm_no_button.grab_focus()

func _on_confirm_quit_yes():
	"""Player confirmed quit"""
	AudioManager.play_button_click()
	
	# Stop music
	if music_player:
		music_player.stop()
	
	# Reset tournament state
	TournamentManager.reset_tournament()
	
	# Unpause and return to menu
	if is_paused:
		is_paused = false
		get_tree().paused = false
	
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_confirm_quit_no():
	"""Player cancelled quit"""
	AudioManager.play_button_click()
	
	# Return to pause menu
	quit_confirm_panel.hide()
	pause_panel.show()
	
	await get_tree().create_timer(0.01, true).timeout
	pause_menu_button.grab_focus()

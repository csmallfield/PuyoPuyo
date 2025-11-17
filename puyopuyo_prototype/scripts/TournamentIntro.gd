extends Control
# TournamentIntro.gd - Tournament Mode intro and difficulty selection

# ============================================
# SCENE REFERENCES
# ============================================

# Difficulty Selection Panel
@onready var difficulty_panel = $DifficultyPanel
@onready var easy_button = $DifficultyPanel/VBoxContainer/EasyButton
@onready var normal_button = $DifficultyPanel/VBoxContainer/NormalButton
@onready var hard_button = $DifficultyPanel/VBoxContainer/HardButton
@onready var back_button = $DifficultyPanel/VBoxContainer/BackButton

# Portrait Shuffle Panel
@onready var shuffle_panel = $ShufflePanel
@onready var shuffle_label = $ShufflePanel/ShuffleLabel
@onready var portrait_grid = $ShufflePanel/PortraitGrid

# Opponent Presentation Panel
@onready var presentation_panel = $PresentationPanel
@onready var opponent_portrait = $PresentationPanel/OpponentPortrait
@onready var opponent_name_label = $PresentationPanel/OpponentName
@onready var opponent_bio_label = $PresentationPanel/OpponentBio
@onready var continue_prompt = $PresentationPanel/ContinuePrompt

# ============================================
# STATE
# ============================================

enum State {
	DIFFICULTY_SELECT,
	SHUFFLING,
	PRESENTING,
	TRANSITIONING
}

var current_state = State.DIFFICULTY_SELECT
var selected_difficulty = TournamentManager.Difficulty.NORMAL
var tournament_roster: TournamentRoster = null
var current_opponent_index = 0

# Portrait shuffle animation
var shuffle_timer = 0.0
var shuffle_duration = 2.0
var shuffle_speed = 0.1
var portraits: Array[TextureRect] = []

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Load tournament roster
	tournament_roster = load("res://resources/default_tournament_roster.tres")
	
	if not tournament_roster:
		push_error("TournamentIntro: Failed to load tournament roster!")
		return
	
	# Connect difficulty buttons
	easy_button.connect("pressed", _on_easy_pressed)
	normal_button.connect("pressed", _on_normal_pressed)
	hard_button.connect("pressed", _on_hard_pressed)
	back_button.connect("pressed", _on_back_pressed)
	
	# Setup initial state
	show_difficulty_selection()
	
	# Play intro music (if you have one)
	AudioManager.play_transition()

# ============================================
# DIFFICULTY SELECTION
# ============================================

func show_difficulty_selection():
	"""Show difficulty selection panel"""
	current_state = State.DIFFICULTY_SELECT
	
	difficulty_panel.show()
	shuffle_panel.hide()
	presentation_panel.hide()
	
	# Grab focus on normal button
	normal_button.grab_focus()

func _on_easy_pressed():
	AudioManager.play_button_click()
	selected_difficulty = TournamentManager.Difficulty.EASY
	start_tournament()

func _on_normal_pressed():
	AudioManager.play_button_click()
	selected_difficulty = TournamentManager.Difficulty.NORMAL
	start_tournament()

func _on_hard_pressed():
	AudioManager.play_button_click()
	selected_difficulty = TournamentManager.Difficulty.HARD
	start_tournament()

func _on_back_pressed():
	AudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# ============================================
# TOURNAMENT START
# ============================================

func start_tournament():
	"""Initialize tournament and begin portrait shuffle"""
	print("\n=== TOURNAMENT START ===")
	print("Difficulty: ", ["Easy", "Normal", "Hard"][selected_difficulty])
	
	# Initialize tournament in manager
	TournamentManager.initialize_tournament(tournament_roster, selected_difficulty)
	
	# Start portrait shuffle sequence
	current_opponent_index = 0
	show_portrait_shuffle()

# ============================================
# PORTRAIT SHUFFLE
# ============================================

func show_portrait_shuffle():
	"""Show portrait shuffle animation"""
	current_state = State.SHUFFLING
	
	difficulty_panel.hide()
	shuffle_panel.show()
	presentation_panel.hide()
	
	shuffle_label.text = "SELECTING OPPONENTS..."
	
	# Create portrait grid
	create_portrait_grid()
	
	# Start shuffle animation
	shuffle_timer = 0.0
	
	print("Starting portrait shuffle animation")

func create_portrait_grid():
	"""Create grid of opponent portraits"""
	# Clear existing portraits
	for child in portrait_grid.get_children():
		child.queue_free()
	portraits.clear()
	
	# Create 5 portrait placeholders in a grid
	# Grid will be 3 columns: [X] [X] [X]
	#                          [X] [X]
	
	portrait_grid.columns = 3
	
	for i in range(5):
		var portrait_rect = TextureRect.new()
		portrait_rect.custom_minimum_size = Vector2(150, 150)
		portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# For now, use colored backgrounds as placeholders
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(150, 150)
		
		# Add opponent name label
		var name_label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 4)
		
		# Set initial appearance (will be updated in animation)
		var opponent = tournament_roster.opponents[i]
		name_label.text = "?"
		panel.modulate = Color(0.3, 0.3, 0.3)
		
		panel.add_child(name_label)
		name_label.anchors_preset = Control.PRESET_FULL_RECT
		name_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		name_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		
		portrait_grid.add_child(panel)
		portraits.append(panel)

func _process(delta):
	if current_state == State.SHUFFLING:
		process_shuffle_animation(delta)

func process_shuffle_animation(delta):
	"""Animate the portrait shuffle"""
	shuffle_timer += delta
	
	# Flash portraits during shuffle
	var flash_interval = shuffle_speed
	var flash_count = int(shuffle_timer / flash_interval)
	
	for i in range(portraits.size()):
		var portrait = portraits[i]
		var opponent = tournament_roster.opponents[i]
		
		# Alternate between showing and hiding opponent info
		if int(shuffle_timer / flash_interval) % 2 == 0:
			portrait.modulate = Color(0.5 + randf() * 0.5, 0.5 + randf() * 0.5, 0.5 + randf() * 0.5)
			if portrait.get_child_count() > 0:
				var label = portrait.get_child(0)
				label.text = "?"
		else:
			# Randomly assign colors during shuffle
			portrait.modulate = Color(randf(), randf(), randf())
	
	# After shuffle duration, reveal opponents
	if shuffle_timer >= shuffle_duration:
		reveal_opponents()

func reveal_opponents():
	"""Reveal the opponent lineup after shuffle"""
	print("Revealing opponent lineup")
	
	# Get the actual opponent order from TournamentManager
	var opponent_queue = TournamentManager.opponent_queue
	
	# Reveal each opponent
	for i in range(portraits.size()):
		var portrait = portraits[i]
		var opponent = opponent_queue[i]
		
		# Set final appearance
		if opponent.is_boss:
			portrait.modulate = Color(1.0, 0.8, 0.0)  # Gold for boss
		else:
			portrait.modulate = Color(0.6, 0.8, 1.0)  # Blue for regulars
		
		if portrait.get_child_count() > 0:
			var label = portrait.get_child(0)
			label.text = opponent.opponent_name

	# Play reveal sound
	AudioManager.play_difficulty_change()
	
	# Wait a moment, then present first opponent
	await get_tree().create_timer(1.5).timeout
	present_opponent(0)

# ============================================
# OPPONENT PRESENTATION
# ============================================

func present_opponent(opponent_index: int):
	"""Present a specific opponent with zoom-in effect"""
	current_state = State.PRESENTING
	current_opponent_index = opponent_index
	
	var opponent = TournamentManager.opponent_queue[opponent_index]
	
	print("Presenting opponent: ", opponent.opponent_name)
	
	# Hide shuffle panel, show presentation panel
	shuffle_panel.hide()
	presentation_panel.show()
	
	# Set opponent info
	opponent_name_label.text = opponent.opponent_name
	opponent_bio_label.text = opponent.bio_text
	
	# Set portrait appearance (placeholder for now)
	if opponent.is_boss:
		opponent_portrait.modulate = Color(1.0, 0.8, 0.0)
	else:
		opponent_portrait.modulate = Color(0.6, 0.8, 1.0)
	
	# Show continue prompt
	continue_prompt.text = "Press SPACE to continue..."
	continue_prompt.modulate.a = 0.0
	
	# Animate presentation
	animate_presentation()

func animate_presentation():
	"""Animate the opponent presentation"""
	# Fade in name
	opponent_name_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(opponent_name_label, "modulate:a", 1.0, 0.5)
	
	# Scale in portrait
	opponent_portrait.scale = Vector2(0.1, 0.1)
	tween.parallel().tween_property(opponent_portrait, "scale", Vector2(1.0, 1.0), 0.5)
	
	# Fade in bio
	opponent_bio_label.modulate.a = 0.0
	tween.tween_property(opponent_bio_label, "modulate:a", 1.0, 0.5)
	
	# Fade in continue prompt
	tween.tween_property(continue_prompt, "modulate:a", 1.0, 0.3)
	
	# Play sound
	AudioManager.play_game_start()

# ============================================
# INPUT HANDLING
# ============================================

func _input(event):
	if current_state == State.PRESENTING:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("fast_drop"):
			advance_to_next()
	
	# Allow escape to go back during difficulty selection
	if current_state == State.DIFFICULTY_SELECT:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_on_back_pressed()

# ============================================
# PROGRESSION
# ============================================

func advance_to_next():
	"""Advance to next opponent presentation or start matches"""
	AudioManager.play_button_click()
	
	current_opponent_index += 1
	
	if current_opponent_index < TournamentManager.opponent_queue.size():
		# Present next opponent
		present_opponent(current_opponent_index)
	else:
		# All opponents presented, start tournament matches!
		start_matches()

func start_matches():
	"""Transition to tournament matches"""
	current_state = State.TRANSITIONING
	
	print("All opponents presented! Starting tournament matches...")
	
	AudioManager.play_transition()
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	# Load tournament match scene (placeholder for now - Phase 3)
	# For now, go back to main menu as a placeholder
	get_tree().change_scene_to_file("res://scenes/TournamentMode.tscn")
	
	# In Phase 3, this will be:
	# get_tree().change_scene_to_file("res://scenes/TournamentMatch.tscn")

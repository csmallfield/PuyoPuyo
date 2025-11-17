extends Control
# TournamentIntro.gd - Tournament difficulty selection and opponent showcase

@onready var difficulty_panel = $DifficultyPanel
@onready var shuffle_panel = $ShufflePanel
@onready var shuffle_label = $ShufflePanel/ShuffleLabel
@onready var portrait_grid = $ShufflePanel/PortraitGrid
@onready var presentation_panel = $PresentationPanel
@onready var opponent_portrait = $PresentationPanel/OpponentPortrait
@onready var opponent_name = $PresentationPanel/OpponentName
@onready var opponent_bio = $PresentationPanel/OpponentBio
@onready var continue_prompt = $PresentationPanel/ContinuePrompt

@onready var easy_button = $DifficultyPanel/VBoxContainer/EasyButton
@onready var normal_button = $DifficultyPanel/VBoxContainer/NormalButton
@onready var hard_button = $DifficultyPanel/VBoxContainer/HardButton
@onready var back_button = $DifficultyPanel/VBoxContainer/BackButton

var tournament_roster: Resource = null
var selected_difficulty: String = ""
var current_opponent: Resource = null
var portrait_nodes = []

func _ready():
	# Load tournament roster
	tournament_roster = load("res://resources/default_tournament_roster.tres")
	
	if not tournament_roster:
		push_error("Failed to load tournament_roster.tres")
		return
	
	# Connect difficulty buttons
	easy_button.connect("pressed", _on_difficulty_pressed.bind("Easy"))
	normal_button.connect("pressed", _on_difficulty_pressed.bind("Normal"))
	hard_button.connect("pressed", _on_difficulty_pressed.bind("Hard"))
	back_button.connect("pressed", _on_back_pressed)
	
	# NEW: Check if tournament is already in progress
	# Use the class variable, not a local variable!
	current_opponent = TournamentManager.get_current_opponent()
	
	if current_opponent != null:
		# Tournament already started - skip difficulty selection and show next opponent
		print("Tournament in progress - showing next opponent: ", current_opponent.opponent_name)
		difficulty_panel.hide()
		shuffle_panel.hide()
		presentation_panel.hide()
		
		# Set the selected difficulty from TournamentManager
		selected_difficulty = TournamentManager.get_difficulty_name()
		
		# Go directly to presenting the opponent (no need to reassign current_opponent)
		present_selected_opponent()
	else:
		# New tournament - start with difficulty selection visible
		difficulty_panel.show()
		shuffle_panel.hide()
		presentation_panel.hide()
		
		# Grab focus on normal button
		normal_button.grab_focus()

func _on_difficulty_pressed(difficulty: String):
	print("Selected difficulty: ", difficulty)
	selected_difficulty = difficulty
	
	AudioManager.play_button_click()
	
	# Fade out difficulty panel
	var tween = create_tween()
	tween.tween_property(difficulty_panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(difficulty_panel.hide)
	
	# Show opponent showcase
	tween.tween_callback(show_opponent_portraits)

func show_opponent_portraits():
	"""Display all opponent portraits in the lineup"""
	shuffle_panel.show()
	shuffle_panel.modulate.a = 0.0
	
	# Clear any existing portraits
	for child in portrait_grid.get_children():
		child.queue_free()
	portrait_nodes.clear()
	
	# Get all opponents from roster
	var all_opponents = tournament_roster.opponents
	
	print("Loading ", all_opponents.size(), " opponent portraits")
	
	for i in range(all_opponents.size()):
		var opponent = all_opponents[i]
		
		# Create TextureRect for portrait
		var portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2(128, 128)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Load portrait image
		if opponent.portrait_path and opponent.portrait_path != "":
			var texture = load(opponent.portrait_path)
			if texture:
				portrait.texture = texture
				print("Loaded portrait for ", opponent.opponent_name, " from ", opponent.portrait_path)
			else:
				print("WARNING: Failed to load portrait from ", opponent.portrait_path)
				# Create fallback colored rect
				portrait.modulate = Color(randf(), randf(), randf())
		else:
			print("WARNING: No portrait path for ", opponent.opponent_name)
			# Create fallback colored rect
			portrait.modulate = Color(randf(), randf(), randf())
		
		# Add to container
		portrait_grid.add_child(portrait)
		portrait_nodes.append(portrait)
		
		# Store opponent data in metadata
		portrait.set_meta("opponent_data", opponent)
	
	# Fade in portraits
	var tween = create_tween()
	tween.tween_property(shuffle_panel, "modulate:a", 1.0, 0.5)
	
	# Start shuffle animation
	tween.tween_callback(shuffle_portraits)

func shuffle_portraits():
	"""Animate portrait shuffling"""
	print("Shuffling portraits...")
	
	var shuffle_duration = 1.5
	var shuffle_count = 8
	var interval = shuffle_duration / shuffle_count
	
	AudioManager.play_button_hover()  # Use hover sound for shuffle
	
	for i in range(shuffle_count):
		await get_tree().create_timer(interval).timeout
		
		# Swap random portraits visually (not the actual nodes)
		var idx1 = randi() % portrait_nodes.size()
		var idx2 = randi() % portrait_nodes.size()
		
		if idx1 != idx2:
			# Swap positions with animation
			var pos1 = portrait_nodes[idx1].position
			var pos2 = portrait_nodes[idx2].position
			
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(portrait_nodes[idx1], "position", pos2, 0.2)
			tween.tween_property(portrait_nodes[idx2], "position", pos1, 0.2)
	
	# Select opponent after shuffle
	await get_tree().create_timer(0.3).timeout
	select_random_opponent()

func select_random_opponent():
	"""Select and present a random opponent"""
	# Convert string difficulty to enum
	var difficulty_enum = TournamentManager.Difficulty.NORMAL  # Default
	match selected_difficulty:
		"Easy":
			difficulty_enum = TournamentManager.Difficulty.EASY
		"Normal":
			difficulty_enum = TournamentManager.Difficulty.NORMAL
		"Hard":
			difficulty_enum = TournamentManager.Difficulty.HARD
	
	# FIXED: Correct argument order (roster, difficulty)
	TournamentManager.initialize_tournament(tournament_roster, difficulty_enum)
	
	# Get first opponent
	current_opponent = TournamentManager.get_current_opponent()
	
	if not current_opponent:
		push_error("Failed to get first opponent")
		return
	
	print("Selected first opponent: ", current_opponent.opponent_name)
	AudioManager.play_button_click()
	present_selected_opponent()

func present_selected_opponent():
	"""Present the selected opponent with details"""
	# Load large portrait
	if current_opponent.portrait_path and current_opponent.portrait_path != "":
		var texture = load(current_opponent.portrait_path)
		if texture:
			opponent_portrait.texture = texture
			print("Loaded large portrait for ", current_opponent.opponent_name)
		else:
			# Fallback: solid color
			print("WARNING: Failed to load large portrait, using fallback")
			opponent_portrait.texture = null
			opponent_portrait.modulate = Color(0.5, 0.5, 0.5)
	else:
		# Fallback: solid color
		print("WARNING: No portrait path, using fallback")
		opponent_portrait.texture = null
		opponent_portrait.modulate = Color(0.5, 0.5, 0.5)
	
	# Set name and bio
	opponent_name.text = current_opponent.opponent_name
	opponent_bio.text = current_opponent.bio_text
	
	# Hide shuffle panel
	shuffle_panel.hide()
	
	# Animate panel appearance
	presentation_panel.modulate.a = 0.0
	presentation_panel.show()
	
	var tween = create_tween()
	tween.tween_property(presentation_panel, "modulate:a", 1.0, 0.5)
	
	# Show continue prompt
	continue_prompt.text = "Press SPACE to begin..."
	
	# Enable input to continue
	set_process_input(true)

func _input(event):
	# Wait for any key press to continue to match
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.pressed and presentation_panel.visible:
			set_process_input(false)
			start_tournament_match()

func start_tournament_match():
	"""Transition to tournament match scene"""
	print("Starting tournament match against ", current_opponent.opponent_name)
	
	AudioManager.play_transition()
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/TournamentMatch.tscn"))

func _on_back_pressed():
	"""Return to main menu"""
	AudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

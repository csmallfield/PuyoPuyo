extends Control
# TournamentIntro.gd - Tournament difficulty selection and opponent showcase

@onready var difficulty_panel = $DifficultyPanel
@onready var opponent_showcase = $OpponentShowcase
@onready var portrait_container = $OpponentShowcase/PortraitContainer
@onready var selected_opponent_panel = $OpponentShowcase/SelectedOpponentPanel
@onready var portrait_large = $OpponentShowcase/SelectedOpponentPanel/PortraitLarge
@onready var name_label = $OpponentShowcase/SelectedOpponentPanel/NameLabel
@onready var bio_label = $OpponentShowcase/SelectedOpponentPanel/BioLabel
@onready var continue_prompt = $OpponentShowcase/SelectedOpponentPanel/ContinuePrompt

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
	tournament_roster = load("res://resources/tournament_roster.tres")
	
	if not tournament_roster:
		push_error("Failed to load tournament_roster.tres")
		return
	
	# Connect difficulty buttons
	easy_button.connect("pressed", _on_difficulty_pressed.bind("Easy"))
	normal_button.connect("pressed", _on_difficulty_pressed.bind("Normal"))
	hard_button.connect("pressed", _on_difficulty_pressed.bind("Hard"))
	back_button.connect("pressed", _on_back_pressed)
	
	# Start with difficulty selection visible
	difficulty_panel.show()
	opponent_showcase.hide()
	
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
	opponent_showcase.show()
	opponent_showcase.modulate.a = 0.0
	
	# Clear any existing portraits
	for child in portrait_container.get_children():
		child.queue_free()
	portrait_nodes.clear()
	
	# Create portrait nodes for all opponents (regular + boss)
	var all_opponents = tournament_roster.regular_opponents.duplicate()
	all_opponents.append(tournament_roster.boss_opponent)
	
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
		portrait_container.add_child(portrait)
		portrait_nodes.append(portrait)
		
		# Store opponent data in metadata
		portrait.set_meta("opponent_data", opponent)
	
	# Fade in portraits
	var tween = create_tween()
	tween.tween_property(opponent_showcase, "modulate:a", 1.0, 0.5)
	
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
	# Randomize opponent order
	var opponent_indices = []
	for i in range(tournament_roster.regular_opponents.size()):
		opponent_indices.append(i)
	opponent_indices.shuffle()
	
	# Initialize tournament with shuffled opponents
	TournamentManager.initialize_tournament(selected_difficulty, tournament_roster)
	
	# Get first opponent
	current_opponent = TournamentManager.get_next_opponent()
	
	if not current_opponent:
		push_error("Failed to get first opponent")
		return
	
	print("Selected first opponent: ", current_opponent.opponent_name)
	
	AudioManager.play_button_click()
	
	# Animate presentation
	present_selected_opponent()

func present_selected_opponent():
	"""Present the selected opponent with details"""
	# Load large portrait
	if current_opponent.portrait_path and current_opponent.portrait_path != "":
		var texture = load(current_opponent.portrait_path)
		if texture:
			portrait_large.texture = texture
		else:
			# Fallback: solid color
			portrait_large.texture = null
			portrait_large.modulate = Color(0.5, 0.5, 0.5)
	else:
		# Fallback: solid color
		portrait_large.texture = null
		portrait_large.modulate = Color(0.5, 0.5, 0.5)
	
	# Set name and bio
	name_label.text = current_opponent.opponent_name
	bio_label.text = current_opponent.bio_text
	
	# Animate panel appearance
	selected_opponent_panel.modulate.a = 0.0
	selected_opponent_panel.show()
	
	var tween = create_tween()
	tween.tween_property(selected_opponent_panel, "modulate:a", 1.0, 0.5)
	
	# Show continue prompt
	continue_prompt.text = "Press any key to begin..."
	
	# Enable input to continue
	set_process_input(true)

func _input(event):
	# Wait for any key press to continue to match
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.pressed and selected_opponent_panel.visible:
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

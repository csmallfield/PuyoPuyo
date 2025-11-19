extends Control
# TournamentIntro.gd - Tournament difficulty selection and opponent showcase

const BombController = preload("res://scripts/BombController.gd")

@onready var difficulty_panel = $DifficultyPanel
@onready var shuffle_panel = $ShufflePanel
@onready var shuffle_label = $ShufflePanel/ShuffleLabel
@onready var portrait_grid = $ShufflePanel/PortraitGrid
@onready var presentation_panel = $PresentationPanel
@onready var opponent_portrait = $PresentationPanel/VBoxContainer/MiddleSection/LeftSide/OpponentPortrait
@onready var opponent_name = $PresentationPanel/VBoxContainer/OpponentName
@onready var opponent_bio = $PresentationPanel/VBoxContainer/MiddleSection/RightSide/OpponentBioPanel/MarginContainer/OpponentBio
@onready var continue_prompt = $PresentationPanel/VBoxContainer/ContinuePrompt

# NEW: Match data UI elements
@onready var bomb_icon = $PresentationPanel/VBoxContainer/MiddleSection/RightSide/MatchDataPanel/MarginContainer/HBoxContainer/BombIcon
@onready var bomb_type_label = $PresentationPanel/VBoxContainer/MiddleSection/RightSide/MatchDataPanel/MarginContainer/HBoxContainer/InfoVBox/BombTypeLabel
@onready var bomb_description = $PresentationPanel/VBoxContainer/MiddleSection/RightSide/MatchDataPanel/MarginContainer/HBoxContainer/InfoVBox/BombDescription
@onready var match_number_label = $PresentationPanel/VBoxContainer/MiddleSection/RightSide/MatchDataPanel/MarginContainer/HBoxContainer/InfoVBox/MatchNumber

@onready var easy_button = $DifficultyPanel/VBoxContainer/EasyButton
@onready var normal_button = $DifficultyPanel/VBoxContainer/NormalButton
@onready var hard_button = $DifficultyPanel/VBoxContainer/HardButton
@onready var back_button = $DifficultyPanel/VBoxContainer/BackButton

var tournament_roster: Resource = null
var selected_difficulty: String = ""
var current_opponent: Resource = null
var portrait_nodes = []

# NEW: Bomb type data mapping
var bomb_type_data_map = {}

func _ready():
	# Load tournament roster
	tournament_roster = load("res://resources/default_tournament_roster.tres")
	
	if not tournament_roster:
		push_error("Failed to load tournament_roster.tres")
		return
	
	# NEW: Load bomb type data resources
	load_bomb_type_data()
	
	# Connect difficulty buttons
	easy_button.connect("pressed", _on_difficulty_pressed.bind("Easy"))
	normal_button.connect("pressed", _on_difficulty_pressed.bind("Normal"))
	hard_button.connect("pressed", _on_difficulty_pressed.bind("Hard"))
	back_button.connect("pressed", _on_back_pressed)
	
	# NEW: Check if tournament is already in progress
	current_opponent = TournamentManager.get_current_opponent()
	
	if current_opponent != null:
		# Tournament already started - skip difficulty selection and show next opponent
		print("Tournament in progress - showing next opponent: ", current_opponent.opponent_name)
		difficulty_panel.hide()
		shuffle_panel.hide()
		presentation_panel.hide()
		
		# Set the selected difficulty from TournamentManager
		selected_difficulty = TournamentManager.get_difficulty_name()
		
		# Go directly to presenting the opponent
		present_selected_opponent()
	else:
		# New tournament - start with difficulty selection visible
		difficulty_panel.show()
		shuffle_panel.hide()
		presentation_panel.hide()
		
		# Grab focus on normal button
		normal_button.grab_focus()

# NEW: Load all bomb type data resources
func load_bomb_type_data():
	"""Load BombTypeData resources into a lookup dictionary"""
	bomb_type_data_map[BombController.BombType.NONE] = load("res://resources/bomb_types/bomb_none.tres")
	bomb_type_data_map[BombController.BombType.NORMAL] = load("res://resources/bomb_types/bomb_color.tres")
	bomb_type_data_map[BombController.BombType.LINE] = load("res://resources/bomb_types/bomb_line.tres")
	bomb_type_data_map[BombController.BombType.TIME] = load("res://resources/bomb_types/bomb_time.tres")
	bomb_type_data_map[BombController.BombType.CROSS] = load("res://resources/bomb_types/bomb_cross.tres")
	bomb_type_data_map[BombController.BombType.AREA] = load("res://resources/bomb_types/bomb_area.tres")
	
	# NEW: Special scenario types (using values 6 and 7)
	bomb_type_data_map[6] = load("res://resources/bomb_types/bomb_all.tres")
	bomb_type_data_map[7] = load("res://resources/bomb_types/bomb_line_cross.tres")
	
	print("Loaded ", bomb_type_data_map.size(), " bomb type data resources")

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
	"""Display all opponent portraits in the lineup - EXCLUDES BOSS"""
	shuffle_panel.show()
	shuffle_panel.modulate.a = 0.0
	
	# Clear any existing portraits
	for child in portrait_grid.get_children():
		child.queue_free()
	portrait_nodes.clear()
	
	# IMPORTANT: Initialize tournament NOW to get the actual order
	var difficulty_enum = TournamentManager.Difficulty.NORMAL
	match selected_difficulty:
		"Easy":
			difficulty_enum = TournamentManager.Difficulty.EASY
		"Normal":
			difficulty_enum = TournamentManager.Difficulty.NORMAL
		"Hard":
			difficulty_enum = TournamentManager.Difficulty.HARD
	
	TournamentManager.initialize_tournament(tournament_roster, difficulty_enum)
	
	# Get NON-BOSS opponents from the queue
	var display_opponents = []
	for opponent in TournamentManager.opponent_queue:
		if not opponent.is_boss:
			display_opponents.append(opponent)
	
	print("Loading ", display_opponents.size(), " opponent portraits (boss excluded)")
	
	for i in range(display_opponents.size()):
		var opponent = display_opponents[i]
		
		# Create TextureRect for portrait
		var portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2(256, 256)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Load portrait image
		if opponent.portrait_path and opponent.portrait_path != "":
			var texture = load(opponent.portrait_path)
			if texture:
				portrait.texture = texture
				print("Loaded portrait for ", opponent.opponent_name)
			else:
				print("WARNING: Failed to load portrait from ", opponent.portrait_path)
				portrait.modulate = Color(randf(), randf(), randf())
		else:
			print("WARNING: No portrait path for ", opponent.opponent_name)
			portrait.modulate = Color(randf(), randf(), randf())
		
		# Add to container
		portrait_grid.add_child(portrait)
		portrait_nodes.append(portrait)
		
		# Store opponent data AND index in metadata
		portrait.set_meta("opponent_data", opponent)
		portrait.set_meta("opponent_index", i)
	
	# Fade in portraits
	var tween = create_tween()
	tween.tween_property(shuffle_panel, "modulate:a", 1.0, 0.5)
	
	# Start shuffle animation
	tween.tween_callback(shuffle_portraits)

func shuffle_portraits():
	"""Animate portrait shuffling - MORE iterations, LONGER duration"""
	print("Shuffling portraits...")
	
	# INCREASED: Longer shuffle with more swaps
	var shuffle_duration = 3.0  # Up from 1.5
	var shuffle_count = 15      # Up from 8
	var interval = shuffle_duration / shuffle_count
	
	shuffle_label.text = "SHUFFLING OPPONENTS..."
	
	AudioManager.play_button_hover()
	
	# Rapid shuffling phase
	for i in range(shuffle_count):
		await get_tree().create_timer(interval).timeout
		
		# Swap random portraits
		var idx1 = randi() % portrait_nodes.size()
		var idx2 = randi() % portrait_nodes.size()
		
		if idx1 != idx2:
			# Swap positions with faster animation for more chaotic feel
			var pos1 = portrait_nodes[idx1].position
			var pos2 = portrait_nodes[idx2].position
			
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(portrait_nodes[idx1], "position", pos2, 0.12)
			tween.tween_property(portrait_nodes[idx2], "position", pos1, 0.12)
	
	# NEW: Show the final playing order clearly
	await show_final_order()

func show_final_order():
	"""Display the final opponent order clearly - REARRANGE portraits in grid"""
	print("Revealing final opponent order...")
	
	# Update label to show this is the final order
	shuffle_label.text = "YOUR OPPONENTS - IN ORDER:"
	
	AudioManager.play_button_click()
	
	# Get the actual ordered opponents (non-boss) from tournament queue
	var ordered_opponents = []
	for opponent in TournamentManager.opponent_queue:
		if not opponent.is_boss:
			ordered_opponents.append(opponent)
	
	# CRITICAL: Remove all portraits from grid and clear the array
	for portrait in portrait_nodes:
		portrait_grid.remove_child(portrait)
	
	var old_portraits = portrait_nodes.duplicate()
	portrait_nodes.clear()
	
	# Re-add portraits in the CORRECT ORDER
	for i in range(ordered_opponents.size()):
		var opponent = ordered_opponents[i]
		
		# Create new portrait for this opponent
		var portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2(256, 256)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Load portrait image
		if opponent.portrait_path and opponent.portrait_path != "":
			var texture = load(opponent.portrait_path)
			if texture:
				portrait.texture = texture
		else:
			portrait.modulate = Color(randf(), randf(), randf())
		
		# Add to grid in order (upper-left to lower-right)
		portrait_grid.add_child(portrait)
		portrait_nodes.append(portrait)
		
		# Store metadata
		portrait.set_meta("opponent_data", opponent)
		portrait.set_meta("opponent_index", i)
		
		print("  Position ", i + 1, ": ", opponent.opponent_name)
	
	# Clean up old portraits
	for old_portrait in old_portraits:
		old_portrait.queue_free()
	
	# Brief pause to let grid layout settle
	await get_tree().create_timer(0.2).timeout
	
	# Animate each portrait in sequence to emphasize order (left to right, top to bottom)
	for i in range(portrait_nodes.size()):
		var portrait = portrait_nodes[i]
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(portrait, "scale", Vector2(1.15, 1.15), 0.2)
		tween.tween_property(portrait, "modulate", Color(1.2, 1.2, 1.2), 0.2)
		tween.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.2)
		tween.tween_property(portrait, "modulate", Color(1.0, 1.0, 1.0), 0.15).set_delay(0.2)
		
		await get_tree().create_timer(0.15).timeout
	
	# HOLD on the final order so player can see it clearly
	await get_tree().create_timer(2.5).timeout
	
	# Now proceed to show the first opponent
	present_first_opponent()

func present_first_opponent():
	"""Present the first opponent (tournament already initialized)"""
	current_opponent = TournamentManager.get_current_opponent()
	
	if not current_opponent:
		push_error("Failed to get first opponent")
		return
	
	print("Presenting first opponent: ", current_opponent.opponent_name)
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
	
	# NEW: Set bomb type data
	display_bomb_info()
	
	# NEW: Set match number
	display_match_number()
	
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

# NEW: Display bomb type information
func display_bomb_info():
	"""Load and display bomb type information for this opponent"""
	# Get tournament difficulty enum
	var difficulty_enum = TournamentManager.current_difficulty
	
	# Get opponent's bomb type for this difficulty
	var opponent_bomb_type = current_opponent.get_bomb_type(difficulty_enum)
	
	# Get the bomb type data
	var bomb_data = bomb_type_data_map.get(opponent_bomb_type)
	
	if bomb_data:
		# Set bomb type name
		bomb_type_label.text = bomb_data.bomb_name.to_upper()
		
		# Set description
		bomb_description.text = bomb_data.description
		
		# Load and set icon
		if bomb_data.bomb_icon_path and bomb_data.bomb_icon_path != "":
			var icon_texture = load(bomb_data.bomb_icon_path)
			if icon_texture:
				bomb_icon.texture = icon_texture
				print("Loaded bomb icon: ", bomb_data.bomb_icon_path)
			else:
				print("WARNING: Failed to load bomb icon from ", bomb_data.bomb_icon_path)
				bomb_icon.texture = null
		else:
			# No bombs - hide icon
			bomb_icon.visible = (opponent_bomb_type != BombController.BombType.NONE)
			bomb_icon.texture = null
		
		print("Displaying bomb info: ", bomb_data.bomb_name, " (Type ", opponent_bomb_type, ")")
	else:
		print("WARNING: No bomb type data found for type ", opponent_bomb_type)
		bomb_type_label.text = "UNKNOWN BOMB"
		bomb_description.text = "Bomb information unavailable."
		bomb_icon.texture = null

# NEW: Display match number
func display_match_number():
	"""Display current match number in the tournament"""
	var current_match = TournamentManager.get_current_opponent_number()
	var total_matches = TournamentManager.get_opponent_count()
	
	match_number_label.text = "Match " + str(current_match) + " of " + str(total_matches)
	
	print("Match info: ", current_match, " / ", total_matches)

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

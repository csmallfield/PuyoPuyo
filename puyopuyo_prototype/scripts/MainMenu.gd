extends Control
# MainMenu.gd - Main menu controller

@onready var single_player_button = $CenterContainer/VBoxContainer/SinglePlayerButton
@onready var vs_ai_button = $CenterContainer/VBoxContainer/VSAIButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	# Connect button signals
	single_player_button.connect("pressed", _on_single_player_pressed)
	vs_ai_button.connect("pressed", _on_vs_ai_pressed)
	quit_button.connect("pressed", _on_quit_pressed)
	
	# Optional: Connect hover signals for button hover sounds
	# Uncomment these if you want hover sounds
	single_player_button.connect("mouse_entered", _on_button_hover)
	vs_ai_button.connect("mouse_entered", _on_button_hover)
	quit_button.connect("mouse_entered", _on_button_hover)
	
	# Set initial focus
	single_player_button.grab_focus()

func _on_button_hover():
	"""Optional: Play hover sound when mouse enters button"""
	AudioManager.play_button_hover()

func _on_single_player_pressed():
	# SOUND: Button click
	AudioManager.play_button_click()
	
	# SOUND: Transition
	AudioManager.play_transition()
	
	# Load the existing single player game
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_vs_ai_pressed():
	# SOUND: Button click
	AudioManager.play_button_click()
	
	# SOUND: Transition
	AudioManager.play_transition()
	
	# This will load VS mode (we'll create this in Phase 3)
	get_tree().change_scene_to_file("res://scenes/VSMode.tscn")

func _on_quit_pressed():
	# SOUND: Button click
	AudioManager.play_button_click()
	
	# Quit the game
	get_tree().quit()

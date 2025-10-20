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
	
	# Set initial focus
	single_player_button.grab_focus()

func _on_single_player_pressed():
	# Load the existing single player game
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_vs_ai_pressed():
	# This will load VS mode (we'll create this in Phase 3)
	get_tree().change_scene_to_file("res://scenes/VSMode.tscn")

func _on_quit_pressed():
	# Quit the game
	get_tree().quit()

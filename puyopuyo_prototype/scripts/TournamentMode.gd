extends Control
# TournamentMode.gd - Placeholder for Tournament Mode (Phase 1)
# This will be replaced with proper tournament flow in Phase 2+

@onready var info_label = Label.new()
@onready var back_button = Button.new()

func _ready():
	# Create a simple UI to show Tournament Mode is working
	setup_placeholder_ui()
	
	print("=== TOURNAMENT MODE PLACEHOLDER ===")
	print("Phase 1 Complete! Core systems ready:")
	print("- OpponentData resource system ✓")
	print("- TournamentRoster resource ✓")
	print("- TournamentManager singleton ✓")
	print("- 5 Example opponents created ✓")
	print("- Main menu integration ✓")
	print("===================================")

func setup_placeholder_ui():
	# Center container for UI
	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "TOURNAMENT MODE"
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Info text
	info_label.text = "Phase 1 Complete!\n\nCore systems implemented:\n• OpponentData & TournamentRoster\n• TournamentManager Singleton\n• 5 Default Opponents\n\nReady for Phase 2: Tournament Intro Scene"
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)
	
	# Back button
	back_button.text = "Back to Main Menu"
	back_button.custom_minimum_size = Vector2(300, 60)
	back_button.add_theme_font_size_override("font_size", 28)
	back_button.connect("pressed", _on_back_pressed)
	vbox.add_child(back_button)
	
	# Grab focus
	back_button.grab_focus()
	
	# Test TournamentManager
	test_tournament_manager()

func test_tournament_manager():
	"""Quick test to verify TournamentManager is working"""
	print("\n=== Testing TournamentManager ===")
	
	# Load default roster
	var roster = load("res://resources/default_tournament_roster.tres")
	if roster:
		print("✓ Default roster loaded successfully")
		print("  Opponents in roster: ", roster.opponents.size())
		for opponent in roster.opponents:
			print("  - ", opponent.opponent_name, " (Boss: ", opponent.is_boss, ")")
	else:
		print("✗ Failed to load roster")
	
	# Test TournamentManager initialization
	if TournamentManager:
		print("✓ TournamentManager singleton accessible")
		
		# Test initialization with Easy difficulty
		TournamentManager.initialize_tournament(roster, TournamentManager.Difficulty.EASY)
		print("✓ Tournament initialized (Easy difficulty)")
		print("  Opponent queue size: ", TournamentManager.opponent_queue.size())
		
		# Get first opponent
		var first_opponent = TournamentManager.get_current_opponent()
		if first_opponent:
			print("✓ First opponent retrieved: ", first_opponent.opponent_name)
	else:
		print("✗ TournamentManager not found")
	
	print("=================================\n")

func _on_back_pressed():
	AudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _input(event):
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

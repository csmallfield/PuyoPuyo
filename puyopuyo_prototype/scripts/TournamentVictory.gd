extends Control
# TournamentVictory.gd - Tournament completion screen

@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var score_label = $CenterContainer/VBoxContainer/StatsPanel/StatsVBox/ScoreLabel
@onready var time_label = $CenterContainer/VBoxContainer/StatsPanel/StatsVBox/TimeLabel
@onready var continues_label = $CenterContainer/VBoxContainer/StatsPanel/StatsVBox/ContinuesLabel
@onready var opponents_list = $CenterContainer/VBoxContainer/OpponentsScroll/OpponentsList
@onready var menu_button = $CenterContainer/VBoxContainer/MenuButton



func _ready():
	# Ensure we're not paused
	get_tree().paused = false
	
	# Connect button
	menu_button.connect("pressed", _on_menu_button_pressed)
	
	# Load tournament results
	display_results()
	
	# Play victory fanfare
	AudioManager.play_victory()
	
	# Focus button
	menu_button.grab_focus()
	
	# Animate entrance
	animate_entrance()

func display_results():
	"""Display tournament statistics"""
	# Get stats from TournamentManager
	var final_score = TournamentManager.get_final_score()
	var total_time = TournamentManager.get_tournament_time()
	var continues_used = TournamentManager.continues_used
	var defeated = TournamentManager.defeated_opponents
	
	# Format and display stats
	score_label.text = "Final Score: " + str(final_score)
	time_label.text = "Time: " + format_time(total_time)
	continues_label.text = "Continues Used: " + str(continues_used) + " / 5"
	
	# Display defeated opponents
	for opponent_id in defeated:
		var opponent_label = Label.new()
		opponent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opponent_label.add_theme_font_size_override("font_size", 24)
		
		# Get opponent name from roster
		var opponent_name = get_opponent_name(opponent_id)
		opponent_label.text = "✓ " + opponent_name
		
		opponents_list.add_child(opponent_label)
	
	print("=== TOURNAMENT VICTORY ===")
	print("Final Score: ", final_score)
	print("Time: ", format_time(total_time))
	print("Continues Used: ", continues_used)
	print("Opponents Defeated: ", defeated.size())
	print("========================")

func get_opponent_name(opponent_id: String) -> String:
	"""Get opponent display name from roster"""
	var roster = load("res://resources/default_tournament_roster.tres")
	if roster:
		for opponent in roster.opponents:
			if opponent.opponent_id == opponent_id:
				return opponent.opponent_name
	return opponent_id

func format_time(seconds: float) -> String:
	"""Format seconds into MM:SS"""
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func animate_entrance():
	"""Animate the victory screen entrance"""
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)

func _on_menu_button_pressed():
	AudioManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

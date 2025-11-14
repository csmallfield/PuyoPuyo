# scripts/TournamentManager.gd
extends Node

# Signals for tournament events
signal opponent_defeated(opponent_id: String)
signal tournament_completed(final_score: int, completion_time: float)
signal tournament_failed()
signal continue_used(continues_remaining: int)

# Tournament configuration
var selected_difficulty: String = "Normal"  # "Easy", "Normal", or "Hard"
var tournament_roster: TournamentRoster = null

# Opponent progression
var remaining_opponents: Array[OpponentData] = []
var current_opponent: OpponentData = null
var defeated_opponents: Array[String] = []

# Match state (Best of 3)
var player_round_wins: int = 0
var ai_round_wins: int = 0
var current_round: int = 1

# Scoring and timing
var tournament_score: int = 0
var tournament_start_time: float = 0.0
var match_start_time: float = 0.0

# Continue system
var continues_remaining: int = 5
var matches_won: int = 0

func _ready():
	# Ensure singleton is always available
	process_mode = Node.PROCESS_MODE_ALWAYS

func initialize_tournament(difficulty: String, roster: TournamentRoster):
	"""Start a new tournament with the given difficulty and roster"""
	if not roster or not roster.validate():
		push_error("TournamentManager: Invalid roster provided")
		return false
	
	selected_difficulty = difficulty
	tournament_roster = roster
	
	# Shuffle regular opponents (boss is NOT shuffled)
	remaining_opponents = roster.regular_opponents.duplicate()
	remaining_opponents.shuffle()
	
	# Add boss at the end
	remaining_opponents.append(roster.boss_opponent)
	
	# Reset all state
	defeated_opponents.clear()
	tournament_score = 0
	continues_remaining = 5
	matches_won = 0
	player_round_wins = 0
	ai_round_wins = 0
	current_round = 1
	current_opponent = null
	
	# Start tournament timer
	tournament_start_time = Time.get_ticks_msec() / 1000.0
	
	print("=================================")
	print("TOURNAMENT STARTED")
	print("Difficulty: ", difficulty)
	print("Total Opponents: ", remaining_opponents.size())
	print("Opponent Order: ", get_opponent_order_names())
	print("=================================")
	
	return true

func get_opponent_order_names() -> Array:
	"""Get list of opponent names for debug"""
	var names = []
	for opp in remaining_opponents:
		names.append(opp.opponent_name)
	return names

func get_next_opponent() -> OpponentData:
	"""Get the next opponent to face"""
	if remaining_opponents.is_empty():
		return null
	
	current_opponent = remaining_opponents[0]
	match_start_time = Time.get_ticks_msec() / 1000.0
	
	print("\n--- NEXT OPPONENT ---")
	print("Name: ", current_opponent.opponent_name)
	print("AI Difficulty: Level ", current_opponent.get_ai_difficulty(selected_difficulty))
	print("Bomb Mode: ", GameState.get_bomb_mode_name(current_opponent.get_bomb_mode(selected_difficulty)))
	print("Is Boss: ", current_opponent.is_boss)
	print("---------------------\n")
	
	return current_opponent

func complete_opponent():
	"""Mark current opponent as defeated and advance"""
	if current_opponent == null:
		push_error("TournamentManager: No current opponent to complete")
		return
	
	# Record victory
	defeated_opponents.append(current_opponent.opponent_id)
	remaining_opponents.remove_at(0)
	matches_won += 1
	
	# Reset match state
	player_round_wins = 0
	ai_round_wins = 0
	current_round = 1
	
	print("\n*** OPPONENT DEFEATED ***")
	print("Defeated: ", current_opponent.opponent_name)
	print("Matches Won: ", matches_won)
	print("Remaining Opponents: ", remaining_opponents.size())
	print("*************************\n")
	
	emit_signal("opponent_defeated", current_opponent.opponent_id)
	
	# Check if tournament is complete
	if remaining_opponents.is_empty():
		complete_tournament()

func complete_tournament():
	"""Tournament completed successfully"""
	var completion_time = (Time.get_ticks_msec() / 1000.0) - tournament_start_time
	
	print("\n")
	print("=================================")
	print("TOURNAMENT COMPLETE!")
	print("Final Score: ", tournament_score)
	print("Completion Time: ", format_time(completion_time))
	print("Difficulty: ", selected_difficulty)
	print("=================================")
	print("\n")
	
	emit_signal("tournament_completed", tournament_score, completion_time)

func fail_tournament():
	"""Tournament failed (out of continues)"""
	print("\n")
	print("=================================")
	print("TOURNAMENT FAILED - GAME OVER")
	print("Final Score: ", tournament_score)
	print("Opponents Defeated: ", defeated_opponents.size())
	print("=================================")
	print("\n")
	
	emit_signal("tournament_failed")

func use_continue() -> bool:
	"""Attempt to use a continue. Returns true if continue was available"""
	if continues_remaining > 0:
		continues_remaining -= 1
		
		# Reset current match state
		player_round_wins = 0
		ai_round_wins = 0
		current_round = 1
		
		print("CONTINUE USED - ", continues_remaining, " continues remaining")
		emit_signal("continue_used", continues_remaining)
		return true
	
	return false

func record_round_victory(player_won: bool, round_score: int, round_time: float):
	"""Record the result of a round"""
	if player_won:
		player_round_wins += 1
	else:
		ai_round_wins += 1
	
	# Add score with speed bonus
	if player_won:
		var speed_bonus = max(0, 1000 - int(round_time * 10))
		tournament_score += round_score + speed_bonus
		print("Round ", current_round, " victory! Score: ", round_score, " + Speed Bonus: ", speed_bonus)
	
	current_round += 1

func has_player_won_match() -> bool:
	"""Check if player won the best-of-3"""
	return player_round_wins >= 2

func has_ai_won_match() -> bool:
	"""Check if AI won the best-of-3"""
	return ai_round_wins >= 2

func get_tournament_progress() -> Dictionary:
	"""Get current tournament state for UI display"""
	return {
		"difficulty": selected_difficulty,
		"current_opponent": current_opponent,
		"player_wins": player_round_wins,
		"ai_wins": ai_round_wins,
		"current_round": current_round,
		"score": tournament_score,
		"continues": continues_remaining,
		"opponents_remaining": remaining_opponents.size(),
		"matches_won": matches_won
	}

func format_time(seconds: float) -> String:
	"""Format time as MM:SS"""
	var minutes = int(seconds / 60)
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func is_tournament_active() -> bool:
	"""Check if a tournament is currently in progress"""
	return tournament_roster != null and not remaining_opponents.is_empty()

func get_current_opponent_name() -> String:
	"""Get current opponent's name (for UI)"""
	if current_opponent:
		return current_opponent.opponent_name
	return ""

func get_current_opponent_portrait() -> String:
	"""Get current opponent's portrait path (for UI)"""
	if current_opponent:
		return current_opponent.portrait_path
	return ""

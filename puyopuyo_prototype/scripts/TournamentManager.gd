extends Node
# TournamentManager.gd - Manages tournament state across scenes

# ============================================
# ENUMS
# ============================================

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

# ============================================
# SIGNALS
# ============================================

signal tournament_started(difficulty: int)
signal opponent_changed(opponent: OpponentData)
signal match_won(opponent: OpponentData)
signal match_lost(opponent: OpponentData)
signal round_won(player_rounds: int, opponent_rounds: int)
signal round_lost(player_rounds: int, opponent_rounds: int)
signal tournament_completed(score: int, time: float)
signal continue_used(continues_remaining: int)
signal game_over()

# ============================================
# TOURNAMENT CONFIGURATION
# ============================================

var tournament_roster: TournamentRoster = null
var current_difficulty: Difficulty = Difficulty.NORMAL
var opponent_queue: Array[OpponentData] = []
var current_opponent_index: int = 0

# ============================================
# MATCH STATE
# ============================================

var player_round_wins: int = 0
var opponent_round_wins: int = 0
var current_round: int = 1
var max_rounds: int = 3  # Best of 3

# ============================================
# TOURNAMENT PROGRESSION
# ============================================

var defeated_opponents: Array[String] = []  # Array of opponent_id strings
var continues_remaining: int = 5
var continues_used: int = 0

# ============================================
# SCORING & TIME
# ============================================

var tournament_score: int = 0
var tournament_start_time: float = 0.0
var current_match_start_time: float = 0.0
var current_round_start_time: float = 0.0

# ============================================
# INITIALIZATION
# ============================================

func initialize_tournament(roster: TournamentRoster, difficulty: Difficulty):
	"""Initialize a new tournament with the given roster and difficulty"""
	print("=== TOURNAMENT INITIALIZATION ===")
	print("Difficulty: ", ["Easy", "Normal", "Hard"][difficulty])
	
	tournament_roster = roster
	current_difficulty = difficulty
	
	# Reset all state
	opponent_queue.clear()
	current_opponent_index = 0
	defeated_opponents.clear()
	continues_remaining = 5
	continues_used = 0
	tournament_score = 0
	tournament_start_time = Time.get_ticks_msec() / 1000.0
	
	reset_match_state()
	
	# Build opponent queue: shuffle regulars, boss always last
	_build_opponent_queue()
	
	print("Opponent queue built: ", opponent_queue.size(), " opponents")
	for i in range(opponent_queue.size()):
		var opp = opponent_queue[i]
		print("  ", i + 1, ". ", opp.opponent_name, " (Boss: ", opp.is_boss, ")")
	
	emit_signal("tournament_started", difficulty)
	print("=================================\n")

func _build_opponent_queue():
	"""Build the opponent queue: shuffle regulars, boss always last"""
	if not tournament_roster or not tournament_roster.has_opponents():
		push_error("TournamentManager: Cannot build queue - no roster or no opponents")
		return
	
	var regulars: Array[OpponentData] = []
	var boss: OpponentData = null
	
	# Separate regulars from boss
	for opponent in tournament_roster.opponents:
		if opponent.is_boss:
			boss = opponent
		else:
			regulars.append(opponent)
	
	# Shuffle regulars
	regulars.shuffle()
	
	# Build queue: regulars first, then boss
	opponent_queue.clear()
	for regular in regulars:
		opponent_queue.append(regular)
	
	if boss:
		opponent_queue.append(boss)

# ============================================
# OPPONENT MANAGEMENT
# ============================================

func get_current_opponent() -> OpponentData:
	"""Get the current opponent"""
	if current_opponent_index < opponent_queue.size():
		return opponent_queue[current_opponent_index]
	return null

func get_next_opponent() -> OpponentData:
	"""Peek at the next opponent without advancing"""
	var next_index = current_opponent_index + 1
	if next_index < opponent_queue.size():
		return opponent_queue[next_index]
	return null

func complete_opponent():
	"""Mark current opponent as defeated and advance to next"""
	var defeated = get_current_opponent()
	if defeated:
		defeated_opponents.append(defeated.opponent_id)
		print("Opponent defeated: ", defeated.opponent_name)
	
	current_opponent_index += 1
	reset_match_state()
	
	var next = get_current_opponent()
	if next:
		emit_signal("opponent_changed", next)
		print("Next opponent: ", next.opponent_name)
	else:
		print("Tournament complete!")

func is_tournament_complete() -> bool:
	"""Check if all opponents have been defeated"""
	return current_opponent_index >= opponent_queue.size()

func get_remaining_opponent_count() -> int:
	"""Get number of opponents remaining (including current)"""
	return max(0, opponent_queue.size() - current_opponent_index)

# ============================================
# MATCH STATE MANAGEMENT
# ============================================

func reset_match_state():
	"""Reset match state for a new opponent"""
	player_round_wins = 0
	opponent_round_wins = 0
	current_round = 1
	current_match_start_time = Time.get_ticks_msec() / 1000.0

func start_new_round():
	"""Start a new round in the current match"""
	current_round += 1
	current_round_start_time = Time.get_ticks_msec() / 1000.0

func player_wins_round():
	"""Player wins the current round"""
	player_round_wins += 1
	emit_signal("round_won", player_round_wins, opponent_round_wins)
	
	if player_round_wins >= 2:
		# Player wins match (best of 3)
		emit_signal("match_won", get_current_opponent())
		return true
	else:
		start_new_round()
		return false

func opponent_wins_round():
	"""Opponent wins the current round"""
	opponent_round_wins += 1
	emit_signal("round_lost", player_round_wins, opponent_round_wins)
	
	if opponent_round_wins >= 2:
		# Opponent wins match (best of 3)
		emit_signal("match_lost", get_current_opponent())
		return true
	else:
		start_new_round()
		return false

func is_match_over() -> bool:
	"""Check if current match is over (someone won 2 rounds)"""
	return player_round_wins >= 2 or opponent_round_wins >= 2

func did_player_win_match() -> bool:
	"""Check if player won the current match"""
	return player_round_wins >= 2

# ============================================
# CONTINUE SYSTEM
# ============================================

func can_continue() -> bool:
	"""Check if player has continues remaining"""
	return continues_remaining > 0

func use_continue() -> bool:
	"""Use a continue (returns false if none remaining)"""
	if not can_continue():
		emit_signal("game_over")
		return false
	
	continues_remaining -= 1
	continues_used += 1
	
	# Reset current match
	reset_match_state()
	
	emit_signal("continue_used", continues_remaining)
	print("Continue used. Remaining: ", continues_remaining)
	
	return true

# ============================================
# SCORING & TIME
# ============================================

func add_score(points: int):
	"""Add points to tournament score"""
	tournament_score += points

func get_round_time() -> float:
	"""Get elapsed time for current round in seconds"""
	return (Time.get_ticks_msec() / 1000.0) - current_round_start_time

func get_match_time() -> float:
	"""Get elapsed time for current match in seconds"""
	return (Time.get_ticks_msec() / 1000.0) - current_match_start_time

func get_tournament_time() -> float:
	"""Get total tournament elapsed time in seconds"""
	return (Time.get_ticks_msec() / 1000.0) - tournament_start_time

func calculate_speed_bonus(round_time_seconds: float) -> int:
	"""Calculate speed bonus for completing a round"""
	return max(0, int(1000.0 - (round_time_seconds * 10.0)))

func get_final_score() -> int:
	"""Get final tournament score"""
	return tournament_score

# ============================================
# HELPER FUNCTIONS
# ============================================

func get_difficulty_name() -> String:
	"""Get the name of the current difficulty"""
	match current_difficulty:
		Difficulty.EASY:
			return "Easy"
		Difficulty.NORMAL:
			return "Normal"
		Difficulty.HARD:
			return "Hard"
		_:
			return "Unknown"

func get_opponent_count() -> int:
	"""Get total number of opponents in tournament"""
	return opponent_queue.size()

func get_current_opponent_number() -> int:
	"""Get current opponent number (1-indexed)"""
	return current_opponent_index + 1

# ============================================
# DEBUG
# ============================================

func print_tournament_state():
	"""Print current tournament state for debugging"""
	print("\n=== TOURNAMENT STATE ===")
	print("Difficulty: ", get_difficulty_name())
	print("Current Opponent: ", current_opponent_index + 1, "/", opponent_queue.size())
	if get_current_opponent():
		print("  Name: ", get_current_opponent().opponent_name)
	print("Match State: ", player_round_wins, "-", opponent_round_wins)
	print("Current Round: ", current_round)
	print("Continues: ", continues_remaining)
	print("Score: ", tournament_score)
	print("========================\n")

# scripts/TournamentRoster.gd
extends Resource
class_name TournamentRoster

# Array of regular opponents (will be shuffled)
@export var regular_opponents: Array[OpponentData] = []

# Boss opponent (always appears last, not shuffled)
@export var boss_opponent: OpponentData = null

func get_total_opponent_count() -> int:
	"""Get total number of opponents in this roster"""
	var count = regular_opponents.size()
	if boss_opponent != null:
		count += 1
	return count

func validate() -> bool:
	"""Validate that the roster is properly configured"""
	if regular_opponents.is_empty():
		push_error("TournamentRoster: No regular opponents defined")
		return false
	
	if boss_opponent == null:
		push_error("TournamentRoster: No boss opponent defined")
		return false
	
	# Check for duplicate IDs
	var ids = {}
	for opponent in regular_opponents:
		if opponent == null:
			push_error("TournamentRoster: Null opponent in regular_opponents array")
			return false
		if ids.has(opponent.opponent_id):
			push_error("TournamentRoster: Duplicate opponent_id: " + opponent.opponent_id)
			return false
		ids[opponent.opponent_id] = true
	
	if ids.has(boss_opponent.opponent_id):
		push_error("TournamentRoster: Boss opponent_id conflicts with regular opponent")
		return false
	
	return true

func get_opponent_by_id(id: String) -> OpponentData:
	"""Find an opponent by their ID"""
	for opponent in regular_opponents:
		if opponent.opponent_id == id:
			return opponent
	
	if boss_opponent and boss_opponent.opponent_id == id:
		return boss_opponent
	
	return null

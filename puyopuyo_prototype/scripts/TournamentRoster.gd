extends Resource
class_name TournamentRoster
# TournamentRoster.gd - Container for tournament opponent lineup

# Array of OpponentData resources
@export var opponents: Array[Resource] = []

func _init():
	pass

func get_opponent_count() -> int:
	return opponents.size()

func get_opponent_at_index(index: int) -> Resource:
	if index >= 0 and index < opponents.size():
		return opponents[index]
	return null

func has_opponents() -> bool:
	return opponents.size() > 0

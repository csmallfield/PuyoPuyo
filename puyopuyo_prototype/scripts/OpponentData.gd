# scripts/OpponentData.gd
extends Resource
class_name OpponentData

const BombController = preload("res://scripts/BombController.gd")

# Opponent identity
@export var opponent_id: String = ""
@export var opponent_name: String = ""
@export var portrait_path: String = ""
@export var bio_text: String = ""
@export var music_track_path: String = ""
@export var is_boss: bool = false

# Easy Difficulty Configuration
@export_group("Easy Difficulty")
@export_enum("Level 0", "Level 1", "Level 2", "Level 3") var easy_ai_difficulty: int = 0
@export_enum("No Bombs:0", "Color Bomb:1", "Line Bomb:2", "Time Bomb:3", "Cross Bomb:4", "Area Bomb:5", "All Bombs:6", "Line & Cross:7") var easy_bomb_mode: int = 1

# Normal Difficulty Configuration
@export_group("Normal Difficulty")
@export_enum("Level 0", "Level 1", "Level 2", "Level 3") var normal_ai_difficulty: int = 1
@export_enum("No Bombs:0", "Color Bomb:1", "Line Bomb:2", "Time Bomb:3", "Cross Bomb:4", "Area Bomb:5", "All Bombs:6", "Line & Cross:7") var normal_bomb_mode: int = 2

# Hard Difficulty Configuration
@export_group("Hard Difficulty")
@export_enum("Level 0", "Level 1", "Level 2", "Level 3") var hard_ai_difficulty: int = 2
@export_enum("No Bombs:0", "Color Bomb:1", "Line Bomb:2", "Time Bomb:3", "Cross Bomb:4", "Area Bomb:5", "All Bombs:6", "Line & Cross:7") var hard_bomb_mode: int = 3

# Boss special configuration
@export_group("Boss Settings")
@export_enum("No Bombs:0", "Color Bomb:1", "Line Bomb:2", "Time Bomb:3", "Cross Bomb:4", "Area Bomb:5", "All Bombs:6", "Line & Cross:7") var boss_bomb_mode: int = 6  # ALL_BOMBS

func get_ai_difficulty(tournament_difficulty: String) -> int:
	"""Get AI difficulty level based on tournament difficulty"""
	match tournament_difficulty:
		"Easy":
			return easy_ai_difficulty
		"Normal":
			return normal_ai_difficulty
		"Hard":
			return hard_ai_difficulty
		_:
			return normal_ai_difficulty

func get_bomb_mode(tournament_difficulty: String) -> int:
	"""Get bomb mode index based on tournament difficulty"""
	# Boss always uses their special bomb mode
	if is_boss:
		return boss_bomb_mode
	
	match tournament_difficulty:
		"Easy":
			return easy_bomb_mode
		"Normal":
			return normal_bomb_mode
		"Hard":
			return hard_bomb_mode
		_:
			return normal_bomb_mode

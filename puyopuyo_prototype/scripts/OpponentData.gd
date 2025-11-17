extends Resource
class_name OpponentData
# OpponentData.gd - Stores opponent characteristics and AI configurations

# Opponent Identity
@export var opponent_id: String = ""
@export var opponent_name: String = ""
@export var portrait_path: String = ""
@export var bio_text: String = ""
@export var music_track_path: String = ""
@export var is_boss: bool = false

# AI Difficulty Settings (per tournament difficulty)
@export_enum("Level 0", "Level 1", "Level 2", "Level 3") var easy_ai_difficulty: int = 0
@export_enum("Level 0", "Level 1", "Level 2", "Level 3") var normal_ai_difficulty: int = 1
@export_enum("Level 0", "Level 1", "Level 2", "Level 3") var hard_ai_difficulty: int = 2

# Bomb Type Settings (per tournament difficulty)
# 0=None, 1=Color, 2=Line, 3=Time, 4=Cross, 5=Area, 6=All Bombs, 7=Line&Cross
@export_enum("None:0", "Color:1", "Line:2", "Time:3", "Cross:4", "Area:5", "All Bombs:6", "Line & Cross:7") var easy_bomb_type: int = 1
@export_enum("None:0", "Color:1", "Line:2", "Time:3", "Cross:4", "Area:5", "All Bombs:6", "Line & Cross:7") var normal_bomb_type: int = 2
@export_enum("None:0", "Color:1", "Line:2", "Time:3", "Cross:4", "Area:5", "All Bombs:6", "Line & Cross:7") var hard_bomb_type: int = 3

func _init():
	pass

# Get AI difficulty based on tournament difficulty
func get_ai_difficulty(tournament_difficulty: int) -> int:
	match tournament_difficulty:
		0:  # TournamentManager.Difficulty.EASY
			return easy_ai_difficulty
		1:  # TournamentManager.Difficulty.NORMAL
			return normal_ai_difficulty
		2:  # TournamentManager.Difficulty.HARD
			return hard_ai_difficulty
		_:
			return normal_ai_difficulty

# Get bomb type based on tournament difficulty
func get_bomb_type(tournament_difficulty: int) -> int:
	match tournament_difficulty:
		0:  # TournamentManager.Difficulty.EASY
			return easy_bomb_type
		1:  # TournamentManager.Difficulty.NORMAL
			return normal_bomb_type
		2:  # TournamentManager.Difficulty.HARD
			return hard_bomb_type
		_:
			return normal_bomb_type

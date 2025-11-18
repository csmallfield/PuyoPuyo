extends Resource
class_name BombTypeData
# BombTypeData.gd - Modular resource for bomb type display information

const BombController = preload("res://scripts/BombController.gd")

# Bomb type enum value (matches BombController.BombType)
@export var bomb_type: int = BombController.BombType.NORMAL

# Display name
@export var bomb_name: String = "Color Bomb"

# Path to bomb icon/graphic
@export var bomb_icon_path: String = ""

# Description of how this bomb works
@export_multiline var description: String = "Clears all pieces of the same color as an adjacent piece when matched."

func _init():
	pass

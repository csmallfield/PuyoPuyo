extends Node2D
# Piece.gd - Individual piece (puyo) with shader-based graphics

const BombController = preload("res://scripts/BombController.gd")

var color = Color.WHITE
var is_bubble = false

# Bomb properties
var bomb_type = BombController.BombType.NONE
var bomb_timer = 5  # For time bombs
var bomb_orientation = BombController.Orientation.VERTICAL  # For line bombs
var first_turn_in_grid = true  # Track if this is the first turn after placement

var graphic_rect = null  # ColorRect with shader
var timer_label = null  # For time bomb countdown display
var target_position = Vector2.ZERO
var is_animating = false
var animation_tween = null

# Preload the graphic library scene
static var graphic_library_scene = preload("res://scenes/graphic_library.tscn")
static var graphic_library_instance = null

func _ready():
	# Ensure we have a graphic library instance
	if graphic_library_instance == null:
		graphic_library_instance = graphic_library_scene.instantiate()
	
	# Create timer label for time bombs (hidden by default)
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(-12, -16)  # Center on piece
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.add_theme_constant_override("outline_size", 4)
	timer_label.z_index = 10
	timer_label.visible = false
	add_child(timer_label)
	
	# Create graphic from library
	create_piece_graphic()

func _process(delta):
	# Update timer display for time bombs
	if bomb_type == BombController.BombType.TIME and timer_label:
		timer_label.text = str(bomb_timer)
		timer_label.visible = true

func create_piece_graphic():
	# Remove old graphic if it exists
	if graphic_rect:
		graphic_rect.queue_free()
		graphic_rect = null
	
	# Determine which graphic to load from library
	var graphic_name = get_graphic_name_for_piece()
	
	# Get the ColorRect from the library and duplicate it
	var source_rect = graphic_library_instance.get_node_or_null(graphic_name)
	
	if source_rect:
		# Duplicate the ColorRect (this maintains the shader connection)
		graphic_rect = source_rect.duplicate()
		add_child(graphic_rect)
		
		# Center the rect (since ColorRects use top-left positioning)
		graphic_rect.position = Vector2(-32, -32)
		graphic_rect.size = Vector2(64, 64)
	else:
		# Fallback: create a simple colored rect
		print("Warning: Could not find graphic '", graphic_name, "' in library, using fallback")
		create_fallback_graphic()

func get_graphic_name_for_piece() -> String:
	"""Determine which ColorRect to use from the graphic library"""
	
	# Check for bomb types first
	match bomb_type:
		BombController.BombType.NORMAL:
			return "bomb_piece"
		BombController.BombType.TIME:
			return "time_bomb"
		BombController.BombType.AREA:
			return "area_bomb"
		BombController.BombType.CROSS:
			return "cross_bomb"
		BombController.BombType.LINE:
			if bomb_orientation == BombController.Orientation.HORIZONTAL:
				return "line_bomb_horizontal"
			else:
				return "line_bomb_vertical"
	
	# Check for bubble
	if is_bubble:
		return "bubble_piece"
	
	# Regular colored pieces
	if color == Color.RED:
		return "red_piece"
	elif color == Color.GREEN:
		return "green_piece"
	elif color == Color.YELLOW:
		return "yellow_piece"
	elif color == Color.BLUE:
		return "blue_piece"
	
	# Default fallback
	return "red_piece"

func create_fallback_graphic():
	"""Create a simple colored rect as fallback"""
	graphic_rect = ColorRect.new()
	add_child(graphic_rect)
	graphic_rect.position = Vector2(-32, -32)
	graphic_rect.size = Vector2(64, 64)
	graphic_rect.color = color

func set_color(new_color):
	color = new_color
	bomb_type = BombController.BombType.NONE
	first_turn_in_grid = true
	create_piece_graphic()

func set_as_bubble():
	is_bubble = true
	bomb_type = BombController.BombType.NONE
	color = GameState.bubble_color
	first_turn_in_grid = true
	create_piece_graphic()

func set_as_bomb(type: int, orientation: int = BombController.Orientation.VERTICAL):
	bomb_type = type
	bomb_orientation = orientation
	is_bubble = false
	color = GameState.bomb_color
	
	# Set timer for time bombs
	if bomb_type == BombController.BombType.TIME:
		bomb_timer = 5
		first_turn_in_grid = true
	
	create_piece_graphic()

func get_bomb_type() -> int:
	return bomb_type

func is_bomb() -> bool:
	return bomb_type != BombController.BombType.NONE

func update_bomb_orientation(orientation: int):
	"""Update orientation for line bombs"""
	if bomb_type == BombController.BombType.LINE:
		bomb_orientation = orientation
		create_piece_graphic()

func animate_to_position(new_position):
	stop_animation()
	
	target_position = new_position
	is_animating = true
	
	animation_tween = create_tween()
	animation_tween.tween_property(self, "position", new_position, 0.3)
	animation_tween.tween_callback(func(): 
		is_animating = false
		animation_tween = null
	)

func set_position_immediately(new_position):
	stop_animation()
	position = new_position
	target_position = new_position
	is_animating = false

func stop_animation():
	if animation_tween:
		animation_tween.kill()
		animation_tween = null
	is_animating = false

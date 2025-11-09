extends Node2D
# Piece.gd - Individual piece (puyo) with bomb support

const BombController = preload("res://scripts/BombController.gd")

var color = Color.WHITE
var is_bubble = false

# Bomb properties
var bomb_type = BombController.BombType.NONE
var bomb_timer = 5  # For time bombs
var bomb_orientation = BombController.Orientation.VERTICAL  # For line bombs

var sprite = null
var timer_label = null  # For time bomb countdown display
var target_position = Vector2.ZERO
var is_animating = false
var animation_tween = null

func _ready():
	# Create the sprite node
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create timer label for time bombs (hidden by default)
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(-12, -16)  # Center on piece
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.add_theme_constant_override("outline_size", 4)
	timer_label.visible = false
	add_child(timer_label)
	
	# Create texture
	create_piece_texture()

func _process(delta):
	# Update timer display for time bombs
	if bomb_type == BombController.BombType.TIME and timer_label:
		timer_label.text = str(bomb_timer)
		timer_label.visible = true

func create_piece_texture():
	# Try to load sprite if using sprites
	if GameState.use_sprites:
		var texture = null
		
		# Load appropriate sprite based on bomb type
		match bomb_type:
			BombController.BombType.NORMAL:
				texture = load("res://assets/bomb_piece.png")
			BombController.BombType.LINE:
				if bomb_orientation == BombController.Orientation.HORIZONTAL:
					texture = load("res://assets/line_bomb_horizontal.png")
				else:
					texture = load("res://assets/line_bomb_vertical.png")
			BombController.BombType.TIME:
				texture = load("res://assets/time_bomb.png")
			BombController.BombType.CROSS:
				texture = load("res://assets/cross_bomb.png")
			BombController.BombType.AREA:
				texture = load("res://assets/area_bomb.png")
			_:
				# Regular piece
				if GameState.sprite_paths.has(color):
					texture = load(GameState.sprite_paths[color])
		
		if texture:
			sprite.texture = texture
			return
	
	# Fall back to procedural generation
	create_procedural_texture()

func create_procedural_texture():
	var texture = ImageTexture.new()
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	if bomb_type != BombController.BombType.NONE:
		# Draw bomb base (black circle)
		for y in range(64):
			for x in range(64):
				var dist = Vector2(x - 32, y - 32).length()
				if dist < 28:
					image.set_pixel(x, y, Color.BLACK)
				elif dist < 32:
					image.set_pixel(x, y, Color.WHITE)
		
		# Add bomb type indicators
		match bomb_type:
			BombController.BombType.LINE:
				# Draw line indicator
				if bomb_orientation == BombController.Orientation.HORIZONTAL:
					for x in range(8, 56):
						image.set_pixel(x, 32, Color.RED)
						image.set_pixel(x, 31, Color.RED)
						image.set_pixel(x, 33, Color.RED)
				else:
					for y in range(8, 56):
						image.set_pixel(32, y, Color.RED)
						image.set_pixel(31, y, Color.RED)
						image.set_pixel(33, y, Color.RED)
			
			BombController.BombType.CROSS:
				# Draw cross indicator
				for i in range(8, 56):
					image.set_pixel(i, 32, Color.RED)
					image.set_pixel(32, i, Color.RED)
					image.set_pixel(i, 31, Color.RED)
					image.set_pixel(32, i - 1, Color.RED)
			
			BombController.BombType.AREA:
				# Draw radius indicator (circles)
				for radius in [12, 18, 24]:
					for angle in range(0, 360, 10):
						var rad = deg_to_rad(angle)
						var px = int(32 + cos(rad) * radius)
						var py = int(32 + sin(rad) * radius)
						if px >= 0 and px < 64 and py >= 0 and py < 64:
							image.set_pixel(px, py, Color.ORANGE)
	
	elif is_bubble:
		# Draw bubble piece
		for y in range(64):
			for x in range(64):
				var dist = Vector2(x - 32, y - 32).length()
				if dist < 24:
					image.set_pixel(x, y, color)
				elif dist < 28:
					image.set_pixel(x, y, color.darkened(0.5))
				elif dist < 30:
					image.set_pixel(x, y, Color.WHITE)
	else:
		# Draw normal piece
		for y in range(64):
			for x in range(64):
				var dist = Vector2(x - 32, y - 32).length()
				if dist < 28:
					image.set_pixel(x, y, color)
				elif dist < 32:
					image.set_pixel(x, y, color.darkened(0.3))
	
	texture.set_image(image)
	sprite.texture = texture

func set_color(new_color):
	color = new_color
	bomb_type = BombController.BombType.NONE
	if sprite:
		create_piece_texture()

func set_as_bubble():
	is_bubble = true
	bomb_type = BombController.BombType.NONE
	color = GameState.bubble_color
	if sprite:
		create_piece_texture()

func set_as_bomb(type: int, orientation: int = BombController.Orientation.VERTICAL):
	bomb_type = type
	bomb_orientation = orientation
	is_bubble = false
	color = GameState.bomb_color
	
	# Set timer for time bombs
	if bomb_type == BombController.BombType.TIME:
		bomb_timer = 5
	
	if sprite:
		create_piece_texture()

func get_bomb_type() -> int:
	return bomb_type

func is_bomb() -> bool:
	return bomb_type != BombController.BombType.NONE

func update_bomb_orientation(orientation: int):
	"""Update orientation for line bombs"""
	if bomb_type == BombController.BombType.LINE:
		bomb_orientation = orientation
		create_piece_texture()

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

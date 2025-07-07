extends Node2D
# Piece.gd - Individual piece (puyo)

var color = Color.WHITE
var is_bubble = false
var is_bomb = false
var sprite = null
var target_position = Vector2.ZERO
var is_animating = false
var animation_tween = null  # Track the tween to avoid conflicts

func _ready():
	# Create the sprite node
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create texture
	create_piece_texture()

func _process(delta):
	# Remove the old animation system since we're using tweens now
	pass

func create_piece_texture():
	if GameState.use_sprites and GameState.sprite_paths.has(color):
		# Try to load sprite file
		var texture = load(GameState.sprite_paths[color])
		if texture:
			sprite.texture = texture
			return
		else:
			print("Could not load sprite: ", GameState.sprite_paths[color])
	
	# Fall back to procedural generation
	create_procedural_texture()

func create_procedural_texture():
	var texture = ImageTexture.new()
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	if is_bomb:
		# Draw bomb piece - solid black circle
		for y in range(64):
			for x in range(64):
				var dist = Vector2(x - 32, y - 32).length()
				if dist < 28:
					image.set_pixel(x, y, Color.BLACK)
				elif dist < 32:
					image.set_pixel(x, y, Color.WHITE)  # White outline for bombs
	elif is_bubble:
		# Draw bubble piece with different pattern
		for y in range(64):
			for x in range(64):
				var dist = Vector2(x - 32, y - 32).length()
				if dist < 24:
					image.set_pixel(x, y, color)
				elif dist < 28:
					image.set_pixel(x, y, color.darkened(0.5))
				elif dist < 30:
					image.set_pixel(x, y, Color.WHITE)  # White outline for bubbles
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
	if sprite:
		create_piece_texture()

func set_as_bubble():
	is_bubble = true
	is_bomb = false
	color = GameState.bubble_color
	if sprite:
		create_piece_texture()

func set_as_bomb():
	is_bomb = true
	is_bubble = false
	color = GameState.bomb_color
	if sprite:
		create_piece_texture()

func animate_to_position(new_position):
	# Stop any existing animation to prevent conflicts
	stop_animation()
	
	target_position = new_position
	is_animating = true
	
	# Use a tween for smooth, controlled animation
	animation_tween = create_tween()
	animation_tween.tween_property(self, "position", new_position, 0.3)
	animation_tween.tween_callback(func(): 
		is_animating = false
		animation_tween = null
	)

func set_position_immediately(new_position):
	# Stop any animation and set position directly
	stop_animation()
	position = new_position
	target_position = new_position
	is_animating = false

func stop_animation():
	# Clean up any existing animation
	if animation_tween:
		animation_tween.kill()
		animation_tween = null
	is_animating = false

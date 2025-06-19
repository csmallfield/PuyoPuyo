extends Node2D
# Piece.gd - Individual piece (puyo)

var color = Color.WHITE
var is_bubble = false
var is_bomb = false
var sprite = null
var target_position = Vector2.ZERO
var is_animating = false

func _ready():
	# Create the sprite node
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create texture
	create_piece_texture()

func _process(delta):
	# Smooth animation towards target position
	if is_animating:
		var distance = target_position.distance_to(position)
		if distance > 2.0:  # Still moving
			var direction = (target_position - position).normalized()
			position += direction * GameState.piece_fall_speed * delta
		else:
			# Close enough, snap to target
			position = target_position
			is_animating = false

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
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	if is_bomb:
		# Draw bomb piece - solid black circle
		for y in range(32):
			for x in range(32):
				var dist = Vector2(x - 16, y - 16).length()
				if dist < 14:
					image.set_pixel(x, y, Color.BLACK)
				elif dist < 16:
					image.set_pixel(x, y, Color.WHITE)  # White outline for bombs
	elif is_bubble:
		# Draw bubble piece with different pattern
		for y in range(32):
			for x in range(32):
				var dist = Vector2(x - 16, y - 16).length()
				if dist < 12:
					image.set_pixel(x, y, color)
				elif dist < 14:
					image.set_pixel(x, y, color.darkened(0.5))
				elif dist < 15:
					image.set_pixel(x, y, Color.WHITE)  # White outline for bubbles
	else:
		# Draw normal piece
		for y in range(32):
			for x in range(32):
				var dist = Vector2(x - 16, y - 16).length()
				if dist < 14:
					image.set_pixel(x, y, color)
				elif dist < 16:
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
	target_position = new_position
	is_animating = true

func set_position_immediately(new_position):
	position = new_position
	target_position = new_position
	is_animating = false

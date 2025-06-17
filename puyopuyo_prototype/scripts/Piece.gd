extends Node2D
# Piece.gd - Individual piece (puyo)

var color = Color.WHITE
var is_bubble = false
var sprite = null

func _ready():
	# Create the sprite node
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create a simple colored circle texture
	create_piece_texture()

func create_piece_texture():
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	if is_bubble:
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
	color = GameState.bubble_color
	if sprite:
		create_piece_texture()

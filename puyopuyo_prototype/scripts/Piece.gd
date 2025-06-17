extends Node2D
# Piece.gd - Individual piece (puyo)

var color = Color.WHITE
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
	
	# Draw a simple circle
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

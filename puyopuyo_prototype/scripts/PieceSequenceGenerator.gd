extends Node
# PieceSequenceGenerator.gd - Generates identical piece sequences for all players

class_name PieceSequenceGenerator

# Structure to hold piece pair data
class PiecePairData:
	var piece1_color: Color
	var piece1_is_bubble: bool
	var piece1_is_bomb: bool
	var piece2_color: Color
	var piece2_is_bubble: bool
	var piece2_is_bomb: bool
	
	func _init():
		piece1_color = Color.WHITE
		piece1_is_bubble = false
		piece1_is_bomb = false
		piece2_color = Color.WHITE
		piece2_is_bubble = false
		piece2_is_bomb = false

var piece_sequence: Array[PiecePairData] = []
var current_sequence_index = 0
var sequence_seed = 0

# Pregenerate this many pieces ahead
const SEQUENCE_BUFFER_SIZE = 100

func _ready():
	# Initialize with a random seed
	initialize_sequence(randi())

func initialize_sequence(seed: int):
	"""Initialize a new piece sequence with the given seed"""
	sequence_seed = seed
	piece_sequence.clear()
	current_sequence_index = 0
	
	# Set the random seed for consistent generation
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	# Pre-generate initial sequence
	generate_more_pieces(rng, SEQUENCE_BUFFER_SIZE)
	
	print("Piece sequence initialized with seed: ", seed)

func generate_more_pieces(rng: RandomNumberGenerator, count: int):
	"""Generate additional pieces and add them to the sequence"""
	
	for i in range(count):
		var piece_pair = PiecePairData.new()
		
		# Generate random values for both pieces
		var rand1 = rng.randf()
		var rand2 = rng.randf()
		var bubble_rand1 = rng.randf()
		var bubble_rand2 = rng.randf()
		
		# Determine piece types - ensure no bomb+bomb pairs
		var piece1_is_bomb = rand1 < GameState.bomb_spawn_chance
		var piece2_is_bomb = false
		
		# If piece1 is not a bomb, piece2 can be a bomb
		if not piece1_is_bomb:
			piece2_is_bomb = rand2 < GameState.bomb_spawn_chance
		
		# Set piece1 type
		if piece1_is_bomb:
			piece_pair.piece1_is_bomb = true
			piece_pair.piece1_color = GameState.bomb_color
		else:
			piece_pair.piece1_is_bubble = bubble_rand1 < GameState.bubble_spawn_chance
			if piece_pair.piece1_is_bubble:
				piece_pair.piece1_color = GameState.bubble_color
			else:
				piece_pair.piece1_color = GameState.colors[rng.randi() % GameState.colors.size()]
		
		# Set piece2 type
		if piece2_is_bomb:
			piece_pair.piece2_is_bomb = true
			piece_pair.piece2_color = GameState.bomb_color
		else:
			piece_pair.piece2_is_bubble = bubble_rand2 < GameState.bubble_spawn_chance
			if piece_pair.piece2_is_bubble:
				piece_pair.piece2_color = GameState.bubble_color
			else:
				piece_pair.piece2_color = GameState.colors[rng.randi() % GameState.colors.size()]
		
		piece_sequence.append(piece_pair)

func get_next_piece_data() -> PiecePairData:
	"""Get the next piece pair data and advance the sequence"""
	
	# Check if we need to generate more pieces
	if current_sequence_index >= piece_sequence.size() - 10:  # Buffer of 10 remaining
		var rng = RandomNumberGenerator.new()
		rng.seed = sequence_seed + current_sequence_index  # Ensure consistent generation
		generate_more_pieces(rng, SEQUENCE_BUFFER_SIZE)
	
	# Return current piece and advance
	var piece_data = piece_sequence[current_sequence_index]
	current_sequence_index += 1
	
	return piece_data

func peek_next_piece_data() -> PiecePairData:
	"""Peek at the next piece without advancing the sequence"""
	
	# Check if we need to generate more pieces
	if current_sequence_index >= piece_sequence.size() - 10:  # Buffer of 10 remaining
		var rng = RandomNumberGenerator.new()
		rng.seed = sequence_seed + current_sequence_index  # Ensure consistent generation
		generate_more_pieces(rng, SEQUENCE_BUFFER_SIZE)
	
	return piece_sequence[current_sequence_index]

func reset_sequence():
	"""Reset to the beginning of the current sequence"""
	current_sequence_index = 0

func get_current_sequence_position() -> int:
	"""Get the current position in the sequence (for debugging)"""
	return current_sequence_index

func create_piece_pair_from_data(piece_data: PiecePairData, piece_pair_node):
	"""Apply the piece data to an actual PiecePair node"""
	
	if not piece_pair_node:
		print("Error: No piece pair node provided")
		return
	
	# Get the pieces from the pair
	var pieces = piece_pair_node.get_pieces()
	if pieces.size() < 2:
		print("Error: Piece pair doesn't have 2 pieces")
		return
	
	var piece1 = pieces[0]
	var piece2 = pieces[1]
	
	# Configure piece1
	if piece_data.piece1_is_bomb:
		piece1.set_as_bomb()
	elif piece_data.piece1_is_bubble:
		piece1.set_as_bubble()
	else:
		piece1.set_color(piece_data.piece1_color)
	
	# Configure piece2
	if piece_data.piece2_is_bomb:
		piece2.set_as_bomb()
	elif piece_data.piece2_is_bubble:
		piece2.set_as_bubble()
	else:
		piece2.set_color(piece_data.piece2_color)

# Global instance management
static var _instance: PieceSequenceGenerator = null

static func get_instance() -> PieceSequenceGenerator:
	"""Get the global piece sequence generator instance"""
	if _instance == null:
		_instance = PieceSequenceGenerator.new()
		# Add it to the scene tree so it persists
		Engine.get_main_loop().current_scene.add_child(_instance)
	return _instance

static func create_new_game_sequence(seed: int = -1):
	"""Create a new sequence for a new game"""
	var generator = get_instance()
	if seed == -1:
		seed = randi()
	generator.initialize_sequence(seed)

extends Node
# BombController.gd - Centralized bomb logic system

enum BombType {
	NONE,
	NORMAL,      # Color-matching bomb (current behavior)
	LINE,        # Clears entire row or column
	TIME,        # Countdown bomb (5 turns)
	CROSS,       # Clears both row and column
	AREA         # Clears 2-cell radius, ignores colors
}

enum Orientation {
	VERTICAL,
	HORIZONTAL
}

# Get display name for bomb type
static func get_bomb_type_name(bomb_type: BombType) -> String:
	match bomb_type:
		BombType.NONE:
			return "No Bombs"
		BombType.NORMAL:
			return "Color Bomb"
		BombType.LINE:
			return "Line Bomb"
		BombType.TIME:
			return "Time Bomb"
		BombType.CROSS:
			return "Cross Bomb"
		BombType.AREA:
			return "Area Bomb"
		_:
			return "Unknown"

# Get all positions affected by a bomb explosion
static func get_affected_positions(bomb_type: BombType, bomb_pos: Vector2, grid_data: Array, orientation: Orientation, target_color: Color = Color.BLACK) -> Array:
	var affected = []
	
	match bomb_type:
		BombType.NORMAL:
			affected = get_normal_bomb_affected(bomb_pos, grid_data, target_color)
		BombType.LINE:
			affected = get_line_bomb_affected(bomb_pos, grid_data, orientation)
		BombType.TIME:
			affected = get_time_bomb_affected(bomb_pos, grid_data, target_color)
		BombType.CROSS:
			affected = get_cross_bomb_affected(bomb_pos, grid_data)
		BombType.AREA:
			affected = get_area_bomb_affected(bomb_pos, grid_data)
	
	return affected

# Normal bomb - matches adjacent color (current behavior)
static func get_normal_bomb_affected(bomb_pos: Vector2, grid_data: Array, target_color: Color) -> Array:
	var affected = []
	
	# Find target color using priority: down, up, left, right
	var check_positions = [
		bomb_pos + Vector2(0, 1),
		bomb_pos + Vector2(0, -1),
		bomb_pos + Vector2(-1, 0),
		bomb_pos + Vector2(1, 0)
	]
	
	var actual_target_color = null
	var target_is_bubble = false
	
	for check_pos in check_positions:
		if is_valid_position(check_pos, grid_data):
			var adjacent_piece = grid_data[int(check_pos.y)][int(check_pos.x)]
			if adjacent_piece != null and not is_bomb_piece(adjacent_piece):
				actual_target_color = adjacent_piece.color
				target_is_bubble = adjacent_piece.is_bubble
				break
	
	if actual_target_color == null:
		return []
	
	# Find all pieces matching the target
	for y in range(grid_data.size()):
		for x in range(grid_data[0].size()):
			var piece = grid_data[y][x]
			if piece != null and not is_bomb_piece(piece):
				if (target_is_bubble and piece.is_bubble) or (not target_is_bubble and not piece.is_bubble and piece.color == actual_target_color):
					affected.append(Vector2(x, y))
	
	return affected

# Line bomb - clears entire row or column based on orientation
static func get_line_bomb_affected(bomb_pos: Vector2, grid_data: Array, orientation: Orientation) -> Array:
	var affected = []
	
	if orientation == Orientation.HORIZONTAL:
		# Clear entire row
		var row = int(bomb_pos.y)
		for x in range(grid_data[0].size()):
			if grid_data[row][x] != null:
				affected.append(Vector2(x, row))
	else:  # VERTICAL
		# Clear entire column
		var col = int(bomb_pos.x)
		for y in range(grid_data.size()):
			if grid_data[y][col] != null:
				affected.append(Vector2(col, y))
	
	return affected

# Time bomb - same as normal bomb (color-matching)
static func get_time_bomb_affected(bomb_pos: Vector2, grid_data: Array, target_color: Color) -> Array:
	return get_normal_bomb_affected(bomb_pos, grid_data, target_color)

# Cross bomb - clears both row AND column
static func get_cross_bomb_affected(bomb_pos: Vector2, grid_data: Array) -> Array:
	var affected = []
	var row = int(bomb_pos.y)
	var col = int(bomb_pos.x)
	
	# Clear entire row
	for x in range(grid_data[0].size()):
		if grid_data[row][x] != null:
			var pos = Vector2(x, row)
			if not pos in affected:
				affected.append(pos)
	
	# Clear entire column
	for y in range(grid_data.size()):
		if grid_data[y][col] != null:
			var pos = Vector2(col, y)
			if not pos in affected:
				affected.append(pos)
	
	return affected

# Area bomb - clears everything in 2-cell radius
static func get_area_bomb_affected(bomb_pos: Vector2, grid_data: Array) -> Array:
	var affected = []
	var radius = 2
	
	for y in range(grid_data.size()):
		for x in range(grid_data[0].size()):
			var distance = bomb_pos.distance_to(Vector2(x, y))
			if distance <= radius and grid_data[y][x] != null:
				affected.append(Vector2(x, y))
	
	return affected

# Check if a position is valid in the grid
static func is_valid_position(pos: Vector2, grid_data: Array) -> bool:
	return pos.x >= 0 and pos.x < grid_data[0].size() and pos.y >= 0 and pos.y < grid_data.size()

# Check if a piece is any type of bomb
static func is_bomb_piece(piece) -> bool:
	return piece.has_method("get_bomb_type") and piece.get_bomb_type() != BombType.NONE

# Decrement all time bombs on the grid (UPDATED to skip first turn)
static func decrement_time_bombs(grid_data: Array) -> Array:
	var exploding_bombs = []
	
	for y in range(grid_data.size()):
		for x in range(grid_data[0].size()):
			var piece = grid_data[y][x]
			if piece != null and is_bomb_piece(piece):
				if piece.get_bomb_type() == BombType.TIME:
					# Skip decrement if this is the first turn after placement
					if piece.first_turn_in_grid:
						piece.first_turn_in_grid = false
						continue
					
					piece.bomb_timer -= 1
					if piece.bomb_timer <= 0:
						exploding_bombs.append(Vector2(x, y))
	
	return exploding_bombs

# Get the orientation of a bomb based on piece pair rotation
static func get_bomb_orientation_from_rotation(rotation: int) -> int:
	# Rotation 0 and 2 are vertical, 1 and 3 are horizontal
	if rotation == 0 or rotation == 2:
		return Orientation.VERTICAL
	else:
		return Orientation.HORIZONTAL

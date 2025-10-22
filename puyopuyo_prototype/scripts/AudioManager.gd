extends Node
# AudioManager.gd - Centralized audio management system

# ============================================
# AUDIO PLAYERS POOL
# ============================================
var audio_players_pool = []
var max_audio_players = 32  # Maximum concurrent sounds
var current_player_index = 0

# ============================================
# SOUND EFFECTS - GAMEPLAY
# ============================================
var sfx_piece_move = preload("res://sounds/gameplay/piece_move.wav")
var sfx_piece_rotate = preload("res://sounds/gameplay/piece_rotate.wav")
var sfx_piece_land = preload("res://sounds/gameplay/piece_land.wav")
var sfx_piece_hard_drop = preload("res://sounds/gameplay/piece_hard_drop.wav")
var sfx_pieces_fall = preload("res://sounds/gameplay/pieces_fall.wav")
var sfx_pieces_settle = preload("res://sounds/gameplay/pieces_settle.wav")

# ============================================
# SOUND EFFECTS - MATCHES
# ============================================
var sfx_match_pop_small = preload("res://sounds/matches/match_pop_small.wav")
var sfx_match_pop_medium = preload("res://sounds/matches/match_pop_medium.wav")
var sfx_match_pop_large = preload("res://sounds/matches/match_pop_large.wav")
var sfx_bubble_pop = preload("res://sounds/matches/bubble_pop.wav")
var sfx_chain_2 = preload("res://sounds/matches/chain_2.wav")
var sfx_chain_3 = preload("res://sounds/matches/chain_3.wav")
var sfx_chain_4_plus = preload("res://sounds/matches/chain_4_plus.wav")

# ============================================
# SOUND EFFECTS - BOMBS
# ============================================
var sfx_bomb_warning = preload("res://sounds/bombs/bomb_warning.wav")
var sfx_bomb_explode = preload("res://sounds/bombs/bomb_explode.wav")
var sfx_bomb_spawn = preload("res://sounds/bombs/bomb_spawn.wav")

# ============================================
# SOUND EFFECTS - GARBAGE
# ============================================
var sfx_garbage_incoming = preload("res://sounds/garbage/garbage_incoming.wav")
var sfx_garbage_drop = preload("res://sounds/garbage/garbage_drop.wav")
var sfx_attack_sent = preload("res://sounds/garbage/attack_sent.wav")
var sfx_danger_warning = preload("res://sounds/garbage/danger_warning.wav")

# ============================================
# SOUND EFFECTS - PROGRESSION
# ============================================
var sfx_level_up = preload("res://sounds/progression/level_up.wav")
var sfx_score_tick = preload("res://sounds/progression/score_tick.wav")
var sfx_chain_bonus = preload("res://sounds/progression/chain_bonus.wav")

# ============================================
# SOUND EFFECTS - GAME STATE
# ============================================
var sfx_game_start = preload("res://sounds/game_state/game_start.wav")
var sfx_game_over = preload("res://sounds/game_state/game_over.wav")
var sfx_victory = preload("res://sounds/game_state/victory.wav")
var sfx_defeat = preload("res://sounds/game_state/defeat.wav")
var sfx_pause = preload("res://sounds/game_state/pause.wav")
var sfx_unpause = preload("res://sounds/game_state/unpause.wav")

# ============================================
# SOUND EFFECTS - UI
# ============================================
var sfx_button_click = preload("res://sounds/ui/button_click.wav")
var sfx_button_hover = preload("res://sounds/ui/button_hover.wav")
var sfx_difficulty_change = preload("res://sounds/ui/difficulty_change.wav")
var sfx_transition = preload("res://sounds/ui/transition.wav")

# ============================================
# VOLUME SETTINGS
# ============================================
var master_volume = 1.0
var sfx_volume = 1.0
var music_volume = 1.0

func _ready():
	# Create audio player pool
	for i in range(max_audio_players):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"  # Ensure you have an SFX bus in your audio settings
		add_child(player)
		audio_players_pool.append(player)

# ============================================
# CORE PLAYBACK FUNCTIONS
# ============================================

func play_sound(sound: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0):
	"""Play a sound effect with optional volume and pitch adjustment"""
	if sound == null:
		push_warning("AudioManager: Attempted to play null sound")
		return
	
	# Get next available player from pool
	var player = get_next_player()
	
	# Configure player
	player.stream = sound
	player.volume_db = volume_db + linear_to_db(sfx_volume * master_volume)
	player.pitch_scale = pitch_scale
	
	# Play sound
	player.play()

func get_next_player() -> AudioStreamPlayer:
	"""Get the next available audio player from the pool"""
	# Try to find a player that's not playing
	for i in range(max_audio_players):
		var index = (current_player_index + i) % max_audio_players
		if not audio_players_pool[index].playing:
			current_player_index = (index + 1) % max_audio_players
			return audio_players_pool[index]
	
	# If all players are busy, use the next one anyway (this will cut off the old sound)
	var player = audio_players_pool[current_player_index]
	current_player_index = (current_player_index + 1) % max_audio_players
	return player

func play_sound_random_pitch(sound: AudioStream, min_pitch: float = 0.9, max_pitch: float = 1.1, volume_db: float = 0.0):
	"""Play a sound with randomized pitch to add variety"""
	var random_pitch = randf_range(min_pitch, max_pitch)
	play_sound(sound, volume_db, random_pitch)

# ============================================
# GAMEPLAY SOUNDS
# ============================================

func play_piece_move():
	play_sound_random_pitch(sfx_piece_move, 0.95, 1.05, -5.0)

func play_piece_rotate():
	play_sound_random_pitch(sfx_piece_rotate, 0.95, 1.05, -3.0)

func play_piece_land():
	play_sound_random_pitch(sfx_piece_land, 0.9, 1.1, 0.0)

func play_piece_hard_drop():
	play_sound(sfx_piece_hard_drop, 0.0, 1.0)

func play_pieces_fall():
	play_sound(sfx_pieces_fall, -2.0, 1.0)

func play_pieces_settle():
	play_sound(sfx_pieces_settle, -4.0, 1.0)

# ============================================
# MATCH SOUNDS
# ============================================

func play_match_pop(piece_count: int):
	"""Play appropriate pop sound based on match size"""
	if piece_count >= 9:
		play_sound(sfx_match_pop_large, 2.0)
	elif piece_count >= 6:
		play_sound(sfx_match_pop_medium, 0.0)
	else:
		play_sound(sfx_match_pop_small, -2.0)

func play_bubble_pop():
	play_sound_random_pitch(sfx_bubble_pop, 0.9, 1.1, -3.0)

func play_chain_sound(chain_count: int):
	"""Play chain sound based on chain number"""
	match chain_count:
		2:
			play_sound(sfx_chain_2, 0.0, 1.0)
		3:
			play_sound(sfx_chain_3, 2.0, 1.0)
		_:  # 4+
			if chain_count >= 4:
				play_sound(sfx_chain_4_plus, 4.0, 1.0)

# ============================================
# BOMB SOUNDS
# ============================================

func play_bomb_warning():
	play_sound(sfx_bomb_warning, 0.0, 1.0)

func play_bomb_explode():
	play_sound(sfx_bomb_explode, 4.0, 1.0)

func play_bomb_spawn():
	play_sound(sfx_bomb_spawn, -2.0, 1.0)

# ============================================
# GARBAGE SOUNDS
# ============================================

func play_garbage_incoming():
	play_sound(sfx_garbage_incoming, 2.0, 1.0)

func play_garbage_drop(amount: int = 1):
	"""Play garbage drop with volume based on amount"""
	var volume = clamp(-2.0 + (amount / 10.0), -2.0, 4.0)
	play_sound(sfx_garbage_drop, volume, 1.0)

func play_attack_sent():
	play_sound(sfx_attack_sent, 0.0, 1.0)

func play_danger_warning():
	play_sound(sfx_danger_warning, 0.0, 1.0)

# ============================================
# PROGRESSION SOUNDS
# ============================================

func play_level_up():
	play_sound(sfx_level_up, 4.0, 1.0)

func play_score_tick():
	play_sound_random_pitch(sfx_score_tick, 0.95, 1.05, -8.0)

func play_chain_bonus(chain_count: int):
	"""Play chain bonus notification sound"""
	var pitch = 1.0 + (chain_count * 0.1)  # Higher pitch for higher chains
	play_sound(sfx_chain_bonus, 2.0, pitch)

# ============================================
# GAME STATE SOUNDS
# ============================================

func play_game_start():
	play_sound(sfx_game_start, 0.0, 1.0)

func play_game_over():
	play_sound(sfx_game_over, 2.0, 1.0)

func play_victory():
	play_sound(sfx_victory, 4.0, 1.0)

func play_defeat():
	play_sound(sfx_defeat, 2.0, 1.0)

func play_pause():
	play_sound(sfx_pause, 0.0, 1.0)

func play_unpause():
	play_sound(sfx_unpause, 0.0, 1.0)

# ============================================
# UI SOUNDS
# ============================================

func play_button_click():
	play_sound(sfx_button_click, -2.0, 1.0)

func play_button_hover():
	play_sound(sfx_button_hover, -6.0, 1.0)

func play_difficulty_change():
	play_sound(sfx_difficulty_change, 0.0, 1.0)

func play_transition():
	play_sound(sfx_transition, 0.0, 1.0)

# ============================================
# VOLUME CONTROL
# ============================================

func set_master_volume(value: float):
	"""Set master volume (0.0 to 1.0)"""
	master_volume = clamp(value, 0.0, 1.0)

func set_sfx_volume(value: float):
	"""Set SFX volume (0.0 to 1.0)"""
	sfx_volume = clamp(value, 0.0, 1.0)

func set_music_volume(value: float):
	"""Set music volume (0.0 to 1.0)"""
	music_volume = clamp(value, 0.0, 1.0)

func get_master_volume() -> float:
	return master_volume

func get_sfx_volume() -> float:
	return sfx_volume

func get_music_volume() -> float:
	return music_volume

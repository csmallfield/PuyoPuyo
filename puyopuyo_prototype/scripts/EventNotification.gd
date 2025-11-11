extends Control
# EventNotification.gd - Handles on-screen event notifications

var notification_label = null
var notification_queue = []
var is_showing = false
var current_notification_type = null
var current_tween = null

enum NotificationType {
	CHAIN,
	FIRST_ATTACK,
	ALL_CLEAR,
	GARBAGE_WARNING,
	DANGER
}

func _ready():
	notification_label = Label.new()
	add_child(notification_label)
	
	# Center the label
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.anchor_left = 0.5
	notification_label.anchor_top = 0.5
	notification_label.anchor_right = 0.5
	notification_label.anchor_bottom = 0.5
	notification_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	notification_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	notification_label.position = Vector2(-200, -50)
	notification_label.size = Vector2(400, 100)
	
	# Style
	notification_label.add_theme_font_size_override("font_size", 48)
	notification_label.add_theme_color_override("font_outline_color", Color.BLACK)
	notification_label.add_theme_constant_override("outline_size", 8)
	
	# CRITICAL: Always render on top
	notification_label.z_index = 1000
	z_index = 1000
	z_as_relative = false
	
	# Start hidden
	notification_label.modulate.a = 0.0

func show_notification(text: String, type: NotificationType = NotificationType.CHAIN, duration: float = 0.8):
	"""Queue a notification to be shown"""
	# Special case: If showing a chain and new chain comes in, update immediately
	if type == NotificationType.CHAIN and current_notification_type == NotificationType.CHAIN and is_showing:
		_update_chain_text(text, duration)
		return
	
	# Special case: If showing garbage warning and new warning comes in, update immediately
	if type == NotificationType.GARBAGE_WARNING and current_notification_type == NotificationType.GARBAGE_WARNING and is_showing:
		_update_chain_text(text, duration)
		return
	
	notification_queue.append({
		"text": text,
		"type": type,
		"duration": duration
	})
	
	if not is_showing:
		_show_next_notification()

func clear_garbage_warning():
	"""Clear garbage warning if it's currently showing"""
	if current_notification_type == NotificationType.GARBAGE_WARNING and is_showing:
		if current_tween:
			current_tween.kill()
		
		# Quick fade out
		current_tween = create_tween()
		current_tween.tween_property(notification_label, "modulate:a", 0.0, 0.2)
		current_tween.tween_callback(_show_next_notification)

func _update_chain_text(text: String, duration: float):
	"""Update chain text and restart the timer"""
	notification_label.text = text
	
	# Kill the old tween and restart with fresh timing
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	
	# Pop effect
	current_tween.tween_property(notification_label, "scale", Vector2(1.3, 1.3), 0.1)
	current_tween.tween_property(notification_label, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Hold (restart the timer)
	current_tween.tween_interval(duration)
	
	# Fade out
	current_tween.tween_property(notification_label, "modulate:a", 0.0, 0.2)
	
	# Show next notification when done
	current_tween.tween_callback(_show_next_notification)

func _show_next_notification():
	"""Show the next notification in the queue"""
	if notification_queue.size() == 0:
		is_showing = false
		current_notification_type = null
		return
	
	is_showing = true
	var notification = notification_queue.pop_front()
	current_notification_type = notification.type
	
	# Kill any existing tween
	if current_tween:
		current_tween.kill()
	
	# Set text and color based on type
	notification_label.text = notification.text
	
	match notification.type:
		NotificationType.CHAIN:
			notification_label.add_theme_color_override("font_color", Color.YELLOW)
		NotificationType.FIRST_ATTACK:
			notification_label.add_theme_color_override("font_color", Color.ORANGE)
		NotificationType.ALL_CLEAR:
			notification_label.add_theme_color_override("font_color", Color.CYAN)
		NotificationType.GARBAGE_WARNING:
			notification_label.add_theme_color_override("font_color", Color.RED)
		NotificationType.DANGER:
			notification_label.add_theme_color_override("font_color", Color.DARK_RED)
	
	# Animate - FASTER
	current_tween = create_tween()
	
	# Reset scale
	notification_label.scale = Vector2(0.5, 0.5)
	
	# Fade in + scale up (faster)
	current_tween.set_parallel(true)
	current_tween.tween_property(notification_label, "modulate:a", 1.0, 0.15)
	current_tween.tween_property(notification_label, "scale", Vector2(1.2, 1.2), 0.15)
	
	# Scale to normal
	current_tween.set_parallel(false)
	current_tween.tween_property(notification_label, "scale", Vector2(1.0, 1.0), 0.08)
	
	# Hold (shorter)
	current_tween.tween_interval(notification.duration)
	
	# Fade out (faster)
	current_tween.tween_property(notification_label, "modulate:a", 0.0, 0.2)
	
	# Show next notification when done
	current_tween.tween_callback(_show_next_notification)

func show_chain_notification(chain_count: int):
	"""Show chain notification with count"""
	var text = str(chain_count) + "x Chain!"
	show_notification(text, NotificationType.CHAIN, 0.6)

func show_first_attack_notification():
	"""Show first attack bonus notification"""
	show_notification("First Attack!", NotificationType.FIRST_ATTACK, 1.0)

func show_all_clear_notification():
	"""Show all clear bonus notification"""
	show_notification("All Clear!", NotificationType.ALL_CLEAR, 1.2)

func show_garbage_warning(rows: int):
	"""Show incoming garbage warning"""
	var text = str(rows) + " Row" + ("s" if rows != 1 else "") + " Incoming!"
	show_notification(text, NotificationType.GARBAGE_WARNING, 2.0)  # Longer duration

func show_danger_warning():
	"""Show danger warning when board is getting full"""
	show_notification("DANGER!", NotificationType.DANGER, 0.8)

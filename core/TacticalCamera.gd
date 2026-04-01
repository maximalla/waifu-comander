class_name TacticalCamera
extends Camera2D

# ==========================================
# НАЛАШТУВАННЯ (Exports)
# ==========================================
@export_group("Movement & Zoom")
@export var pan_speed := 600.0
@export var zoom_speed := 0.15
@export var min_zoom := 0.5
@export var max_zoom := 2.0

@export_group("Edge Scrolling")
@export var enable_edge_scroll := true
@export var edge_scroll_margin := 50.0

# ==========================================
# СТАН КАМЕРИ (Змінні)
# ==========================================
var target_zoom := Vector2(1, 1)
var touches := {} # Словник для зберігання точок дотику (для тачскріна)

# ==========================================
# ВБУДОВАНІ ФУНКЦІЇ GODOT
# ==========================================
func _ready():
	target_zoom = zoom
	make_current()

func _process(delta: float):
	_handle_movement(delta)
	_clamp_position()

func _unhandled_input(event: InputEvent):
	# --- 1. КЕРУВАННЯ ЗУМОМ (Коліщатко ПК) ---
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom += Vector2(zoom_speed, zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom -= Vector2(zoom_speed, zoom_speed)
			
			target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
			target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

	# --- 2. МОБІЛЬНЕ КЕРУВАННЯ (Тачскрін) ---
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event # Палець торкнувся екрана
		else:
			touches.erase(event.index) # Палець прибрали з екрана

	elif event is InputEventScreenDrag:
		touches[event.index] = event

		if touches.size() == 1:
			# Свайп одним пальцем (Панорамування)
			position -= event.relative * (1.0 / zoom.x)

		elif touches.size() == 2:
			# Щипок двома пальцями (Зум)
			var keys = touches.keys()
			var drag_event = event as InputEventScreenDrag
			var other_touch_index = keys[0] if keys[1] == drag_event.index else keys[1]
			var other_touch = touches[other_touch_index]

			var current_dist = drag_event.position.distance_to(other_touch.position)
			var prev_dist = (drag_event.position - drag_event.relative).distance_to(other_touch.position)

			if prev_dist > 0:
				var pinch_zoom_factor = current_dist / prev_dist
				target_zoom *= Vector2(pinch_zoom_factor, pinch_zoom_factor)
				
				target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
				target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

# ==========================================
# ВЛАСНІ ФУНКЦІЇ КАМЕРИ
# ==========================================
func _handle_movement(delta: float):
	var direction := Vector2.ZERO
	
	# Керування клавіатурою (WASD / Стрілки)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
		
	# Керування мишкою (Edge Scrolling) - працює лише якщо не натиснуті клавіші
	if enable_edge_scroll and direction == Vector2.ZERO:
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			var screen_size = viewport.get_visible_rect().size
			
			if Rect2(Vector2.ZERO, screen_size).has_point(mouse_pos):
				if mouse_pos.x < edge_scroll_margin: direction.x -= 1
				elif mouse_pos.x > screen_size.x - edge_scroll_margin: direction.x += 1
				
				if mouse_pos.y < edge_scroll_margin: direction.y -= 1
				elif mouse_pos.y > screen_size.y - edge_scroll_margin: direction.y += 1

	# Застосування руху та зуму
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * pan_speed * delta * (1.0 / zoom.x)
		
	zoom = zoom.lerp(target_zoom, 10 * delta)

func _clamp_position():
	var viewport_size = get_viewport().get_visible_rect().size
	var half_width = (viewport_size.x / zoom.x) / 2.0
	var half_height = (viewport_size.y / zoom.y) / 2.0
	
	var min_x = limit_left + half_width
	var max_x = limit_right - half_width
	var min_y = limit_top + half_height
	var max_y = limit_bottom - half_height
	
	if min_x > max_x:
		min_x = (limit_left + limit_right) / 2.0
		max_x = min_x
	if min_y > max_y:
		min_y = (limit_top + limit_bottom) / 2.0
		max_y = min_y

	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)

func setup_limits(map_width: float, map_height: float, margin: float = 300.0):
	limit_left = int(-margin)
	limit_top = int(-margin)
	limit_right = int(map_width + margin)
	limit_bottom = int(map_height + margin)

func focus_on_position(target_pos: Vector2):
	var tween = create_tween()
	tween.tween_property(self , "position", target_pos, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

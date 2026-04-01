extends Node2D

# ==========================================
# НАЛАШТУВАННЯ СІТКИ (Exports)
# ==========================================
@export var grid_size := Vector2i(24, 16)
@export var cell_size := 64
@export var line_color := Color(0.5, 0.5, 0.5, 1)

@export var obstacle_scene: PackedScene 
@export var tex_high_covers: Array[Texture2D]
@export var tex_low_covers: Array[Texture2D]

# ==========================================
# СТАН ГРИ (Змінні)
# ==========================================
var obstacles := {} # Зберігає тип перешкоди: "high" або "low"
var occupied := {}  # Зберігає посилання на юніта, який стоїть на клітинці

# Змінні для підсвітки (UI)
var highlight_cells := []
var actual_reachable_area := []
var highlight_size := Vector2i(1, 1)
var hover_cell := Vector2i(-1, -1)
var cursor_cell := Vector2i(-1, -1)
var current_highlight_color := Color(0.2, 0.8, 0.2, 0.4) # За замовчуванням - зелений

# ==========================================
# ВБУДОВАНІ ФУНКЦІЇ GODOT
# ==========================================
func _draw():
	# 1. Малюємо лінії сітки
	for x in range(grid_size.x + 1):
		draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, grid_size.y * cell_size), line_color)
	for y in range(grid_size.y + 1):
		draw_line(Vector2(0, y * cell_size), Vector2(grid_size.x * cell_size, y * cell_size), line_color)

	# 2. Малюємо зону (рух або атака)
	for cell in actual_reachable_area:
		draw_rect(Rect2(cell * cell_size, Vector2(cell_size, cell_size)), current_highlight_color)

	# 3. Малюємо рамку при наведенні мишки на клітинку з зони
	if hover_cell != Vector2i(-1, -1):
		var color = Color(1, 1, 0, 0.5) if highlight_cells.has(hover_cell) else Color(1, 0, 0, 0.4)
		var draw_pos = cell_to_world(hover_cell)
		var draw_size = Vector2(highlight_size) * cell_size
		draw_rect(Rect2(draw_pos, draw_size), color, false, 2.0)
		draw_rect(Rect2(draw_pos, draw_size), Color(color.r, color.g, color.b, 0.1))

	# 4. Малюємо маленький курсор під мишкою
	if cursor_cell != Vector2i(-1, -1):
		var cursor_pos = cell_to_world(cursor_cell) + Vector2(cell_size * 0.4, cell_size * 0.4)
		var cursor_rect_size = Vector2(cell_size * 0.2, cell_size * 0.2)
		draw_rect(Rect2(cursor_pos, cursor_rect_size), Color(1, 1, 1, 0.8))

# ==========================================
# КОНВЕРТАЦІЯ КООРДИНАТ ТА ПЕРЕВІРКИ
# ==========================================
func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(pos / cell_size)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * cell_size)

func get_top_left_from_mouse(mouse_cell: Vector2i, unit_size: Vector2i) -> Vector2i:
	return mouse_cell - (unit_size / 2)

func is_cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

func is_area_free(top_left: Vector2i, size: Vector2i) -> bool:
	for x in size.x:
		for y in size.y:
			var c = top_left + Vector2i(x, y)
			if not is_cell_inside(c): return false
			if occupied.has(c): return false
			if obstacles.has(c): return false
	return true

# ==========================================
# КЕРУВАННЯ ЮНІТАМИ ТА ПЕРЕШКОДАМИ
# ==========================================
func occupy_area(unit: Node2D, top_left: Vector2i, size: Vector2i):
	for x in size.x:
		for y in size.y: 
			occupied[top_left + Vector2i(x, y)] = unit

func clear_area(top_left: Vector2i, size: Vector2i):
	for x in size.x:
		for y in size.y: 
			occupied.erase(top_left + Vector2i(x, y))

func get_unit_at(cell: Vector2i) -> Node2D:
	return occupied.get(cell)

func add_obstacle(cell: Vector2i, is_high: bool = false):
	obstacles[cell] = "high" if is_high else "low"
		
	if obstacle_scene:
		var obs = obstacle_scene.instantiate() as Obstacle
		var tex: Texture2D = null
		
		if is_high and tex_high_covers.size() > 0:
			tex = tex_high_covers.pick_random() 
		elif not is_high and tex_low_covers.size() > 0:
			tex = tex_low_covers.pick_random()
			
		add_child(obs)
		obs.setup(cell, tex, is_high, self)

# ==========================================
# ВІЗУАЛІЗАЦІЯ ЗОН (UI)
# ==========================================
func set_highlight(cells: Array, unit_size: Vector2i, color: Color = Color(0, 1, 0, 0.15)):
	highlight_cells = cells
	highlight_size = unit_size
	current_highlight_color = color 
	
	# Створюємо унікальний набір клітинок (відкидаємо дублікати для великих юнітів)
	var footprint = {}
	for start_cell in cells:
		for x in unit_size.x:
			for y in unit_size.y: 
				footprint[start_cell + Vector2i(x, y)] = true
				
	actual_reachable_area = footprint.keys()
	queue_redraw()

# ==========================================
# АЛГОРИТМИ
# ==========================================
# Алгоритм Брезенхема для побудови лінії видимості
func get_line_of_sight(start_cell: Vector2i, end_cell: Vector2i) -> Array:
	var line = []
	var x0 = start_cell.x
	var y0 = start_cell.y
	var x1 = end_cell.x
	var y1 = end_cell.y
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while true:
		if Vector2i(x0, y0) != start_cell and Vector2i(x0, y0) != end_cell:
			line.append(Vector2i(x0, y0))
			
		if x0 == x1 and y0 == y1:
			break
			
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
			
	return line

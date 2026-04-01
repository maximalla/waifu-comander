class_name Obstacle
extends Sprite2D

# ==========================================
# НАЛАШТУВАННЯ (Exports)
# ==========================================
@export var is_high_cover := false
@export var target_width := 100.0 

# ==========================================
# СТАН ОБ'ЄКТА (Змінні)
# ==========================================
var grid_pos: Vector2i
var grid_ref: Node2D

# ==========================================
# ВБУДОВАНІ ФУНКЦІЇ GODOT
# ==========================================
func _process(delta: float):
	# Перевіряємо прозорість тільки для високих об'єктів (дерев)
	if not is_high_cover or not is_instance_valid(grid_ref): 
		return
		
	# Клітинка рівно "за" перешкодою (на 1 вище по Y)
	var cell_behind = grid_pos + Vector2i(0, -1)
	
	# Визначаємо цільову прозорість: 0.4 (напівпрозоре), якщо там є юніт, інакше 1.0 (видиме)
	var target_alpha = 0.4 if grid_ref.get_unit_at(cell_behind) != null else 1.0
	
	# Плавно змінюємо прозорість одним рядком
	modulate.a = lerp(modulate.a, target_alpha, 10.0 * delta)

# ==========================================
# ІНІЦІАЛІЗАЦІЯ
# ==========================================
func setup(cell: Vector2i, tex: Texture2D, high: bool, grid_node: Node2D):
	texture = tex
	is_high_cover = high
	grid_pos = cell
	grid_ref = grid_node
	
	y_sort_enabled = true
	
	if texture:
		var tex_size = texture.get_size()
		var scale_factor = target_width / tex_size.x
		scale = Vector2(scale_factor, scale_factor)
		
		# Зміщуємо якір (Pivot) у самий низ по центру, щоб дерево стояло на землі
		centered = false
		offset = Vector2(-tex_size.x / 2.0, -tex_size.y)
		
		var cell_size = grid_node.cell_size
		position = grid_node.cell_to_world(cell) + Vector2(cell_size / 2.0, cell_size)
	else:
		# Захист від помилок, якщо текстуру забули додати
		position = grid_node.cell_to_world(cell)

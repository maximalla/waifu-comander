class_name MapGenerator
extends Node

# ==========================================
# НАЛАШТУВАННЯ (Exports)
# ==========================================
@export var grid: Node2D     
@export var main_node: Node2D 

@export_group("Map Settings")
@export var min_obstacles := 10
@export var max_obstacles := 20
@export var spawn_zone_width := 3 # Скільки колонок відводиться для спавну баз (зліва і справа)

# ==========================================
# ГОЛОВНІ ФУНКЦІЇ
# ==========================================
func generate_battle(player_scenes: Array[PackedScene], enemy_scenes: Array[PackedScene]):
	var grid_size = grid.grid_size
	
	# 1. Розставляємо перешкоди (тільки в нейтральній зоні центру)
	var num_obstacles = randi_range(min_obstacles, max_obstacles)
	var placed_obstacles = 0
	var attempts = 0
	
	while placed_obstacles < num_obstacles and attempts < 1000:
		attempts += 1
		var rx = randi_range(0, grid_size.x - 1)
		var ry = randi_range(0, grid_size.y - 1)
		var cell = Vector2i(rx, ry)
		
		# Забороняємо ставити перешкоди в зонах спавну гравця та ворога
		if rx < spawn_zone_width or rx >= grid_size.x - spawn_zone_width:
			continue
			
		if not grid.obstacles.has(cell):
			var is_high = randf() > 0.5 # 50% шанс на дерево, 50% на камінь
			grid.add_obstacle(cell, is_high)
			placed_obstacles += 1

	# 2. Спавнимо команду ГРАВЦЯ (Зліва)
	_spawn_team(player_scenes, 0, spawn_zone_width - 1, 0)
	
	# 3. Спавнимо команду ВОРОГІВ (Справа)
	_spawn_team(enemy_scenes, grid_size.x - spawn_zone_width, grid_size.x - 1, 1)

# ==========================================
# ДОПОМІЖНІ ФУНКЦІЇ (Приватні)
# ==========================================
func _spawn_team(scenes: Array[PackedScene], min_x: int, max_x: int, team_id: int):
	for unit_scene in scenes:
		var unit = unit_scene.instantiate()
		var cell = _get_random_free_cell(min_x, max_x, unit.size)
		
		if cell != Vector2i(-1, -1):
			grid.add_child(unit)
			unit.team = team_id
			unit.place(cell)
			main_node.units.append(unit)
		else:
			# Використовуємо попередження, щоб воно світилося жовтим у консолі Godot
			push_warning("Не вистачило місця для спавну юніта з команди: " + str(team_id))
			unit.queue_free() 

func _get_random_free_cell(min_x: int, max_x: int, unit_size: Vector2i) -> Vector2i:
	var attempts = 0
	while attempts < 100:
		attempts += 1
		
		var rx = randi_range(min_x, max_x)
		var ry = randi_range(0, grid.grid_size.y - 1)
		var cell = Vector2i(rx, ry)
		
		# ПЕРЕВІРКА 1: Чи не вилазить юніт за межі дозволеної зони по ширині?
		if cell.x + unit_size.x - 1 > max_x:
			continue 
			
		# ПЕРЕВІРКА 2: Чи вільна область від інших юнітів, перешкод та країв карти?
		if grid.is_area_free(cell, unit_size):
			return cell
			
	return Vector2i(-1, -1)

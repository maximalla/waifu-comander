extends Node2D

# ==========================================
# НАЛАШТУВАННЯ (Exports)
# ==========================================
@export var player_roster: Array[PackedScene]
@export var enemy_roster: Array[PackedScene]

# ==========================================
# СТАН ГРИ (Змінні)
# ==========================================
var units := []
var defeated_enemies := [] # Список переможених ворогів для розрахунку полонених
var current_index := 0
var active_unit: Node2D
var targeted_enemy: Node2D = null # Ворог, якого ми виділили для атаки
var active_skill: Skill = null

var is_moving := false
var current_action := "move" # Стан: "move", "attack" тощо
var is_auto_aiming := false # Запам'ятовує, чи гра сама перемкнулася на атаку

# Змінні для мобільного керування (Long Press)
var touch_start_time: int = 0
var touch_start_pos: Vector2 = Vector2.ZERO
var is_touching := false
var long_press_triggered := false
const LONG_PRESS_TIME_MS := 500

# ==========================================
# ВБУДОВАНІ ФУНКЦІЇ GODOT
# ==========================================
func _ready():
	# Підключення кнопок UI
	$UI.end_turn_pressed.connect(skip_turn)
	$UI.skill_selected.connect(_on_skill_selected)
	
	# Налаштування камери
	var map_width = $Grid.grid_size.x * $Grid.cell_size
	var map_height = $Grid.grid_size.y * $Grid.cell_size
	$Camera2D.setup_limits(map_width, map_height, 300.0)
	$Camera2D.position = Vector2(map_width / 2.0, map_height / 2.0)
	
	# Генерація карти та старт гри
	if has_node("MapGenerator"):
		$MapGenerator.generate_battle(player_roster, enemy_roster)
	else:
		push_error("Не знайдено вузол MapGenerator!")
	
	if units.size() > 0:
		start_turn()
	else:
		push_error("Юніти не заспавнились! Перевірте списки Roster в Інспекторі.")

func _process(_delta):
	if active_unit and not is_moving:
		var m_cell = $Grid.world_to_cell($Grid.get_local_mouse_position())
		var tl_cell = $Grid.get_top_left_from_mouse(m_cell, active_unit.size)
		$Grid.cursor_cell = m_cell
		
		if $Grid.hover_cell != tl_cell:
			$Grid.hover_cell = tl_cell
			$Grid.queue_redraw()

	# --- МОБІЛЬНА ЛОГІКА: Довгий натиск (Target Panel) ---
	if $UI.is_mobile and is_touching and not long_press_triggered:
		if Time.get_ticks_msec() - touch_start_time > LONG_PRESS_TIME_MS:
			long_press_triggered = true
			if is_instance_valid(active_unit) and not active_unit.is_exhausted:
				# Переводимо координати екрана у координати ігрового світу
				var canvas_transform = get_canvas_transform()
				var world_pos = canvas_transform.affine_inverse() * touch_start_pos
				var m_cell = $Grid.world_to_cell($Grid.to_local(world_pos))
				var hovered_unit = $Grid.get_unit_at(m_cell)
				
				if hovered_unit and hovered_unit.team != active_unit.team and hovered_unit.current_hp > 0:
					var first_skill = active_unit.skills[0] if active_unit.skills.size() > 0 else null
					if first_skill and first_skill.target_type == Skill.TargetType.ENEMY:
						# ==========================================
						# 1. ЗАВЖДИ вмикаємо режим атаки і малюємо зону 
						# (навіть якщо ворог далеко)
						# ==========================================
						current_action = "use_skill"
						active_skill = first_skill
						var target_cells = active_unit.get_skill_target_cells(first_skill)
						$Grid.set_highlight(target_cells, Vector2i(1, 1), Color(0.8, 0.1, 0.1, 0.5))
						
						# ==========================================
						# 2. ПОТІМ перевіряємо, чи дістаємо, щоб показати UI
						# ==========================================
						var min_dist = _get_min_distance_to_unit(active_unit, hovered_unit)
						if min_dist <= first_skill.range:
							var chance = active_unit.get_hit_chance(hovered_unit)
							var expected_dmg = abs(first_skill.base_damage)
							var crit = active_unit.crit_chance
							$UI.show_target_panel(hovered_unit.unit_name, chance, expected_dmg, crit)
							targeted_enemy = hovered_unit
						else:
							# Якщо ворог далеко, ховаємо панель (якщо вона була відкрита)
							$UI.hide_target_panel()
							targeted_enemy = null

	# --- ЛОГІКА ХОВЕРУ ТА АВТО-ПРИЦІЛЮВАННЯ (ТІЛЬКИ ДЛЯ ПК!) ---
	if not $UI.is_mobile:
		$UI.hide_hover_label() # Ховаємо текст кожен кадр
		
		var m_cell = $Grid.world_to_cell($Grid.get_local_mouse_position())
		var hovered_unit = $Grid.get_unit_at(m_cell)
		var is_hovering_enemy = hovered_unit and hovered_unit.team != active_unit.team and hovered_unit.current_hp > 0
		
		# ЧАСТИНА 1: Автоматичне перемикання move <-> use_skill
		if is_instance_valid(active_unit) and not is_moving:
			if current_action == "move" and is_hovering_enemy:
				if active_unit.skills.size() > 0:
					var first_skill = active_unit.skills[0]
					if first_skill.target_type == Skill.TargetType.ENEMY:
						is_auto_aiming = true
						active_skill = first_skill
						current_action = "use_skill"
						var target_cells = active_unit.get_skill_target_cells(first_skill)
						$Grid.set_highlight(target_cells, Vector2i(1, 1), Color(0.8, 0.1, 0.1, 0.5))
			
			elif current_action == "use_skill" and is_auto_aiming and not is_hovering_enemy:
				is_auto_aiming = false
				active_skill = null
				current_action = "move"
				active_unit.calculate_reachable_cells()

		# ЧАСТИНА 2: Відображення шансу влучання
		if current_action == "use_skill" and is_instance_valid(active_unit) and not is_moving and active_skill:
			if hovered_unit and hovered_unit.current_hp > 0:
				var min_dist = _get_min_distance_to_unit(active_unit, hovered_unit)
				
				if min_dist <= active_skill.range:
					var valid = false
					match active_skill.target_type:
						Skill.TargetType.ENEMY:
							if hovered_unit.team != active_unit.team: valid = true
						Skill.TargetType.ALLY:
							if hovered_unit.team == active_unit.team: valid = true
						Skill.TargetType.SELF:
							if hovered_unit == active_unit: valid = true
							
					if valid:
						var chance = active_unit.get_hit_chance(hovered_unit)
						$UI.show_hover_label(chance)


# ==========================================
# ОБРОБКА ВВОДУ (Універсальна)
# ==========================================
func _unhandled_input(event):
	if is_moving or (active_unit and active_unit.team != 0):
		return
	
	# Пропуск ходу клавіатурою
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		skip_turn()
		return
		
	# Скасування дії на ПКМ
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if current_action != "move":
			current_action = "move"
			active_unit.calculate_reachable_cells()
			$UI.hide_target_panel()
			is_touching = false
		return

	# --- Гібридна логіка Тапів / Кліків ---
	var is_press_event = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch)
	var is_drag_event = (event is InputEventMouseMotion) or (event is InputEventScreenDrag)

	if is_press_event:
		if event.pressed:
			# Початок кліку/дотику
			is_touching = true
			long_press_triggered = false
			touch_start_time = Time.get_ticks_msec()
			touch_start_pos = event.position
		else:
			# Відпускання (Кінець кліку/дотику)
			if is_touching:
				is_touching = false
				
				# Якщо ми не тримали довго (Короткий тап) - виконуємо дію!
				if not long_press_triggered:
					var canvas_transform = get_canvas_transform()
					var world_pos = canvas_transform.affine_inverse() * touch_start_pos
					var m_cell = $Grid.world_to_cell($Grid.to_local(world_pos))
					var clicked_unit = $Grid.get_unit_at(m_cell)
					
					match current_action:
						"move":
							await _handle_move_action(m_cell, clicked_unit)
						"use_skill":
							await _handle_attack_action(clicked_unit)
							
	elif is_drag_event and is_touching:
		# Якщо гравець свайпає екран (відхилення більше 15 пікселів) - скасовуємо довгий натиск
		if event.position.distance_to(touch_start_pos) > 15:
			is_touching = false
			long_press_triggered = false

# ==========================================
# ЛОГІКА ДІЙ (Рух та Атака)
# ==========================================
func _handle_move_action(m_cell: Vector2i, clicked_unit: Node2D) -> void:
	if clicked_unit != null and clicked_unit != active_unit:
		if clicked_unit.team != active_unit.team and active_unit.skills.size() > 0:
			var first_skill = active_unit.skills[0]
			if first_skill.target_type == Skill.TargetType.ENEMY:
				var min_dist = _get_min_distance_to_unit(active_unit, clicked_unit)
				if min_dist <= first_skill.range and active_unit.current_ap >= first_skill.ap_cost:
					active_skill = first_skill
					await _handle_attack_action(clicked_unit)
		return
		
	var target_tl = $Grid.get_top_left_from_mouse(m_cell, active_unit.size)
	
	if active_unit.reachable_cells.has(target_tl):
		if target_tl == active_unit.grid_position:
			return
			
		is_moving = true
		active_unit.move_to(target_tl)
		
		await get_tree().create_timer(0.2).timeout
		is_moving = false
		
		if not is_instance_valid(active_unit):
			next_turn()
			return
		
		if active_unit.is_exhausted:
			next_turn()
		else:
			active_unit.calculate_reachable_cells()
			if active_unit.reachable_cells.is_empty():
				next_turn()

func _handle_attack_action(clicked_unit: Node2D) -> void:
	if not clicked_unit:
		targeted_enemy = null
		$UI.hide_target_panel()
		current_action = "move"
		active_unit.calculate_reachable_cells()
		return

	var min_dist = _get_min_distance_to_unit(active_unit, clicked_unit)
	if min_dist > active_skill.range:
		return

	match active_skill.target_type:
		Skill.TargetType.ENEMY:
			if clicked_unit.team == active_unit.team: return
		Skill.TargetType.ALLY:
			if clicked_unit.team != active_unit.team: return
		Skill.TargetType.SELF:
			if clicked_unit != active_unit: return

	if active_unit.current_ap >= active_skill.ap_cost:
		$UI.hide_target_panel()
		targeted_enemy = null
		
		await active_unit.use_skill(clicked_unit, active_skill)
		
		if clicked_unit.current_hp <= 0:
			await _process_unit_death(clicked_unit)
		
		current_action = "move"
		if active_unit.current_ap <= 0:
			active_unit.is_exhausted = true
			next_turn()
		else:
			active_unit.calculate_reachable_cells()
	else:
		print("Недостатньо AP!")

func _get_min_distance_to_unit(attacking_unit: Node2D, target_unit: Node2D) -> int:
	var min_dist = 9999
	for tx in range(target_unit.size.x):
		for ty in range(target_unit.size.y):
			var target_cell = target_unit.grid_position + Vector2i(tx, ty)
			var dist = attacking_unit.distance_to_cell(target_cell)
			if dist < min_dist:
				min_dist = dist
	return min_dist

# ==========================================
# УПРАВЛІННЯ ХОДАМИ
# ==========================================
func start_turn():
	current_action = "move"
	
	active_unit = units[current_index]
	active_unit.reset_ap()
	$UI.setup_skill_buttons(active_unit.skills)
	
	$UI.update_turn_queue(units, current_index)
	
	active_unit.calculate_reachable_cells()
	
	$Grid.hover_cell = active_unit.grid_position
	$Grid.queue_redraw()
	
	if is_instance_valid(active_unit) and has_node("Camera2D"):
		var unit_center = active_unit.position + (Vector2(active_unit.size) * $Grid.cell_size) / 2.0
		$Camera2D.focus_on_position(unit_center)
		
	if active_unit.team != 0:
		is_moving = true
		await active_unit.execute_ai()
		is_moving = false
		next_turn()

func _on_skill_selected(skill: Skill):
	current_action = "use_skill"
	active_skill = skill
	is_auto_aiming = false # Блокуємо відключення скілу через ховер
	
	var target_cells = active_unit.get_skill_target_cells(skill)
	var color = Color(0, 1, 0, 0.15)
	if skill.target_type == Skill.TargetType.ENEMY:
		color = Color(0.8, 0.1, 0.1, 0.5)
	else:
		color = Color(0.1, 0.8, 0.1, 0.5)

	$Grid.set_highlight(target_cells, Vector2i(1, 1), color)

func next_turn():
	if is_instance_valid(active_unit):
		active_unit.is_exhausted = true
		active_unit.update_visual()
		
	current_index += 1
	if current_index >= units.size():
		current_index = 0
		
	start_turn()

func skip_turn():
	if is_moving: return
	if active_unit and not active_unit.is_exhausted:
		active_unit.current_ap = 0
		$Grid.highlight_cells.clear()
		$Grid.queue_redraw()
		next_turn()

# ==========================================
# ЗАВЕРШЕННЯ БОЮ ТА ЗАХОПЛЕННЯ
# ==========================================
func _process_unit_death(unit: Node2D):
	if unit.team != 0:
		# Зберігаємо дані юніта перед видаленням
		print(unit)
		var unit_data = {
			"name": unit.unit_name,
			"portrait": unit.portrait,
			"scene": unit.scene_file_path if "scene_file_path" in unit else unit.filename
		}
		defeated_enemies.append(unit_data)
	
	units.erase(unit)
	
	# Оновлюємо індекс, щоб не вилетіти за межі масиву
	if current_index >= units.size() and units.size() > 0:
		current_index = 0
		
	$UI.update_turn_queue(units, current_index)
	await unit.die()
	
	_check_battle_end()

func _check_battle_end():
	var player_alive = false
	var enemy_alive = false
	
	for u in units:
		if u.team == 0: player_alive = true
		else: enemy_alive = true
	
	if not enemy_alive:
		_end_battle(true)
	elif not player_alive:
		_end_battle(false)

func _end_battle(is_victory: bool):
	is_moving = true 
	
	if is_victory:
		var potential_captures := []
		if defeated_enemies.size() > 0:
			var count = max(1, int(defeated_enemies.size() * 0.2))
			defeated_enemies.shuffle()
			for i in range(min(count, defeated_enemies.size())):
				potential_captures.append(defeated_enemies[i])
		
		if $UI.has_method("show_capture_screen"):
			$UI.show_capture_screen(potential_captures)
		else:
			# Фолбек, якщо новий екран ще не готовий
			$UI.show_result(true, potential_captures.size())
	else:
		$UI.show_result(false, 0)
func _on_btn_attack_pressed():
	if is_moving or not is_instance_valid(active_unit) or active_unit.is_exhausted: return
	if active_unit.team != 0: return
		
	$UI.release_focuses()
	current_action = "attack"
	
	var attack_cells = active_unit.get_attackable_cells()
	var red_color = Color(0.8, 0.1, 0.1, 0.5)
	
	$Grid.set_highlight(attack_cells, Vector2i(1, 1), red_color)

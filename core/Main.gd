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
var current_index := 0
var active_unit: Node2D
var targeted_enemy: Node2D = null # Ворог, якого ми виділили для атаки
var active_skill: Skill = null

var is_moving := false
var current_action := "move" # Стан: "move", "attack" тощо

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

	# --- ЛОГІКА ХОВЕРУ (ТІЛЬКИ ДЛЯ ПК!) ---
	if not $UI.is_mobile:
		$UI.hide_hover_label() # Ховаємо текст кожен кадр
		
		if current_action == "use_skill" and is_instance_valid(active_unit) and not is_moving and active_skill:
			var m_cell = $Grid.world_to_cell($Grid.get_local_mouse_position())
			var hovered_unit = $Grid.get_unit_at(m_cell)
			
			if hovered_unit and hovered_unit.current_hp > 0:
				var dist = active_unit.distance_to_cell(hovered_unit.grid_position)
				if dist <= active_skill.range:
					# Перевірка типу цілі
					var valid = false
					match active_skill.target_type:
						Skill.TargetType.ENEMY:
							if hovered_unit.team != active_unit.team:
								valid = true
						Skill.TargetType.ALLY:
							if hovered_unit.team == active_unit.team:
								valid = true
						Skill.TargetType.SELF:
							if hovered_unit == active_unit:
								valid = true
					if valid:
						var chance = active_unit.get_hit_chance(hovered_unit) # Можливо, треба адаптувати для скілів
						$UI.show_hover_label(chance) # Показуємо, якщо навели на ціль

func _unhandled_input(event):
	if is_moving or (active_unit and active_unit.team != 0):
		return
	
	# Пропуск ходу клавіатурою
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		skip_turn()
		return
		
	if event is InputEventMouseButton and event.pressed:
		# --- ПКМ: Скасування дії ---
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if current_action != "move":
				current_action = "move"
				active_unit.calculate_reachable_cells()
			return

		# --- ЛКМ: Виконання дії ---
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_instance_valid(active_unit) or active_unit.is_exhausted:
				return
			
			var m_cell = $Grid.world_to_cell($Grid.get_local_mouse_position())
			var clicked_unit = $Grid.get_unit_at(m_cell)
			
			match current_action:
				"move":
					_handle_move_action(m_cell, clicked_unit)
				"use_skill":
					_handle_attack_action(clicked_unit)

# ==========================================
# ЛОГІКА ДІЙ (Рух та Атака)
# ==========================================
func _handle_move_action(m_cell: Vector2i, clicked_unit: Node2D):
	# ФІКС 1: Блокуємо рух, ТІЛЬКИ якщо клікнули на ІНШОГО юніта
	if clicked_unit != null and clicked_unit != active_unit:
		return
		
	var target_tl = $Grid.get_top_left_from_mouse(m_cell, active_unit.size)
	
	if active_unit.reachable_cells.has(target_tl):
		# ФІКС 2: Якщо ми клікнули рівно туди, де вже стоїмо — просто ігноруємо, щоб не витрачати AP
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

func _handle_attack_action(clicked_unit: Node2D):
	if not clicked_unit:
		targeted_enemy = null
		$UI.hide_target_panel()
		current_action = "move"
		active_unit.calculate_reachable_cells()
		return

	var dist = active_unit.distance_to_cell(clicked_unit.grid_position)
	if dist > active_skill.range:
		return

	# Перевірка типу цілі
	match active_skill.target_type:
		Skill.TargetType.ENEMY:
			if clicked_unit.team == active_unit.team:
				return
		Skill.TargetType.ALLY:
			if clicked_unit.team != active_unit.team:
				return
		Skill.TargetType.SELF:
			if clicked_unit != active_unit:
				return

	if active_unit.current_ap >= active_skill.ap_cost:
		$UI.hide_target_panel()
		targeted_enemy = null
		
		await active_unit.use_skill(clicked_unit, active_skill)
		
		if clicked_unit.current_hp <= 0:
			units.erase(clicked_unit)
			await clicked_unit.die()
		
		current_action = "move"
		if active_unit.current_ap <= 0:
			active_unit.is_exhausted = true
			next_turn()
		else:
			active_unit.calculate_reachable_cells()
	else:
		print("Недостатньо AP!")

# ==========================================
# УПРАВЛІННЯ ХОДАМИ
# ==========================================
func start_turn():
	current_action = "move"
	
	active_unit = units[current_index]
	active_unit.reset_ap()
	$UI.setup_skill_buttons(active_unit.skills)
	active_unit.calculate_reachable_cells()
	
	$Grid.hover_cell = active_unit.grid_position
	$Grid.queue_redraw()
	
	# Фокус камери
	if is_instance_valid(active_unit) and has_node("Camera2D"):
		var unit_center = active_unit.position + (Vector2(active_unit.size) * $Grid.cell_size) / 2.0
		$Camera2D.focus_on_position(unit_center)
		
	# Хід ШІ
	if active_unit.team != 0:
		is_moving = true
		await active_unit.execute_ai()
		is_moving = false
		next_turn()

func _on_skill_selected(skill: Skill):
	current_action = "use_skill"
	active_skill = skill
	# Підсвітити зону застосування скілу
	var target_cells = active_unit.get_skill_target_cells(skill)
	var red_color = Color(0.8, 0.1, 0.1, 0.5)
	$Grid.set_highlight(target_cells, Vector2i(1, 1), red_color)

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
# СИГНАЛИ UI
# ==========================================
func _on_btn_attack_pressed():
	if is_moving or not is_instance_valid(active_unit) or active_unit.is_exhausted: return
	if active_unit.team != 0: return
		
	# ФІКС: Просимо UI зняти фокус
	$UI.release_focuses()
	
	current_action = "attack"
	
	var attack_cells = active_unit.get_attackable_cells()
	var red_color = Color(0.8, 0.1, 0.1, 0.5)
	
	$Grid.set_highlight(attack_cells, Vector2i(1, 1), red_color)

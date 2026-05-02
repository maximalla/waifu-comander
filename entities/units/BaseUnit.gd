class_name BaseUnit
extends Node2D

# ==========================================
# ХАРАКТЕРИСТИКИ ЮНІТА (Exports)
# ==========================================
@export_group("Basic Stats")
@export var unit_name: String = "Невідомий юніт"
@export var team := 0 # 0 = Гравець, 1 = Ворог
@export var size := Vector2i(2, 3)
@export var max_ap := 6
@export var max_hp := 10

@export_group("Combat Stats")
@export var attack_range := 1 # 1 = ближній бій, 2+ = лук або магія
@export var melee_damage := 4
@export var attack_ap_cost := 4
@export var accuracy := 100 # Базовий шанс влучити (100%)
@export var evasion := 0 # Шанс ухилитися (0-30%)
@export var crit_chance := 10 # Шанс критичного удару (10%)
@export var skills: Array[Skill]
@export_group("Visuals")
@export var portrait: Texture2D
# Сцена снаряда, яку цей юніт використовує для дальніх атак
@export var projectile_scene: PackedScene

# ==========================================
# СТАН ГРИ (Змінні)
# ==========================================
var current_ap := 6
var current_hp := 10
var grid_position: Vector2i
var is_exhausted := false

var reachable_cells := []
var cell_costs := {}
var grid: Node2D

# ==========================================
# ВБУДОВАНІ ФУНКЦІЇ GODOT
# ==========================================
func _ready():
	grid = get_tree().root.find_child("Grid", true, false)
	current_hp = max_hp
	update_visual()

func _draw():
	var team_color = Color(0.2, 0.8, 0.2, 0.5) if team == 0 else Color(0.8, 0.2, 0.2, 0.5)
	var cell_size = 64.0
	
	var radius = (size.x * cell_size / 2.0) * 0.8
	var center_x = (size.x * cell_size) / 2.0
	var center_y = (size.y * cell_size) - (radius * 0.5)
	
	draw_set_transform(Vector2(center_x, center_y), 0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radius, team_color)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# ==========================================
# ВІЗУАЛ ТА UI
# ==========================================
func update_visual():
	var target_px = Vector2(size) * grid.cell_size
	var sprite_top_y = 0.0
	
	if $Sprite2D and $Sprite2D.texture:
		var tex_size = $Sprite2D.texture.get_size()
		var oversize_factor = 1.25
		
		var uniform_scale = (target_px.x / tex_size.x) * oversize_factor
		$Sprite2D.scale = Vector2(uniform_scale, uniform_scale)
		$Sprite2D.centered = false
		$Sprite2D.offset = Vector2(-tex_size.x / 2.0, -tex_size.y)
		
		# ==========================================
		# НОВЕ: ВІДДЗЕРКАЛЕННЯ ВОРОГІВ
		# Якщо команда не 0 (тобто ворог) — дзеркалимо спрайт по горизонталі!
		# ==========================================
		$Sprite2D.flip_h = (team != 0)
		
		var bottom_center_px = Vector2(target_px.x / 2.0, target_px.y)
		$Sprite2D.position = bottom_center_px
		sprite_top_y = bottom_center_px.y - (tex_size.y * $Sprite2D.scale.y)
	
	modulate = Color(0.5, 0.5, 0.5) if is_exhausted else Color(1, 1, 1)

	var bar_height = 14
	var ui_base_y = sprite_top_y - 10
	
	if has_node("HPBar"):
		$HPBar.max_value = max_hp
		$HPBar.value = current_hp
		$HPBar.size = Vector2(target_px.x, bar_height)
		$HPBar.position = Vector2(0, ui_base_y - bar_height * 2)
		$HPBar.modulate = Color(0, 1, 0) if team == 0 else Color(1, 0, 0)
		
	if has_node("HPLabel"):
		$HPLabel.text = str(current_hp) + "/" + str(max_hp)
		$HPLabel.size = $HPBar.size
		$HPLabel.position = $HPBar.position
		
	if has_node("APBar"):
		$APBar.max_value = max_ap
		$APBar.value = current_ap
		$APBar.size = Vector2(target_px.x, bar_height)
		$APBar.position = Vector2(0, ui_base_y - bar_height)
		
	if has_node("APLabel"):
		$APLabel.text = str(current_ap) + "/" + str(max_ap)
		$APLabel.size = $APBar.size
		$APLabel.position = $APBar.position

func _spawn_floating_text(text_str: String, color: Color, font_size: int, is_crit: bool = false):
	var label = Label.new()
	label.text = text_str
	label.z_index = 100
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", font_size)
	
	var target_px = Vector2(size) * grid.cell_size
	var x_offset = 40 if is_crit else 10
	label.position = (target_px / 2.0) - Vector2(x_offset, target_px.y * 0.4)
	
	add_child(label)
	
	var float_tween = create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(label, "position:y", label.position.y - 40, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	float_tween.tween_property(label, "modulate:a", 0.0, 0.7)
	float_tween.chain().tween_callback(label.queue_free)

# ==========================================
# ЛОГІКА РУХУ ТА РОЗМІЩЕННЯ
# ==========================================
func place(cell: Vector2i):
	grid.clear_area(grid_position, size)
	grid_position = cell
	grid.occupy_area(self , cell, size)
	position = grid.cell_to_world(cell)
	update_visual()
	queue_redraw()

func reset_ap():
	current_ap = max_ap
	is_exhausted = false
	reduce_cooldowns()
	update_visual()

func reduce_cooldowns():
	for skill in skills:
		if skill.current_cooldown > 0:
			skill.current_cooldown -= 1

func calculate_reachable_cells():
	reachable_cells.clear()
	cell_costs.clear()
	
	if is_exhausted or current_ap <= 0:
		grid.set_highlight([], size)
		return
	
	grid.clear_area(grid_position, size)
	var frontier = [grid_position]
	var visited = {grid_position: 0}

	while frontier.size() > 0:
		var current = frontier.pop_front()
		var current_cost = visited[current]
		
		if current_cost >= current_ap: continue

		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next = current + dir
			if next not in visited and grid.is_area_free(next, size):
				var new_cost = current_cost + 1
				visited[next] = new_cost
				
				frontier.append(next)
				reachable_cells.append(next)
				cell_costs[next] = new_cost

	grid.occupy_area(self , grid_position, size)
	grid.set_highlight(reachable_cells, size)

func move_to(target_cell: Vector2i):
	var engaged_enemies = get_adjacent_enemies()
	
	var cost = cell_costs[target_cell]
	current_ap -= cost
	if current_ap <= 0: is_exhausted = true
		
	# Атака при втечі
	for enemy in engaged_enemies:
		print("Вільна атака від ворога!")
		receive_attack(enemy.melee_damage, enemy.accuracy, enemy.crit_chance)
		
		if current_hp <= 0:
			var main_node = grid.get_parent()
			await main_node._process_unit_death(self )
			return
			
	grid.clear_area(grid_position, size)
	grid_position = target_cell
	grid.occupy_area(self , grid_position, size)
	
	var tween = create_tween()
	tween.tween_property(self , "position", grid.cell_to_world(target_cell), 0.2)
	
	update_visual()

# ==========================================
# БОЙОВА ЛОГІКА (Розрахунки)
# ==========================================
func distance_to_cell(target_cell: Vector2i) -> int:
	var min_manhattan = 9999
	var min_chebyshev = 9999
	
	for x in range(size.x):
		for y in range(size.y):
			var my_cell = grid_position + Vector2i(x, y)
			var dx = abs(my_cell.x - target_cell.x)
			var dy = abs(my_cell.y - target_cell.y)
			
			var manhattan = dx + dy
			var chebyshev = max(dx, dy)
			
			if manhattan < min_manhattan: min_manhattan = manhattan
			if chebyshev < min_chebyshev: min_chebyshev = chebyshev
			
	if min_chebyshev == 1:
		return 1
	return min_manhattan

func is_in_attack_range(target: Node2D) -> bool:
	var min_dist = 9999
	for tx in range(target.size.x):
		for ty in range(target.size.y):
			var target_cell = target.grid_position + Vector2i(tx, ty)
			var dist = distance_to_cell(target_cell)
			if dist < min_dist: min_dist = dist
				
	return min_dist <= attack_range

func is_adjacent_to(target: Node2D) -> bool:
	var my_rect = Rect2(grid_position, size)
	var target_rect = Rect2(target.grid_position, target.size)
	var attack_range_rect = my_rect.grow(1)
	return attack_range_rect.intersects(target_rect)

func get_adjacent_enemies() -> Array:
	var enemies = []
	var main_node = grid.get_parent()
	
	for u in main_node.units:
		if u != self and u.team != self.team and u.current_hp > 0:
			if is_adjacent_to(u):
				enemies.append(u)
	return enemies

# Повертає шанс влучання у відсотках (0, якщо постріл неможливий через стіну)
func get_hit_chance(target: Node2D) -> int:
	var dist = distance_to_cell(target.grid_position)
	var final_accuracy = accuracy
	
	# Якщо це дальній бій (відстань більше 1 клітинки)
	if dist > 1:
		var los_data = check_los(target)
		if not los_data.can_see:
			return 0 # Через дерево/стіну не стріляємо взагалі
			
		if los_data.has_cover:
			final_accuracy -= 30 # Зрізаємо точність за укриття (можеш змінити на свою змінну)
			
	# Формула: Наша точність мінус ухилення цілі (завжди від 5% до 100%)
	var hit_chance = clamp(final_accuracy - target.evasion, 5, 100)
	return hit_chance

func check_los(target: Node2D) -> Dictionary:
	var result = {"can_see": true, "has_cover": false, "cover_unit": null}
	var line = grid.get_line_of_sight(grid_position, target.grid_position)
	
	for cell in line:
		if grid.obstacles.has(cell) and grid.obstacles[cell] == "high":
			result.can_see = false
			return result
			
	if line.size() > 0:
		var cell_before_target = line.back()
		
		if grid.obstacles.has(cell_before_target) and grid.obstacles[cell_before_target] == "low":
			result.has_cover = true
		else:
			var main_node = grid.get_parent()
			for u in main_node.units:
				if u.grid_position == cell_before_target and u.current_hp > 0:
					result.has_cover = true
					result.cover_unit = u
					break
					
	return result

func get_attackable_cells() -> Array:
	var cells = []
	var my_rect = Rect2(grid_position, size)
	var attack_rect = my_rect.grow(attack_range)
	
	for x in range(attack_rect.position.x, attack_rect.end.x):
		for y in range(attack_rect.position.y, attack_rect.end.y):
			var cell = Vector2i(x, y)
			
			if cell.x >= 0 and cell.x < grid.grid_size.x and cell.y >= 0 and cell.y < grid.grid_size.y:
				if not my_rect.has_point(cell):
					if distance_to_cell(cell) <= attack_range:
						var can_see = true
						var line = grid.get_line_of_sight(grid_position, cell)
						
						for line_cell in line:
							if grid.obstacles.has(line_cell) and grid.obstacles[line_cell] == "high":
								can_see = false
								break
								
						if can_see:
							cells.append(cell)
	return cells

func get_skill_target_cells(skill: Skill) -> Array:
	var cells = []
	var my_rect = Rect2(grid_position, size)
	var skill_rect = my_rect.grow(skill.range)
	
	for x in range(skill_rect.position.x, skill_rect.end.x):
		for y in range(skill_rect.position.y, skill_rect.end.y):
			var cell = Vector2i(x, y)
			
			if cell.x >= 0 and cell.x < grid.grid_size.x and cell.y >= 0 and cell.y < grid.grid_size.y:
				if not my_rect.has_point(cell):
					if distance_to_cell(cell) <= skill.range:
						var can_see = true
						var line = grid.get_line_of_sight(grid_position, cell)
						
						for line_cell in line:
							if grid.obstacles.has(line_cell) and grid.obstacles[line_cell] == "high":
								can_see = false
								break
								
						if can_see:
							cells.append(cell)
	return cells
func execute_ranged_attack(target: Node2D, los_data: Dictionary):
	current_ap -= attack_ap_cost
	var final_accuracy = accuracy
	
	if los_data.has_cover:
		final_accuracy -= 30
		print("Ціль в укритті!")
		
	var hit_chance = clamp(final_accuracy - target.evasion, 5, 100)
	var roll = randi() % 100 + 1
	
	# Розраховуємо шкоду наперед (але не наносимо її!)
	var is_crit = (randi() % 100 + 1) <= crit_chance
	var dmg = melee_damage * 2 if is_crit else melee_damage
	
	if roll <= hit_chance:
		# === ВЛУЧИЛИ! ===
		if projectile_scene:
			# 1. Створюємо снаряд
			var proj = projectile_scene.instantiate()
			
			# 2. Додаємо його на сцену (до Grid, щоб він був у тому ж просторі)
			grid.add_child(proj)
			
			# 3. Налаштовуємо його політ
			# Беремо центр тіла лучника як точку старту
			var start_px = global_position + Vector2(size * grid.cell_size) / 2.0
			proj.setup(start_px, target, dmg, is_crit)
			
			print("Стріла летить!")
			
			# 4. ВАЖЛИВО: Чекаємо, поки снаряд долетить!
			# (Ми слухаємо сигнал tree_exited, який спрацьовує при queue_free())
			await proj.tree_exited
			
			print("Стріла долетіла!")
			
		else:
			# Якщо забули додати сцену снаряда в Інспекторі — наносимо шкоду миттєво
			push_warning("У " + name + " немає projectile_scene! Наношу шкоду миттєво.")
			target.take_damage(dmg, is_crit)
			
	else:
		# === ПРОМАХ! ===
		# Снаряд все одно летить, але ми передаємо йому 0 шкоди!
		# (Ми можемо пізніше додати анімацію прольоту повз ціль, 
		# але поки що для простоти зробимо так)
		if projectile_scene:
			var proj = projectile_scene.instantiate()
			grid.add_child(proj)
			var start_px = global_position + Vector2(size * grid.cell_size) / 2.0
			# Передаємо 0 шкоди!
			proj.setup(start_px, target, 0, false)
			
			await proj.tree_exited
		
		# Після того, як снаряд пролетів — показуємо текст промаху
		target.show_miss_text()
		
	# Оновлюємо візуал AP після завершення всієї анімації
	update_visual()

func execute_melee_attack(target: Node2D):
	current_ap -= attack_ap_cost
	
	# Зберігаємо початкову позицію (верхній лівий кут області)
	var start_pos = position
	
	# Розрахунок центру юніта та цілі (локальні координати відносно Grid)
	var unit_center = position + (Vector2(size) * grid.cell_size) / 2.0
	var target_center = target.position + (Vector2(target.size) * grid.cell_size) / 2.0
	var direction = (target_center - unit_center).normalized()
	var lunge_distance = 20.0 # Відстань ривка в пікселях (налаштуйте)
	var lunge_offset = direction * lunge_distance
	var lunge_pos = start_pos + lunge_offset
	
	# Tween для ривка вперед
	var tween = create_tween()
	tween.tween_property(self , "position", lunge_pos, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Чекаємо завершення ривка
	await tween.finished
	
	# Наносимо шкоду (як у receive_attack, але з критичним ударом)
	var hit_chance = clamp(accuracy - target.evasion, 5, 100)
	var roll = randi() % 100 + 1
	if roll <= hit_chance:
		var is_crit = (randi() % 100 + 1) <= crit_chance
		var dmg = melee_damage * 2 if is_crit else melee_damage
		target.take_damage(dmg, is_crit)
	else:
		target.show_miss_text()
	
	# Tween для повернення назад
	tween = create_tween()
	tween.tween_property(self , "position", start_pos, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	
	# Оновлюємо візуал після анімації
	update_visual()
		
func use_skill(target: Node2D, skill: Skill):
	# Перевірка типу цілі
	match skill.target_type:
		Skill.TargetType.ENEMY:
			if target.team == self.team:
				return
		Skill.TargetType.ALLY:
			if target.team != self.team:
				return
		Skill.TargetType.SELF:
			if target != self:
				return
	
	current_ap -= skill.ap_cost
	skill.current_cooldown = skill.max_cooldown
	
	var dist = distance_to_cell(target.grid_position)
	
	if dist > 1:
		# Дальній скіл
		var los_data = check_los(target)
		if not los_data.can_see:
			return
		
		if projectile_scene:
			var proj = projectile_scene.instantiate()
			grid.add_child(proj)
			var start_px = global_position + Vector2(size * grid.cell_size) / 2.0
			proj.setup(start_px, target, skill.base_damage, false) # Без криту поки
			await proj.tree_exited
		else:
			if skill.base_damage > 0:
				target.take_damage(skill.base_damage, false)
			else:
				target.current_hp += abs(skill.base_damage)
				target.current_hp = min(target.current_hp, target.max_hp)
				# Показати зелений текст лікування
				target._spawn_floating_text("+" + str(abs(skill.base_damage)), Color(0, 1, 0), 24, false)
	else:
		# Ближній скіл
		if skill.range == 1:
			# Ривок для ближнього
			var start_pos = position
			var unit_center = position + (Vector2(size) * grid.cell_size) / 2.0
			var target_center = target.position + (Vector2(target.size) * grid.cell_size) / 2.0
			var direction = (target_center - unit_center).normalized()
			var lunge_distance = 20.0
			var lunge_offset = direction * lunge_distance
			var lunge_pos = start_pos + lunge_offset
			
			var tween = create_tween()
			tween.tween_property(self , "position", lunge_pos, 0.1)
			await tween.finished
			
			if skill.base_damage > 0:
				target.take_damage(skill.base_damage, false)
			else:
				target.current_hp += abs(skill.base_damage)
				target.current_hp = min(target.current_hp, target.max_hp)
				target._spawn_floating_text("+" + str(abs(skill.base_damage)), Color(0, 1, 0), 24, false)
			
			tween = create_tween()
			tween.tween_property(self , "position", start_pos, 0.1)
			await tween.finished
		else:
			# Якщо range > 1, але dist == 1? Не має бути, але для безпеки
			if skill.base_damage > 0:
				target.take_damage(skill.base_damage, false)
			else:
				target.current_hp += abs(skill.base_damage)
				target.current_hp = min(target.current_hp, target.max_hp)
				target._spawn_floating_text("+" + str(abs(skill.base_damage)), Color(0, 1, 0), 24, false)
	
	update_visual()

func receive_attack(damage: int, attacker_accuracy: int, attacker_crit_chance: int):
	var hit_chance = clamp(attacker_accuracy - evasion, 5, 100)
	var roll = randi() % 100 + 1
	
	if roll <= hit_chance:
		var is_crit = (randi() % 100 + 1) <= attacker_crit_chance
		var final_damage = damage * 2 if is_crit else damage
		take_damage(final_damage, is_crit)
	else:
		show_miss_text()

func take_damage(amount: int, is_crit: bool = false):
	current_hp -= amount
	
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(1, 0, 0), 0.1)
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1), 0.1)
	
	if is_crit:
		_spawn_floating_text("КРИТ! -" + str(amount), Color(1, 0.8, 0), 28, true)
	else:
		_spawn_floating_text("-" + str(amount), Color(1, 0.2, 0.2), 24, false)
	
	update_visual()

func show_miss_text():
	_spawn_floating_text("Промах!", Color(0.8, 0.8, 0.8), 20, false)

func die():
	grid.clear_area(grid_position, size)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "rotation", deg_to_rad(90), 0.6)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.6)
	
	await tween.finished
	
	queue_free()

# ==========================================
# ШТУЧНИЙ ІНТЕЛЕКТ (AI)
# ==========================================
func execute_ai():
	await get_tree().create_timer(0.5).timeout
	
	var target = get_closest_enemy()
	if target == null: return
		
	if is_in_attack_range(target) and current_ap >= attack_ap_cost:
		await ai_attack(target)
		return
		
	var best_cell = get_best_move_towards(target)
	
	if best_cell != grid_position:
		move_to(best_cell)
		await get_tree().create_timer(0.3).timeout
		
		if not is_instance_valid(self ): return
			
		calculate_reachable_cells()
		
		if is_in_attack_range(target) and current_ap >= attack_ap_cost:
			await ai_attack(target)

func get_closest_enemy() -> Node2D:
	var target = null
	var min_dist = 99999
	var main_node = grid.get_parent()
	
	for u in main_node.units:
		if u.team != self.team and u.current_hp > 0:
			# ОНОВЛЕНО: Тепер ШІ знає справжню дистанцію до великих юнітів!
			var dist = distance_to_cell(u.grid_position)
			if dist < min_dist:
				min_dist = dist
				target = u
	return target

func get_best_move_towards(target: Node2D) -> Vector2i:
	var best_cell = grid_position
	var best_dist = target.distance_to_cell(grid_position)
	
	for cell in reachable_cells:
		# ОНОВЛЕНО: ШІ рахує кроки до реального краю ворога, а не до його центру
		var dist = target.distance_to_cell(cell)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	return best_cell

func ai_attack(target: Node2D):
	await execute_melee_attack(target)
	
	if target.current_hp <= 0:
		var main_node = grid.get_parent()
		await main_node._process_unit_death(target)

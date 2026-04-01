class_name Archer
extends BaseUnit

# ==========================================
# ШТУЧНИЙ ІНТЕЛЕКТ (AI) ЛУЧНИКА
# ==========================================
func execute_ai():
	await get_tree().create_timer(0.5).timeout
	
	var target = get_closest_enemy()
	if not is_instance_valid(target):
		return
		
	# 1. СПРОБА АТАКИ З МІСЦЯ
	if is_in_attack_range(target) and current_ap >= attack_ap_cost:
		if await _try_attack(target):
			return # Якщо успішно вистрілили/вдарили — завершуємо хід
		
	# 2. ЯКЩО ВОРОГ ДАЛЕКО (АБО ЗА ДЕРЕВОМ) — ЙДЕМО ДО НЬОГО
	var best_cell = get_best_move_towards(target)
	
	if best_cell != grid_position:
		move_to(best_cell)
		await get_tree().create_timer(0.3).timeout
		
		# Захист: чи вижили ми після удару в спину при втечі
		if not is_instance_valid(self ) or not is_instance_valid(target):
			return
			
		calculate_reachable_cells()
		
		# 3. СПРОБА АТАКИ ПІСЛЯ КРОКУ
		if is_in_attack_range(target) and current_ap >= attack_ap_cost:
			await _try_attack(target)

# ==========================================
# ДОПОМІЖНІ ФУНКЦІЇ
# ==========================================
# Повертає true, якщо атака відбулася, і false, якщо заважає укриття
func _try_attack(target: Node2D) -> bool:
	# Якщо ворог стоїть впритул — б'ємо кинджалом (базова атака)
	if is_adjacent_to(target):
		await ai_attack(target)
		return true
		
	# Якщо ворог далеко — пробуємо вистрілити
	else:
		var los_data = check_los(target)
		
		if los_data.can_see:
			execute_ranged_attack(target, los_data)
			
			# Робимо паузу для краси, щоб гравець побачив політ "стріли" і цифри шкоди
			await get_tree().create_timer(0.5).timeout
			
			# Перевіряємо, чи не вбили ми ціль (бо execute_ranged_attack не має вбудованої перевірки смерті ШІ)
			if target.current_hp <= 0:
				var main_node = grid.get_parent()
				main_node.units.erase(target)
				await target.die()
				
			return true
			
	# Якщо ми дійшли сюди, значить ми в радіусі атаки, але ціль за деревом (can_see = false).
	# Повертаємо false, щоб ШІ перейшов до кроку "Рух" і спробував знайти кращу позицію!
	return false

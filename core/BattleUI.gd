class_name BattleUI
extends CanvasLayer

signal skill_selected(skill: Skill)
signal end_turn_pressed
signal restart_pressed

@onready var btn_restart = $BtnRestart

@onready var panel = $Panel
@onready var hbox = $Panel/HBoxContainer
@onready var btn_end_turn = $Panel/HBoxContainer/BtnEndTurn

# Елементи мобільного інтерфейсу (Панель цілі)
@onready var target_panel = $TargetPanel
@onready var lbl_name = $TargetPanel/VBoxContainer/LblName
@onready var lbl_hit = $TargetPanel/VBoxContainer/LblHit
@onready var lbl_dmg = $TargetPanel/VBoxContainer/LblDmg
@onready var lbl_crit = $TargetPanel/VBoxContainer/LblCrit

# Елементи ПК інтерфейсу (Ховер-текст)
@onready var hover_label = $HitChanceLabel

# Контейнер для черги ходів (його треба створити в сцені!)
@onready var turn_queue_box = $TurnQueueBox

# ЦЮ ЗМІННУ ЧИТАТИМЕ MAIN.GD
var is_mobile := false

func _ready():
	btn_end_turn.pressed.connect(func(): end_turn_pressed.emit())
	btn_restart.pressed.connect(func(): restart_pressed.emit()) # ДОДАНО

	# === ВІДРАЗУ ПЕРЕДАЄМО СТАН З СИНГЛТОНА ===
	btn_restart.visible = GameManager.is_sandbox_mode
	
	var os_name = OS.get_name()
	is_mobile = os_name in ["Android", "iOS"]
	
	_adapt_ui_for_platform()
	hide_target_panel()
	hide_hover_label()

func _adapt_ui_for_platform():
	if is_mobile:
		panel.custom_minimum_size.y = 150
		panel.size.y = 150
		btn_end_turn.custom_minimum_size.y = 100
		btn_end_turn.add_theme_font_size_override("font_size", 40)
	else:
		panel.custom_minimum_size.y = 80
		panel.size.y = 80
		btn_end_turn.custom_minimum_size.y = 0
		btn_end_turn.add_theme_font_size_override("font_size", 24)

func setup_skill_buttons(skills: Array[Skill]):
	for child in hbox.get_children():
		if child != btn_end_turn:
			child.queue_free()
	
	for i in range(1, skills.size()):
		var skill = skills[i]
		var btn = Button.new()
		btn.text = skill.skill_name
		btn.add_theme_font_size_override("font_size", 24)
		btn.custom_minimum_size.x = 120
		
		if skill.current_cooldown > 0:
			btn.disabled = true
			btn.text += " (" + str(skill.current_cooldown) + ")"
		else:
			btn.disabled = false
		
		btn.pressed.connect(func(): skill_selected.emit(skill))
		hbox.add_child(btn)
		hbox.move_child(btn, hbox.get_child_count() - 2)

func release_focuses():
	btn_end_turn.release_focus()

# ==========================================
# ЧЕРГА ХОДІВ (Turn Queue)
# ==========================================
func update_turn_queue(units: Array, current_index: int):
	if not turn_queue_box: return
		
	# Очищаємо старі іконки
	for child in turn_queue_box.get_children():
		child.queue_free()

	if units.size() == 0: return

	var queue_length = min(8, units.size() * 2)
	for i in range(queue_length):
		var idx = (current_index + i) % units.size()
		var unit = units[idx]

		# 1. Створюємо контейнер із фоном для портрета
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		
		# Налаштовуємо колір фону залежно від команди
		if unit.team == 0:
			style.bg_color = Color(0.1, 0.4, 0.1, 0.8) # Темно-зелений для гравця
		else:
			style.bg_color = Color(0.5, 0.1, 0.1, 0.8) # Темно-червоний для ворога
			
		# Робимо красиві закруглені кути
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8

		# 2. Створюємо саму іконку
		var icon = TextureRect.new()
		
		if "portrait" in unit and unit.portrait != null:
			icon.texture = unit.portrait
		elif unit.has_node("Sprite2D") and unit.get_node("Sprite2D").texture:
			icon.texture = unit.get_node("Sprite2D").texture
			
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		if unit.team != 0:
			icon.flip_h = true

		# 3. Виділяємо поточного юніта (першого в черзі)
		if i == 0:
			panel.custom_minimum_size = Vector2(80, 80) # Більший розмір
			icon.modulate = Color(1.2, 1.2, 1.2, 1.0)
			
			# Додаємо золоту рамку тому, хто зараз ходить!
			style.border_width_bottom = 4
			style.border_width_top = 4
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_color = Color(1.0, 0.8, 0.0, 1.0)
		else:
			panel.custom_minimum_size = Vector2(64, 64) # Менший розмір для інших
			icon.modulate = Color(0.7, 0.7, 0.7, 0.8) # Трохи затемнюємо

		# Застосовуємо стиль і збираємо все до купи
		panel.add_theme_stylebox_override("panel", style)
		panel.add_child(icon)
		turn_queue_box.add_child(panel)

# ==========================================
# МОБІЛЬНА ЛОГІКА ТА ПК ХОВЕР (Без змін)
# ==========================================
func show_target_panel(enemy_name: String, chance: int, expected_dmg: int, crit: int):
	lbl_name.text = "Ціль: Ворог"
	lbl_hit.text = "Шанс: " + str(chance) + "%"
	if chance >= 70: lbl_hit.add_theme_color_override("font_color", Color.GREEN)
	elif chance >= 40: lbl_hit.add_theme_color_override("font_color", Color.YELLOW)
	else: lbl_hit.add_theme_color_override("font_color", Color.RED)
	lbl_dmg.text = "Шкода: " + str(expected_dmg)
	lbl_crit.text = "Крит: " + str(crit) + "%"
	target_panel.visible = true

func hide_target_panel():
	target_panel.visible = false

func show_hover_label(chance: int):
	if chance > 0:
		hover_label.text = str(chance) + "% Хіт"
		hover_label.visible = true
		hover_label.global_position = hover_label.get_global_mouse_position() + Vector2(20, -30)
		if chance >= 70: hover_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
		elif chance >= 40: hover_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		else: hover_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		hide_hover_label()

func hide_hover_label():
	if hover_label: hover_label.visible = false

# =========================================
# ЕКРАН ЗАХОПЛЕННЯ ПОЛОНЕНИХ
# =========================================
func show_capture_screen(units_data: Array):
	# 1. Створюємо ізольований шар, щоб обійти баг зі зміщенням
	var popup_layer = CanvasLayer.new()
	popup_layer.layer = 100 # Гарантовано поверх усього іншого
	add_child(popup_layer)
	
	# 2. Створюємо фон-затемнення
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(overlay)
	
	# 3. Використовуємо CenterContainer для ідеального центрування
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	# 4. Створюємо головну панель (БЕЗ ручного PRESET_CENTER)
	var main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(600, 450)
	center.add_child(main_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	main_panel.add_child(margin)
	
	var layout = VBoxContainer.new()
	margin.add_child(layout)
	
	# ... далі ВВЕСЬ твій старий код без змін, починаючи зі створення title ...
	var title = Label.new()
	title.text = "ТРОФЕЇ ТА ПОЛОНЕНІ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)
	
	var desc = Label.new()
	desc.text = "Ви можете захопити частину розбитих сил ворога. Виберіть, кого взяти з собою:"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(desc)
	
	layout.add_child(HSeparator.new())
	
	# Контейнер для списку юнітів
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	
	var list = HFlowContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.alignment = FlowContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("h_separation", 15)
	list.add_theme_constant_override("v_separation", 15)
	scroll.add_child(list)
	
	var captured_indices = {} # Запам'ятовуємо вибір
	
	if units_data.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "\nНікого не вдалося захопити..."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty_lbl)
	else:
		for i in range(units_data.size()):
			var data = units_data[i]
			
			# Створюємо блок юніта як кнопку
			var unit_btn = Button.new()
			unit_btn.toggle_mode = true
			unit_btn.custom_minimum_size = Vector2(160, 200)
			list.add_child(unit_btn)
			
			var vbox = VBoxContainer.new()
			vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			unit_btn.add_child(vbox)
			
			var icon = TextureRect.new()
			icon.texture = data.portrait
			icon.custom_minimum_size = Vector2(120, 120)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(icon)
			
			var name_lbl = Label.new()
			name_lbl.text = data.name
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_lbl.add_theme_font_size_override("font_size", 18)
			vbox.add_child(name_lbl)
			
			unit_btn.toggled.connect(func(pressed):
				if pressed:
					captured_indices[i] = true
					unit_btn.modulate = Color(0.6, 1.2, 0.6) # Підсвітка при виборі
				else:
					captured_indices.erase(i)
					unit_btn.modulate = Color(1, 1, 1)
			)
	
	layout.add_child(HSeparator.new())
	
	var btn_confirm = Button.new()
	btn_confirm.text = "ПІДТВЕРДИТИ ВИБІР"
	btn_confirm.custom_minimum_size.y = 50
	btn_confirm.add_theme_font_size_override("font_size", 24)
	layout.add_child(btn_confirm)
	
	btn_confirm.pressed.connect(func():
		var final_captured = []
		for idx in captured_indices.keys():
			final_captured.append(units_data[idx])
		
		print("ГРАВЕЦЬ ЗАХОПИВ: ", final_captured.size(), " юнітів")
		# Тут можна додати логіку збереження в інвентар/ростер
		get_tree().reload_current_scene()
	)
func show_result(is_victory: bool, captured_count: int):
	var dialog = AcceptDialog.new()
	dialog.title = "Кінець бою"
	
	if is_victory:
		var text = "ПЕРЕМОГА!\n\n"
		if captured_count > 0:
			text += "Ваш загін здобув тріумф. Ви захопили " + str(captured_count) + " ворогів у полон!"
		else:
			text += "Ваш загін здобув тріумф, але ворог втік без полонених."
		dialog.dialog_text = text
	else:
		dialog.dialog_text = "ПОРАЗКА...\n\nВаші сили вичерпано. Загін змушений відступити."
	
	add_child(dialog)
	dialog.popup_centered(Vector2i(400, 200))
	
	# Після закриття вікна можна, наприклад, повернутися в меню або перезапустити сцену
	dialog.confirmed.connect(func(): get_tree().reload_current_scene())

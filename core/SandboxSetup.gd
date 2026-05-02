extends Control

const BATTLE_SCENE_PATH = "res://core/Main.tscn" # Перевір свій шлях!

const UNITS_DIR = "res://entities/units/"
var available_units: Array[PackedScene] = []

var selected_player: Array[PackedScene] = []
var selected_enemy: Array[PackedScene] = []

@onready var lbl_player_team = Label.new()
@onready var lbl_enemy_team = Label.new()

func _ready():
	# === Автоматичне завантаження сцен із папки ===
	var dir = DirAccess.open(UNITS_DIR)
	if dir:
		for file in dir.get_files():
			var clean_name = file.replace(".remap", "")
			
			# ДОДАНО: Пропускаємо базову сцену
			if clean_name == "BaseUnit.tscn":
				continue
				
			if clean_name.ends_with(".tscn"):
				var scene = load(UNITS_DIR + clean_name) as PackedScene
				if scene:
					available_units.append(scene)
	else:
		push_error("Не вдалося відкрити папку з юнітами: " + UNITS_DIR)
	# ======================================================

	# 1. Фон
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. Відступи
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)

	# 3. Заголовок
	var title = Label.new()
	title.text = "НАЛАШТУВАННЯ ПІСОЧНИЦІ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	main_vbox.add_child(title)

	# 4. Панель статусу команд
	var status_hbox = HBoxContainer.new()
	status_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_hbox.add_theme_constant_override("separation", 50)
	main_vbox.add_child(status_hbox)

	lbl_player_team.text = "Команда гравця: 0"
	lbl_player_team.add_theme_font_size_override("font_size", 24)
	lbl_player_team.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	status_hbox.add_child(lbl_player_team)

	lbl_enemy_team.text = "Команда ворога: 0"
	lbl_enemy_team.add_theme_font_size_override("font_size", 24)
	lbl_enemy_team.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	status_hbox.add_child(lbl_enemy_team)

	# 5. Скрол і сітка юнітів (твій HFlowContainer)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var list = HFlowContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.alignment = FlowContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("h_separation", 20)
	list.add_theme_constant_override("v_separation", 20)
	scroll.add_child(list)

	# 6. Генеруємо картки доступних юнітів
	for scene in available_units:
		var card = _create_unit_card(scene)
		list.add_child(card)

	# 7. Кнопка старту
	var btn_start = Button.new()
	btn_start.text = "ПОЧАТИ БІЙ"
	btn_start.custom_minimum_size.y = 60
	btn_start.add_theme_font_size_override("font_size", 28)
	btn_start.pressed.connect(_on_start_pressed)
	main_vbox.add_child(btn_start)

# Функція генерації візуальної картки з двома кнопками
func _create_unit_card(scene: PackedScene) -> Control:
	# Тимчасово створюємо юніта, щоб "прочитати" його ім'я та портрет
	var temp_instance = scene.instantiate()
	var u_name = temp_instance.unit_name if "unit_name" in temp_instance else temp_instance.name
	var u_icon = temp_instance.portrait if "portrait" in temp_instance else null
	temp_instance.queue_free() # Одразу видаляємо

	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var icon = TextureRect.new()
	icon.texture = u_icon
	icon.custom_minimum_size = Vector2(120, 120)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon)

	var name_lbl = Label.new()
	name_lbl.text = u_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_lbl)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var btn_add_player = Button.new()
	btn_add_player.text = "+ Гравець"
	btn_add_player.modulate = Color(0.6, 1.0, 0.6)
	btn_add_player.pressed.connect(func():
		selected_player.append(scene)
		_update_status()
	)
	btn_hbox.add_child(btn_add_player)

	var btn_add_enemy = Button.new()
	btn_add_enemy.text = "+ Ворог"
	btn_add_enemy.modulate = Color(1.0, 0.6, 0.6)
	btn_add_enemy.pressed.connect(func():
		selected_enemy.append(scene)
		_update_status()
	)
	btn_hbox.add_child(btn_add_enemy)

	return panel

func _update_status():
	lbl_player_team.text = "Команда гравця: " + str(selected_player.size())
	lbl_enemy_team.text = "Команда ворога: " + str(selected_enemy.size())

func _on_start_pressed():
	if selected_player.is_empty() or selected_enemy.is_empty():
		print("Додайте хоча б по одному юніту кожній команді!")
		return
		
	# Записуємо вибір у Синглтон і стартуємо
	GameManager.player_roster = selected_player
	GameManager.enemy_roster = selected_enemy
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
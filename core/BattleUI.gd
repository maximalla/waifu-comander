class_name BattleUI
extends CanvasLayer

signal skill_selected(skill: Skill)
signal end_turn_pressed

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

# ЦЮ ЗМІННУ ЧИТАТИМЕ MAIN.GD
var is_mobile := false

func _ready():

	btn_end_turn.pressed.connect(func(): end_turn_pressed.emit())
	
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
	# Видалити старі кнопки, крім BtnEndTurn
	for child in hbox.get_children():
		if child != btn_end_turn:
			child.queue_free()
	
	# Створити нові кнопки для скілів
	for skill in skills:
		var btn = Button.new()
		btn.text = skill.skill_name
		if skill.current_cooldown > 0:
			btn.disabled = true
			btn.text += " (" + str(skill.current_cooldown) + ")"
		else:
			btn.disabled = false
		
		btn.pressed.connect(func(): skill_selected.emit(skill))
		hbox.add_child(btn)
		hbox.move_child(btn, hbox.get_child_count() - 2)  # Перед BtnEndTurn


func release_focuses():
	# btn_attack.release_focus()
	btn_end_turn.release_focus()

# ==========================================
# МОБІЛЬНА ЛОГІКА (Target Panel)
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

# ==========================================
# ПК ЛОГІКА (Hover Label)
# ==========================================
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
	if hover_label:
		hover_label.visible = false

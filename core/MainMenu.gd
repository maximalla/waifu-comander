extends Control

# ПЕРЕВІР ШЛЯХ! Він має точно збігатися з тим, де лежить твій Main.tscn
const BATTLE_SCENE_PATH = "res://core/Main.tscn"

func _ready():
	# Підключаємо кнопки
	$VBoxContainer/BtnPlay.pressed.connect(_on_play_pressed)
	$VBoxContainer/BtnSandbox.pressed.connect(_on_sandbox_pressed)
	$VBoxContainer/BtnExit.pressed.connect(_on_exit_pressed)

func _on_play_pressed():
	# Звичайний режим
	GameManager.is_sandbox_mode = false
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _on_sandbox_pressed():
	GameManager.is_sandbox_mode = true
	# ВЕДЕМО НА ЕКРАН НАЛАШТУВАННЯ
	get_tree().change_scene_to_file("res://core/SandboxSetup.tscn") # Перевір шлях!
func _on_exit_pressed():
	# Вихід з гри (працює на ПК та Android)
	get_tree().quit()
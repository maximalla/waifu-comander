extends Node2D

# Швидкість польоту (пікселів на секунду)
@export var speed := 1000.0

var target: Node2D = null
var is_crit := false
var damage := 0
var distance_threshold := 5.0 # Відстань, яку вважаємо влучанням

# Сигнал, який випускаємо, коли долетіли (щоб Main знав, коли малювати цифри шкоди)
signal hit_target(target_node, dmg_amount, crit_flag)

# Функція ініціалізації снаряда
func setup(start_pos: Vector2, target_node: Node2D, dmg: int, crit: bool):
	global_position = start_pos
	target = target_node
	damage = dmg
	is_crit = crit
	
	# Розвертаємо снаряд "обличчям" до цілі
	look_at(target.global_position)

func _process(delta: float):
	if not is_instance_valid(target):
		# Якщо ціль раптово зникла (вбили іншим скілом), видаляємо снаряд
		queue_free()
		return
		
	# Вираховуємо вектор руху до цілі
	var direction = (target.global_position - global_position).normalized()
	
	# Рухаємо снаряд
	global_position += direction * speed * delta
	
	# Перевіряємо, чи ми вже долетіли (якщо відстань менша за поріг)
	if global_position.distance_to(target.global_position) < distance_threshold:
		_on_hit()

func _on_hit():
	# Випускаємо сигнал, щоб світ дізнався про влучання
	hit_target.emit(target, damage, is_crit)
	
	# Наносимо шкоду цілі безпосередньо (анімація шкоди буде в Main)
	# (Ми використовуємо take_damage з BaseUnit, яку ми вже написали)
	target.take_damage(damage, is_crit)
	
	# Видаляємо снаряд зі сцени
	queue_free()

extends Area2D

@export var damage_per_second: float = 2.0  # Daño por segundo
@export var interval: float = 0.5            # Cada cuánto se aplica el daño

var players_in_area: Array = []  # Lista de jugadores dentro

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Timer interno para aplicar daño
	var timer = Timer.new()
	timer.wait_time = interval
	timer.autostart = true
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_apply_damage)
	

func _on_body_entered(body):
	if body.name == "Rey":  # Cambia si tu jugador tiene otro nombre
		players_in_area.append(body)
		print("Jugador entró a los pinchos")

func _on_body_exited(body):
	if body in players_in_area:
		players_in_area.erase(body)
		

func _apply_damage():
	for player in players_in_area:
		if player and player.has_method("recibir_dano"):
			player.recibir_dano(damage_per_second)

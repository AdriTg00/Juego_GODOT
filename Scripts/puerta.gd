extends AnimatedSprite2D

func _ready():
	# Abre la puerta al iniciar
	play("open")
	
	# Espera a que termine la animación de abrir (opcional, pero recomendado)
	await animation_finished
	
	# Espera 2 segundos
	await get_tree().create_timer(1.5).timeout
	
	# Cierra la puerta
	play("close")

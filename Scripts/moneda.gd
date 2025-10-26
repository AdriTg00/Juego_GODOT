extends Area2D

# --- Variables ---
@export var valor: int = 1  # valor o puntuación que da la moneda
@onready var anim = $AnimatedSprite2D

# --- Inicialización ---
func _ready():
	anim.play("idle")  # o el nombre de tu animación
	body_entered.connect(_on_body_entered)

# --- Detección del jugador ---
func _on_body_entered(body):
	if body.name == "Rey": 
		body.agregar_moneda(valor)  
		queue_free()  

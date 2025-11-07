extends CharacterBody2D

# --- Nodos ---
@onready var anim = $AnimatedSprite2D
@onready var detector_area = $Area2D
@onready var detector_salto = $detector_salto
@onready var gruñido = $"gruñido_cerdo"


# --- Parámetros exportados ---
@export var margen_colision: float = 20.0
@export var velocidad: float = 50.0
@export var gravedad: float = 1200.0
@export var max_caida: float = 1000.0
@export var rango_persecucion: float = 250.0
@export var tiempo_idle_colision: float = 1.0 

# --- Estados ---
var jugador: CharacterBody2D = null
var muerto := false
var recibiendo_daño := false
var direccion := 1
var en_persecucion := false
var patrullando := false
var cancelando_patruya := false
var en_pausa_colision := false  
var invulnerable := false
var vida = 5

# --- Constantes ---
const IMPULSO_SALTO = -400.0


func _ready():
	detector_area.body_entered.connect(_on_jugador_entro)
	detector_area.body_exited.connect(_on_jugador_salio)
	_iniciar_patruya()


func _physics_process(delta):
	if muerto:
		return
	_aplicar_gravedad(delta)
	if en_persecucion and jugador and not en_pausa_colision and not recibiendo_daño:
		_perseguir_jugador()
	else:
		if not patrullando and not recibiendo_daño and not en_pausa_colision and not en_persecucion:
			_iniciar_patruya()
		
			
	
	move_and_slide()


# --- GRAVEDAD ---
func _aplicar_gravedad(delta):
	# Aumenta la velocidad Y sólo si no está en el suelo
	if not is_on_floor():
		velocity.y += gravedad * delta
		velocity.y = min(velocity.y, max_caida)
	else:
		velocity.y = 0


# --- PERSEGUIR AL JUGADOR ---
func _perseguir_jugador():
	var dist = global_position.distance_to(jugador.global_position)
	# Si el jugador sale del rango
	if dist > rango_persecucion:
		en_persecucion = false
		_iniciar_patruya()
		return

	# Dirección hacia el jugador
	var dir = sign(jugador.global_position.x - global_position.x)
	velocity.x = dir * velocidad
	anim.flip_h = dir > 0
	anim.play("run")

	# Si ya está tocando al jugador
	if _colisiona_con_jugador():
		if recibiendo_daño:
			return
		if jugador and jugador.has_method("recibir_dano"):
			jugador.recibir_dano(1)
		await _pausa_idle_colision()


# --- FUNCIÓN NUEVA ---
func _colisiona_con_jugador() -> bool:
	if jugador:
		var dx = abs(global_position.x - jugador.global_position.x)
		var dy = abs(global_position.y - jugador.global_position.y)
		return dx < margen_colision and dy < margen_colision 
	return false



# --- SE DETIENE AL CHOCAR ---
func _pausa_idle_colision():
	if recibiendo_daño:
		return
	en_pausa_colision = true
	velocity.x = 0
	await get_tree().create_timer(tiempo_idle_colision).timeout
	en_pausa_colision = false


# --- PATRULLA (igual que antes, reducida) ---
func _iniciar_patruya():
	gruñido.stop()
	patrullando = true
	_patrol_loop()

func recibir_dano(cantidad: int = 1):
	
	en_persecucion = false
	patrullando = false
	if muerto or invulnerable:
		return
	vida -= cantidad
	print("El cerdo recibió daño. Vida restante:", vida)
	
	if vida <= 0:
		_morir()
		return
	recibiendo_daño = true
	invulnerable = true	

	
	# --- Animación y retroceso ---
	anim.play("hit")
	
	var dir_retroceso = sign(global_position.x - jugador.global_position.x)
	velocity.x = dir_retroceso * 50         
	# --- Aplica la física normal una sola vez ---
	move_and_slide()
	await anim.animation_finished
	
	
	recibiendo_daño = false
	invulnerable = false
	
	en_persecucion = true
	
	


func _patrol_loop():
	await get_tree().process_frame
	while not muerto and not en_persecucion:
		anim.play("run")
		velocity.x = direccion * velocidad
		anim.flip_h = direccion > 0
		await get_tree().create_timer(1.0).timeout
		anim.play("idle")
		velocity.x = 0
		await get_tree().create_timer(2.0).timeout
		direccion *= -1
	patrullando = false
	
	

func _morir():
	muerto = true
	en_persecucion = false
	patrullando = false
	var hud = get_tree().root.get_node("Juego/CanvasLayer")
	hud.añadir_moneda(3)
	print("El cerdo ha muerto")
	# Detiene cualquier movimiento o ataque
	velocity = Vector2.ZERO
	# Desactiva las colisiones (para no seguir detectando al jugador)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Reproduce la animación de muerte
	anim.play("dead")
	# Espera a que termine la animación antes de eliminar el nodo
	await anim.animation_finished
	# Elimina el cerdo de la escena
	queue_free()



# --- DETECCIÓN ---
func _on_jugador_entro(cuerpo):
	if cuerpo.name == "Rey":
		gruñido.play()
		jugador = cuerpo
		en_persecucion = true
		print("Jugador detectado:", jugador.name)
	


func _on_jugador_salio(cuerpo):
	if cuerpo == jugador:
		jugador = null
		en_persecucion = false
		print("Jugador fuera de rango, vuelve a patrullar")

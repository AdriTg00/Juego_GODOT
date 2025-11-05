extends CharacterBody2D

#Exportaciones de nodos
@onready var anim = $AnimatedSprite2D
@onready var area_ataque = $Area2D
@onready var vida_ui = get_tree().root.get_node("Juego/CanvasLayer") 
@onready var hit = $sonidoHit
@onready var hachazo = $golpe
@onready var saltar = $saltar
@onready var morir = $morir
@onready var musica = $musicaFondo
@onready var recoger_moneda = $recolectar_moneda

# --- CONSTANTES ---
@export var gravedad: float = 1200.0
@export var max_caida: float = 1000.0


const VELOCIDAD = 150.0
const IMPULSO_SALTO = -400.0
const GRAVEDAD_SUBIDA = 1200.0
const GRAVEDAD_BAJADA = 2000.0
const MULTIPLICADOR_SALTO_CORTO = 0.6
const MAX_VELOCIDAD_CAIDA = 1200.0
const IMPULSO_RETROCESO = 100.0
const IMPULSO_RETROCESO_DAÑO = 100.0
const COOLDOWN_ATAQUE = 0.2

var vida = 5
var invulnerable = false
var monedas = 0

var recibiendo_daño := false;

# ---  PARA SABER SI ESTA MUERTO
var muerto = false
# --- BLOQUEO DE ANIMACIÓN DE PUERTA ---
var en_secuencia_puerta = false
# --- ESTADOS ---
var puede_atacar = true
var atacando = false
# --- ATERIZAJE ---
var estaba_en_el_aire = false
var aterrizo_recientemente = false

# --- INPUTS ---
var direccion_movimiento = 0


func _physics_process(delta):
	if muerto:
		return
	if en_secuencia_puerta:
		move_and_slide()
		return  # Sale inmediatamente, sin procesar nada más
	_aplicar_gravedad(delta)
	# --- Detección de aterrizaje ---
	_detectar_aterrizaje()
	
	# --- Movimiento lateral (solo si no está atacando) ---
	if not atacando:
		direccion_movimiento = Input.get_axis("move_left", "move_right")
		_aplicar_movimiento_horizontal()
	# --- Salto (solo si no está atacando) ---
# Al pulsar salto
	if Input.is_action_just_pressed("jump") and is_on_floor() and not atacando and not aterrizo_recientemente:
		saltar.play()
		velocity.y = IMPULSO_SALTO
		anim.play("jump")

# Si sueltas el botón antes de llegar al pico del salto
	if Input.is_action_just_released("jump") and velocity.y < 0 and not aterrizo_recientemente:
		velocity.y *= 0.5  # reduce la altura si suelta antes

	
	# --- Ataque ---
	if Input.is_action_just_pressed("ui_accept") and puede_atacar and not muerto:
		_atacar()
	# --- Animaciones automáticas ---
	_actualizar_animacion()
	move_and_slide()
	# --- Actualizar posición del área de ataque según la dirección ---
	area_ataque.position.x = -21 if anim.flip_h else 21

# --- FUNCIONES DE AYUDA ---
func _aplicar_gravedad(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
		velocity.y = min(velocity.y, max_caida)
	else:
		velocity.y = 0


func _detectar_aterrizaje():
	if not is_on_floor():
		estaba_en_el_aire = true
	else:
		if estaba_en_el_aire and not aterrizo_recientemente and not atacando:
			_reproducir_aterrizaje()
		estaba_en_el_aire = false

func _aplicar_movimiento_horizontal():
	if direccion_movimiento != 0:
		velocity.x = direccion_movimiento * VELOCIDAD
		anim.flip_h = direccion_movimiento < 0
	else:
		velocity.x = move_toward(velocity.x, 0, VELOCIDAD * 3 * get_physics_process_delta_time())

func _actualizar_animacion():
	if atacando or aterrizo_recientemente:
		return

	if not is_on_floor():
		anim.play("jump" if velocity.y < 0 else "fall")
	elif direccion_movimiento != 0:
		anim.play("run")
	else:
		anim.play("idle")

func agregar_moneda(cantidad: int):
	var hud = get_tree().root.get_node("Juego/CanvasLayer")
	hud.añadir_moneda(1)
	recoger_moneda.play()
	monedas += cantidad
	print("Monedas:", monedas)


func recibir_dano(cantidad: int = 1):
	
	if muerto or invulnerable:
		return
		# --- Bloqueo temporal ---
	recibiendo_daño = true
	invulnerable = true
	atacando = true
	
	anim.play("hit")

	# --- Resta vida ---
	vida -= cantidad
	print("El rey recibió daño. Vida restante:", vida)

	# --- Actualiza HUD (no bloqueante) ---
	var vida_ui = get_tree().root.get_node("Juego/CanvasLayer") 
	if vida_ui and vida_ui.has_method("actualizar_vida"):
		vida_ui.call_deferred("actualizar_vida", vida)

	# --- Si muere ---
	if vida <= 0:
		_morir()
		return


	
	hit.play()
# --- Retroceso estilo pixel platformer ---
	var dir = 1 if anim.flip_h else -1
	velocity = Vector2(dir * IMPULSO_RETROCESO_DAÑO, -100) # un pequeño salto atrás

# Mantiene el impulso por unos frames mientras la gravedad actúa
	for i in range(10):  # ~0.16s
		move_and_slide()
		await get_tree().process_frame

	velocity = Vector2.ZERO

	# --- Esperamos fin de animación de golpe ---
	await anim.animation_finished
	
	atacando = false
	invulnerable = false
	recibiendo_daño = false

	# --- Cooldown de invulnerabilidad ---
	await get_tree().create_timer(1.0).timeout

func _morir():
	musica.stop()
	morir.play()
	muerto = true
	anim.play("dead")
	velocity.x = 0
	print("El rey ha muerto")
# --- ATAQUE ---

func _atacar():
	if recibiendo_daño:
		return
	atacando = true
	puede_atacar = false
	anim.play("attack")
	hachazo.play()
	velocity = Vector2.ZERO
	# Activar área de ataque temporalmente
	area_ataque.set_deferred("monitoring", true)
	area_ataque.set_deferred("monitorable", true)
	# Esperar un poco para que las colisiones se registren
	await get_tree().create_timer(0.1).timeout
	# Obtener cuerpos que están dentro del área
	var cuerpos = area_ataque.get_overlapping_bodies()

	if cuerpos.size() > 0:
		var golpeo_enemigo = false
		for cuerpo in cuerpos:
			if cuerpo != self and cuerpo.has_method("recibir_dano"):
				cuerpo.recibir_dano(1)
				print("Golpeó a enemigo:", cuerpo.name)
				_aplicar_retroceso()
				golpeo_enemigo = true
				break

		# Si no golpeó a ningún enemigo, aplicar retroceso si hay colisión
		if not golpeo_enemigo:
			print("Golpeó contra pared u obstáculo")
			_aplicar_retroceso()

	# Desactivar área de ataque
	area_ataque.monitoring = false
	area_ataque.monitorable = false

	await anim.animation_finished
	atacando = false

	await get_tree().create_timer(COOLDOWN_ATAQUE).timeout
	puede_atacar = true

# --- ANIMACIÓN DE ATERIZAJE ---
func _reproducir_aterrizaje():
		aterrizo_recientemente = true
		anim.play("ground")
		await anim.animation_finished
		aterrizo_recientemente = false

# --- RETROCESO ---
func _aplicar_retroceso():
	var direccion = -1 if anim.flip_h else 1
	velocity.x = direccion * -IMPULSO_RETROCESO

func _ready():
	musica.play()
	# Iniciar la secuencia de puerta al comienzo
	en_secuencia_puerta = true
	anim.play("door_out")
	await anim.animation_finished
	# Termina la secuencia → permite movimiento normal
	en_secuencia_puerta = false

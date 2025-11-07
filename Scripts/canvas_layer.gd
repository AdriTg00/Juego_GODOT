extends CanvasLayer

# --- CONFIGURACIÓN DEL HUD ---
@onready var score_label = $ScoreLabel
@onready var timerLabel = $timerLabel
@export var hud_offset := Vector2(-500, -250)  # Desplazamiento del HUD en pantalla
@export var suavizado := true
@export var velocidad_suavizado := 5.0

@onready var resume_button = $VBoxContainer/reanudar
@onready var save_button = $VBoxContainer/guardar
@onready var exit_button = $VBoxContainer/salir
# --- SISTEMA DE VIDA ---
@export var max_vida := 5
var vida_actual := max_vida
var corazones := []
var score: int = 0
var elapsed_time: float = 0.0
var running: bool = false
# --- VARIABLES INTERNAS ---
var camara_actual: Camera2D = null


func _ready():
	
	#Empieza el tiempo
	start_timer()
	#Se empieza con 0 puntos
	score_label.text = "Score: " + str(score)  # Muestra "0" al inicio
	# 🔹 Inicializa corazones
	for nodo in get_children():
		if nodo is AnimatedSprite2D:
			corazones.append(nodo)
			nodo.play("idle")
	corazones.sort_custom(func(a, b): return a.name < b.name)

	# 🔹 Detecta cámara activa automáticamente
	_actualizar_camara()
	get_tree().connect("node_added", Callable(self, "_on_node_added"))


func start_timer():
	elapsed_time = 0.0
	running = true
	
func stop_timer():
	running = false

func update_timer_label():
	var minutes = int(elapsed_time / 60)
	var seconds = int(elapsed_time) % 60
	timerLabel.text = "%02d:%02d" % [minutes, seconds]
	
func get_elapsed_ms() -> int:
	return int(round(elapsed_time * 1000.0))  # INTEGER en SQLite

func get_elapsed_text() -> String:
	var minutes = int(elapsed_time / 60)
	var seconds = int(elapsed_time) % 60
	return "%02d:%02d" % [minutes, seconds]
	
func añadir_moneda(amount: int):
	score += amount
	score_label.text = "Score: " +str(score)
	
	
func _process(delta : float):
	if running:
		
		elapsed_time += delta
		update_timer_label()
		
	if not camara_actual:
		_actualizar_camara()
		return
	
	
	var destino = camara_actual.get_screen_center_position() + hud_offset
	if suavizado:
		transform.origin = transform.origin.lerp(destino, delta * velocidad_suavizado)
	else:
		transform.origin = destino


# ---LÓGICA DE VIDA ---
func actualizar_vida(nueva_vida: int):
	# Si perdió vida
	if nueva_vida < vida_actual:
		for i in range(vida_actual - 1, nueva_vida - 1, -1):
			if i >= 0 and i < corazones.size():
				await _romper_corazon(corazones[i])
	# Si ganó vida
	elif nueva_vida > vida_actual:
		for i in range(vida_actual, nueva_vida):
			if i < corazones.size():
				corazones[i].visible = true
				corazones[i].play("idle")

	vida_actual = clamp(nueva_vida, 0, max_vida)


func _romper_corazon(corazon: AnimatedSprite2D):
	if not corazon.visible:
		return
	corazon.play("hit")
	await corazon.animation_finished
	corazon.visible = false


# --- DETECTA NUEVAS CÁMARAS ---
func _on_node_added(nodo):
	if nodo is Camera2D and nodo.is_current():
		camara_actual = nodo


# --- FUNCIÓN DE APOYO ---
func _actualizar_camara():
	var camaras = get_tree().get_nodes_in_group("camaras")
	if camaras.size() > 0:
		for c in camaras:
			if c.is_current():
				camara_actual = c
				return
	
	# Si no hay grupo "camaras", buscar cualquier Camera2D activa
	for nodo in get_tree().get_nodes_in_group(""):
		if nodo is Camera2D and nodo.is_current():
			camara_actual = nodo
			return

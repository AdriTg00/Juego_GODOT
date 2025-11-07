extends CanvasLayer

@onready var color_rect := $ColorRect
@onready var vbox := $VBoxContainer
@onready var btn_reanudar := $VBoxContainer/reanudar
@onready var btn_salir := $VBoxContainer/salir

func _ready():
	# Ocultamos el menú al inicio
	color_rect.visible = false
	vbox.visible = false

	# Conectamos los botones
	btn_reanudar.pressed.connect(_on_reanudar_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

func _unhandled_input(event):
	if event.is_action_pressed("pausa"):
		_toggle_pause()

func _toggle_pause():
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused

	color_rect.visible = is_paused
	vbox.visible = is_paused

	if is_paused:
		btn_reanudar.grab_focus()  # opcional: enfocar botón al pausar

func _on_reanudar_pressed():
	get_tree().paused = false
	color_rect.visible = false
	vbox.visible = false

func _on_salir_pressed():
	get_tree().quit()

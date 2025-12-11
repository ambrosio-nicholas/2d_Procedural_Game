extends CharacterBody2D

var SPEED = 30.0

var maxZoom = 2
var minZoom = 0.01
var currentZoom = 0.2
@onready var camera: Camera2D = get_node("Camera2D")

func _physics_process(delta: float) -> void:
	getMovement()
	getCameraZoom()

func getMovement() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		SPEED = 30
	else:
		SPEED = 15
	
	if Input.is_key_pressed(KEY_S):
		position.y += SPEED
	if Input.is_key_pressed(KEY_W):
		position.y -= SPEED
	if Input.is_key_pressed(KEY_D):
		position.x += SPEED
	if Input.is_key_pressed(KEY_A):
		position.x -= SPEED

func getCameraZoom() -> void:
	var zoom = camera.zoom.x   # uniform zoom assumed
	# Zoom in
	if Input.is_key_pressed(KEY_EQUAL):
		zoom *= 1.05
	# Zoom out
	if Input.is_key_pressed(KEY_MINUS):
		zoom /= 1.05
	zoom = clamp(zoom, minZoom, maxZoom)
	camera.zoom = Vector2(zoom, zoom)

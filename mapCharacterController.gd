extends CharacterBody2D

var SPEED = 32.0

var maxZoom = 2
var minZoom = 0.01
var currentZoom = 0.2
@onready var camera : Camera2D = get_node("Camera2D")

# world generator script
@onready var worldGenerator : TileMapLayer = get_node("../TileMapLayer")
@onready var mapSizeX = worldGenerator.mapSizeX
@onready var mapSizeY = worldGenerator.mapSizeY

func _ready() -> void:
	position = Vector2i((mapSizeX * 32) / 2, (mapSizeY * 32) / 2)

func _physics_process(delta: float) -> void:
	getMovement()
	getCameraZoom()

func getMovement() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		SPEED = 128
	else:
		SPEED = 32
	# Fine movement with arrow keys
	if Input.is_action_just_pressed("ui_down"):
		position.y = clamp(position.y + SPEED, 0, (mapSizeY * 32) - 32)
	if Input.is_action_just_pressed("ui_up"):
		position.y = clamp(position.y - SPEED, 0, (mapSizeY * 32) - 32)
	if Input.is_action_just_pressed("ui_right"):
		position.x = clamp(position.x + SPEED, 0, (mapSizeX * 32) - 32)
	if Input.is_action_just_pressed("ui_left"):
		position.x = clamp(position.x - SPEED, 0, (mapSizeX * 32) - 32)
		
	# Quick movement with WASD
	if Input.is_key_pressed(KEY_S):
		position.y = clamp(position.y + SPEED, 0, (mapSizeY * 32) - 32)
	if Input.is_key_pressed(KEY_W):
		position.y = clamp(position.y - SPEED, 0, (mapSizeY * 32) - 32)
	if Input.is_key_pressed(KEY_D):
		position.x = clamp(position.x + SPEED, 0, (mapSizeX * 32) - 32)
	if Input.is_key_pressed(KEY_A):
		position.x = clamp(position.x - SPEED, 0, (mapSizeX * 32) - 32)

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

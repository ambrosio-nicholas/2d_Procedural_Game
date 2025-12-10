extends CharacterBody2D

const SPEED = 30.0

func _physics_process(delta: float) -> void:
	if Input.is_key_pressed(KEY_S):
		position.y += SPEED
	if Input.is_key_pressed(KEY_W):
		position.y -= SPEED
	if Input.is_key_pressed(KEY_D):
		position.x += SPEED
	if Input.is_key_pressed(KEY_A):
		position.x -= SPEED

extends CharacterBody2D

func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move-left", "move-right", "move-up", "move-down")
	global_position += delta * 900.0 * input_vector
	move_and_slide()
	CircleShape2D.new()

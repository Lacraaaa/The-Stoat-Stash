extends CharacterBody2D


const SPEED = 300.0

func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector("left","right","up","down")
	
	velocity = input_direction * SPEED
	
	move_and_slide()

extends Node3D

@onready var ballmarker = preload("res://Tests/BallMarker.tscn")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("left_click"):
		var ball = ballmarker.instantiate()
		add_child(ball)
		ball.global_position = StoatStash.get_mouse_world_position_3d_collision($Camera3D)

func _on_button_pressed() -> void:
	StoatStash.shake_heavy_3d($Camera3D,0.4)


func _on_button_2_pressed() -> void:
	StoatStash.change_scene_with_simple_transition("res://Tests/tests2d.tscn")

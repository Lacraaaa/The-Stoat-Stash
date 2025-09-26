extends Node2D

enum CharacterEdgeHandler {WRAP, CLAMP, NONE}

var currentEdge: CharacterEdgeHandler = CharacterEdgeHandler.WRAP

var trackNum = false

func _ready() -> void:
	StoatStash.typewriter_text($Label, "Try the combo up down left right left right", 0.1)
	StoatStash.animate_ui_slide_in($ShakeScreen, Vector2.DOWN)
	if(!StoatStash.is_music_playing()):
		StoatStash.play_music(preload("res://Tests/mainMenu.wav"))

func _process(delta: float) -> void:
	if currentEdge == CharacterEdgeHandler.WRAP:
		StoatStash.wrap_node_to_screen($CharacterBody2D, $Camera2D, 64)
	if currentEdge == CharacterEdgeHandler.CLAMP:
		StoatStash.clamp_node_to_screen($CharacterBody2D, $Camera2D, 64) ## godot icon is 128x128
	
	if StoatStash.is_input_sequence_just_pressed(["up","down","left","right","left","right"],1.0):
		StoatStash.pulse_node($CharacterBody2D,1.8, 0.5)
		StoatStash.play_sfx(preload("res://Tests/death.wav"),0.5)


func _on_shake_screen_pressed() -> void:
	StoatStash.shake_light($Camera2D,2.2)


func _on_wrap_toggled(toggled_on: bool) -> void:
	if toggled_on: currentEdge = CharacterEdgeHandler.WRAP


func _on_clamp_toggled(toggled_on: bool) -> void:
	if toggled_on: currentEdge = CharacterEdgeHandler.CLAMP


func _on_none_toggled(toggled_on: bool) -> void:
	if toggled_on: currentEdge = CharacterEdgeHandler.NONE


func _on_music_volume_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		StoatStash.set_music_volume($MusicVolumeSlider.value/100)
		StoatStash.mute_music($MusicVolumeSlider.value == 0)


func _on_next_track_pressed() -> void:
	trackNum = !trackNum
	if not trackNum:
		StoatStash.crossfade_music(preload("res://Tests/mainMenu.wav"))
	else:
		StoatStash.crossfade_music(preload("res://Tests/obliterated.wav"))


func _on_transition_to_3d_pressed() -> void:
	StoatStash.change_scene_with_simple_transition("res://Tests/tests3d.tscn")


func _on_button_pressed() -> void:
	StoatStash.flash_screen(Color.WHITE, 0.3)

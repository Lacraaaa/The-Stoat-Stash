# The Stoat Stash
An unopinionated single file utility library for Godot 4, meant for quick prototyping and game jams.

## Install
1. Download stoat_stash.gd
2. Add to godot project
3. Add file as autoload script

## Quick Start
```gdscript
# Camera Shake
StoatStash.shake_light($Camera2D)

# Play sound effect
StoatStash.play_sfx(explosion_sound, 0.8)

# buffered input (great for platformers)
if StoatStash.is_action_just_pressed_buffered("jump", 0.15):
	player.jump()

# Scene transition with fade
StoatStash.change_scene_with_simple_transition("res://next_level.tscn")
```

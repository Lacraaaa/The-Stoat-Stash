"""
MIT License

Copyright (c) 2025 Thomas Bestvina

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

extends Node

##################################################################################
################################## MATH UTILS ####################################
##################################################################################
func remap_value(value: float, from_min: float, from_max: float, to_min: float, to_max: float) -> float:
	"""Remaps a value from one range to another"""
	if from_max == from_min:
		push_warning("remap value: from_min and from_max are equal")
		return to_min
	return to_min + (value - from_min) * (to_max - to_min) / (from_max - from_min)

func chance(probability: float) -> bool:
	"""Returns true with given probablity (0.0 to 1.0)"""
	return randf() < clamp(probability, 0.0, 1.0)

func weighted_random(weights: Array) -> int:
	"""Returns a random index based on weights array, or -1 if invalid"""
	if weights.is_empty():
		push_warning("weighted_random: weight array is empty")
		return -1
	
	var valid_weights = []
	var valid_indices = []
	var total = 0.0
	
	# Filter out invalid weights and track valid indices
	for i in range(weights.size()):
		var weight = weights[i]
		if typeof(weight) in [TYPE_FLOAT, TYPE_INT]:
			if weight > 0:
				valid_weights.append(weight)
				valid_indices.append(i)
				total += weight
			elif weight < 0:
				push_warning("weighted_random: negative weight found at index " + str(i))
		else:
			push_warning("weighted_random: non-numeric weight found at index " + str(i))
	
	if valid_weights.is_empty():
		push_warning("weighted_random: no valid positive weights found")
		return -1
	
	if total <= 0.0:
		push_warning("weighted_random: total weight is zero or negative")
		return -1
	
	var r = randf() * total
	var cumulative = 0.0
	
	for i in range(valid_weights.size()):
		cumulative += valid_weights[i]
		if r <= cumulative:
			return valid_indices[i]
	
	return valid_indices[0] if valid_indices.size() > 0 else -1

func random_point_in_circle(radius: float) -> Vector2:
	"""Returns random point within a circle"""
	var angle = randf() * TAU
	var r = sqrt(randf()) * radius
	return Vector2(cos(angle) * r, sin(angle) * r)

func random_point_on_circle_perimeter(radius: float) -> Vector2:
	"""Returns random point on perimeter of circle"""
	var angle = randf() * TAU
	return Vector2(cos(angle) * radius, sin(angle) * radius)

func wrap_angle(angle: float) -> float:
	"""Wraps angle to 0 to TAU (2*PI) range"""
	var result = fmod(angle, TAU)
	if result < 0.0:
		result += TAU
	return result

func angle_difference(from: float, to: float) -> float:
	"""Returns shortest signed angular distance from `from` to `to` in range [-PI, PI)"""
	var diff = fmod((to - from) + PI, TAU) - PI
	return diff

func snap_to_grid(pos: Vector2, grid_size: float) -> Vector2:
	"""Returns snapped position on grid"""
	if grid_size <= 0.0:
		push_warning("snap_to_grid: grid_size must be positive")
		return pos
	return Vector2(round(pos.x/grid_size) * grid_size, round(pos.y / grid_size) * grid_size)

func random_color() -> Color:
	"""Returns random color"""
	return Color(randf(), randf(), randf(), 1.0)

func vector_from_angle(angle: float, length: float = 1.0) -> Vector2:
	"""Creates vector from angle and length"""
	return Vector2(cos(angle), sin(angle)) * length

func rotate_around_point(point: Vector2, center: Vector2, angle: float) -> Vector2:
	"""Rotates point around center by angle"""
	var cos_a = cos(angle)
	var sin_a = sin(angle)
	var dx = point.x - center.x
	var dy = point.y - center.y
	return Vector2(
		center.x + dx * cos_a - dy * sin_a,
		center.y + dx * sin_a - dy * cos_a
	)

##################################################################################
################################## CAMERA UTILS ##################################
##################################################################################
var _active_shake_tweens: Array[Tween] = []
var _active_shake_timers: Array[SceneTreeTimer] = []
var _camera_tween_associations: Dictionary = {}

func shake(camera: Camera2D, intensity: float, time: float) -> Tween:
	"""Shakes camera and returns tween for optional control"""
	if not camera or not is_instance_valid(camera):
		push_warning("shake: invalid camera provided")
		return null
	
	if intensity < 0.0 or time < 0.0:
		push_warning("shake: intensity and time must be positive")
		return null
	stop_camera_shake(camera)
	
	var original_offset = camera.offset
	var tween = create_tween()
	tween.set_loops()
	
	# Store reference for cleanup
	_active_shake_tweens.append(tween)
	
	var shake_callable = func():
		if is_instance_valid(camera) and is_instance_valid(tween):
			var random_offset = Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			camera.offset = original_offset + random_offset
	
	tween.tween_callback(shake_callable).set_delay(1/Engine.get_frames_per_second())
	
	# Create cleanup timer
	var cleanup_timer = get_tree().create_timer(time)
	_active_shake_timers.append(cleanup_timer)
	
	_camera_tween_associations[camera] = [tween, original_offset, cleanup_timer]
	
	cleanup_timer.timeout.connect(func():
		# Only clean up if this is still the current association for this camera
		if !_camera_tween_associations.has(camera): 
			return
			
		var current_association = _camera_tween_associations[camera]
		# Verify this timer and tween are still the active ones for this camera
		if current_association[0] != tween || current_association[2] != cleanup_timer:
			return  # A new shake has replaced this one
			
		# Proceed with cleanup
		if is_instance_valid(tween):
			tween.kill()
		if is_instance_valid(camera):
			camera.offset = original_offset
		
		_active_shake_tweens.erase(tween)
		_active_shake_timers.erase(cleanup_timer)
		_camera_tween_associations.erase(camera)
	)
	
	# Clean up if tween is manually killed
	tween.finished.connect(func():
		_active_shake_tweens.erase(tween)
	)
	
	return tween

func shake_light(camera: Camera2D, time: float = 0.2) -> void:
	"""Shakes camera with light shake"""
	shake(camera, 3.0, time)

func shake_medium(camera: Camera2D, time: float = 0.3) -> void:
	"""Shakes camera with medium shake"""
	shake(camera, 5.0, time)

func shake_heavy(camera: Camera2D, time: float = 0.5) -> void:
	"""Shakes camera with heavy shake"""
	shake(camera, 8.0, time)

func stop_camera_shake(camera: Camera2D) -> bool:
	"""Stop all active shakes for specific camera"""
	if _camera_tween_associations.has(camera):
		var association = _camera_tween_associations[camera]
		var tween = association[0]
		var original_offset = association[1]
		var cleanup_timer = association[2]
		
		if is_instance_valid(tween):
			tween.kill()
		
		if is_instance_valid(camera):
			camera.offset = original_offset
		
		# Clean up arrays
		_active_shake_tweens.erase(tween)
		_active_shake_timers.erase(cleanup_timer)
		_camera_tween_associations.erase(camera)
		
		return true
	return false

func flash_screen(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	"""Flashes screen for some duration"""
	if duration <= 0.0:
		push_warning("flash_screen: duration must be positive")
		return
	
	var flash = ColorRect.new()
	flash.color = color
	flash.modulate.a = 0.8
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)

func get_camera_bounds(camera: Camera2D) -> Rect2:
	"""Gets the visible bounds of a camera"""
	if not camera or not is_instance_valid(camera):
		push_warning("get_camera_bounds: invalid camera provided")
		return Rect2()
	
	var zoom = camera.zoom
	if zoom.x <= 0 or zoom.y <= 0:
		push_warning("get_camera_bounds: invalid camera zoom")
		return Rect2()
	
	var viewport_size = get_viewport().size
	var size = Vector2(viewport_size.x, viewport_size.y) / zoom # viewport size is a vector2i
	var top_left = camera.global_position - size / 2
	return Rect2(top_left, size)

func wrap_node_to_screen(object: Node2D, camera: Camera2D, buffer: float = 0.0) -> void:
	"""Wraps object position to camera bounds with extra buffer zone"""
	if not object or not is_instance_valid(object) or not camera or not is_instance_valid(camera):
		push_warning("wrap_node_to_screen: invalid object or camera provided")
		return
	
	var bounds = get_camera_bounds(camera)
	if(bounds.size.x <= 0 or bounds.size.y <= 0):
		return
	bounds = bounds.grow(buffer)
	var pos = object.global_position
	
	if pos.x > bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x - buffer
	elif pos.x < bounds.position.x - buffer:
		pos.x = bounds.position.x + bounds.size.x
	
	if pos.y > bounds.position.y + bounds.size.y:
		pos.y = bounds.position.y - buffer
	elif pos.y < bounds.position.y - buffer:
		pos.y = bounds.position.y + bounds.size.y
	
	object.global_position = pos

func is_off_screen(object: Node2D, camera: Camera2D, buffer: float = 0.0) -> bool:
	"""Checks if object is completely off screen"""
	if not object or not is_instance_valid(object) or not camera or not is_instance_valid(camera):
		return true
	
	var bounds = get_camera_bounds(camera).grow(buffer)
	return not bounds.has_point(object.global_position)

func clamp_node_to_screen(object: Node2D, camera: Camera2D, margin: float = 0.0) -> Vector2:
	"""Clamps object position to stay withen camera bounds"""
	if not object or not is_instance_valid(object) or not camera or not is_instance_valid(camera):
		push_warning("clamp_node_to_screen: invalid object or camera provided")
		return Vector2.ZERO
	
	var bounds = get_camera_bounds(camera).grow(-margin)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return object.global_position
	
	var pos = object.global_position
	pos.x = clamp(pos.x, bounds.position.x, bounds.position.x + bounds.size.x)
	pos.y = clamp(pos.y, bounds.position.y, bounds.position.y + bounds.size.y)
	object.global_position = pos
	return pos

func shake_3d(camera: Camera3D, intensity: float, time: float) -> Tween:
	"""Shakes 3D camera and returns tween for optional control"""
	if not camera or not is_instance_valid(camera):
		push_warning("shake_3d: invalid camera provided")
		return null
	
	if intensity < 0.0 or time < 0.0:
		push_warning("shake_3d: intensity and time must be positive")
		return null
	
	stop_camera_shake_3d(camera)
	
	var original_position = camera.position
	var tween = create_tween()
	tween.set_loops()
	
	# Store reference for cleanup
	_active_shake_tweens.append(tween)
	
	
	var shake_callable = func():
		if is_instance_valid(camera) and is_instance_valid(tween):
			var random_offset = Vector3(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			camera.position = original_position + random_offset
	
	tween.tween_callback(shake_callable).set_delay(1/Engine.get_frames_per_second())
	
	# Create cleanup timer
	var cleanup_timer = get_tree().create_timer(time)
	_active_shake_timers.append(cleanup_timer)
	
	_camera_tween_associations[camera] = [tween, original_position, cleanup_timer]
	
	cleanup_timer.timeout.connect(func():
		if !_camera_tween_associations.has(camera):
			return
		
		var current_association = _camera_tween_associations[camera]
		# Verify this timer and tween are still the active ones for this camera
		if current_association[0] != tween || current_association[2] != cleanup_timer:
			return  # A new shake has replaced this one
			
		# Proceed with cleanup
		if is_instance_valid(tween):
			tween.kill()
		if is_instance_valid(camera):
			camera.position = original_position
		
		_active_shake_tweens.erase(tween)
		_active_shake_timers.erase(cleanup_timer)
		_camera_tween_associations.erase(camera)
	)
	
	# Clean up if tween is manually killed
	tween.finished.connect(func():
		_active_shake_tweens.erase(tween)
	)
	
	return tween

func shake_light_3d(camera: Camera3D, time: float = 0.2) -> void:
	"""Shakes 3D camera with light shake"""
	shake_3d(camera, 0.05, time)

func shake_medium_3d(camera: Camera3D, time: float = 0.3) -> void:
	"""Shakes 3D camera with medium shake"""
	shake_3d(camera, 0.1, time)

func shake_heavy_3d(camera: Camera3D, time: float = 0.5) -> void:
	"""Shakes 3D camera with heavy shake"""
	shake_3d(camera, 0.2, time)

func stop_camera_shake_3d(camera: Camera3D) -> bool:
	"""Stop all active shakes for specific camera"""
	if _camera_tween_associations.has(camera):
		var association = _camera_tween_associations[camera]
		var tween = association[0]
		var original_position = association[1]
		var cleanup_timer = association[2]
		
		if is_instance_valid(tween):
			tween.kill()
		
		if is_instance_valid(camera):
			camera.position = original_position
		
		# Clean up arrays
		_active_shake_tweens.erase(tween)
		_active_shake_timers.erase(cleanup_timer)
		_camera_tween_associations.erase(camera)
		
		return true
	return false

func get_mouse_world_position_3d_plane(camera: Camera3D) -> Vector3:
	"""Gets mouse position projected to 3D world on a plane"""
	if not camera or not is_instance_valid(camera):
		push_warning("get_mouse_world_position_3d: invalid camera provided")
		return Vector3.ZERO
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	if ray_direction.y != 0:
		var t = -ray_origin.y / ray_direction.y
		return ray_origin + ray_direction * t
	
	return Vector3.ZERO

func get_mouse_world_position_3d_collision(camera: Camera3D) -> Vector3:
	"""Gets mouse position projected to 3D world based on ray collision"""
	if not camera or not is_instance_valid(camera):
		push_warning("get_mouse_world_position_3d_collision: invalid camera provided")
		return Vector3.ZERO
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.ZERO

# Add cleanup function for all camera effects
func cleanup_camera_effects() -> void:
	"""Cleans up all active camera shake effects and timers"""
	for tween in _active_shake_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_active_shake_tweens.clear()
	
	_active_shake_timers.clear()

##################################################################################
################################## AUDIO UTILS ###################################
##################################################################################
signal current_music_finished

var _music_player: AudioStreamPlayer
var _sfx_volume: float = 1.0
var _music_volume: float = 1.0
var _sfx_muted: bool = false
var _music_muted: bool = false
var _should_loop_music: bool = false
var _music_fade_tween: Tween
var _crossfade_tween: Tween

func play_sfx(sound: AudioStream, volume: float = 1.0, pitch: float = 1.0) -> void:
	"""Plays an sfx sound"""
	if not sound or _sfx_muted:
		return
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = sound
	player.volume_db = _to_db(_sfx_volume * volume)
	player.pitch_scale = clamp(pitch, 0.1, 3.0)
	player.play()
	
	# Auto cleanup
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)

func play_music(music: AudioStream, volume: float = 1.0, loop: bool = true, fade_in_duration: float = 0.0) -> void:
	"""Plays music"""
	if(_music_player == null):
		_music_player = AudioStreamPlayer.new()
		add_child(_music_player)
	if not music:
		push_warning("play_music: invalid audiostream")
		return
	
	# Stop current music and clean up any existing connections
	_music_player.stop()
	_cleanup_music_connections()
	_cleanup_music_tweens()
	
	_should_loop_music = loop
	
	# Create a copy to avoid modifying the original resource
	var music_copy = music.duplicate()
	
	_music_player.stream = music_copy
	
	var target_volume_db = _to_db(_music_volume * volume) if not _music_muted else -80.0
	
	if fade_in_duration > 0.0:
		_music_player.volume_db = -80.0
		_music_player.play()
		
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(_music_player, "volume_db", target_volume_db, fade_in_duration)
	else:
		_music_player.volume_db = target_volume_db
		_music_player.play()
	
	if loop:
		_music_player.finished.connect(_on_music_finished, CONNECT_ONE_SHOT)

func crossfade_music(new_music: AudioStream, volume: float = 1.0, loop: bool = true, crossfade_duration: float = 1.0) -> void:
	"""Crossfades from current music to new music over specified duration"""
	if(_music_player == null):
		_music_player = AudioStreamPlayer.new()
		add_child(_music_player)
	if not new_music:
		return
	
	if crossfade_duration <= 0.0:
		play_music(new_music, volume, loop)
		return
	
	if not _music_player.playing or not _music_player.stream:
		play_music(new_music, volume, loop, crossfade_duration)
		return
	
	var old_player = _music_player
	var new_player = AudioStreamPlayer.new()
	add_child(new_player)
	
	var music_copy = new_music.duplicate()
	new_player.stream = music_copy
	var target_volume_db = _to_db(_music_volume * volume) if not _music_muted else -80.0
	new_player.volume_db = -80.0  # Start silent
	new_player.play()
	
	_cleanup_music_connections()
	_cleanup_music_tweens()
	_music_player = new_player
	_should_loop_music = loop
	
	if loop:
		_music_player.finished.connect(_on_music_finished, CONNECT_ONE_SHOT)
	
	# old player fades out, new player fades in
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)  # Allow multiple simultaneous tweens
	
	# Fade out old player
	_crossfade_tween.tween_property(old_player, "volume_db", -80.0, crossfade_duration)
	
	# Fade in new player
	_crossfade_tween.tween_property(new_player, "volume_db", target_volume_db, crossfade_duration)
	
	# Clean up old player when crossfade is complete
	_crossfade_tween.tween_callback(func():
		if is_instance_valid(old_player):
			old_player.queue_free()
	).set_delay(crossfade_duration)

func _on_music_finished() -> void:
	"""Helper function called when music finished"""
	current_music_finished.emit()
	
	if _should_loop_music and _music_player and _music_player.stream:
		_music_player.play()
		
		if not _music_player.finished.is_connected(_on_music_finished):
			_music_player.finished.connect(_on_music_finished, CONNECT_ONE_SHOT)

func stop_music() -> void:
	"""Stops music"""
	_cleanup_music_connections()
	_should_loop_music = false
	_music_player.stop()

func _cleanup_music_connections() -> void:
	"""Clean up any existing music connections"""
	if _music_player.finished.is_connected(_on_music_finished):
		_music_player.finished.disconnect(_on_music_finished)

func _cleanup_music_tweens() -> void:
	"""Clean up any existing music tweens"""
	if _music_fade_tween and is_instance_valid(_music_fade_tween):
		_music_fade_tween.kill()
	if _crossfade_tween and is_instance_valid(_crossfade_tween):
		_crossfade_tween.kill()


func set_sfx_volume(volume: float) -> void:
	"""Sets volume of all sfx sounds"""
	_sfx_volume = clamp(volume, 0.0, 1.0)

func set_music_volume(volume: float) -> void:
	"""Sets volume of all music sounds"""
	if(_music_player == null): return
	_music_volume = clamp(volume, 0.0, 1.0)
	if _music_player.playing and not _music_muted:
		_music_player.volume_db = _to_db(_music_volume)

func mute_sfx(muted: bool) -> void:
	"""Mutes all sfx"""
	_sfx_muted = muted

func mute_music(muted: bool) -> void:
	"""mutes all music"""
	if _music_player == null: return
	_music_muted = muted
	if _music_player.playing:
		_music_player.volume_db = -80.0 if muted else _to_db(_music_volume)

func _to_db(linear: float) -> float:
	"""(0.0, 1.0) made into a deciable scale non linearly"""
	return -80.0 if linear <= 0.0 else 20.0 * log(linear) / log(10.0)

func is_music_playing() -> bool:
	return _music_player != null && _music_player.playing


##################################################################################
################################## SCENE UTILS ###################################
##################################################################################
func change_scene(scene_path: String):
	if not FileAccess.file_exists(scene_path):
		push_warning("change_scene: scene file does not exist: " + scene_path)
		return
	cleanup_camera_effects()
	clear_input_buffer()
	get_tree().change_scene_to_file(scene_path)

func change_scene_with_simple_transition(scene_path: String, transition_duration: float = 0.5) -> void:
	"""Changes scene with fade transition"""
	if not FileAccess.file_exists(scene_path):
		push_warning("change_scene_with_simple_transition: scene file does not exist: " + scene_path)
		return
	if transition_duration <= 0.0:
		push_warning("change_scene_with_simple_transition: transition duration must be positive")
		return
	
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, transition_duration / 2)
	tween.tween_callback(change_scene.bind(scene_path))
	tween.tween_property(fade, "modulate:a", 0.0, transition_duration / 2)
	tween.tween_callback(fade.queue_free)

func restart_scene():
	"""Restarts current scene"""
	clear_input_buffer()
	get_tree().reload_current_scene()

##################################################################################
################################## INPUT UTILS ###################################
##################################################################################
var _tracked_inputs: Dictionary = {}
var _sequences: Dictionary = {}

# Buffer types enum for clarity
enum BufferType {
	TIME,
	FRAMES
}

func register_input_tracking(action: String) -> void:
	"""Register an action to be tracked for buffering"""
	if not InputMap.has_action(action):
		push_warning("register_input_tracking: action '" + action + "' does not exist")
		return
	
	_tracked_inputs[action] = {
		"last_pressed_time": 0.0,
		"last_pressed_frame": 0,
		"consumed": true  # Start as consumed so first check doesn't immediately trigger
	}

func unregister_input_tracking(action: String) -> bool:
	"""Unregister an action from tracking"""
	return _tracked_inputs.erase(action)

func is_buffered_input_available(action: String, buffer_time: float = 0.1) -> bool:
	"""Check if a tracked action has been pressed within the buffer time"""
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - data.last_pressed_time
	return elapsed <= max(0.0, buffer_time)

func is_buffered_input_available_frames(action: String, buffer_frames: int = 6) -> bool:
	"""Check if a tracked action has been pressed within the buffer frames"""
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_frame = Engine.get_process_frames()
	var frames_passed = current_frame - data.last_pressed_frame
	return frames_passed <= max(0, buffer_frames)

func consume_buffered_input(action: String, buffer_time: float = 0.1) -> bool:
	"""Consume a buffered input if it's available within the buffer time"""
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - data.last_pressed_time
	
	if elapsed <= max(0.0, buffer_time):
		data.consumed = true
		return true
	
	return false

func consume_buffered_input_frames(action: String, buffer_frames: int = 6) -> bool:
	"""Consume a buffered input if it's available within the buffer frames"""
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_frame = Engine.get_process_frames()
	var frames_passed = current_frame - data.last_pressed_frame
	
	if frames_passed <= max(0, buffer_frames):
		data.consumed = true
		return true
	
	return false

func peek_buffered_input(action: String, buffer_time: float = 0.1) -> bool:
	"""Check if buffered input is available without consuming it"""
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - data.last_pressed_time
	return elapsed <= max(0.0, buffer_time)

func peek_buffered_input_frames(action: String, buffer_frames: int = 6) -> bool:
	"""Check if buffered input is available without consuming it (frame-based)"""
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_frame = Engine.get_process_frames()
	var frames_passed = current_frame - data.last_pressed_frame
	return frames_passed <= max(0, buffer_frames)

func get_input_elapsed_time(action: String) -> float:
	"""Get time elapsed since the tracked action was last pressed"""
	if not _tracked_inputs.has(action):
		return -1.0
	
	var data = _tracked_inputs[action]
	var current_time = Time.get_unix_time_from_system()
	return current_time - data.last_pressed_time

func get_input_elapsed_frames(action: String) -> int:
	"""Get frames elapsed since the tracked action was last pressed"""
	if not _tracked_inputs.has(action):
		return -1
	
	var data = _tracked_inputs[action]
	var current_frame = Engine.get_process_frames()
	return current_frame - data.last_pressed_frame

func _update_tracked_inputs() -> void:
	"""Update all tracked inputs - call this every frame"""
	var current_time = Time.get_unix_time_from_system()
	var current_frame = Engine.get_process_frames()
	
	for action in _tracked_inputs.keys():
		if Input.is_action_just_pressed(action):
			var data = _tracked_inputs[action]
			data.last_pressed_time = current_time
			data.last_pressed_frame = current_frame
			data.consumed = false

# Sequence functions remain the same
func is_input_sequence_just_pressed(sequence: Array[String], timeout: float = 2.0) -> bool:
	"""Returns true if an entire input sequence has been pressed"""
	if sequence.is_empty():
		push_warning("is_input_sequence_just_pressed: empty sequence provided")
		return false
	
	# Check if all actions exist
	for action in sequence:
		if not InputMap.has_action(action):
			push_warning("is_input_sequence_just_pressed: action '" + action + "' does not exist")
			return false
	
	# Generate a unique key for this sequence
	var sequence_key = "_".join(sequence)
	
	# Initialize sequence tracking if it doesn't exist
	if not _sequences.has(sequence_key):
		_sequences[sequence_key] = {
			"target_sequence": sequence,
			"current_inputs": [],
			"last_input_time": 0.0,
			"timeout": max(0.1, timeout)
		}
	
	var seq_data = _sequences[sequence_key]
	var current_time = Time.get_unix_time_from_system()
	
	# Find which action was just pressed
	var new_input = ""
	for action in sequence:
		if Input.is_action_just_pressed(action):
			new_input = action
			break
	
	if new_input == "":
		return false
	
	# Check if too much time has passed since last input
	if seq_data.current_inputs.size() > 0:
		var time_diff = current_time - seq_data.last_input_time
		if time_diff > seq_data.timeout:
			seq_data.current_inputs.clear()
	
	seq_data.last_input_time = current_time
	
	var expected_index = seq_data.current_inputs.size()
	
	# Check if this input matches the expected next input in sequence
	if expected_index < sequence.size() and sequence[expected_index] == new_input:
		seq_data.current_inputs.append(new_input)
		
		# Check if sequence is complete
		if seq_data.current_inputs.size() == sequence.size():
			seq_data.current_inputs.clear()
			return true
	else:
		# Wrong input - check if it's the start of the sequence
		if sequence[0] == new_input:
			seq_data.current_inputs = [new_input]
		else:
			seq_data.current_inputs.clear()
	
	return false

func get_sequence_progress(sequence: Array[String]) -> float:
	"""Returns progress of sequence completion (0.0 to 1.0), or -1.0 if sequence doesn't exist"""
	if sequence.is_empty():
		return -1.0
	
	var sequence_key = "_".join(sequence)
	
	if not _sequences.has(sequence_key):
		return 0.0
	
	var seq_data = _sequences[sequence_key]
	
	# Check if sequence has timed out
	var current_time = Time.get_unix_time_from_system()
	if seq_data.current_inputs.size() > 0:
		var time_diff = current_time - seq_data.last_input_time
		if time_diff > seq_data.timeout:
			seq_data.current_inputs.clear()
			return 0.0
	
	return float(seq_data.current_inputs.size()) / float(sequence.size())

func clear_input_buffer():
	"""Clears all input buffers and sequences, useful when changing scenes"""
	_tracked_inputs.clear()
	_sequences.clear()

func clear_input_sequences():
	"""Clears only input sequences, keeping input buffers"""
	_sequences.clear()

func get_tracked_actions() -> Array[String]:
	"""Returns array of currently tracked actions"""
	var actions: Array[String] = []
	for action in _tracked_inputs.keys():
		actions.append(action)
	return actions

func _update_sequence_timeouts(_delta: float) -> void:
	"""Helper function to update sequence timeouts"""
	var current_time = Time.get_unix_time_from_system()
	
	for sequence_name in _sequences.keys():
		var seq_data = _sequences[sequence_name]
		if seq_data.current_inputs.size() > 0:
			var time_diff = current_time - seq_data.last_input_time
			if time_diff > seq_data.timeout:
				seq_data.current_inputs.clear()

##################################################################################
################################## TIMER UTILS ###################################
##################################################################################
func delayed_call(callback: Callable, delay: float) -> void:
	"""Calls a function after delay"""
	if delay < 0.0:
		push_warning("delayed_call: delay must be positive")
		delay = 0.0
	
	await get_tree().create_timer(delay).timeout
	callback.call()

func repeat_call(callback: Callable, interval: float, times: int = -1) -> void:
	"""Repeats a function call at intervals"""
	if interval <= 0.0:
		push_warning("repeat_call: interval must be positive")
		return
	
	var count = 0
	while times == -1 or count < times:
		if callback.is_valid():
			callback.call()
		await get_tree().create_timer(interval).timeout
		count += 1

##################################################################################
################################## NODE UTILS ####################################
##################################################################################
func find_node_by_name(node_name: String, root: Node = null, max_depth: int = 10) -> Node:
	"""Recursively finds node by name with depth limit, returns null if none found"""
	if not root:
		root = get_tree().root
	
	if max_depth <= 0:
		return null
	
	if root.name == node_name:
		return root
	
	for child in root.get_children():
		var found = find_node_by_name(node_name, child, max_depth - 1)
		if found:
			return found
	
	return null

func safe_signal_connect(signal_obj: Signal, callable: Callable) -> bool:
	"""Safely connects a signal, avoiding duplicate connections"""
	if not callable.is_valid():
		push_warning("safe_connect: invalid callable provided")
		return false
	if not signal_obj.is_connected(callable):
		signal_obj.connect(callable)
		return true
	return false

func safe_signal_disconnect(signal_obj: Signal, callable: Callable) -> bool:
	"""Safely connects a signal, avoiding duplicate connections"""
	if not callable.is_valid():
		push_warning("safe_disconnect: invalid callable provided")
		return false
	if signal_obj.is_connected(callable):
		signal_obj.disconnect(callable)
		return true
	return false

##################################################################################
################################# ANIMATION UTILS ################################
##################################################################################
func pulse_node(node: CanvasItem, scale_mult: float = 1.2, duration: float = 0.2) -> void:
	"""Makes node pulse by scaling"""
	if not node or not is_instance_valid(node):
		push_warning("pulse_node: invalid node provided")
		return
	
	if duration <= 0.0:
		push_warning("pulse_node: duration must be positive")
		return
	
	var original_scale = node.scale
	var target_scale = original_scale * abs(scale_mult)
	
	var tween = create_tween()
	tween.tween_property(node, "scale", target_scale, duration/2)
	tween.tween_property(node, "scale", original_scale, duration/2)

func fade_in(node: CanvasItem, duration: float = 0.3) -> void:
	"""Fades node in"""
	if not node or not is_instance_valid(node):
		push_warning("fade_in: invalid node provided")
		return
	
	if duration <= 0.0:
		node.modulate.a = 1.0
		node.visible = true
		return
	
	node.modulate.a = 0.0
	node.visible = true
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

func fade_out(node: CanvasItem, duration: float = 0.3, hide_when_done: bool = true) -> void:
	"""Fades node out"""
	if not node or not is_instance_valid(node):
		push_warning("fade_out: invalid node provided")
		return
	
	if duration <= 0.0:
		node.modulate.a = 0.0
		if hide_when_done:
			node.visible = false
		return
	
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	if hide_when_done:
		tween.tween_callback(func(): if is_instance_valid(node): node.visible = false)

##################################################################################
################################## EASING FUNCTIONS ##############################
##################################################################################
# Standalone easing functions
func ease_in_sine(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - cos((t * PI) / 2.0)

func ease_out_sine(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return sin((t * PI) / 2.0)

func ease_in_out_sine(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return -(cos(PI * t) - 1.0) / 2.0

func ease_in_quad(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t

func ease_out_quad(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_out_quad(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0

func ease_in_cubic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t * t

func ease_out_cubic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

func ease_in_out_cubic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0

func ease_in_elastic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	elif t == 1.0:
		return 1.0
	else:
		var c4 = (2.0 * PI) / 3.0
		return -pow(2.0, 10.0 * t - 10.0) * sin((t * 10.0 - 10.75) * c4)

func ease_out_elastic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	elif t == 1.0:
		return 1.0
	else:
		var c4 = (2.0 * PI) / 3.0
		return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0

func ease_in_bounce(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - ease_out_bounce(1.0 - t)

func ease_out_bounce(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	var n1 = 7.5625
	var d1 = 2.75
	
	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	else:
		t -= 2.625 / d1
		return n1 * t * t + 0.984375

##################################################################################
#################################### UI UTILS ####################################
##################################################################################
func typewriter_text(label: Label, text: String, speed: float = 0.05) -> void:
	"""Animates text with a typewriter effect"""
	if not label or not is_instance_valid(label):
		push_warning("typewriter_text: invalid label provided")
		return
	
	var safe_speed = max(0.001, speed) # prevent infinite loops
	
	label.text = ""
	for i in range(text.length()):
		if not is_instance_valid(label):
			return
		label.text += text[i]
		await get_tree().create_timer(safe_speed).timeout

func animate_ui_slide_in(control: Control, direction: Vector2, duration: float = 0.3, easing: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	"""Scales UI element in from specified direction"""
	if not control or not is_instance_valid(control):
		push_warning("animate_ui_slide_in: invalid control provided")
		return
	
	if duration <= 0.0:
		control.visible = true
		return
	
	direction = -direction # this allows us to pass in simpley Vector2.UP and it makes sense.
	
	var original_pos = control.position
	var start_pos = original_pos + direction * 500
	
	control.position = start_pos
	control.visible = true
	
	var tween = create_tween()
	tween.set_trans(easing)
	tween.tween_property(control, "position", original_pos, duration)

func animate_ui_scale_in(control: Control, duration: float = 0.3, easing: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	"""Scales UI element in with scale effect"""
	if not control or not is_instance_valid(control):
		push_warning("animated_ui_scale_in: invalid control provided")
		return
	
	if duration <= 0.0:
		control.visible = true
		return
	
	var original_scale = control.scale
	control.scale = Vector2.ZERO
	control.visible = true
	
	var tween = create_tween()
	tween.set_trans(easing)
	tween.tween_property(control, "scale", original_scale, duration)

##################################################################################
#################################### FILE UTILS ##################################
##################################################################################
func save_data(data: Dictionary, filename: String = "save_game.dat") -> bool:
	"""Saves data to file, returns bool of success"""
	if filename.is_empty():
		push_warning("save_data: filename cannot be empty")
		return false
	
	var file = FileAccess.open("user://" + filename, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data)
		file.store_string(json_string)
		file.close()
		return true
	push_warning("save_data: failed to open file for writing: " + filename)
	return false

func load_data(filename: String = "save_game.dat") -> Dictionary:
	"""Loads data from file"""
	if filename.is_empty():
		push_warning("load_data: filename cannot be empty")
		return {}
	
	var file = FileAccess.open("user://" + filename, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		if json_string.is_empty():
			return {}
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK and json.data is Dictionary:
			return json.data
		else:
			push_warning("load_data: failed to parse JSON from file: " + filename)
	return {}

func delete_save(filename: String = "save_game.dat"):
	"""Deletes save file"""
	if filename.is_empty():
		push_warning("delete_save: filename cannot be empty")
		return false
	
	var full_path = "user://" + filename
	if FileAccess.file_exists(full_path):
		var error = DirAccess.remove_absolute(full_path)
		if error != OK:
			push_warning("delete_save: failed to delete file: " + filename)
			return false
		return true
	return true  # File doesn't exist, consider it "successfully deleted"

##################################################################################
###################################### UPDATE ####################################
##################################################################################
func _ready():
	set_process(true)

func _process(delta: float) -> void:
	_update_tracked_inputs()
	_update_sequence_timeouts(delta)

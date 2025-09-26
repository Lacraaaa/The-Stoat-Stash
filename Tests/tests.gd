extends Node

# Test suite for utility functions
# Run this scene to execute all tests

var utils: Node
var test_results: Dictionary = {}
var total_tests: int = 0
var passed_tests: int = 0

func _ready():
	print("Starting Utils Test Suite...")
	
	# Load the utils script
	utils = load("res://stoat_stash.gd").new()
	add_child(utils)
	
	# Run all tests
	test_math_functions()
	test_file_functions()
	test_node_functions()
	test_animation_functions()
	test_easing_functions()
	test_utility_functions()
	
	# Print results
	print_test_results()

func test_math_functions():
	print("\n=== Testing Math Functions ===")
	
	# Test remap_value
	test_assert("remap_value basic", 
		abs(utils.remap_value(5.0, 0.0, 10.0, 0.0, 100.0) - 50.0) < 0.001)
	
	test_assert("remap_value edge case", 
		abs(utils.remap_value(0.0, 0.0, 10.0, -50.0, 50.0) - (-50.0)) < 0.001)
	
	test_assert("remap_value reverse", 
		abs(utils.remap_value(2.0, 0.0, 10.0, 100.0, 0.0) - 80.0) < 0.001)
	
	# Test chance function
	var chance_results = []
	for i in range(1000):
		if utils.chance(0.5):
			chance_results.append(1)
		else:
			chance_results.append(0)
	
	var average = chance_results.reduce(func(a, b): return a + b) / float(chance_results.size())
	test_assert("chance probability ~0.5", abs(average - 0.5) < 0.1)
	
	test_assert("chance 0.0", not utils.chance(0.0))
	test_assert("chance 1.0", utils.chance(1.0))
	
	# Test weighted_random
	var weights = [1.0, 2.0, 3.0]
	var weight_counts = [0, 0, 0]
	for i in range(1000):
		var result = utils.weighted_random(weights)
		if result >= 0 and result < weight_counts.size():
			weight_counts[result] += 1
	
	# Index 2 should appear most often (weight 3), index 0 least often (weight 1)
	test_assert("weighted_random distribution", 
		weight_counts[2] > weight_counts[1] and weight_counts[1] > weight_counts[0])
	
	test_assert("weighted_random empty array", utils.weighted_random([]) == -1)
	
	# Test random_point_in_circle
	var point = utils.random_point_in_circle(10.0)
	test_assert("random_point_in_circle within radius", point.length() <= 10.0)
	
	# Test random_point_on_circle_perimeter
	var perimeter_point = utils.random_point_on_circle_perimeter(5.0)
	test_assert("random_point_on_circle_perimeter on radius", 
		abs(perimeter_point.length() - 5.0) < 0.001)
	
	# Test wrap_angle
	test_assert("wrap_angle positive", 
		abs(utils.wrap_angle(7.0) - (7.0 - 2*PI)) < 0.001)
	
	test_assert("wrap_angle negative", 
		abs(utils.wrap_angle(-4.0) - (-4.0 + 2*PI)) < 0.001)
	
	test_assert("wrap_angle within range", 
		abs(utils.wrap_angle(1.0) - 1.0) < 0.001)
	
	# Test angle_difference
	test_assert("angle_difference simple", 
		abs(utils.angle_difference(0.0, PI/2) - PI/2) < 0.001)
	
	test_assert("angle_difference wrap", 
		abs(abs(utils.angle_difference(-PI/2, PI/2)) - PI) < 0.001) # this is an edge case where both -pi and pi are valid, so we should simply take the abs.
	
	# Test snap_to_grid
	var snapped = utils.snap_to_grid(Vector2(12.3, 17.8), 5.0)
	test_assert("snap_to_grid", snapped == Vector2(10.0, 20.0))
	
	test_assert("snap_to_grid zero size returns original", 
		utils.snap_to_grid(Vector2(1, 1), 0.0) == Vector2(1, 1))
	
	# Test random_color
	var color = utils.random_color()
	test_assert("random_color valid", 
		color.r >= 0.0 and color.r <= 1.0 and 
		color.g >= 0.0 and color.g <= 1.0 and 
		color.b >= 0.0 and color.b <= 1.0 and 
		color.a == 1.0)
	
	# Test vector_from_angle
	var vec = utils.vector_from_angle(0.0, 5.0)
	test_assert("vector_from_angle", 
		abs(vec.x - 5.0) < 0.001 and abs(vec.y) < 0.001)
	
	var vec_pi2 = utils.vector_from_angle(PI/2, 3.0)
	test_assert("vector_from_angle PI/2", 
		abs(vec_pi2.x) < 0.001 and abs(vec_pi2.y - 3.0) < 0.001)
	
	# Test rotate_around_point
	var rotated = utils.rotate_around_point(Vector2(1, 0), Vector2.ZERO, PI/2)
	test_assert("rotate_around_point", 
		abs(rotated.x) < 0.001 and abs(rotated.y - 1.0) < 0.001)

func test_file_functions():
	print("\n=== Testing File Functions ===")
	
	var test_data = {
		"player_name": "TestPlayer",
		"level": 42,
		"score": 123456,
		"items": ["sword", "potion", "key"],
		"position": {"x": 10.5, "y": 20.3}
	}
	
	# Test save_data
	var save_success = utils.save_data(test_data, "test_save.json")
	test_assert("save_data success", save_success)
	
	test_assert("save_data empty filename", not utils.save_data(test_data, ""))
	
	# Test load_data
	var loaded_data = utils.load_data("test_save.json")
	test_assert("load_data success", not loaded_data.is_empty())
	test_assert("load_data player_name", loaded_data.get("player_name") == "TestPlayer")
	test_assert("load_data level", loaded_data.get("level") == 42)
	test_assert("load_data score", loaded_data.get("score") == 123456)
	test_assert("load_data items array", loaded_data.get("items", []).size() == 3)
	test_assert("load_data position dict", loaded_data.get("position", {}).has("x"))
	
	# Test load non-existent file
	var empty_data = utils.load_data("nonexistent.json")
	test_assert("load_data nonexistent file", empty_data.is_empty())
	
	test_assert("load_data empty filename", utils.load_data("").is_empty())
	
	# Test delete_save
	var delete_success = utils.delete_save("test_save.json")
	test_assert("delete_save success", delete_success)
	
	# Verify file was deleted
	var deleted_data = utils.load_data("test_save.json")
	test_assert("delete_save verification", deleted_data.is_empty())
	
	# Test delete non-existent file (should still return true)
	test_assert("delete_save nonexistent", utils.delete_save("nonexistent.json"))
	test_assert("delete_save empty filename", not utils.delete_save(""))


func test_node_functions():
	print("\n=== Testing Node Functions ===")
	
	# Create test nodes
	var test_parent = Node.new()
	test_parent.name = "TestParent"
	add_child(test_parent)
	
	var test_child = Node.new()
	test_child.name = "TestChild"
	test_parent.add_child(test_child)
	
	var test_grandchild = Node.new()
	test_grandchild.name = "TestGrandchild"
	test_child.add_child(test_grandchild)
	
	# Test find_node_by_name
	var found_child = utils.find_node_by_name("TestChild", test_parent)
	test_assert("find_node_by_name direct child", found_child == test_child)
	
	var found_grandchild = utils.find_node_by_name("TestGrandchild", test_parent)
	test_assert("find_node_by_name grandchild", found_grandchild == test_grandchild)
	
	var not_found = utils.find_node_by_name("NonExistent", test_parent)
	test_assert("find_node_by_name not found", not_found == null)
	
	# Test depth limit
	var depth_limited = utils.find_node_by_name("TestGrandchild", test_parent, 1)
	test_assert("find_node_by_name depth limit", depth_limited == null)
	
	# Clean up
	test_parent.queue_free()

func test_animation_functions():
	print("\n=== Testing Animation Functions ===")
	
	# Create test control for animation
	var test_control = Control.new()
	test_control.size = Vector2(100, 100)
	test_control.modulate = Color.WHITE
	add_child(test_control)
	
	# Test fade_in (just verify it doesn't crash and sets up correctly)
	test_control.modulate.a = 0.0
	test_control.visible = false
	utils.fade_in(test_control, 0.0)  # Instant fade
	test_assert("fade_in instant", test_control.visible and test_control.modulate.a == 1.0)
	
	# Test fade_out
	utils.fade_out(test_control, 0.0, true)  # Instant fade
	test_assert("fade_out instant", not test_control.visible and test_control.modulate.a == 0.0)
	
	# Test with null node
	utils.fade_in(null, 0.1)  # Should not crash
	utils.fade_out(null, 0.1)  # Should not crash
	test_assert("animation null safety", true)  # If we get here, no crash occurred
	
	# Clean up
	test_control.queue_free()

func test_easing_functions():
	print("\n=== Testing Easing Functions ===")
	
	# Test that all easing functions return valid values for edge cases
	var easing_funcs = [
		utils.ease_in_sine,
		utils.ease_out_sine,
		utils.ease_in_out_sine,
		utils.ease_in_quad,
		utils.ease_out_quad,
		utils.ease_in_out_quad,
		utils.ease_in_cubic,
		utils.ease_out_cubic,
		utils.ease_in_out_cubic,
		utils.ease_in_elastic,
		utils.ease_out_elastic,
		utils.ease_in_bounce,
		utils.ease_out_bounce
	]
	
	for i in range(easing_funcs.size()):
		var func_ref = easing_funcs[i]
		
		# Test edge cases
		var result_0 = func_ref.call(0.0)
		var result_1 = func_ref.call(1.0)
		var result_mid = func_ref.call(0.5)
		
		test_assert("easing function " + str(i) + " at t=0", 
			result_0 >= -0.1 and result_0 <= 1.1)  # Allow small tolerance for bounces
		
		test_assert("easing function " + str(i) + " at t=1", 
			result_1 >= -0.1 and result_1 <= 1.1)
		
		test_assert("easing function " + str(i) + " at t=0.5", 
			result_mid >= -0.5 and result_mid <= 1.5)  # Elastic can overshoot
		
		# Test clamping
		var result_negative = func_ref.call(-1.0)
		var result_over = func_ref.call(2.0)
		
		test_assert("easing function " + str(i) + " clamps negative", 
			result_negative == result_0)
		
		test_assert("easing function " + str(i) + " clamps over 1", 
			result_over == result_1)

func test_utility_functions():
	print("\n=== Testing Utility Functions ===")
	
	# Test input buffer functions (basic functionality)
	utils.clear_input_buffer()
	test_assert("clear_input_buffer", true)  # Should not crash
	
	# Test various utility functions that don't require complex setup
	
	# Test camera bounds with mock camera (create minimal mock)
	var mock_camera = Camera2D.new()
	mock_camera.zoom = Vector2(1.0, 1.0)
	mock_camera.global_position = Vector2(0, 0)
	add_child(mock_camera)
	
	var bounds = utils.get_camera_bounds(mock_camera)
	test_assert("get_camera_bounds valid", bounds.size.x > 0 and bounds.size.y > 0)
	
	# Test with invalid camera
	var null_bounds = utils.get_camera_bounds(null)
	test_assert("get_camera_bounds null", null_bounds == Rect2())
	
	mock_camera.queue_free()
	
	# Test audio settings save/load
	utils.set_sfx_volume(-10.0)
	utils.set_music_volume(-5.0)
	utils.mute_sfx(true)
	utils.mute_music(false)

func test_assert(test_name: String, condition: bool):
	total_tests += 1
	if condition:
		passed_tests += 1
		test_results[test_name] = "PASS"
		print("✓ " + test_name)
	else:
		test_results[test_name] = "FAIL"
		print("✗ " + test_name)

func print_test_results():
	print("\n" + "=".repeat(50))
	print("TEST RESULTS")
	print("=".repeat(50))
	print("Total tests: " + str(total_tests))
	print("Passed: " + str(passed_tests))
	print("Failed: " + str(total_tests - passed_tests))
	print("Success rate: " + str(round((float(passed_tests) / float(total_tests)) * 100.0)) + "%")
	
	if passed_tests == total_tests:
		print("\nAll tests passed")
	else:
		print("\nSome tests failed. Check output above for details.")
		print("\nFailed tests:")
		for test_name in test_results.keys():
			if test_results[test_name] == "FAIL":
				print("  - " + test_name)
	
	print("=".repeat(50))

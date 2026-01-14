extends Node3D

@export var calibration_ui: Control
@export var left_cameras: Camera3D
@export var right_cameras: Camera3D
@export var left_viewport_container: SubViewportContainer
@export var right_viewport_container: SubViewportContainer

var currently_loaded_object: Node

func load_glb_from_path(path: String) -> Variant:
	var gltf_document_load = GLTFDocument.new()
	var gltf_state_load = GLTFState.new()

	var error = gltf_document_load.append_from_file(path, gltf_state_load)

	if error == OK:
		return gltf_document_load.generate_scene(gltf_state_load)
	else:
		print("Couldn't load glTF scene (error code: %s)." % error_string(error))
		return error

var conn
var waiting_for_request: bool = true;
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	conn = StreamPeerTCP.new()

	var result = await conn.connect_to_host('127.0.0.1', 42842)

	if result != OK:
		#print('Failed to connect to controller program, with error code %d' % result)
		get_tree().quit()
	
	var node = load_glb_from_path('/home/eric/Downloads/tank-display.glb')
	if (typeof(node) == typeof(Node)):
		add_child(node)
	else:
		print(error_string(node))
		print('huh')

	currently_loaded_object = node


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print('NEW PROCESS.')

	#print('Starting polling')
	conn.poll()
	#print('Polling done.')

	if conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return

	if conn.get_status() == StreamPeerTCP.STATUS_ERROR:
		print("Stream Peer Status is error with no message to cleanly exit. Stopping.")
		get_tree().quit(1)

	var num_bytes_ready_to_read: int = conn.get_available_bytes()
	#print('Num bytes ready: ' + str(num_bytes_ready_to_read))

	if num_bytes_ready_to_read > 0:

		if waiting_for_request:
			#print('Must be request code, so has to be a int 64')
			var request_code: int = conn.get_64()

			#print('Request code is ' + str(request_code))

			match request_code:
				0:
					# Show calibration window
					calibration_ui.visible = true
				1:
					# Hide calibration window
					calibration_ui.visible = false
				2: 
					var pixels_per_lens = conn.get_float()
					var index_of_refraction = conn.get_float()
					print('Received code 2. Pixels per lens is ', pixels_per_lens)
					print('In addition, the index of refraction is ', index_of_refraction)
					left_viewport_container.material.set_shader_parameter("pixels_per_lens", pixels_per_lens)
					right_viewport_container.material.set_shader_parameter("pixels_per_lens", pixels_per_lens)

					left_viewport_container.material.set_shader_parameter("index_of_refraction", index_of_refraction)
					right_viewport_container.material.set_shader_parameter("index_of_refraction", index_of_refraction)
				3:
					conn.put_64(get_viewport().get_visible_rect().size.x)
				4:
					# New eye angles, so move the camera
					var left_eye_horizontal_angle: float = conn.get_double()
					var left_eye_vertical_angle: float = conn.get_double()
					var right_eye_horizontal_angle: float = conn.get_double()
					var right_eye_vertical_angle: float = conn.get_double()
					
					var left_x = cos(deg_to_rad(left_eye_vertical_angle)) * cos(deg_to_rad(left_eye_horizontal_angle))
					var left_y = -sin(deg_to_rad(left_eye_vertical_angle))
					var left_z = cos(deg_to_rad(left_eye_vertical_angle)) * sin(deg_to_rad(left_eye_horizontal_angle))

					var right_x = cos(deg_to_rad(right_eye_vertical_angle)) * cos(deg_to_rad(right_eye_horizontal_angle))
					var right_y = -sin(deg_to_rad(right_eye_vertical_angle))
					var right_z = cos(deg_to_rad(right_eye_vertical_angle)) * sin(deg_to_rad(right_eye_horizontal_angle))

					left_cameras.position = Vector3(left_x, left_y, left_z)
					right_cameras.position = Vector3(right_x, right_y, right_z)

					left_cameras.look_at(Vector3(0, 0, 0), Vector3.UP)
					right_cameras.look_at(Vector3(0, 0, 0), Vector3.UP)

					left_viewport_container.material.set_shader_parameter("left_eye_angle_degrees", left_eye_horizontal_angle)
					left_viewport_container.material.set_shader_parameter("right_eye_angle_degrees", right_eye_horizontal_angle)

					right_viewport_container.material.set_shader_parameter("left_eye_angle_degrees", left_eye_horizontal_angle)
					right_viewport_container.material.set_shader_parameter("right_eye_angle_degrees", right_eye_horizontal_angle)
				5:
					# Quit code
					print("Renderer received quit. Stopping.")
					get_tree().quit(0)

				6:
					# Given a new path for a glb object. Load that object.
					var path_string_length = conn.get_64()
					var path_string = conn.get_string(path_string_length)

					var node = load_glb_from_path(path_string)
					if (typeof(node) == typeof(Node)):
						add_child(node)
						remove_child(currently_loaded_object)
						currently_loaded_object = node
					else:
						print(error_string(node))
						print('huh')


			#print('End of match statement')
	
	#print('End of process function\n\n\n')
 

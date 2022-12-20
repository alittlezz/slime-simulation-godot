extends TextureRect


var NO_SLIMES := 1000000;
var rd: RenderingDevice
var shader_file: RDShaderFile = load("res://compute.glsl");
var rng: RandomNumberGenerator = RandomNumberGenerator.new();
var shader: RID
var slime_shader_file: RDShaderFile = load("res://slime.glsl");
var slime_shader: RID
var slime_pipeline: RID
var texture_read: RID
var texture_write: RID
var slimes_buffer: RID
var settings_buffer: RID
var uniform_set: RID
var slime_uniform_set: RID
var pipeline: RID
var read_data: PackedByteArray
var write_data: PackedByteArray
var image_size: Vector2i
var image_format := Image.FORMAT_RGBA8

func _ready() -> void:
	
	# We will be using our own RenderingDevice to handle the compute commands
	rd = RenderingServer.create_local_rendering_device()

	# Create shader and pipeline
	var shader_spirv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

	var data = []
	var sz = self.texture.get_size();
	for i in range(sz.x * sz.y * 4):
		data.append(0)
	var og_image := Image.create_from_data(sz.x, sz.y, false, Image.FORMAT_RGBA8, data);
	og_image.convert(image_format)
	image_size = og_image.get_size()

	# Data for compute shaders has to come as an array of bytes
	# Initialize read data
	read_data = og_image.get_data()

	var tex_read_format := RDTextureFormat.new()
	tex_read_format.width = image_size.x
	tex_read_format.height = image_size.y
	tex_read_format.depth = 4
	tex_read_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tex_read_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	var tex_view := RDTextureView.new()
	texture_read = rd.texture_create(tex_read_format, tex_view, [read_data])

	# Create uniform set using the read texture
	var read_uniform := RDUniform.new()
	read_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	read_uniform.binding = 0
	read_uniform.add_id(texture_read)
	
	
	var input = PackedFloat32Array();
	for i in range(NO_SLIMES):
		var x = rng.randf_range(0, sz.x);
		var y = rng.randf_range(0, sz.y);
		var angle = rng.randf_range(0, 2*PI);
		input.append(x);
		input.append(y);
		input.append(angle);
	var input_bytes := input.to_byte_array();
	slimes_buffer = rd.storage_buffer_create(input_bytes.size(), input_bytes)
	var slimes_uniform := RDUniform.new()
	slimes_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	slimes_uniform.binding = 2
	slimes_uniform.add_id(slimes_buffer)
	
	var settings_bytes := PackedFloat32Array([
		# width, height, no_flimes,
		sz.x, sz.y, float(NO_SLIMES),
		# time_delta, random_steer, random_angle
		0.0, rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0),
		# sensor_distance, sensor_size, sensor_angle_offset,
		35.0, 1.0, 30.0,
		# turn_speed, move_speed
		2.0, 30.0,
		# trail_weight, decay, diffuse
		5.0, 0.2, 3.0
	]).to_byte_array();
	settings_buffer = rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	var settings_uniform := RDUniform.new()
	settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	settings_uniform.binding = 3
	settings_uniform.add_id(settings_buffer)
	
	# Initialize write data
	write_data = PackedByteArray()
	write_data.resize(read_data.size())

	var tex_write_format := RDTextureFormat.new()
	tex_write_format.width = image_size.x
	tex_write_format.height = image_size.y
	tex_write_format.depth = 4
	tex_write_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tex_write_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	texture_write = rd.texture_create(tex_write_format, tex_view, [write_data])

	# Create uniform set using the write texture
	var write_uniform := RDUniform.new()
	write_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	write_uniform.binding = 1
	write_uniform.add_id(texture_write)

	uniform_set = rd.uniform_set_create([read_uniform, write_uniform, settings_uniform], shader, 0)
	
	
	var slime_shader_spirv := slime_shader_file.get_spirv()
	slime_shader = rd.shader_create_from_spirv(slime_shader_spirv)
	slime_pipeline = rd.compute_pipeline_create(slime_shader)
	
	slime_uniform_set = rd.uniform_set_create([read_uniform, slimes_uniform, settings_uniform], slime_shader, 0)	

func _process(delta: float) -> void:
	compute(delta)
	pass


func compute(delta: float) -> void:
	rd.texture_update(texture_read, 0, read_data)
	rd.buffer_update(settings_buffer, 12, 12, PackedFloat32Array([delta, rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0)]).to_byte_array());
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, slime_pipeline)
	rd.compute_list_bind_uniform_set(compute_list, slime_uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 	(NO_SLIMES / 64) + 1, 1, 1)
	rd.compute_list_end()  # Tell the GPU we are done with this compute task
	rd.submit()  # Force the GPU to start our commands
	rd.sync()  # Force the CPU to wait for the GPU to finish with the recorded commands
	read_data = rd.texture_get_data(texture_read, 0)

	compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, image_size.x / 8, image_size.y / 8, 1)
	rd.compute_list_end()  # Tell the GPU we are done with this compute task
	rd.submit()  # Force the GPU to start our commands
	rd.sync()  # Force the CPU to wait for the GPU to finish with the recorded commands

	# Now we can grab our data from the texture
	read_data = rd.texture_get_data(texture_write, 0)
	var image := Image.new();
	image.set_data(image_size.x, image_size.y, false, image_format, read_data);
	#image.create_from_data(image_size.x, image_size.y, false, image_format, read_data)
	self.texture = ImageTexture.create_from_image(image)

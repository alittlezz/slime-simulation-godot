#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D trails_in;
layout(set = 0, binding = 1, rgba32f) uniform image2D trails_out;
layout(set = 0, binding = 3, std430) restrict buffer Settings {
	float width;
	float height;
	float no_slimes;
	float time_delta;
	float random_steer;
	float random_angle;
    float sensor_distance;
    float sensor_size;
    float sensor_angle_offset;
    float slime_turn_speed;
    float slime_move_speed;
    float trail_weight;
    float decay;
    float diffuse;
} settings;

// The code we want to execute in each invocation
void main() {
	ivec2 gidx = ivec2(gl_GlobalInvocationID.xy);
    if (gidx.x >= settings.width || gidx.x < 0 || gidx.y >= settings.height || gidx.y < 0){
        return;
    }

	float sum = 0.0;
	float originalCol = imageLoad(trails_in, gidx).x;
	for (int offsetX = -1; offsetX <= 1; offsetX ++) {
		for (int offsetY = -1; offsetY <= 1; offsetY ++) {
			int sampleX = min(int(settings.width)-1, max(0, gidx.x + offsetX));
			int sampleY = min(int(settings.height)-1, max(0, gidx.y + offsetY));
			sum += imageLoad(trails_in, ivec2(sampleX, sampleY)).x;
		}
	}

	float blurredCol = sum / 9.0;
	float diffuseWeight = settings.time_delta * settings.diffuse;
	blurredCol = originalCol * (1.0 - diffuseWeight) + blurredCol * (diffuseWeight);

    imageStore(trails_out, gidx, vec4(vec3(max(0, blurredCol - settings.decay * settings.time_delta)), 1.0));
}

#[compute]
#version 450
#define PI 3.1415926535897932384626433832795
#define TO_PI 3.1415 / 180.0

// Invocations in the (x, y, z) dimension
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D trails_in;
layout(set = 0, binding = 2, std430) restrict buffer Slimes {
  float data[];
} slimes;
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

float sense(float angle, float x, float y, float sensor_angle_offset) {
	float sensor_angle = angle + sensor_angle_offset;
	vec3 sensor_dir = vec3(cos(sensor_angle), sin(sensor_angle), 0.0);
	vec3 sensor_pos = vec3(x, y, 0.0) + sensor_dir * settings.sensor_distance;
	int sensor_centre_x = int(sensor_pos.x);
	int sensor_centre_y = int(sensor_pos.y);
	float sum = 0.0;

    int dist = int(settings.sensor_size);
	for (int offset_x = -dist; offset_x <= dist; offset_x += 1) {
		for (int offset_y = -dist; offset_y <= dist; offset_y += 1) {
			int pos_x = sensor_centre_x + offset_x;
			int pos_y = sensor_centre_y + offset_y;
			int sample_x = max(0, min(int(settings.width) - 1, pos_x));
			int sample_y = max(0, min(int(settings.height) - 1, pos_y));
			sum += imageLoad(trails_in, ivec2(sample_x, sample_y)).x;
		}
	}

	return sum;
}

void update_slime(int i) {
	float x = slimes.data[i];
	float y = slimes.data[i+1];
	float angle = slimes.data[i+2];

    vec2 weights[3] = {
        vec2(0.0, sense(angle, x, y, 0.0)),
        vec2(-settings.sensor_angle_offset, sense(angle, x, y, -settings.sensor_angle_offset * TO_PI)),
        vec2(settings.sensor_angle_offset, sense(angle, x, y, settings.sensor_angle_offset * TO_PI)),
    };
    vec2 best_weight = vec2(0.0, 0.0);
    for(int j = 0;j < 3;j++){
        if (weights[j].y > best_weight.y){
            best_weight = weights[j];
        }
    }

	float random_steer_strength = settings.random_steer;
	float turn_speed = settings.slime_turn_speed * 2.0 * 3.1415;

	// Continue in same direction
    float new_angle = angle + best_weight.x * TO_PI * random_steer_strength * turn_speed * settings.time_delta;

	float new_x = x + settings.time_delta * settings.slime_move_speed * cos(angle);
	float new_y = y + settings.time_delta * settings.slime_move_speed * sin(angle);
    if (new_x <= 0 || new_x >= settings.width - 1 || new_y <= 0 || new_y >= settings.height - 1) {
        new_angle = settings.random_angle * 2.0 * PI;
    }
	new_x = max(0.0, min(settings.width - 1.0, new_x));
	new_y = max(0.0, min(settings.height - 1.0, new_y));
    new_angle = max(0.0, min(2.0 * PI, new_angle));

	slimes.data[i] = new_x;
	slimes.data[i+1] = new_y;
	slimes.data[i+2] = new_angle;
}

// The code we want to execute in each invocation
void main() {
	ivec2 gidx = ivec2(gl_GlobalInvocationID.xy);
	if (gidx.x >= settings.no_slimes) {
		return;
	}
    int idx = 3 * gidx.x;
    float prev_value = imageLoad(trails_in, ivec2(slimes.data[idx], slimes.data[idx+1])).x + settings.trail_weight * settings.time_delta;
	imageStore(trails_in, ivec2(slimes.data[idx], slimes.data[idx+1]), vec4(vec3(prev_value), 1.0));
	update_slime(idx);
}

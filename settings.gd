extends Object

class_name Settings

var width: float;
var height: float;
var no_slimes: int;
var time_delta: float = 0.0;
var random_steer: float = 1.0;
var random_angle: float = 1.0;

static func bytes_size() -> int:
	return 8 + 8 + 8 + 8 + 8 + 8;

func _init(width: float, height: float, no_slimes: int):
	self.width = width;
	self.height = height;
	self.no_slimes = no_slimes;

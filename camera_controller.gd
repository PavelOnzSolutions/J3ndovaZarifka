extends Camera3D
## Free-look camera.
##   * Arrow keys  -> move (forward/back + strafe), kept horizontal.
##   * Mouse       -> tilt/look (yaw + pitch), FPS style.
##   * Escape      -> toggle capturing the mouse.

@export var move_speed: float = 4.0
@export var mouse_sensitivity: float = 0.0025
@export var pitch_limit_deg: float = 80.0

var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	# Seed yaw/pitch from the scene's starting orientation so the view
	# doesn't jump on the first frame.
	_yaw = rotation.y
	_pitch = rotation.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		var limit := deg_to_rad(pitch_limit_deg)
		_pitch = clamp(_pitch, -limit, limit)
		# YXZ Euler order gives clean FPS yaw/pitch with no roll.
		rotation = Vector3(_pitch, _yaw, 0.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			else Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		input.z -= 1.0
	if Input.is_action_pressed("ui_down"):
		input.z += 1.0
	if Input.is_action_pressed("ui_left"):
		input.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		input.x += 1.0

	if input != Vector3.ZERO:
		# Move relative to where we're facing (yaw only -> stays level).
		var dir := Basis(Vector3.UP, _yaw) * input.normalized()
		position += dir * move_speed * delta

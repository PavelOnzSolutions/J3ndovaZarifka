extends OmniLight3D
## Drives the cast light's energy so the room flickers together with the tube's
## emissive shader. A shader can only affect the surface it runs on, so the
## actual Light3D needs its own (matching) flicker to make the effect believable.

@export var base_energy: float = 2.6
@export var flicker_speed: float = 11.0
@export var flicker_amount: float = 0.18
@export var blink_chance: float = 0.04

var _t: float = 0.0
var _noise_seed: float = 0.0

func _ready() -> void:
	# Random phase so reruns don't look identical.
	_noise_seed = randf() * 100.0

func _process(delta: float) -> void:
	_t += delta
	var t := _t + _noise_seed

	# Same recipe as incandescent_tube.gdshader so light and surface agree.
	var f1 := sin(t * flicker_speed)
	var f2 := sin(t * flicker_speed * 2.73 + 1.3)
	var f3 := sin(t * flicker_speed * 0.41 + 4.1)
	var n := (sin(t * flicker_speed * 5.3) * 0.5 + sin(t * 37.0) * 0.5) # cheap jitter

	var wobble := 0.45 * f1 + 0.20 * f2 + 0.15 * f3 + 0.40 * n
	var flicker := 1.0 - flicker_amount * (0.5 + 0.5 * wobble)

	# Occasional brief deep dip.
	if randf() < blink_chance * delta * 60.0:
		flicker *= 0.4

	light_energy = max(0.0, base_energy * flicker)

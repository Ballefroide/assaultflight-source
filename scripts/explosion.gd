class_name Explosion
extends Node2D

## A one-shot particle burst used when a missile blows up.
## Frees itself automatically once the particle burst finishes.


func _ready() -> void:
	add_to_group("explosions")
	var particles: CPUParticles2D = $CPUParticles2D
	particles.one_shot = true
	particles.emitting = true
	particles.finished.connect(queue_free)

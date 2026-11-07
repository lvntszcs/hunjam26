class_name ScreenFader
extends ColorRect
## Full-screen overlay used to fade between views.

@export var default_duration := 0.3


## Tweens the overlay's alpha to [param alpha]; returns when finished.
func fade_to(alpha: float, duration: float = default_duration) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", alpha, duration)
	await tween.finished

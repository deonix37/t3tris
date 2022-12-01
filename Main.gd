extends Node

@onready var hud := $HUD as HUD

func _on_field_lines_completed(score: int) -> void:
    hud.update_score(score)

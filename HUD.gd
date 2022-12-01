class_name HUD

extends CanvasLayer

@onready var score_label := $ScoreLabel as Label

func update_score(score: int) -> void:
    score_label.text = str(score)

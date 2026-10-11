# spike.gd
extends Area2D

@onready var tags: TagComponent = $TagComponent

func _ready() -> void:
	tags.add_tag("real_sensor")

func _on_body_entered(body: Node2D) -> void:
	var t = body.get_node_or_null("TagComponent")
	if t == null:
		return
	if not t.has_tag("real_alive"):
		return
	if body.has_method("die"):
		body.die()

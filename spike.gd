# Spike.gd
extends Area2D

@onready var tags: TagComponent = $TagComponent

func _ready() -> void:
	tags.add_tag("real")
	tags.add_tag("harmful")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var other = body.get_node_or_null("TagComponent")
	if other and other.has_tag("mortal"):
		body.die()

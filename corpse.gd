# Corpse.gd
extends RigidBody2D

@onready var tags: TagComponent = $TagComponent

func _ready() -> void:
	tags.add_tag("real_body")  
	GameState.world_changed.connect(_on_world_changed)
	_on_world_changed(GameState.current_world)

func _on_world_changed(world: int) -> void:
	var is_real := world == GameState.World.REAL
	visible = is_real
	freeze = not is_real   # 灵魂世界时冻结

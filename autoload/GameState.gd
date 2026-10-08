# GameState.gd
extends Node

enum World { REAL, VIRTUAL }
var current_world: World = World.REAL

signal world_changed(new_world: World)

func set_world(world: World) -> void:
	if current_world == world:
		return
	current_world = world
	world_changed.emit(world)

func reset() -> void:
	current_world = World.REAL

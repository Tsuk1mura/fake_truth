# GameState.gd
extends Node

enum World { REAL, VIRTUAL }
var current_world: World = World.REAL
# 复活点：由 World 在开局记录主角初始位置。R 键复活时回到这里。
var spawn_position: Vector2 = Vector2.ZERO

signal world_changed(new_world: World)

func set_world(world: World) -> void:
	if current_world == world:
		return
	current_world = world
	world_changed.emit(world)

func reset() -> void:
	# 走 set_world 才能发出 world_changed，否则重置后
	# 所有 BodyMasker 还以为自己在旧世界里（可见性和冻结状态不会恢复）
	set_world(World.REAL)

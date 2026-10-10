# World.gd
extends Node2D

@onready var real_tilemap: TileMapLayer = $RealTileMap
@onready var virtual_tilemap: TileMapLayer = $VirtualTileMap
@onready var camera_2d: Camera2D = $Player/Camera2D

func _ready() -> void:
	var used := real_tilemap.get_used_rect()
	var tile_size := real_tilemap.tile_set.tile_size
	
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_right = used.end.x * tile_size.x
	camera_2d.limit_bottom = used.end.y * tile_size.y
	camera_2d.limit_left = used.position.x * tile_size.x
	camera_2d.reset_smoothing()
	
	GameState.world_changed.connect(_on_world_changed)
	_on_world_changed(GameState.current_world)

func _on_world_changed(world: int) -> void:
	var is_real := world == GameState.World.REAL
	real_tilemap.visible = is_real
	virtual_tilemap.visible = not is_real
	# 碰撞不用管，玩家自己的掩码决定

# World.gd
extends Node2D

@onready var real_tilemap: TileMapLayer = $RealTileMap
@onready var virtual_tilemap: TileMapLayer = $VirtualTileMap

func _ready() -> void:
	GameState.world_changed.connect(_on_world_changed)
	_on_world_changed(GameState.current_world)

func _on_world_changed(world: int) -> void:
	var is_real := world == GameState.World.REAL
	real_tilemap.visible = is_real
	virtual_tilemap.visible = not is_real
	# 碰撞不用管，玩家自己的掩码决定

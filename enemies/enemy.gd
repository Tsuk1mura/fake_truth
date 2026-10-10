class_name Enemy
extends CharacterBody2D

enum Direction {
	RIGHT = +1,
	LEFT = -1
}

@export var direction := Direction.RIGHT:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = -direction
@export var max_speed: float = 180
@export var acceleration: float = 2000

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float

@onready var graphics: Node2D = $Graphics
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var stats: Stats = $Stats



func move(speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x,direction * speed,acceleration * delta) #有加速度的移动有
	velocity.y +=default_gravity * delta	
	
	move_and_slide()



func die() -> void:
	queue_free()

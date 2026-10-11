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
@onready var tags: TagComponent = $TagComponent


## 敌人的碰撞层/掩码在 enemy.tscn 里手配（layer 16 RealEnemy / mask 3），
## 故意不挂 BodyMasker：BodyMasker 会在找不到身份标签时改写碰撞，
## 而敌人的身份永远不变，不需要那套动态机制。
func _ready() -> void:
	tags.add_tag("real_alive")   # ★ 让地刺能对所有"活着的现实生物"生效



func move(speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x,direction * speed,acceleration * delta) #有加速度的移动有
	velocity.y +=default_gravity * delta	
	
	move_and_slide()



func die() -> void:
	queue_free()

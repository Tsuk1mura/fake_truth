class_name Player
extends CharacterBody2D

enum State {
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	KICK,
	ROLL,
	HURT,
	DYING
}

const GROUND_STATE := [State.IDLE, State.RUNNING,State.LANDING,State.KICK] #在地面的状态
const RUN_SPEED := 160.0 #跑速
const FLOOR_ACCELERATION =RUN_SPEED / 0.2 #地面加速度
const AIR_ACCELERATION =RUN_SPEED / 0.02 #空中加速度
const JUMP_VELOCITY := -300.0 #跳跃量
const KNOCKBACK_AMOUNT := 512.0 #击飞

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false
var pending_damage: Damage

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer #郊狼时间
@onready var jump_request_timer: Timer = $JumpRequestTimer #跳跃预输入
@onready var stats: Stats = $Stats


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	if event.is_action_released("jump") and velocity.y < JUMP_VELOCITY / 2:
		velocity.y = JUMP_VELOCITY / 2 

func tick_physics(state:State, delta: float) -> void: #每帧做的事
	match state:
		State.IDLE:
			move(default_gravity, delta)
		
		State.RUNNING:
			move(default_gravity, delta)
		
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
		
		State.FALL:
			move(default_gravity, delta)
		
		State.LANDING:
			stand(delta)
		
		State.KICK:
			move(default_gravity, delta)
		
		State.HURT, State.DYING:
			stand(delta)
	
	
	is_first_tick = false
	


func move(gravity:float,delta: float) ->void:	 #移动
	var direction := Input.get_axis("move_left","move_right")
	var acceleration = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x,direction * RUN_SPEED,acceleration * delta) #有加速度的移动有
	velocity.y +=gravity * delta	
	
	if not is_zero_approx(direction):
		sprite_2d.flip_h = direction <  0
	
	move_and_slide()


func stand(delta:float) -> void:
	var acceleration = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x,0.0,acceleration * delta) #有加速度的移动
	velocity.y +=default_gravity * delta	
	
	move_and_slide()

func die() -> void:
	pass

func get_next_state(state: State) -> int: #输入改变
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else   State.DYING
	
	if pending_damage:
		return State.HURT
	
	var can_jump := is_on_floor() or coyote_timer.time_left > 0 
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	if state in GROUND_STATE and not is_on_floor():
		return State.FALL
	
	var direction := Input.get_axis("move_left","move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("kick"):
				return State.KICK
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if Input.is_action_just_pressed("kick"):
				return State.KICK
			if is_still:
				return State.IDLE
		
		State.JUMP:
			if velocity.y >=0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				return State.LANDING
		
		State.LANDING:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.KICK:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.ROLL:
			pass
		
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.DYING:
			pass
		
	return StateMachine.KEEP_CURRENT


func transition_state(from:State, to:State) -> void: #状态改变：from，to
	
	if from not in GROUND_STATE and to in GROUND_STATE:
		coyote_timer.stop()
	
	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.RUNNING:
			animation_player.play("running")
		
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
		
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATE:
				coyote_timer.start()
		
		State.LANDING:
			animation_player.play("landing")
			
		State.KICK:
			animation_player.play("kick1")
		
		State.HURT:
			animation_player.play("hit")
			
			stats.health -= pending_damage.amount
			
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			
			pending_damage = null
		
		State.DYING:
			animation_player.play("dead")
	
	is_first_tick = true


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner

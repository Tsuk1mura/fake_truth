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
	DYING,
	DEAD
}

const GROUND_STATE := [State.IDLE, State.RUNNING,State.LANDING,State.KICK] #在地面的状态
const RUN_SPEED := 160.0 #跑速
const FLOOR_ACCELERATION =RUN_SPEED / 0.2 #地面加速度
const AIR_ACCELERATION =RUN_SPEED / 0.02 #空中加速度
const JUMP_VELOCITY := -300.0 #跳跃量
const KNOCKBACK_AMOUNT := 512.0 #击飞
const CORPSE_SCENE := preload("res://corpse.tscn")
const DEAD_TINT := Color(0.0, 81.0 / 255.0, 1.0, 1.0)
const ALIVE_TINT := Color.WHITE
const PUSH_GAIN := 3.0        # 推力增益：玩家速度 × 这个系数
const PUSH_MIN_SPEED := 5.0 

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false
var pending_damage: Damage
var _is_dead := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer #郊狼时间
@onready var jump_request_timer: Timer = $JumpRequestTimer #跳跃预输入
@onready var stats: Stats = $Stats
@onready var graphics: Node2D = $Graphics
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var state_machine: StateMachine = $StateMachine
@onready var tags: TagComponent = $TagComponent
@onready var push_area: Area2D = $Graphics/PushArea

func _ready() -> void:
	tags.add_tag("real_player")
	tags.add_tag("real_alive")
	push_area.body_entered.connect(_on_push_body_entered)


func _on_push_body_entered(body: Node2D) -> void:
	push_body(body, 1.0 / 60.0)

func _physics_process(delta: float) -> void:
	for body in push_area.get_overlapping_bodies():
		push_body(body, delta)

func push_body(body: Node2D, delta: float) -> void:
	if not body is RigidBody2D:
		return

	var t = body.get_node_or_null("TagComponent")
	if t == null:
		return

	# ★ 标签驱动：只能推动"和自己同世界"的身体。
	# 注意要用正向判断（必须是 real_player 才能推 real_body），
	# 不能用 `if real_player else dead_body` —— 那样死亡形态(dead_player)
	# 会去推 dead_body，而目前尸体永远只有 real_body 标签，
	# 结果是"死亡形态能推、活着的形态推不动"，完全反了。
	if not tags.has_tag("real_player"):
		return
	if not t.has_tag("real_body"):
		return

	# ★ 核心：推力正比于当前水平速度
	var speed := velocity.x
	if absf(speed) < PUSH_MIN_SPEED:
		return

	# speed 自带正负号，方向不需要另外算
	body.apply_central_impulse(Vector2(speed * PUSH_GAIN * delta, 0.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	if event.is_action_released("jump") and velocity.y < JUMP_VELOCITY / 3:
		velocity.y = JUMP_VELOCITY / 3 
	if event.is_action_pressed("restart"):   
		revive_at(GameState.spawn_position)

func tick_physics(state:State, delta: float) -> void: #每帧做的事
	if invincible_timer.time_left > 0:
		graphics.modulate.a = sin(Time.get_ticks_msec() / 20.0) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1
	
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
		
		State.DEAD:
			move(default_gravity / 2.0, delta)
	
	
	is_first_tick = false
	


func move(gravity:float,delta: float) ->void:	 #移动
	var direction := Input.get_axis("move_left","move_right")
	var acceleration = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x,direction * RUN_SPEED,acceleration * delta) #有加速度的移动有
	velocity.y +=gravity * delta	
	
	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction <  0 else 1
	
	move_and_slide()


func stand(delta:float) -> void:
	var acceleration = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x,0.0,acceleration * delta) #有加速度的移动
	velocity.y +=default_gravity * delta	
	
	move_and_slide()

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	if tags.has_tag("real_player"):
		_first_death()      
	else:
		_true_death()

func _first_death() -> void:
	_spawn_corpse()
	_enter_dead_form()
	stats.reset()                                  
	pending_damage = null
	invincible_timer.start()                   
	state_machine.current_state = State.DEAD 

func _true_death() -> void:
	GameState.reset()
	get_tree().reload_current_scene()

func _spawn_corpse() -> void:
	var corpse := CORPSE_SCENE.instantiate()
	# ★ 必须先设位置再 add_child：add_child 会同步跑完 corpse._ready()
	corpse.global_position = global_position + Vector2(0, -8)
	corpse.rotation = 0.0
	# ★ 绝对不要把玩家的 collision_layer / collision_mask 复制给尸体！
	# 尸体的层由它自己的 real_body 标签 + BodyMasker 决定（layer 256 / mask 785）。
	# 复制玩家的层会让尸体变成"第二个玩家"，同时覆盖掉 BodyMasker 的配置。
	get_parent().add_child(corpse)

func _enter_dead_form() -> void:
	var t := graphics.modulate
	graphics.modulate = Color(DEAD_TINT.r, DEAD_TINT.g, DEAD_TINT.b, t.a)

	# 换身份：BodyMasker 监听到 tags_changed 会自动把层切到 DeathPlayer
	tags.remove_tag("real_player")
	tags.remove_tag("real_alive")
	tags.add_tag("dead_player")
	
	GameState.set_world(GameState.World.VIRTUAL)

## 当前形态的"闲置态"是哪个
func _idle_state() -> int:
	return State.DEAD if tags.has_tag("dead_player") else State.IDLE

func get_next_state(state: State) -> int: #输入改变
	if _is_dead:
		return StateMachine.KEEP_CURRENT
	
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
		State.DEAD:
			if not is_still:
				return State.RUNNING
			return StateMachine.KEEP_CURRENT
		
		State.IDLE:
			if Input.is_action_just_pressed("kick"):
				return State.KICK
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if Input.is_action_just_pressed("kick"):
				return State.KICK
			if is_still:
				return _idle_state()
		
		State.JUMP:
			if velocity.y >=0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				return State.LANDING
		
		State.LANDING:
			if not animation_player.is_playing():
				return _idle_state()
		
		State.KICK:
			if not animation_player.is_playing():
				return _idle_state()
		
		State.ROLL:
			pass
		
		State.HURT:
			if not animation_player.is_playing():
				return _idle_state()
		
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
			invincible_timer.start()
		
		State.DYING:
			animation_player.play("dead")
			invincible_timer.stop()
		
		State.DEAD:
			animation_player.play("idle")  
			_is_dead = false                
			invincible_timer.stop()
	
	is_first_tick = true


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	if invincible_timer.time_left > 0:
		return
	
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner


#复活函数
func revive_at(pos: Vector2 = global_position) -> void:
	# 1) 只有死亡形态才需要复活
	if not tags.has_tag("dead_player"):
		return

	# 2) 换身份标签（BodyMasker 自动把层切回 RealPlayer）
	tags.remove_tag("dead_player")
	tags.add_tag("real_player")
	tags.add_tag("real_alive")           # ★ 重新变回"活着的现实生物"

	# 3) 恢复视觉
	var t := graphics.modulate
	graphics.modulate = Color(ALIVE_TINT.r, ALIVE_TINT.g, ALIVE_TINT.b, t.a)

	# 4) 血量补满
	stats.reset()

	# 5) 位置和速度
	global_position = pos
	velocity = Vector2.ZERO

	# 6) 清掉残留状态
	pending_damage = null
	invincible_timer.start()             # 复活后给一段无敌

	# 7) 回实类世界
	GameState.set_world(GameState.World.REAL)

	# 8) 解除锁 + 强制切闲置态
	#    注意顺序：_is_dead 必须先清，否则 current_state 的赋值会被 get_next_state 的锁挡住
	_is_dead = false
	state_machine.current_state = State.IDLE

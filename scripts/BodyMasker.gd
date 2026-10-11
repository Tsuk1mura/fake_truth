class_name BodyMasker
extends Node

## 把 TagComponent 的标签翻译成物理层/掩码。
## 挂载规则：必须和 TagComponent 平级，且父节点是 CollisionObject2D。

## 每个身份标签 -> { layer, mask }
## layer = 我是谁；mask = 我要撞谁
## ★ 注意：mask 里必须含"对方的 layer"才能碰撞，Godot 要求双方互相认可。
const PROFILES := {
	# ---- 实类世界 ----
	# 3 RealPlayer -> 1 RealEnv + 16 RealEnemy + 256 RealBody + 512 DeathBody
	"real_player":  { "layer": 4,   "mask": 785  },
	# 9 RealBody -> 1 RealEnv + 16 RealEnemy + 256 RealBody + 512 DeathBody
	"real_body":    { "layer": 256, "mask": 785  },
	"real_sensor":  { "layer": 64,  "mask": 529  },  # 7 RealSensor  -> 1 + 16 + 512
	"real_tile":    { "layer": 1,   "mask": 789  },  # 1 RealEnv     -> 1 + 4 + 16 + 256 + 512
	# ---- 死亡世界 ----
	"dead_player":  { "layer": 8,   "mask": 514  },  # 4 DeathPlayer -> 2 DeathEnv + 512 DeathBody
	"dead_body":    { "layer": 512, "mask": 529  },  # 10 DeathBody  -> 1 + 16 + 512
	"dead_sensor":  { "layer": 128, "mask": 520  },  # 8 DeathSensor -> 8 + 512
	"dead_tile":    { "layer": 2,   "mask": 522  },  # 2 DeathEnv    -> 2 + 8 + 512
	# ---- 受击盒不受标签影响，固定值 ----
	"hurtbox":      { "layer": 16,  "mask": 0    },  # 5 PlayerHurtbox
}

## 身份标签的优先级：上面的压过下面的
const IDENTITY_PRIORITY := [
	"dead_player", "real_player",
	"dead_body", "real_body",
	"dead_sensor", "real_sensor",
	"dead_tile", "real_tile",
	"hurtbox",
]

@export var tag_component_path: NodePath = ^"../TagComponent"

var _tags: TagComponent
var _body: CollisionObject2D


func _ready() -> void:
	_body = get_parent() as CollisionObject2D
	if _body == null:
		push_error("BodyMasker 的父节点必须是 CollisionObject2D，当前是 %s" % get_parent())
		return

	_tags = get_node_or_null(tag_component_path) as TagComponent
	if _tags == null:
		push_error("BodyMasker 找不到 TagComponent: %s" % tag_component_path)
		return

	_tags.tags_changed.connect(refresh)
	# ★ 不能在 _ready() 里直接 refresh()：
	#   Godot 的子节点先于父节点 _ready()，所以此刻父节点（Player/Enemy/corpse）
	#   的 _ready() 还没跑、标签还没加，refresh() 必然找不到身份标签。
	#   用 set_deferred 推迟到本帧所有 _ready() 结束后再执行一次。
	#   如果父节点后续再加/换标签，tags_changed 信号会立刻触发 refresh，
	#   所以死亡时 real_player -> dead_player 的切换仍然是实时的。
	_refresh_deferred.call_deferred()


func _refresh_deferred() -> void:
	refresh()


func refresh() -> void:
	if _body == null or _tags == null:
		return

	for identity in IDENTITY_PRIORITY:
		if _tags.has_tag(identity):
			var p: Dictionary = PROFILES[identity]
			_set_deferred_layers(p["layer"], p["mask"])
			return

	# ★ 没有任何身份标签时"什么都不做"，保留场景里手配的碰撞值。
	#   原来这里写的是 _set_deferred_layers(0, 0)，会在"忘记加标签"时
	#   静默地把碰撞清零（表现为物体直接穿过地面掉出地图），极难排查。
	#   敌人(enemy.tscn)就是靠手配碰撞 + 不加 BodyMasker 来避免这个坑的。
	push_warning("BodyMasker: '%s' 没有任何身份标签，保留原有碰撞配置" % get_parent().name)

func _set_deferred_layers(layer: int, mask: int) -> void:
	_body.set_deferred("collision_layer", layer)
	_body.set_deferred("collision_mask", mask)

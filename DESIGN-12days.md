# fake-truth 12 天方案：把「尸体留存」打通成涌现闭环

> 本文只出方案，不改代码。所有改动点都标了**文件 + 具体行 + 原因**，可以直接照着写。
> 前提结论（已完成代码核对）：`player.gd` / `corpse.gd` / `spike.gd` / `GameState.gd` 有真实实现；
> `world.tscn` 是个空壳（只有两张 TileMap、一个 Player、两个刺），readme 里「已实现」清单部分不实。

---

## 零、先讲一个判断，它决定后面所有取舍

你现在的死亡循环是：

```
踩刺 → 换灵魂态 → 15 秒 → reload_current_scene() → 世界完全重置
```

这条循环里**没有任何东西被记住**。尸体随场景一起销毁，灵魂态本质是个倒计时惩罚。
而 readme 第 51 行写的是「答案在世界里，不在玩家脑子里」——代码里世界不承载任何答案。

**所以你的「涌现」目前不是设计不够，是闭环断了。** 涌现的最小充分条件是三条：

1. **规则正交** —— 你已经有了（实/虚标签 + `TagComponent`）
2. **状态持久** —— **缺**。尸体必须活得比玩家久
3. **反馈可读** —— **缺**。玩家必须看见「我上次的尸体还在，而且它在起作用」

12 天做不完 readme 的 20 天计划（灯 + 贪吃兽 + 附身 + 双世界谜题 + UI + 美术）。
但只要把第 2、3 条补上，**一个房间就足以让主题立住**。下面全按这个来。

---

## 一、12 天排期

| 天 | 目标 | 验收标准 |
|---|---|---|
| D1 | 修 4 个硬 bug（见第二节） | 游戏能正常跑：有画面、灵魂态不穿地形、能看见角色 |
| D2–D4 | **尸体持久化**（第三节） | 死 3 次，地上留 3 具尸体，灵魂态死后尸体不消失 |
| D5–D6 | 压力板 + 门（第四节） | 尸体压住压力板，门保持打开 |
| D7–D8 | 关卡几何 + **可读性**（第五、六节） | 陌生玩家 5 分钟内自己发现「要死在那里」 |
| D9–D10 | 灯（第七节，如果前面顺利） | 灯能踮脚、能按压力板、两世界共享位置 |
| D11 | 调参 + 删没人用的交互 | 删掉的东西比加的多 |
| D12 | 打包、录 GIF、写商店页 | 能发布 |

**D1–D8 是保底线。做完 D8 你就有一个能拿出手的完整作品。** D9–D10 是加分项，做不完不心疼。

> 如果 D4 结束时尸体持久化还没跑通，**跳过压力板，直接进 D7–D8 的可读性**。
> 让玩家看见 3 具尸体堆在同一个坑里，比一个跑不通的机关有价值得多。

---

## 二、D1：4 个必修的 bug

### Bug 1（阻断级）虚类地形对灵魂态没有碰撞

**文件**：`world.tscn` 第 36–37 行

```
[sub_resource type="TileSet" id="TileSet_036b0"]
physics_layer_0/collision_layer = 2
physics_layer_0/collision_mask = 2
```

`player.gd` 第 131 行灵魂态 `set_collision_mask_value(2, true)`（掩码=层2）是对的，
但**虚类 TileSet 自己的 `collision_mask = 2` 只检测层 2，永远检测不到层 5（PlayerSoul）**。
TileMap 的碰撞要双方都成立，所以灵魂态直接穿过虚类地形掉出地图。

**改**：`physics_layer_0/collision_mask = 2` → `physics_layer_0/collision_mask = 34`

`34 = 2 | 32 = 层2(虚类自己) | 层6(灵魂态玩家)`

> 为什么不是 `5`：层号在下面 Bug 2 里被重排了，别用旧编号。

### Bug 2（隐形炸弹）物理层完全没有命名

`project.godot` 里 `[layer_names]` 段只有一行 `2d_physics/canvas_textures/default_texture_filter=1`，
**7 个物理层全是匿名的**。现在所有脚本里都是裸数字 `set_collision_mask_value(2, true)` ——
你三个月后回来看这张表，没人知道层 2 是什么。

**改**：把 `project.godot` 的 `[layer_names]` 段替换成：

```ini
[layer_names]

2d_physics/layer_1="Real"
2d_physics/layer_2="Virtual"
2d_physics/layer_3="Interactable"
2d_physics/layer_4="PlayerReal"
2d_physics/layer_5="PlayerSoul"
2d_physics/layer_6="Corpse"
2d_physics/layer_7="Lamp"
2d_render/layer_1="RealWorld"
2d_render/layer_2="VirtualWorld"
```

> 注意：`project.godot` 里层号是 `layer_1` = 层 1，但脚本 API 是 `set_collision_mask_value(1, true)` = 层 1。
> 两者对得上，唯一陷阱是 `set_collision_mask_value(0, ...)` 才是第 1 层 —— **索引从 0 开始。**
> 建议以后统一用 `CollisionObject2D.collision_layer = 0b...` 的位掩码写法，比 `set_..._value` 更难写错。

**权威层表**（照着填，别再自由发挥）：

| 层 | 名称 | 谁在上面 |
|---|---|---|
| 1 | Real | 实类 TileMap、实类 RigidBody/StaticBody、实类道具 |
| 2 | Virtual | 虚类 TileMap、虚类刚体 |
| 3 | Interactable | 压力板、门、可拾取物 |
| 4 | PlayerReal | 实类形态玩家 |
| 5 | PlayerSoul | 灵魂态玩家 |
| 6 | Corpse | 尸体 |
| 7 | Lamp | 灯（唯一双属性） |

**掩码表**：

| 物体 | layer | mask（十进制） | mask 位 | 说明 |
|---|---|---|---|---|
| RealTileMap | 1 | 1+4+6=**11** | 1,4,6 | 撞实类、实类玩家、尸体 |
| VirtualTileMap | 2 | 2+5+7=**34** | 2,5,7 | 撞虚类、灵魂态、灯 |
| Player 实类形态 | 4 | 1+6=**6** | 1,6 | 撞实类墙、撞尸体 |
| Player 灵魂态 | 5 | 2=**2** | 2 | 只撞虚类 |
| Corpse（RigidBody2D） | 6 | 1+6=**10** | 1,6 | 落在地面、尸体能互相堆叠 |
| Spike（Area2D） | 3 | 4+6=**40** | 4,6 | 只检测实类玩家 + 尸体 |
| Lamp | 7 | 1+2+6=**14** | 1,2,6 | 能停在实类地也能停在虚类地 |

> **零成本验证**：改完在 Godot 里开 `调试 → 可见碰撞形状`，跑一遍。
> 灵魂态应该踩在虚类平台上，而不是掉下去。
> 顺便：`corpse.tscn` 的 RigidBody2D **没有设任何 layer/mask**，
> 现在它是默认「layer 1 / mask 1」，所以它「恰好」能落在地面上。
> 一旦你按上表改成 layer 6 / mask 10，它照样对，但这不再是巧合。

### Bug 3（观感全毁）角色精灵全部错位

`player.tscn` 里 `Sprite2D` 的 `region_rect` 全是错的，角色会渲染成一条竖着的长条或纯色块。

**文件**：`player.tscn`，逐个改 `region_rect`：

| 动画 | 现在（错） | 改成 |
|---|---|---|
| idle | `Rect2(0, -4, 128, 32)` | `Rect2(0, 0, 128, 32)` |
| running | `Rect2(0, 60, 256, 64)` | `Rect2(0, 4, 128, 32)` |
| jump | `Rect2(32, 60, 64, 32)` | `Rect2(0, 36, 128, 32)` |
| death | `Rect2(0, 220, 128, 32)` | `Rect2(0, 40, 128, 32)` |
| hit | `Rect2(0, 188, 128, 32)` | `Rect2(0, 44, 128, 32)` |
| roll | `Rect2(0, 156, 256, 32)` | **删掉这个动画**（用不到，readme 里也没这动作） |

**同时改帧数**：每个动画的 `hframes` 设 `4`、`vframes` 设 `1`，
`frame` 关键帧的 `values` 分别是 `[0,1,2,3]`（idle/death/hit）、`[0,1]`（jump）、`[0..3]`（running）。

> ⚠️ 我**没有你的 `knight.png` 实际排版**，上面的 Y 偏移是按「每行 32px、行距 4px」猜的。
> **正确做法**：在 Godot 里双击 `resources/knight.png` 打开 SpriteFrames 编辑器，
> 我强烈建议改用 **`AnimatedSprite2D` + `SpriteFrames` 资源**替代现在的 `Sprite2D + region_rect + AnimationPlayer` 方案，
> 因为 region_rect 手算偏移是这个 bug 的根源，而 SpriteFrames 有可视化编辑器。
> 这是 D1 里唯一可能需要花半天的事，值得。

### Bug 4 没有摄像机

`player.tscn` 里**没有 `Camera2D`**，而视口只有 `384x216`。
角色一走出屏幕左上角就再也看不见了 —— 现在完全没法玩。

**改**：在 `player.tscn` 里加一个 `Camera2D` 子节点：

```
[node name="Camera2D" type="Camera2D" parent="."]
position_smoothing_enabled = true
position_smoothing_speed = 8.0
limit_left = 0
limit_top = 0
limit_right = 384
limit_bottom = 216
```

> 低分辨率下平滑跟随会有像素抖动，如果画面看起来在「游泳」，
> 关掉 `position_smoothing_enabled`，或者给 Camera2D 开 `Snap 2D Transforms to Pixel`（项目设置里）。

---

## 三、D2–D4：尸体持久化（**本次的核心**）

这一节是整份文档里唯一不能妥协的部分。

### 3.1 病根

`player.gd` 第 139–140 行：

```gdscript
func _permanent_death() -> void:
	get_tree().reload_current_scene()
```

`reload_current_scene()` 会重建整棵场景树，**所有尸体连骨灰都不剩**。
只要这一行还在，「死在哪里」就永远不可能是一个解。

### 3.2 数据层：`GameState.gd` 加一条持久记录

`GameState` 是 Autoload，场景重载不会销毁它，所以它是天然的存档位。

**在 `autoload/GameState.gd` 末尾追加**：

```gdscript
# ---------- 尸体持久化 ----------
# 每具尸体：{"pos": Vector2, "rot": float, "tags": Array[String]}
var corpses: Array[Dictionary] = []

func add_corpse(pos: Vector2, rot: float, tags: Array[String]) -> void:
	corpses.append({"pos": pos, "rot": rot, "tags": tags.duplicate()})

func clear_corpses() -> void:
	corpses.clear()
```

> **为什么存 `tags` 而不是只存坐标**：readme 第 63 行说贪吃兽是「标签转换器」。
> 一旦你以后做贪吃兽吃掉尸体、尸体变成虚类方块，尸体的标签就是会变的。
> 现在多存一个数组是零成本，以后能省一次重构。
> **这是这份方案里唯一一处「为未来多写一行」，其余地方我都建议往死里砍。**

### 3.3 存档点：`SpawnPoint`

**新建 `spawn_point.gd`**：

```gdscript
extends Area2D
class_name SpawnPoint

func _ready() -> void:
	tags_init()
	body_entered.connect(_on_body_entered)

func tags_init() -> void:
	var t = get_node_or_null("TagComponent")
	if t:
		t.add_tag("real")
		t.add_tag("interactable")

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		GameState.set_spawn(global_position)
```

`GameState.gd` 再加：

```gdscript
var spawn_position: Vector2 = Vector2.ZERO

func set_spawn(pos: Vector2) -> void:
	spawn_position = pos
```

**层级**：`SpawnPoint` 的 `collision_layer = 8`（层4 PlayerReal），
`mask = 0`；玩家实类形态 mask 6 不含层 3，所以**需要在 `player.gd` 里加层 3 到实类掩码**，
或者更省事的做法 —— **别用 Area2D，用 `_ready()` 里把 `GameState.spawn_position` 设成出生点坐标就行**。

> **建议直接用最省事的**：D2 阶段不要做「动态存档点」。
> 开一局就一个固定出生点，`World._ready()` 里 `GameState.set_spawn($SpawnPoint.global_position)`。
> 动态存档点是 D11 有余力再说的事 —— 它跟涌现主题没关系。

### 3.4 尸体改造：`corpse.gd`

现在 `corpse.gd` 第 6–9 行把标签**硬编码**在 `_ready()` 里，
所以从存档恢复的尸体会丢掉它原本的标签（以后被贪吃兽改过的尸体就还原不回去了）。

**改 `corpse.gd` 全文**：

```gdscript
extends RigidBody2D

@onready var tags: TagComponent = $TagComponent

# 由生成方在 add_child 之前/之后注入；为空则用默认标签
var initial_tags: Array[String] = []

func _ready() -> void:
	if initial_tags.is_empty():
		initial_tags = ["real", "corpse", "body"] as Array[String]
	for t in initial_tags:
		tags.add_tag(t)

	# 物理参数：让尸体「停下」而不是永远滑
	gravity_scale = 1.0
	linear_damp = 4.0        # 关键：默认 0，被推一下会滑到天荒地老
	angular_damp = 4.0
	can_sleep = true

	GameState.world_changed.connect(_on_world_changed)
	_on_world_changed(GameState.current_world)
	GameState.add_corpse(global_position, rotation, tags.tags)

func _on_world_changed(world: int) -> void:
	var is_real := world == GameState.World.REAL
	visible = is_real
	# 注意：不要 freeze 成 not is_real，见下方说明
	set_physics_process(is_real)
	freeze = not is_real

func get_save_tags() -> Array[String]:
	return tags.tags.duplicate()
```

> **⚠️ 一个真实的设计冲突，必须现在决定**：
> 现在 `_on_world_changed` 里切到虚类世界就 `freeze = true`。
> 这意味着**虚类世界时尸体是块冻结的隐形墙**（`freeze` 只停物理，碰撞还在）。
> 灵魂态玩家 mask = 2（只撞虚类），尸体的 `collision_layer` 是 6 —— 所以灵魂态会穿过尸体，**巧合地正确**。
> 但如果你以后想让「灵魂推虚类物体」时尸体要挡路，这套就崩了。
> **我的建议**：尸体切到虚类世界时，除了 `freeze` 还要把 `collision_layer` 设为 0、
> 恢复实类世界时再设回 6。别依赖掩码的巧合，显式关掉碰撞。

**`corpse.tscn` 的 RigidBody2D 节点**加：

```
collision_layer = 6
collision_mask = 10
```

### 3.5 存档/读档：`world.gd` 改造

**在 `world.gd` 里加**（保留原有的 tilemap 切换逻辑不动）：

```gdscript
@onready var player: Player = $Player

func _ready() -> void:
	GameState.world_changed.connect(_on_world_changed)
	_on_world_changed(GameState.current_world)
	_restore_corpses()

func _restore_corpses() -> void:
	var scene := preload("res://corpse.tscn")
	for rec in GameState.corpses:
		var c := scene.instantiate()
		add_child(c)
		c.global_position = rec["pos"]
		c.rotation = rec["rot"]
		c.initial_tags = rec["tags"]
```

> **⚠️ 顺序陷阱**：`corpse._ready()` 里会调 `GameState.add_corpse()`，
> 所以恢复时**会重复写入**存档，尸体列表会指数增长。
> **解法**：加一个 `var restoring := false` 标志，或在 `corpse.gd` 里加参数 `var register_on_ready := true`，
> 恢复时设 `false`。**这个 bug 会以「内存爆炸 + 尸体数量翻倍」的形式出现，D3 一定会踩到。**

### 3.6 `player.gd` 的重生改造

把 `_permanent_death()` 从「重载场景」改成「在出生点复活，世界保留」：

```gdscript
func _permanent_death() -> void:
	# 灵魂态死亡：不是世界重置，是玩家回到出生点
	# 关键：尸体全部保留 —— 这才是「我死过，所以我知道了，所以我做到了」
	GameState.set_world(GameState.World.REAL)
	global_position = GameState.spawn_position
	velocity = Vector2.ZERO
	_apply_form(Form.REAL)

func reset_run() -> void:
	# 只有开新局才清空（比如按 R 键）
	GameState.clear_corpses()
	get_tree().reload_current_scene()
```

并把 `_spawn_corpse()` 改成用传送带标签（见 3.4）—— 其实不用改，
因为 `corpse._ready()` 会自己调 `add_corpse`。

**再加掉落保护**（现在掉出地图就卡死）：

```gdscript
const KILL_Y := 400.0

func _physics_process(delta: float) -> void:
	if global_position.y > KILL_Y:
		_permanent_death()
		return
	match current_form:
		Form.REAL: _process_real(delta)
		Form.SOUL: _process_soul(delta)
	move_and_slide()
```

### 3.7 顺便修 `player.gd` 第 68 行的死代码

```gdscript
var was_onfloar := is_on_floor()
# ... 中间什么都没发生
if is_on_floor() != was_onfloar:   # 永远为 false
```

`was_onfloar` 在 `move_and_slide()`（第 41 行）**之前**取值，而 `move_and_slide()` 在 `_process_real()` 之后，
所以这个比较永远为 `false`，**郊狼时间（coyote time）从来没生效过**。

**改法**：把郊狼时间的检测挪到 `_physics_process()` 里、`move_and_slide()` **之后**：

```gdscript
func _physics_process(delta: float) -> void:
	...
	var was_on_floor := is_on_floor()
	move_and_slide()
	if was_on_floor and not is_on_floor() and velocity.y >= 0.0:
		coyote_timer.start()
```

> 这是个 5 分钟的修复，但手感提升很明显。readme 第 96 行把郊狼时间列为已实现功能，其实一直是坏的。

### 3.8 D2–D4 验收脚本

按顺序手测，**必须全部通过**：

1. 开局，走到刺上 → 死亡，尸体留在刺上，玩家变灵魂态
2. 灵魂态飘走 → 15 秒超时 → 玩家出现在出生点，**尸体还在刺上**
3. 再死一次 → **地上有 2 具尸体**
4. 灵魂态飘到地图外 → 回到出生点，**尸体都还在**
5. 尸体从空中掉下来 → 落在地上**不会无限滑动**（`linear_damp` 生效）

任何一条挂了，D2–D4 就没结束，别往下走。

---

## 四、D5–D6：压力板 + 门

这是让尸体「从装饰变成因果」的最小机关。只做两个物体。

### 4.1 压力板 `pressure_plate.gd`

```gdscript
extends Area2D
class_name PressurePlate

signal pressed_changed(is_pressed: bool)

@onready var tags: TagComponent = $TagComponent
@onready var sprite: Sprite2D = $Sprite2D

var _overlapping := 0
var is_pressed := false

func _ready() -> void:
	tags.add_tag("real")
	tags.add_tag("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	# 只有「实类且有一定质量」的东西能压住：尸体和实类玩家
	var t = body.get_node_or_null("TagComponent")
	if t == null or not t.has_tag("real"):
		return
	if body is RigidBody2D or body is CharacterBody2D:
		_overlapping += 1
		_refresh()

func _on_body_exited(body: Node2D) -> void:
	var t = body.get_node_or_null("TagComponent")
	if t == null or not t.has_tag("real"):
		return
	if body is RigidBody2D or body is CharacterBody2D:
		_overlapping = max(0, _overlapping - 1)
		_refresh()

func _refresh() -> void:
	var now := _overlapping > 0
	if now == is_pressed:
		return
	is_pressed = now
	pressed_changed.emit(is_pressed)
	_update_visual()

func _update_visual() -> void:
	# 可读性：按下时下沉 2px + 变暗。别做粒子，做不起
	sprite.position.y = 2.0 if is_pressed else 0.0
	sprite.modulate = Color(0.6, 0.6, 0.6) if is_pressed else Color.WHITE
```

**层级**：`collision_layer = 8`（层3 Interactable），`collision_mask = 40`（层4+层6 = 实类玩家 + 尸体）
—— **注意：这里必须能检测到尸体（层6），这就是整个设计的支点。**

### 4.2 门 `door.gd`

```gdscript
extends StaticBody2D

@export var plate_path: NodePath

@onready var tags: TagComponent = $TagComponent
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	tags.add_tag("real")
	GameState.world_changed.connect(_on_world_changed)
	var plate := get_node_or_null(plate_path)
	if plate:
		plate.pressed_changed.connect(_on_pressed_changed)

func _on_pressed_changed(is_pressed: bool) -> void:
	_set_open(is_pressed)

func _set_open(open: bool) -> void:
	# 用显式关碰撞，不要只靠 visible —— 隐形墙是玩家最恨的东西
	$CollisionShape2D.disabled = open
	sprite.visible = not open

func _on_world_changed(world: int) -> void:
	visible = world == GameState.World.REAL
```

### 4.3 关键设计点：**压力板必须在两个世界都有意义**

如果你只让实类玩家 + 尸体能压板，那灵魂态玩家压不了板 —— 这是**对的**，
因为 readme 第 42 行说灵魂态与实类不交互。

**但**：这引出一个涌现机会，也是你整个 demo 的高光时刻 ——
灵魂态玩家**不能**压板，但他能**推虚类物体**去压虚类的板。
同一块板，实类世界靠尸体，虚类世界靠推箱子。**两条路径，一个目标。**

> D5–D6 先只做实类路径（尸体压板）。
> 虚类路径等 D9 的灯做完、或者干脆不做 —— **一条路径也足以让主题成立**。
> 记住 readme 第 162 行的自我警告：「范围蔓延是最大风险」。

---

## 五、D7–D8：关卡几何（这是你现在最大的空洞）

`world.tscn` 现在是**一块平地 + 两个刺**，而且：

> **`world.gd` 第 12 行注释「碰撞不用管，玩家自己的掩码决定」是错的。**
> 实类 TileMap 在 x=4..10 那段**没有地面**（打开编辑器能看到左边有个坑），
> 玩家出生在 (128,111) 站在 x=8 附近 —— 一开始就在坑边缘，而且是唯一的出生点。
> 整张图**没有任何墙**，实类形态往左右走会直接掉出地图。

### 5.1 强烈建议：把 TileMap 从「手绘」改成「代码生成」

原因：你还有 12 天要反复调关卡，而 `.tscn` 里那个 `tile_map_data = PackedByteArray(...)`
是二进制 blob，**没法 diff、没法手编、每次都得开编辑器**。
换成 GDScript 常量数组之后，改关卡就是改一个二维数组，改错了立刻看得见。

**新建 `level_layout.gd`**（或直接写在 `world.gd` 里）：

```gdscript
# 0 = 空, 1 = 实类墙, 2 = 虚类墙, 3 = 两者都有
const LAYOUT := [
#   0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # y=0 天花板
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],  # y=8   ← 玩家出生层
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],  # y=9   中间平台
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # y=10  地面(中间有洞)
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # y=12 坑底
]
```

**在 `world.gd` 里生成**：

```gdscript
const TILE_SIZE := 16
# 你的 tileset 里 atlas 坐标 (0,0) 是左下角实类砖，(0,1) 是虚类砖
const ATLAS_REAL := Vector2i(0, 0)
const ATLAS_VIRTUAL := Vector2i(0, 1)

func _build_level() -> void:
	real_tilemap.clear()
	virtual_tilemap.clear()
	for y in LAYOUT.size():
		for x in LAYOUT[y].size():
			var cell := Vector2i(x + 4, y - 12)   # 偏移到当前位置附近，按需调
			var v: int = LAYOUT[y][x]
			if v == 1 or v == 3:
				real_tilemap.set_cell(cell, 0, ATLAS_REAL)
			if v == 2 or v == 3:
				virtual_tilemap.set_cell(cell, 0, ATLAS_VIRTUAL)
```

> **上面的地图布局和偏移是示意，不是成品。** 你的 TileSet atlas 实际哪一格是什么，
> 我在 tscn 里只能看到 `0:0`、`0:1`、`1:0`、`1:1` 四个格子有物理多边形，
> 需要你打开编辑器确认哪个是实类砖、哪个是虚类砖。
> **但把生成逻辑写成代码这件事本身，是我最强烈的建议之一。**

### 5.2 房间设计（一屏内，无卷轴）

按 readme 第 71 行的示例房间，压缩成 **384x216 视口内的一屏**：

```
┌──────────────────────────────────────────┐
│                                          │
│        ┌──虚类平台──┐                    │
│        │            │      门(关)         │
│   出生点 ●          │   ════════         │
│  ══╤════════════════╤══════════════════  │
│    │   ▲刺         │                   │
│    │   压力板▭      │                   │
│    └───坑───────────┘                   │
└──────────────────────────────────────────┘
```

**玩家必须做的事**（不许给文字提示）：

1. 出生在左侧，向右走 → 掉进坑
2. 坑里有刺 → **死**，尸体落在刺旁边的压力板上（或直接死在压力板上）
3. 变灵魂态，飘上去 → 发现门关了
4. 回坑里 → 发现**自己的尸体压住了压力板**，门开着
5. 但灵魂态穿不过门（门是实类）→ 需要复活
6. 复活机制（D7 最简版）：**压力板保持按下状态时，坑底出现一个复活点**
   —— 或者更简单：**灵魂态回到出生点自动复活**（`player.gd` 加区域检测）

> **第 6 步是唯一还没定的机制，也是整个 demo 的必要闭环。**
> 我建议用最廉价的方案：**灵魂态碰出生点 SpawnPoint 区域 → 自动 `revive()`**。
> 不需要新道具、不需要新场景。readme 里的「复活物品」砍掉。

---

## 六、D7–D8：可读性（**比机关更重要**）

readme 第 67 行自己写了「可读性通过视觉特效、音效、死亡日志、双世界地图叠加来保障」，
第 162 行又担心「玩家可能看不懂」。
**涌现式设计的最大失败模式不是没内容，是玩家看不懂因果链。**

按性价比排序，**只做前两个**：

### 6.1 尸体计数 + 一个数字（成本 10 分钟，收益最大）

左上角一个 `Label`：

```gdscript
# 在任何 UI 脚本里
func _process(_delta: float) -> void:
	$Label.text = "尸体 %d" % GameState.corpses.size()
```

这一个数字就让玩家意识到「**尸体是资源，不是失败次数**」。
这是你整个 demo 里最重要的一个 UI 元素。

### 6.2 世界切换的视觉区分（成本 30 分钟，收益极大）

现在切到虚类世界只是 `modulate.a = 0.5`，**根本看不出来换了世界**。

**做一个全屏 `ColorRect` 覆盖层**（`CanvasLayer` 里）：

```gdscript
func _on_world_changed(world: int) -> void:
	var tween := create_tween()
	if world == GameState.World.REAL:
		tween.tween_property($Overlay, "color:a", 0.0, 0.15)
	else:
		tween.tween_property($Overlay, "color:a", 0.35, 0.15)

func _ready() -> void:
	$Overlay.color = Color(0.3, 0.2, 0.6, 0.35)  # 冷紫
	$Overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

**冷紫色调 + 透明度 = 玩家一秒就懂「我在虚类世界」。** 比任何教程都管用。

### 6.3 明确不做的事

以下全部砍掉，D12 之前不碰：
- ❌ 双世界地图叠加（成本高，低分辨率下必然一团糊）
- ❌ 死亡日志（涌现式设计里日志等于给答案，**反主题**）
- ❌ 音效（D12 最后一天如果还有时间，加 3 个音：死亡、压板、开门）
- ❌ 美术替换（`knight.png` 能用就用，D1 的 Bug 3 修完就够了）

---

## 七、D9–D10：灯（**可选，做不完不心疼**）

灯是 readme 里最有创意的设计（第 57–59 行），也是**最容易做不完**的。
如果 D8 结束时尸体 + 压力板 + 可读性都跑通了，再动灯。

**最小可验证版本**（只做这三个属性，其余全砍）：

```gdscript
extends RigidBody2D
class_name Lamp

@onready var tags: TagComponent = $TagComponent

func _ready() -> void:
	# 灯是唯一双属性物体 —— 同时有 real 和 virtual 标签
	tags.add_tag("real")
	tags.add_tag("virtual")
	tags.add_tag("lamp")
	tags.add_tag("body")
	collision_layer = 1 | 2 | 64      # 层1+层2+层7
	collision_mask  = 1 | 2 | 64      # 撞两个世界的地面
	linear_damp = 2.0
```

砍掉的：照明（要 `PointLight2D` + 光照贴图，成本翻倍）、驱赶怕光生物、
扔进水里变灵魂灯（要新的水区域 + 状态机）。

**保住的三条**：
1. 物理体积 → 能踮脚、能按压力板（**和尸体同一条规则，零新代码**）
2. 双世界可见 → 两个世界共享同一个位置（这才是「万能接口」的含义）
3. `J` 键扔出 / `K` 键回收

> **灯的真正价值不是它的功能，是它证明了你的规则系统能容纳「例外」。**
> 一个标签系统里出现一个双标签物体，玩家会立刻理解「标签是可以被改变的」——
> 而这正是贪吃兽（标签转换器）的伏笔。**这个认知价值 > 灯的所有具体功能。**

---

## 八、风险清单（按发生概率排序）

| 风险 | 概率 | 应对 |
|---|---|---|
| **`_restore_corpses` 重复写入存档，尸体指数增长** | **极高** | 3.5 节的 `register_on_ready` 标志，D3 第一天就防住 |
| 尸体永久堆积导致性能下降 | 高 | 上限 20 具，超出删最早的；`can_sleep = true` |
| 灵魂态 15 秒太短，玩家来不及想 | 高 | 调到 30 秒，或改成「静止时暂停计时」 |
| 玩家看不懂需要故意死 | 中 | 6.1 的尸体计数 + 把压力板放在**唯一必经的刺上** |
| 尸体滑走压不住板 | 中 | `linear_damp = 4.0` + 压力板做成凹槽形 |
| 灵魂态和尸体都堆在坑里，视觉混乱 | 中 | 6.2 的色调区分 + 灵魂态 `modulate.a = 0.5` |
| 12 天做不完，D10 还在调灯 | 中 | **D8 结束设硬性冻结线**，之后的都是加分项 |
| 层号改错导致新的碰撞 bug | 中 | D1 改完立刻开 `调试 → 可见碰撞形状` 全图跑一遍 |

---

## 九、一句话总结

> **你不需要更多内容，你需要让尸体活得比玩家久。**
>
> 现在的 `reload_current_scene()` 把玩家的每一次死亡都变成了一次「什么都没有发生」。
> 把它改成「玩家回出生点，尸体留在原地」，你的游戏就从一个平台跳跃 demo
> 变成了一个关于「用死亡改变世界」的游戏。
>
> **这一行改动，就是你 12 天里最重要的一行。**

---

## 附录：改动文件清单

| 文件 | 操作 | 优先级 |
|---|---|---|
| `project.godot` | 加 `[layer_names]` 段 | D1 |
| `world.tscn` | 改 `VirtualTileMap` 的 TileSet mask 2→34 | D1 阻断级 |
| `player.tscn` | 修 6 个 `region_rect`（或改用 AnimatedSprite2D）；加 `Camera2D` | D1 |
| `player.gd` | 修郊狼时间；`_permanent_death` 改成重生；加掉落保护 | D1/D3 |
| `corpse.gd` | 支持注入标签；加阻尼；显式关碰撞 | D3 |
| `corpse.tscn` | RigidBody2D 加 `collision_layer=6, mask=10` | D3 |
| `autoload/GameState.gd` | 加 `corpses` / `spawn_position` / `add_corpse()` | D2 |
| `world.gd` | 加 `_restore_corpses()`、`_build_level()` | D3/D7 |
| `pressure_plate.gd` + `.tscn` | 新建 | D5 |
| `door.gd` + `.tscn` | 新建 | D6 |
| `spawn_point.gd` + `.tscn` | 新建（最简版） | D2 |
| UI（Label + ColorRect） | 新建 | D7 |
| `lamp.gd` + `.tscn` | 新建 | D9（可选） |

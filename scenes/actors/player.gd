extends CharacterBody2D

@export var speed := 90.0
@export var shovel_scene: PackedScene

var last_direction := Vector2.DOWN
var last_anim := "walk_down"
var is_attacking: bool = false
var facing_dir: String = "down"
var shovel_instance: Node = null

@onready var anim := $AnimatedSprite2D

var hearts_list : Array[TextureRect]
@export var health = 6
@export var max_hearts = 16
var max_health = max_hearts*2 #each heart represents 2 health
# Track the press order
var press_order := []


# --- screen transition vars ---
var on_transition: bool = false
var auto_walk_dir: Vector2 = Vector2.ZERO
var auto_walk_distance: float = 0.0
@export var room_size: Vector2 = Vector2(256, 176) # width × height of the bottom-room
@export var room_offset_y: float = 64.0           # top excluded area
@export var push_distance: float = 8.0
@export var edge_margin: float = 5.0

func _ready() -> void:
	var cam = get_node("../Camera2D") # adjust path if needed
	cam.room_changed.connect(_on_room_changed)
	cam.tween_finished.connect(_on_camera_finished)
	$CanvasLayer.visible = true
	set_health_bar()

func take_damage(damage):
	if health > 0:
		health -= damage
		update_heart_display()
		if health <= 0:
			dead = true
		
func set_health_bar():
	var hearts_parent1 = $CanvasLayer/Interface/HealthBar
	var hearts_parent2 = $CanvasLayer/Interface/HealthBar2
	for child in hearts_parent1.get_children():
		hearts_list.append(child)
	for child in hearts_parent2.get_children():
		hearts_list.append(child)
	#Hides hearts over max_heart count
	for i in range(hearts_list.size()-max_hearts):
		hearts_list[i+max_hearts].get_node("Heart").frame = 3
	update_heart_display()
	
			
func update_heart_display():
	#Set empty hearts sprites
	for i in range(max_hearts):
		hearts_list[i].get_node("Heart").frame = 0
	#Set filled hearts sprites
	for i in range(max_hearts):
		if i*2 < health - 1:
			hearts_list[i].get_node("Heart").frame = 2
		if i*2 == health - 1:
			hearts_list[i].get_node("Heart").frame = 1
			
	
func _input(event):
	if event is InputEventKey or event is InputEventJoypadButton:
			# Handle pressing
		for dir in ["ui_up", "ui_down", "ui_left", "ui_right"]:
			if event.is_action_pressed(dir):
				press_order.erase(dir)
				press_order.append(dir)
			elif event.is_action_released(dir):
				press_order.erase(dir)
		if not is_attacking:
			if event.is_action_pressed("attack"):
				start_attack()

func _physics_process(delta):
	if is_hurt:
		process_hurt(delta)
		return
	if on_transition:
		if auto_walk_distance > 0.0:
			var step = speed * delta
			if step >= auto_walk_distance:
				global_position += auto_walk_dir * auto_walk_distance
				auto_walk_distance = 0.0
				auto_walk_dir = Vector2.ZERO
			else:
				global_position += auto_walk_dir * step
				auto_walk_distance -= step
		return
	var input_dir := Vector2.ZERO
	
	if not is_attacking:
		# Determine which direction to use (last pressed has priority)
		if press_order.size() > 0:
			var dir: String = press_order[-1]  # last pressed
			match dir:
				"ui_up":
					input_dir = Vector2.UP
				"ui_down":
					input_dir = Vector2.DOWN
				"ui_left":
					input_dir = Vector2.LEFT
				"ui_right":
					input_dir = Vector2.RIGHT

		velocity = input_dir * speed
		move_and_slide()

		# Handle animations

		if input_dir != Vector2.ZERO:
			last_direction = input_dir
			if input_dir == Vector2.UP:
				last_anim = "walk_up"
				anim.flip_h = false
			elif input_dir == Vector2.DOWN:
				last_anim = "walk_down"
				anim.flip_h = false
			elif input_dir == Vector2.RIGHT:
				last_anim = "walk_right"
				anim.flip_h = false
			elif input_dir == Vector2.LEFT:
				last_anim = "walk_right"
				anim.flip_h = true

			if anim.animation != last_anim or !anim.is_playing():
				anim.play(last_anim)
		else:
			anim.pause()
			
func start_attack():
	if on_transition:
		return
	is_attacking = true

	var spawner: Node2D
	var attack_anim: String
	# Spawn shovel
	shovel_instance = shovel_scene.instantiate()
	match last_direction:
		Vector2.UP:
			spawner = $Item_Spawns/Up
			attack_anim = "attack_up"
			anim.flip_h = false
			shovel_instance.rotation_degrees = 180
		Vector2.DOWN:
			spawner = $Item_Spawns/Down
			attack_anim = "attack_down"
			anim.flip_h = false
		Vector2.LEFT:
			spawner = $Item_Spawns/Left
			attack_anim = "attack_right"  # or "attack_left" if you have one
			anim.flip_h = true
			shovel_instance.rotation_degrees = 90
		Vector2.RIGHT:
			spawner = $Item_Spawns/Right
			attack_anim = "attack_right"
			anim.flip_h = false
			shovel_instance.rotation_degrees = 90
			shovel_instance.scale.y *= -1
	spawner.add_child(shovel_instance)
	if shovel_instance.has_method("play"):
		shovel_instance.play("use") # shovel's own animation

	# Play player attack animation
	anim.play(attack_anim)

# ---------------------------
# SCREEN TRANSITION
# ---------------------------
# --- called by the Camera: _on_room_changed(new_room) ---
func _on_room_changed(_new_room: Vector2) -> void:
	on_transition = true

	# remainders based on bottom-room coordinates
	var rem_x := fposmod(global_position.x, room_size.x)
	var rem_y := fposmod(global_position.y - room_offset_y, room_size.y)
	var right_thresh := room_size.x - edge_margin
	var bottom_thresh := room_size.y - edge_margin

	if rem_x <= edge_margin:
		auto_walk_dir = Vector2.RIGHT
		auto_walk_distance = push_distance
	elif rem_x >= right_thresh:
		auto_walk_dir = Vector2.LEFT
		auto_walk_distance = push_distance
	elif rem_y <= edge_margin:
		auto_walk_dir = Vector2.DOWN
		auto_walk_distance = push_distance
	elif rem_y >= bottom_thresh:
		auto_walk_dir = Vector2.UP
		auto_walk_distance = push_distance
		
func _on_camera_finished():
	# enable player control AFTER camera has finished panning
	on_transition = false

func _on_attack_anim_finished():
	print(is_attacking)
	print("holy moly")
	if anim.get_animation().begins_with("attack_"):
		if shovel_instance and is_instance_valid(shovel_instance):
			shovel_instance.queue_free()
			shovel_instance = null
		is_attacking = false
	print(is_attacking)
	
# ---------------------------
# HURT AND DAMAGE BEHAVIOUR
# ---------------------------
var is_hurt: bool = false
var hurt_timer: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var dead = false
@export var hurt_time: float = 0.15        # how long hurt lasts
@export var knockback_force: float = 300

func hurt(hit_pos: Vector2, damage: int) -> void:
	if is_hurt:
		return  # prevent stacking hurt during invincibility	
	take_damage(damage)
	if dead:
		die()
	is_hurt = true
	hurt_timer = hurt_time
	
	# Knockback direction (away from hit, snapped to cardinal)
	var away = (global_position - hit_pos).normalized()
	
	if abs(away.x) > abs(away.y):
		# horizontal
		knockback = Vector2(sign(away.x), 0) * knockback_force
	else:
		# vertical
		knockback = Vector2(0, sign(away.y)) * knockback_force


	anim.play("hurt")
	start_flicker()

func process_hurt(delta: float) -> void:
	hurt_timer -= delta

	# Apply knockback (decays over time)
	velocity = knockback
	knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()

	if hurt_timer <= 0.0:
		stop_flicker()
		is_hurt = false
		anim.play("default")


# ---------------------------
# FLICKER EFFECT (multi-color)
# ---------------------------
@onready var sprite: CanvasItem = $AnimatedSprite2D   # used for modulate flicker
var flicker_on: bool = false
var flicker_timer: float = 0.0
@export var flicker_speed: float = 0.08  # seconds per toggle

var flicker_colors: Array[Color] = [Color(1,1,1,1), Color(1,0,0,1)]
var flicker_index: int = 0

func start_flicker() -> void:
	flicker_timer = 0.0
	flicker_index = 0
	sprite.modulate = flicker_colors[flicker_index]

func stop_flicker() -> void:
	sprite.modulate = Color(1, 1, 1, 1)  # reset to normal

func _process(delta: float) -> void:
	if is_hurt:
		flicker_timer += delta
		if flicker_timer >= flicker_speed:
			flicker_timer = 0.0
			flicker_index = (flicker_index + 1) % flicker_colors.size()
			sprite.modulate = flicker_colors[flicker_index]



# ---------------------------
# DEATH
# ---------------------------
func die() -> void:
	queue_free()

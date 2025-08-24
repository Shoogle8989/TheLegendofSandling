extends CharacterBody2D

@export var speed: float = 40.0
var direction: Vector2 = Vector2.ZERO
var time_passed: float = 0.0
var change_direction_time: float = 1.0
var rng := RandomNumberGenerator.new()
@onready var anim := $AnimatedSprite2D

@export var hurt_time: float = 0.15        # how long hurt lasts
@export var knockback_force: float = 300

var is_hurt: bool = false
var hurt_timer: float = 0.0
var knockback: Vector2 = Vector2.ZERO
@export var max_hp: int = 3
var hp: int


@onready var sprite: CanvasItem = $AnimatedSprite2D   # used for modulate flicker
@export var attack_power: int = 1

func _ready() -> void:
	rng.randomize()
	pick_new_direction()
	anim.play("default")
	hp = max_hp
	
func _physics_process(delta: float) -> void:
	if is_hurt:
		process_hurt(delta)
		return

	# Normal movement
	time_passed += delta
	if time_passed >= change_direction_time:
		pick_new_direction()
		time_passed = 0.0
		

	velocity = direction * speed
	var collision = move_and_collide(velocity * delta)
	if collision:
		pick_new_direction()
		time_passed = 0.0


func pick_new_direction() -> void:
	var dirs = {
		Vector2.UP:    [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN],
		Vector2.DOWN:  [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP],
		Vector2.LEFT:  [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT],
		Vector2.RIGHT: [Vector2.UP, Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT]
	}

	if direction == Vector2.ZERO:
		# First direction, pick random
		var base_dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		direction = base_dirs[rng.randi_range(0, base_dirs.size() - 1)]
	else:
		# Weighted preference
		var candidates = dirs[direction]
		var roll = rng.randf()
		if roll < 0.6:
			direction = candidates[rng.randi_range(0, 1)] # tangent
		elif roll < 0.9:
			direction = candidates[2] # same
		else:
			direction = candidates[3] # reverse

	# Randomize next change time between 0.9s and 1.5s
	change_direction_time = rng.randf_range(0.9, 1.2)
	
# ---------------------------
# HURT AND DAMAGE BEHAVIOUR
# ---------------------------
func hurt(hit_pos: Vector2) -> void:
	if is_hurt:
		return  # prevent stacking hurt during invincibility	
	print(hp)
	hp -= 1
	if hp < 1:
		die()
		return
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
		pick_new_direction()
		anim.play("default")




# ---------------------------
# FLICKER EFFECT (multi-color)
# ---------------------------
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


func _on_hit_box_area_entered(area):
	# get the parent of the HitBox (should be the enemy)
	var target = area.get_parent()
	
	if target and target.has_method("hurt"):
		target.hurt(global_position, attack_power)  # pass shovel position as hit position

extends Camera2D

@export var room_size: Vector2 = Vector2(256, 176) # width × height of the bottom-room
@export var room_offset_y: float = 64.0           # top excluded area
@export var pan_speed: float = 300.0             # pixels per second

var current_room: Vector2
var tween: Tween = null
signal room_changed(new_room: Vector2)
signal tween_finished()

func _ready():
	var player = get_node("../Player")
	var player_pos = player.global_position
	current_room = Vector2(floor(player_pos.x / room_size.x),
						   floor((player_pos.y - room_offset_y) / room_size.y))
	global_position = Vector2(
		current_room.x * room_size.x + room_size.x / 2,
		room_offset_y + current_room.y * room_size.y + (room_size.y - room_offset_y) / 2
	)

func _process(_delta):
	var player = get_node("../Player")
	var player_pos = player.global_position
	var new_room = Vector2(floor(player_pos.x / room_size.x),
						   floor((player_pos.y - room_offset_y) / room_size.y))

	if new_room != current_room and (tween == null or not tween.is_running()):
		current_room = new_room
		var target = Vector2(
			current_room.x * room_size.x + room_size.x / 2,
			room_offset_y + current_room.y * room_size.y + (room_size.y - room_offset_y) / 2
		)

		var distance = global_position.distance_to(target)
		var duration = distance / pan_speed

		tween = create_tween()
		tween.tween_property(self, "global_position", target, duration) \
			 .set_trans(Tween.TRANS_SINE) \
			 .set_ease(Tween.EASE_IN_OUT)
		

		emit_signal("room_changed", current_room)
		
		tween.tween_callback(_on_tween_finished)

func _on_tween_finished():
	emit_signal("tween_finished")

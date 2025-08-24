extends Area2D
@onready var anim := $AnimatedSprite2D
func play(anim_name):
	anim.play(anim_name)


func _on_area_entered(area):
	# get the parent of the HitBox (should be the enemy)
	var target = area.get_parent()
	
	if target and target.has_method("hurt"):
		target.hurt(global_position)  # pass shovel position as hit position

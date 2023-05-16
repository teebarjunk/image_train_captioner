tool
extends AspectRatioContainer

#func _process(delta):
#	update()

func update_ratio():
	var texture: Texture = $preview.texture
	if texture:
		var s := texture.get_size()
		ratio = s.x / s.y
	else:
		ratio = 1.0

func _draw():
	update_ratio()
	var tr: Rect2 = get_parent().get_rect()
	
#	var min_side := min(tr.size.x, tr.size.y)
#	var t_size := texture.get_size()
#	var t_aspect := t_size.x / t_size.y
#	var tex_size := Vector2(min_side * t_aspect, min_side)
#	var tex_pos: Vector2 = (tr.size - tex_size) * .5
	
	draw_rect(get_child(0).get_rect(), Color.aquamarine, false, 16)
#	draw_rect(Rect2(tex_pos, tex_size), Color.tomato, false, 8)

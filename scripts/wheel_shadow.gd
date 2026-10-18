extends Control
## Nonrotating sibling of the wheel. Same local size/center, fixed downward offset.
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func _draw() -> void:
 var radius := minf(size.x,size.y) / 2 - 12
 if radius < 10: return
 draw_circle(size / 2 + Vector2(0,3),radius + 7,Color(0.12,0.14,0.16,.08),true,-1,true)

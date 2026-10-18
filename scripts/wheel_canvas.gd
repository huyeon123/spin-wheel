extends Control

var slices: Array = []
var font: Font
var show_labels := true
var draw_shadow := true

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 resized.connect(func(): pivot_offset = size / 2; queue_redraw())

func _draw() -> void:
 var c := size / 2
 var r := minf(size.x, size.y) / 2 - 12
 if r < 10: return
 if draw_shadow: draw_circle(c + Vector2(0, 3), r + 7, Color(0.12,0.14,0.16,.08), true, -1, true)
 draw_circle(c, r + 5, Color.WHITE, true, -1, true)
 if slices.is_empty():
  draw_circle(c, r, Color("dce1ee"))
  return
 var total := 0.0
 for s in slices: total += float(s.weight)
 if total <= 0: return
 var start := -PI / 2
 var separators: Array[float] = []
 for s in slices:
  var sweep := TAU * float(s.weight) / total
  var points := PackedVector2Array([c])
  var segments := maxi(2, int(ceil(sweep * r / 6)))
  for i in range(segments + 1):
   points.append(c + Vector2.from_angle(start + sweep * i / segments) * r)
  draw_colored_polygon(points, Color(s.color))
  separators.append(start)
  var angle := start + sweep / 2
  var label: String = s.name
  if label.length() > 10: label = label.left(9) + "…"
  var fs := clampi(int(r * .073), 12, 23)
  if show_labels and sweep * r > 28:
   var pos := c + Vector2.from_angle(angle) * r * .64
   var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
   draw_string(font, pos - Vector2(text_size.x / 2, -fs * .34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _label_color(Color(s.color)))
  start += sweep
 # Draw every boundary after every fill, so adjacent wedges cannot cover it.
 for boundary in separators:
  draw_line(c, c + Vector2.from_angle(boundary) * r, Color(1,1,1,0.65), 2, true)
 draw_arc(c, r, 0, TAU, 256, Color.WHITE, 1.5, true)
 draw_circle(c, r * .15 + 4, Color(0.09,0.13,0.26,.10), true, -1, true)
 draw_circle(c, r * .15, Color.WHITE, true, -1, true)
 draw_circle(c, r * .06, Color("303a34"), true, -1, true)

func _label_color(background: Color) -> Color:
 var linear := background.srgb_to_linear()
 var luminance := .2126 * linear.r + .7152 * linear.g + .0722 * linear.b
 var ink := Color("172143")
 var ink_linear := ink.srgb_to_linear()
 var ink_luminance := .2126 * ink_linear.r + .7152 * ink_linear.g + .0722 * ink_linear.b
 var dark_contrast := (luminance + .05) / (ink_luminance + .05)
 var white_contrast := 1.05 / (luminance + .05)
 return Color.WHITE if white_contrast > dark_contrast else ink

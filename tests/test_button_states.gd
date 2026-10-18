extends SceneTree
# Native renderer required: pointer dispatch plus framebuffer pixels, not a headless theme-only check.
var checks:=0
var failures:=0
func _init()->void:
 # Legacy behavior fixtures explicitly opt out; real timing is tested separately.
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if DisplayServer.get_name()=="headless":print("BUTTON_STATE_QA requires native renderer");quit(2);return
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(3):await process_frame
func move(p:Vector2)->void:
 var e:=InputEventMouseMotion.new();e.position=p;root.push_input(e,true)
func mouse(p:Vector2,down:bool)->void:
 var e:=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
func linear(v:float)->float:return v/12.92 if v<=.04045 else pow((v+.055)/1.055,2.4)
func luminance(c:Color)->float:return .2126*linear(c.r)+.7152*linear(c.g)+.0722*linear(c.b)
func contrast(a:Color,b:Color)->float:return (maxf(luminance(a),luminance(b))+.05)/(minf(luminance(a),luminance(b))+.05)
func run()->void:
 root.size=Vector2i(960,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 # Isolated genuine Godot buttons with production theme/styling, actions intentionally absent.
 var fixture:=Panel.new();fixture.position=Vector2(40,40);fixture.size=Vector2(880,720);fixture.theme=app.theme;app.add_child(fixture)
 var white:=StyleBoxFlat.new();white.bg_color=Color.WHITE;fixture.add_theme_stylebox_override("panel",white)
 var states=["normal","hover","pressed","hover_pressed","focus","disabled"]
 var roles=["ratio_selected","percent_selected","ratio_unselected","percent_unselected","inherit_selected","inherit_unselected","custom_selected","custom_unselected","removal_selected","primary","neutral","danger"]
 var sheet:=Image.create(900,roles.size()*70,false,Image.FORMAT_RGBA8);sheet.fill(Color.WHITE)
 for ri in range(roles.size()):
  var role:String=roles[ri]
  for si in range(states.size()):
   var state:String=states[si]
   var b:Button=CheckBox.new() if role in ["ratio_selected","percent_selected","ratio_unselected","percent_unselected","inherit_selected","inherit_unselected","custom_selected","custom_unselected"] else Button.new()
   fixture.add_child(b)
   if b is CheckBox:
    b.button_group=ButtonGroup.new();b.button_group.allow_unpress=true
    b.add_theme_icon_override("radio_checked",load("res://assets/radio-on.svg"));b.add_theme_icon_override("radio_unchecked",load("res://assets/radio-off.svg"))
   b.text="정하기";b.position=Vector2(30,30);b.size=Vector2(180,52)
   if role.ends_with("selected") and not role.ends_with("unselected"):b.toggle_mode=true;app._accent_button(b,true)
   if role=="primary":app._accent_button(b)
   if role=="danger":app._danger_button(b)
   for selected in [false,true]:
    b.toggle_mode=true;b.disabled=false;b.button_pressed=selected;b.release_focus();move(Vector2(930,780));await settle()
    var center=b.get_global_rect().get_center()
    if state in ["hover","hover_pressed"]:move(center)
    elif state=="pressed":mouse(center,true);move(Vector2(930,780))
    elif state=="focus":b.grab_focus()
    elif state=="disabled":b.disabled=true
    if state=="hover_pressed":b.button_pressed=true
    await settle()
    var mode=b.get_draw_mode()
    var fg:Color=b.get_theme_color("font_disabled_color" if b.disabled else ("font_hover_pressed_color" if mode==4 else ("font_pressed_color" if mode==2 else ("font_hover_color" if mode==1 else "font_color"))))
    var frame=root.get_texture().get_image();var rect:Rect2i=Rect2i(b.get_global_rect());var crop=frame.get_region(rect)
    var bg=crop.get_pixel(crop.get_width()/2,crop.get_height()-8)
    var ink:=0
    for y in range(14,38):
     for x in range(40,145):
      if contrast(crop.get_pixel(x,y),bg)> (1.4 if b.disabled else 3.0):ink+=1
    check(contrast(fg,bg)>=(1.4 if b.disabled else 3.0),role+" "+state+" selected="+str(selected)+" rendered foreground/background contrast")
    check(ink>=8,role+" "+state+" selected="+str(selected)+" actual text pixels visible")
    if selected:sheet.blit_rect(crop,Rect2i(0,0,150,52),Vector2i(si*150,ri*70))
    mouse(Vector2(930,780),false);await settle()
   b.queue_free();await settle()
 sheet.save_png("/tmp/button-state-matrix.png")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("BUTTON_STATE_QA: ",checks," checks, ",failures," failures; rows=",roles," columns=",states)
 quit(1 if failures else 0)

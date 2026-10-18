extends LineEdit
## Plain numeric user edits; existing fractional saves remain exact until edited.
signal value_changed(value: float)
var value: float = 6.0
var _accepted_text := "6"

func _ready() -> void:
 context_menu_enabled = false
 virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
 max_length = 64
 custom_minimum_size = Vector2(100, 48)
 set_meta("duration_input", true)
 text_changed.connect(_validate_draft)
 text_submitted.connect(func(_text): apply())
 focus_exited.connect(apply)
 set_value_no_signal(value)

func set_value_no_signal(next: float) -> void:
 value = next
 text = str(int(value)) if value == floorf(value) else str(value)
 _accepted_text = text
 tooltip_text = "1~30초 · 숫자만 입력"

func _validate_draft(draft: String) -> void:
 if draft.is_empty(): return
 var dots := 0
 for ch in draft:
  if ch == ".": dots += 1
  if (ch != "." and (ch < "0" or ch > "9")) or dots > 1:
   var caret := caret_column
   text = _accepted_text
   caret_column = mini(caret, text.length())
   tooltip_text = "숫자만 입력해 주세요."
   return
 _accepted_text = draft

func apply() -> void:
 # A legacy decimal is allowed unchanged, never silently rounded on opening.
 if text == (str(int(value)) if value == floorf(value) else str(value)):
  return
 var numeric := RegEx.new()
 numeric.compile("^[0-9]+(\\.[0-9]+)?$")
 if numeric.search(text) == null or not text.is_valid_float() or not is_finite(float(text)) or float(text) < 1 or float(text) > 30:
  set_value_no_signal(value)
  tooltip_text = "회전 시간은 1~30초여야 합니다."
  return
 var next := float(text)
 set_value_no_signal(next)
 value_changed.emit(value)

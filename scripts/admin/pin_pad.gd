## Εισαγωγή PIN διαχειριστή: αριθμητικό πληκτρολόγιο οθόνης (για αφή) και
## πληκτρολόγιο (ψηφία, Enter, Backspace, Esc) σε PC.
## Μετά από 5 λάθος προσπάθειες κλειδώνει για 30 δευτερόλεπτα.
extends Control

const UI = preload("res://scripts/admin/ui.gd")

signal accepted
signal cancelled

const MAX_DIGITS := 8
const MAX_FAILS := 5
const LOCK_SECONDS := 30

static var _fails := 0
static var _locked_until_ms := 0

var _entered := ""
var _dots: Label
var _msg: Label
var _panel: PanelContainer


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_panel.add_child(v)

	var title := UI.label("PIN διαχειριστή", "TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_dots = UI.label("")
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.add_theme_font_size_override("font_size", 48)
	_dots.custom_minimum_size = Vector2(0, 70)
	v.add_child(_dots)

	_msg = UI.label("", "MutedLabel")
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.custom_minimum_size = Vector2(420, 30)
	v.add_child(_msg)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]:
		var b := UI.button(key, "AccentButton" if key == "OK" else "", 130)
		b.custom_minimum_size = Vector2(130, 96)
		b.add_theme_font_size_override("font_size", 38)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_key.bind(key))
		grid.add_child(b)

	var cancel := UI.button("Άκυρο")
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): cancelled.emit())
	v.add_child(cancel)
	_refresh()


func _on_key(key: String) -> void:
	if _is_locked():
		_refresh()
		return
	match key:
		"⌫":
			_entered = _entered.substr(0, maxi(_entered.length() - 1, 0))
		"OK":
			_submit()
			return
		_:
			if _entered.length() < MAX_DIGITS:
				_entered += key
	_msg.text = ""
	_refresh()


func _submit() -> void:
	if _entered == str(Config.data["admin"]["pin"]):
		_fails = 0
		accepted.emit()
		return
	_fails += 1
	_entered = ""
	if _fails >= MAX_FAILS:
		_fails = 0
		_locked_until_ms = Time.get_ticks_msec() + LOCK_SECONDS * 1000
	else:
		_msg.text = "Λάθος PIN"
	_shake()
	_refresh()


func _is_locked() -> bool:
	return Time.get_ticks_msec() < _locked_until_ms


func _refresh() -> void:
	_dots.text = "●".repeat(_entered.length()) if _entered != "" else "– – – –"
	if _is_locked():
		var left := int(ceil((_locked_until_ms - Time.get_ticks_msec()) / 1000.0))
		_msg.text = "Πολλές λάθος προσπάθειες. Δοκίμασε ξανά σε %d δ." % left
		_msg.add_theme_color_override("font_color", UI.DANGER)
	elif _msg.text != "":
		_msg.add_theme_color_override("font_color", UI.DANGER)


func _process(_delta: float) -> void:
	if _is_locked():
		_refresh()


func _shake() -> void:
	var tw := create_tween()
	var x := _panel.position.x
	for i in 4:
		tw.tween_property(_panel, "position:x", x + (14.0 if i % 2 == 0 else -14.0), 0.05)
	tw.tween_property(_panel, "position:x", x, 0.05)


## Πληκτρολόγιο σε PC.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	get_viewport().set_input_as_handled()
	if k.keycode >= KEY_0 and k.keycode <= KEY_9:
		_on_key(str(k.keycode - KEY_0))
	elif k.keycode >= KEY_KP_0 and k.keycode <= KEY_KP_9:
		_on_key(str(k.keycode - KEY_KP_0))
	elif k.keycode == KEY_BACKSPACE:
		_on_key("⌫")
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_on_key("OK")
	elif k.keycode == KEY_ESCAPE:
		cancelled.emit()

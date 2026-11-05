## Θέμα (Theme) και βοηθητικά widgets για την οθόνη ρυθμίσεων.
## Σχεδιασμένα για αφή: μεγάλα κουμπιά, χοντρά sliders με μεγάλη λαβή,
## αλλά λειτουργούν κανονικά και με ποντίκι.
extends RefCounted

const BG := Color("#141827")
const PANEL := Color("#1e2338")
const CARD := Color("#262c47")
const FIELD := Color("#0f1220")
const BORDER := Color("#3a4270")
const ACCENT := Color("#ffcc33")
const BLUE := Color("#4f7cff")
const TEXT := Color("#eef1ff")
const MUTED := Color("#9aa3c0")
const DANGER := Color("#ff5a6a")
const SUCCESS := Color("#4fd18b")

const FONT_SIZE := 24
const ROW_H := 64

static var _theme: Theme


static func _box(bg: Color, radius: int = 12, mx: int = 20, my: int = 12, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	return sb


static func _circle_texture(d: int, fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := (d - 1) * 0.5
	for y in d:
		for x in d:
			var r := Vector2(x - c, y - c).length()
			var col := Color(0, 0, 0, 0)
			if r <= c - 3.0:
				col = fill
			elif r <= c:
				col = ring
			# απλό anti-aliasing στην άκρη
			if r > c - 1.0 and r <= c + 0.5:
				col.a *= clampf(c + 0.5 - r, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _button_styles(t: Theme, kind: String, normal: Color, hover: Color, pressed: Color, font: Color, font_pressed: Color) -> void:
	t.set_stylebox("normal", kind, _box(normal))
	t.set_stylebox("hover", kind, _box(hover))
	t.set_stylebox("pressed", kind, _box(pressed))
	t.set_stylebox("hover_pressed", kind, _box(pressed.lightened(0.08)))
	t.set_stylebox("disabled", kind, _box(normal.darkened(0.3)))
	t.set_stylebox("focus", kind, _box(Color(0, 0, 0, 0), 12, 20, 12, BLUE.lightened(0.3), 2))
	t.set_color("font_color", kind, font)
	t.set_color("font_hover_color", kind, font)
	t.set_color("font_focus_color", kind, font)
	t.set_color("font_pressed_color", kind, font_pressed)
	t.set_color("font_hover_pressed_color", kind, font_pressed)
	t.set_color("font_disabled_color", kind, Color(font, 0.4))


## Το θέμα της οθόνης ρυθμίσεων (πάντα DejaVu Sans, ώστε να διαβάζεται ακόμα
## κι αν ο διαχειριστής διαλέξει γραμματοσειρά για το παιχνίδι χωρίς ελληνικά).
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	t.default_font_size = FONT_SIZE
	var bold := load("res://assets/fonts/DejaVuSans-Bold.ttf") as Font

	_button_styles(t, "Button", CARD, CARD.lightened(0.1), BLUE, TEXT, Color.WHITE)
	t.set_font("font", "Button", bold)

	t.set_type_variation("AccentButton", "Button")
	_button_styles(t, "AccentButton", ACCENT, ACCENT.lightened(0.15), ACCENT.darkened(0.15), BG, BG)
	t.set_type_variation("DangerButton", "Button")
	_button_styles(t, "DangerButton", DANGER.darkened(0.35), DANGER.darkened(0.2), DANGER, TEXT, Color.WHITE)
	t.set_type_variation("NavButton", "Button")
	_button_styles(t, "NavButton", Color(0, 0, 0, 0), CARD, BLUE, MUTED, Color.WHITE)
	t.set_type_variation("SegButton", "Button")
	_button_styles(t, "SegButton", FIELD, CARD, BLUE, MUTED, Color.WHITE)

	_button_styles(t, "OptionButton", CARD, CARD.lightened(0.1), BLUE, TEXT, Color.WHITE)
	_button_styles(t, "ColorPickerButton", CARD, CARD.lightened(0.1), BLUE, TEXT, Color.WHITE)
	t.set_font_size("font_size", "PopupMenu", 28)
	t.set_constant("v_separation", "PopupMenu", 18)
	t.set_stylebox("panel", "PopupMenu", _box(PANEL, 12, 12, 12, BORDER, 2))
	t.set_stylebox("panel", "PopupPanel", _box(PANEL, 12, 12, 12, BORDER, 2))

	t.set_stylebox("normal", "LineEdit", _box(FIELD, 10, 16, 12, BORDER, 2))
	t.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), 10, 16, 12, BLUE, 2))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)

	# Slider: χοντρή μπάρα, μεγάλη λαβή (εύκολη στο δάχτυλο).
	var track := _box(FIELD, 8, 0, 9)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _box(BLUE, 8, 0, 9))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(BLUE.lightened(0.15), 8, 0, 9))
	t.set_icon("grabber", "HSlider", _circle_texture(44, Color.WHITE, BLUE))
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(44, ACCENT, BLUE))
	t.set_icon("grabber_disabled", "HSlider", _circle_texture(44, MUTED, BORDER))

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 16, 20, 16))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _box(CARD, 14, 20, 16))
	t.set_type_variation("WarnPanel", "PanelContainer")
	t.set_stylebox("panel", "WarnPanel", _box(DANGER.darkened(0.55), 12, 16, 10, DANGER, 2))

	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_font_size("font_size", "MutedLabel", 19)
	t.set_type_variation("HeadingLabel", "Label")
	t.set_color("font_color", "HeadingLabel", ACCENT)
	t.set_font_size("font_size", "HeadingLabel", 30)
	t.set_font("font", "HeadingLabel", bold)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", 34)
	t.set_font("font", "TitleLabel", bold)

	# Μεγάλη μπάρα κύλισης για αφή.
	var grab := _box(BORDER, 8, 8, 8)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(BLUE, 8, 8, 8))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(BLUE, 8, 8, 8))
	t.set_stylebox("scroll", "VScrollBar", _box(Color(0, 0, 0, 0.15), 8, 8, 8))

	t.set_stylebox("background", "ProgressBar", _box(FIELD, 8, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(BLUE, 8, 0, 0))
	t.set_type_variation("GoldBar", "ProgressBar")
	t.set_stylebox("fill", "GoldBar", _box(ACCENT, 8, 0, 0))
	t.set_type_variation("BigNumber", "Label")
	t.set_font_size("font_size", "BigNumber", 52)
	t.set_font("font", "BigNumber", bold)
	t.set_color("font_color", "BigNumber", ACCENT)

	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	_theme = t
	return t


# ---------------------------------------------------------------- widgets ---

static func button(text: String, variation: String = "", min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, ROW_H)
	if variation != "":
		b.theme_type_variation = variation
	return b


static func label(text: String, variation: String = "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func help(text: String) -> Label:
	return label(text, "MutedLabel")


static func heading(text: String) -> Label:
	return label(text, "HeadingLabel")


static func card() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "CardPanel"
	var v := VBoxContainer.new()
	p.add_child(v)
	return p


## Το VBoxContainer μέσα σε ένα card().
static func body(card_panel: PanelContainer) -> VBoxContainer:
	return card_panel.get_child(0) as VBoxContainer


## Οριζόντια σειρά: ετικέτα αριστερά (σταθερό πλάτος) και περιεχόμενο δεξιά.
static func row(caption: String, content: Control, caption_w: float = 300.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(caption)
	l.custom_minimum_size = Vector2(caption_w, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	# Τα πεδία απλώνονται, εκτός αν ζήτησαν μικρό μέγεθος (π.χ. Ναι/Όχι, χρώμα).
	if content.size_flags_horizontal == Control.SIZE_FILL:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(content)
	return h


## Παράθυρο διαλόγου πάνω από όλα. `buttons`: [[κείμενο, Callable, variation], ...].
## Κάθε κουμπί κλείνει το παράθυρο και μετά καλεί το Callable του.
static func modal(parent: Node, title: String, text: String, buttons: Array) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	panel.add_child(v)
	v.add_child(label(title, "HeadingLabel"))
	if text != "":
		var l := label(text)
		l.custom_minimum_size = Vector2(700, 0)
		v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h)
	for spec in buttons:
		var b := button(str(spec[0]), str(spec[2]) if spec.size() > 2 else "", 180)
		var cb: Callable = spec[1]
		b.pressed.connect(func():
			root.queue_free()
			if cb.is_valid():
				cb.call())
		h.add_child(b)
	parent.add_child(root)
	return root


## Σύντομο μήνυμα στο κάτω μέρος που σβήνει μόνο του.
static func toast(parent: Control, text: String, color: Color = SUCCESS) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(PANEL, 14, 24, 14, color, 3))
	var l := label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.reset_size()
	var s := parent.size
	p.position = Vector2((s.x - p.size.x) * 0.5, s.y - p.size.y - 40)
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


## Οριζόντια μπάρα τιμής (π.χ. στατιστικά).
static func bar(value: float, max_value: float, variation: String = "") -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = maxf(max_value, 1.0)
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(120, 26)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if variation != "":
		p.theme_type_variation = variation
	return p


## «Πλακίδιο» με μεγάλο αριθμό και ετικέτα.
static func tile(caption: String, value: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(FIELD, 14, 22, 14))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var n := label(value, "BigNumber")
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var c := label(caption, "MutedLabel")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	return p

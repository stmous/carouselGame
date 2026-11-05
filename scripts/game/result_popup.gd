## Popup αποτελέσματος: εικόνα που δίνει ο διαχειριστής (ή εναλλακτικό κείμενο),
## με animation εμφάνισης (scale-in με bounce ή απλό fade).
## Κλείνει με πάτημα (μετά από μικρό χρόνο ασφαλείας, ώστε το ίδιο πάτημα που
## σταμάτησε την κίνηση να μην το κλείσει αμέσως) ή αυτόματα.
extends Control

const PressInput = preload("res://scripts/util/press_input.gd")

signal closed

const MIN_OPEN_TIME := 0.7         # δευτερόλεπτα πριν δεχτεί πάτημα για κλείσιμο

var _dim: ColorRect
var _card: Control
var _image: TextureRect
var _fallback_icon: TextureRect
var _fallback_label: Label
var _hint: Label
var _open_time := 0.0
var _auto_close := 0.0
var _closing := false
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_image)

	_fallback_icon = TextureRect.new()
	_fallback_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fallback_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fallback_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_fallback_icon)

	_fallback_label = Label.new()
	_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_fallback_label)

	_hint = Label.new()
	_hint.text = "Πάτα για συνέχεια"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _card != null:
		_layout()


func _layout() -> void:
	var s := size
	var card_size := Vector2(s.x * 0.8, s.y * 0.78)
	_card.position = (s - card_size) * 0.5 - Vector2(0, s.y * 0.03)
	_card.size = card_size
	_card.pivot_offset = card_size * 0.5
	_fallback_icon.position = Vector2(card_size.x * 0.5 - card_size.y * 0.25, card_size.y * 0.05)
	_fallback_icon.size = Vector2(card_size.y * 0.5, card_size.y * 0.5)
	var fs := int(s.y * 0.085)
	_fallback_label.add_theme_font_size_override("font_size", fs)
	_fallback_label.add_theme_constant_override("outline_size", maxi(4, int(fs / 8.0)))
	_fallback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	var hs := int(s.y * 0.035)
	_hint.add_theme_font_size_override("font_size", hs)
	_hint.add_theme_constant_override("outline_size", maxi(2, int(hs / 6.0)))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.position = Vector2(0, s.y * 0.92)
	_hint.size = Vector2(s.x, hs * 1.5)


## Εμφανίζει το popup.
##  image:          εικόνα popup (ή null ⇒ εναλλακτικό περιεχόμενο)
##  fallback_text:  κείμενο αν δεν υπάρχει εικόνα
##  fallback_icon:  προαιρετικό εικονίδιο πάνω από το κείμενο
##  bounce:         true ⇒ scale-in με bounce, false ⇒ απλό fade
##  auto_close:     δευτερόλεπτα (≤ 0 ⇒ μόνο με πάτημα)
func open(image: Texture2D, fallback_text: String, fallback_icon: Texture2D, bounce: bool,
		auto_close: float, text_color: Color = Color.WHITE) -> void:
	_layout()
	_image.texture = image
	_image.visible = image != null
	var use_fallback := image == null
	_fallback_label.visible = use_fallback
	_fallback_icon.visible = use_fallback and fallback_icon != null
	_fallback_icon.texture = fallback_icon
	_fallback_label.text = fallback_text
	_fallback_label.add_theme_color_override("font_color", text_color)
	_hint.add_theme_color_override("font_color", Color(text_color, 0.8))
	if use_fallback:
		var top := _card.size.y * (0.58 if fallback_icon != null else 0.0)
		_fallback_label.position = Vector2(0, top)
		_fallback_label.size = Vector2(_card.size.x, _card.size.y - top)

	_open_time = 0.0
	_auto_close = auto_close
	_closing = false
	visible = true
	_hint.modulate.a = 0.0

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	modulate.a = 0.0
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	if bounce:
		_card.scale = Vector2(0.3, 0.3)
		_tween.tween_property(_card, "scale", Vector2.ONE, 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_card.scale = Vector2(0.96, 0.96)
		_tween.tween_property(_card, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hint, "modulate:a", 1.0, 0.3).set_delay(MIN_OPEN_TIME)


func is_open() -> bool:
	return visible and not _closing


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(_on_closed)


func _on_closed() -> void:
	visible = false
	_closing = false
	closed.emit()


func _process(delta: float) -> void:
	if not visible or _closing:
		return
	_open_time += delta
	if _auto_close > 0.0 and _open_time >= _auto_close:
		close()


func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if _open_time < MIN_OPEN_TIME:
		# Καταναλώνουμε τα πατήματα ώστε να μη «διαρρεύσουν» σε άλλες οθόνες.
		if PressInput.is_press(event):
			get_viewport().set_input_as_handled()
		return
	if PressInput.accept(event):
		get_viewport().set_input_as_handled()
		close()

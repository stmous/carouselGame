## Ζωντανή προεπισκόπηση στην οθόνη ρυθμίσεων: μια μικρή «οθόνη παιχνιδιού»
## (φόντο, λωρίδα, εικονίδια, κύκλος) που δείχνει αμέσως κάθε αλλαγή,
## ιδίως ταχύτητα και χρώματα. Άγγιγμα πάνω της = σταμάτημα/ξεκίνημα, με
## ένδειξη του αποτελέσματος (νίκη/αστόχηση/εικονίδιο).
extends VBoxContainer

const UI = preload("res://scripts/admin/ui.gd")
const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const ResultDetector = preload("res://scripts/core/result_detector.gd")
const PressInput = preload("res://scripts/util/press_input.gd")
const Backdrop = preload("res://scripts/game/backdrop.gd")
const CarouselView = preload("res://scripts/game/carousel_view.gd")
const TargetCircle = preload("res://scripts/game/target_circle.gd")

var aspect: AspectRatioContainer
var container: SubViewportContainer
var viewport: SubViewport
var backdrop: Backdrop
var circle_back: TargetCircle
var carousel: CarouselView
var circle_front: TargetCircle
var info: Label
var result: Label

var _cfg: Dictionary = {}
var _icons_signature := ""
var _speed := 0.5
var _speed_caption := ""


func _ready() -> void:
	aspect = AspectRatioContainer.new()
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.custom_minimum_size = Vector2(0, 260)
	add_child(aspect)

	container = SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_preview_input)
	aspect.add_child(container)

	viewport = SubViewport.new()
	viewport.handle_input_locally = false
	container.add_child(viewport)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(root)
	backdrop = Backdrop.new()
	root.add_child(backdrop)
	circle_back = TargetCircle.new()
	circle_back.layer = TargetCircle.Layer.BACK
	root.add_child(circle_back)
	carousel = CarouselView.new()
	root.add_child(carousel)
	carousel.stopped.connect(_show_result)
	circle_front = TargetCircle.new()
	circle_front.layer = TargetCircle.Layer.FRONT
	root.add_child(circle_front)

	result = UI.label("Άγγιξε την προεπισκόπηση για δοκιμαστικό σταμάτημα.", "MutedLabel")
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(result)
	info = UI.label("", "MutedLabel")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)


## Η προεπισκόπηση έχει την αναλογία της πραγματικής οθόνης.
func _process(_delta: float) -> void:
	var vs := get_viewport_rect().size
	if vs.y > 0.0:
		var r := vs.x / vs.y
		if absf(aspect.ratio - r) > 0.001:
			aspect.ratio = r
	_update_info()


## Εφαρμόζει τις (μη αποθηκευμένες) ρυθμίσεις. Αν δεν άλλαξε η λίστα
## εικονιδίων, η κίνηση συνεχίζει ομαλά χωρίς «άλμα».
func refresh(cfg: Dictionary) -> void:
	_cfg = cfg
	backdrop.configure(cfg["theme"]["background"])
	var fx: Dictionary = cfg["effects"]
	var boost := ConfigSchema.effect_intensity(str(fx["preset"]))
	circle_back.configure(cfg["theme"]["circle"], bool(fx["glow"]), boost)
	circle_front.configure(cfg["theme"]["circle"], bool(fx["glow"]), boost)
	var sig := ""
	for icon in cfg["icons"]["list"]:
		sig += str(icon["id"]) + "|" + str(icon["image"]) + ";"
	if sig != _icons_signature:
		_icons_signature = sig
		carousel.configure(cfg["icons"]["list"], cfg["icons"], cfg["theme"]["strip"])
		carousel.start(_speed)
		result.text = "Άγγιξε την προεπισκόπηση για δοκιμαστικό σταμάτημα."
	else:
		carousel.update_style(cfg["icons"], cfg["theme"]["strip"])


## Ορίζει την ταχύτητα που δείχνει η προεπισκόπηση (π.χ. της προσπάθειας
## που ρυθμίζεται εκείνη τη στιγμή).
func show_speed(speed_sw: float, caption: String = "") -> void:
	_speed = speed_sw
	_speed_caption = caption
	if carousel.is_moving():
		carousel.set_speed(speed_sw)
	else:
		carousel.start(speed_sw)


## Εικονίδια/δευτερόλεπτο στην ΠΡΑΓΜΑΤΙΚΗ οθόνη για ταχύτητα σε πλάτη/δ.
static func icons_per_second(cfg: Dictionary, speed_sw: float, screen: Vector2) -> float:
	var pitch_pct := float(cfg["icons"]["size_pct"]) + float(cfg["icons"]["gap_pct"])
	if pitch_pct <= 0.0 or screen.y <= 0.0:
		return 0.0
	return speed_sw * screen.x / (pitch_pct / 100.0 * screen.y)


func _update_info() -> void:
	if _cfg.is_empty():
		return
	var ips := icons_per_second(_cfg, _speed, get_viewport_rect().size)
	var t := "Ταχύτητα: %.2f πλάτη οθόνης/δ ≈ %.1f εικονίδια/δ" % [_speed, ips]
	if _speed_caption != "":
		t = _speed_caption + " — " + t
	if info.text != t:
		info.text = t


func _on_preview_input(event: InputEvent) -> void:
	# accept(): ένα άγγιγμα δίνει touch + εξομοιωμένο κλικ ⇒ μόνο ένα μετράει.
	if event is InputEventKey or not PressInput.accept(event):
		return
	if carousel.is_moving():
		var stop_cfg: Dictionary = _cfg["stop"]
		var ease_time := float(stop_cfg["ease_duration"]) if stop_cfg["mode"] == "ease" else 0.0
		if carousel.request_stop(ease_time) and ease_time <= 0.0:
			_show_result()
	else:
		circle_front.highlight = 0.0
		circle_back.highlight = 0.0
		carousel.start(_speed)
		result.text = "…"


func _show_result() -> void:
	var oc: Dictionary = _cfg["modes"][ConfigSchema.MODE_ONE_CORRECT]
	var is_oc: bool = _cfg["mode"] == ConfigSchema.MODE_ONE_CORRECT
	var radius := TargetCircle.radius_for(_cfg["theme"]["circle"], carousel.size.y)
	var r := ResultDetector.evaluate(carousel.offsets_px(), radius, float(oc["tolerance_pct"]) if is_oc else 100.0, is_oc)
	var idx: int = r["index"]
	if idx < 0:
		result.text = "Αστόχηση (εκτός ανοχής). Άγγιξε για ξανά."
		circle_front.highlight_color = Color("#ff5a5a")
	else:
		carousel.snap_to(idx, 0.18, true)
		var icon: Dictionary = _cfg["icons"]["list"][carousel.model.icon_at(idx)]
		var name_text := str(icon["name"])
		if is_oc:
			name_text += "  →  " + ("ΝΙΚΗ" if icon["id"] == oc["target_id"] else "όχι ο στόχος")
		result.text = "Σταμάτησε: " + name_text + ". Άγγιξε για ξανά."
		circle_front.highlight_color = Color.from_string(str(_cfg["theme"]["circle"]["highlight_color"]), Color.YELLOW)
	circle_back.highlight_color = circle_front.highlight_color
	circle_front.highlight = 1.0
	circle_back.highlight = 1.0

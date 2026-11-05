## Ζωγραφίζει την κινούμενη σειρά εικονιδίων (και την προαιρετική λωρίδα).
##
## Η λογική κίνησης ζει στο CarouselModel (σε μονάδες «βήματος»)· εδώ γίνεται
## μόνο η μετατροπή σε pixels και η σχεδίαση. Ένα draw pass για όλα τα
## εικονίδια ⇒ ελάχιστο κόστος, σταθερά 60 fps και σε tablet.
extends Control

const AssetLoader = preload("res://scripts/util/asset_loader.gd")
const IconSequencer = preload("res://scripts/core/icon_sequencer.gd")
const CarouselModel = preload("res://scripts/core/carousel_model.gd")

signal stopped
signal snapped

var model: CarouselModel
var sequencer: IconSequencer
var icons: Array = []             # λίστα εικονιδίων από το config
var textures: Array = []          # Texture2D ανά εικονίδιο (ή null)
var icon_cfg: Dictionary = {}     # icons.* (μέγεθος, απόσταση, σκιά)
var strip_cfg: Dictionary = {}    # theme.strip
var opacity := 1.0                # για χρήση ως φόντο στην οθόνη έλξης
var shadow_enabled := true

var speed_sw := 0.0               # πλάτη οθόνης / δευτερόλεπτο
var focus_slot := -1              # θυρίδα που «κούμπωσε» (για bounce)
var focus_scale := 1.0:
	set(v):
		focus_scale = v
		queue_redraw()

var _snap_tween: Tween
var _snap_done := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sequencer = IconSequencer.new(0)
	model = CarouselModel.new(sequencer, 5.0)


## Φορτώνει εικονίδια/ρυθμίσεις και ξαναχτίζει τη σειρά.
func configure(icon_list: Array, icons_settings: Dictionary, strip_settings: Dictionary) -> void:
	icons = icon_list
	icon_cfg = icons_settings
	strip_cfg = strip_settings
	shadow_enabled = bool(icon_cfg.get("shadow", true))
	textures.clear()
	for icon in icons:
		textures.append(AssetLoader.texture(str(icon["image"])))
	sequencer.reset(icons.size())
	_update_span()
	model.rebuild()
	focus_slot = -1
	queue_redraw()


func icon_size_px() -> float:
	return float(icon_cfg.get("size_pct", 18.0)) / 100.0 * size.y


## Απόσταση (σε px) μεταξύ των κέντρων δύο διαδοχικών εικονιδίων.
func pitch_px() -> float:
	var gap := float(icon_cfg.get("gap_pct", 6.0)) / 100.0 * size.y
	return maxf(icon_size_px() + gap, 1.0)


## Μετατροπή ταχύτητας από «πλάτη οθόνης/δ» σε «βήματα/δ».
func _speed_u() -> float:
	return speed_sw * size.x / pitch_px()


## Πόσα εικονίδια ανά δευτερόλεπτο περνούν από τον κύκλο σε αυτή την ταχύτητα
## (βοηθητική ένδειξη για το admin).
func icons_per_second(speed_screen_widths: float) -> float:
	return speed_screen_widths * size.x / pitch_px()


func _update_span() -> void:
	if model != null and size.x > 0.0:
		model.set_half_span(size.x * 0.5 / pitch_px() + 1.0)


func start(speed_screen_widths: float) -> void:
	_kill_snap()
	focus_slot = -1
	focus_scale = 1.0
	speed_sw = speed_screen_widths
	model.start(_speed_u())


## Ζητά σταμάτημα· επιστρέφει false αν δεν έτρεχε (διπλό πάτημα κ.λπ.).
func request_stop(ease_duration: float) -> bool:
	return model.request_stop(ease_duration)


func is_moving() -> bool:
	return model.is_moving()


## Θέσεις (με πρόσημο, σε px) των εικονιδίων σε σχέση με το κέντρο του κύκλου.
func offsets_px() -> Array:
	var p := pitch_px()
	var out: Array = []
	for u in model.offsets():
		out.append(float(u) * p)
	return out


## «Κούμπωμα»: φέρνει τη θυρίδα `slot` ακριβώς στο κέντρο, με μικρό bounce.
func snap_to(slot: int, duration: float = 0.18, bounce: bool = true) -> void:
	_kill_snap()
	var target_u: float = model.offsets()[slot]
	focus_slot = slot
	_snap_done = 0.0
	_snap_tween = create_tween()
	_snap_tween.tween_method(_snap_step.bind(-target_u), 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if bounce:
		_snap_tween.tween_property(self, "focus_scale", 1.15, 0.10).set_trans(Tween.TRANS_SINE)
		_snap_tween.tween_property(self, "focus_scale", 1.0, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_callback(func(): snapped.emit())


func _snap_step(t: float, total_du: float) -> void:
	# Προωθούμε μόνο τη διαφορά ⇒ σωστό ακόμα κι αν το μοντέλο ανακυκλώσει θυρίδες.
	var du := total_du * t - _snap_done
	_snap_done = total_du * t
	var before := model.popped_total
	model.advance(du)
	# Αν αφαιρέθηκαν θυρίδες από δεξιά, οι δείκτες μετατοπίστηκαν.
	if focus_slot >= 0:
		focus_slot -= model.popped_total - before
	queue_redraw()


func _kill_snap() -> void:
	if _snap_tween != null and _snap_tween.is_valid():
		_snap_tween.kill()
	_snap_tween = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_span()
		# Η ταχύτητα σε px/s εξαρτάται από το πλάτος: ενημέρωση σε αλλαγή μεγέθους.
		if model != null and model.state == CarouselModel.State.RUNNING:
			model.speed = _speed_u()
		queue_redraw()


func _process(delta: float) -> void:
	if model == null:
		return
	if model.is_moving():
		var before := model.popped_total
		var just_stopped := model.update(delta)
		if focus_slot >= 0:
			focus_slot -= model.popped_total - before
		queue_redraw()
		if just_stopped:
			stopped.emit()


func _draw() -> void:
	var s := size
	if s.x <= 0.0 or icons.is_empty():
		return
	var cy := s.y * 0.5
	var cx := s.x * 0.5

	if bool(strip_cfg.get("enabled", false)):
		var sc := Color.from_string(str(strip_cfg.get("color", "#000000")), Color.BLACK)
		sc.a = clampf(float(strip_cfg.get("alpha", 0.25)), 0.0, 1.0) * opacity
		var sh := float(strip_cfg.get("height_pct", 24.0)) / 100.0 * s.y
		draw_rect(Rect2(0.0, cy - sh * 0.5, s.x, sh), sc)

	var isz := icon_size_px()
	var p := pitch_px()
	var white := Color(1, 1, 1, opacity)
	var shadow := Color(0, 0, 0, 0.35 * opacity)
	for item in model.items():
		var x: float = cx + float(item["u"]) * p
		if x < -isz or x > s.x + isz:
			continue
		var idx: int = item["icon"]
		if idx < 0 or idx >= textures.size():
			continue
		var k := focus_scale if item["slot"] == focus_slot else 1.0
		var rect := _fit_rect(textures[idx], Vector2(x, cy), isz * k)
		var tex: Texture2D = textures[idx]
		if tex == null:
			draw_circle(Vector2(x, cy), isz * 0.45 * k, Color(1, 1, 1, 0.5 * opacity))
			continue
		if shadow_enabled:
			draw_texture_rect(tex, Rect2(rect.position + Vector2(isz * 0.03, isz * 0.05), rect.size), false, shadow)
		draw_texture_rect(tex, rect, false, white)


## Ορθογώνιο που χωράει την υφή σε τετράγωνο πλευράς `box` χωρίς παραμόρφωση.
static func _fit_rect(tex: Texture2D, center: Vector2, box: float) -> Rect2:
	var sz := Vector2(box, box)
	if tex != null:
		var ts := tex.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			var k := minf(box / ts.x, box / ts.y)
			sz = ts * k
	return Rect2(center - sz * 0.5, sz)

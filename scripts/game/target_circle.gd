## Ο κύκλος-στόχος. Ζωγραφίζεται σε δύο στρώματα:
##  - BACK  (πίσω από τα εικονίδια): εσωτερικό γέμισμα
##  - FRONT (μπροστά από τα εικονίδια): glow και περίγραμμα, ή εικόνα
## Όλα τα μεγέθη κλιμακώνονται με το ύψος της οθόνης (ανεξάρτητα από ανάλυση).
extends Control

const AssetLoader = preload("res://scripts/util/asset_loader.gd")

enum Layer { BACK, FRONT }

const REF_HEIGHT := 1080.0

var layer: int = Layer.FRONT
var cfg: Dictionary = {}          # theme.circle
var glow_enabled := true          # effects.glow
## 0..1: έμφαση μετά το σταμάτημα (χρώμα highlight, πιο έντονο glow).
var highlight := 0.0:
	set(v):
		highlight = v
		queue_redraw()
## Χρώμα έμφασης (π.χ. διαφορετικό για αστόχηση).
var highlight_color := Color.YELLOW
## Κλίμακα παλμού (1.0 = κανονικό μέγεθος).
var pulse := 1.0:
	set(v):
		pulse = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func configure(circle_cfg: Dictionary, glow_on: bool) -> void:
	cfg = circle_cfg
	glow_enabled = glow_on
	highlight_color = Color.from_string(str(cfg.get("highlight_color", "#ffe14d")), Color.YELLOW)
	queue_redraw()


## Ακτίνα του κύκλου σε pixels για το τρέχον μέγεθος οθόνης.
static func radius_for(circle_cfg: Dictionary, screen_h: float) -> float:
	return float(circle_cfg.get("size_pct", 26.0)) / 100.0 * screen_h * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if cfg.is_empty():
		return
	var s := size
	var c := s * 0.5
	var scale_k := s.y / REF_HEIGHT
	var r := radius_for(cfg, s.y) * pulse
	var base_col := Color.from_string(str(cfg["color"]), Color.WHITE)
	var col := base_col.lerp(highlight_color, highlight)
	var image_path := str(cfg.get("image", ""))

	if layer == Layer.BACK:
		if image_path == "":
			var fill := Color.from_string(str(cfg["fill_color"]), Color.WHITE)
			fill.a = clampf(float(cfg["fill_alpha"]) + 0.15 * highlight, 0.0, 1.0)
			if fill.a > 0.0:
				draw_circle(c, r, fill)
		return

	# FRONT
	var glow_on := glow_enabled and bool(cfg["glow"])
	if glow_on or highlight > 0.0:
		var gcol := Color.from_string(str(cfg["glow_color"]), Color.WHITE).lerp(highlight_color, highlight)
		var intensity := clampf(float(cfg["glow_intensity"]), 0.0, 1.0)
		if not glow_on:
			intensity = 0.0
		intensity = clampf(intensity + 0.6 * highlight, 0.0, 1.5)
		var steps := 8
		for i in range(steps, 0, -1):
			var t := float(i) / steps
			var a := intensity * 0.10 * (1.0 - t) * (1.0 - t) + intensity * 0.02
			gcol.a = a
			draw_arc(c, r, 0.0, TAU, 128, gcol, (6.0 + 46.0 * t) * scale_k, true)

	if image_path != "":
		var tex := AssetLoader.texture(image_path)
		if tex != null:
			var d := r * 2.0
			draw_texture_rect(tex, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false, Color.WHITE.lerp(highlight_color, highlight * 0.5))
			return

	var thick := maxf(1.0, float(cfg["thickness"]) * scale_k * (1.0 + 0.4 * highlight))
	draw_arc(c, r, 0.0, TAU, 160, col, thick, true)

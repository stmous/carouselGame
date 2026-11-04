## Φόντο: χρώμα, γραμμική διαβάθμιση δύο χρωμάτων ή εικόνα (cover/contain).
extends Control

const AssetLoader = preload("res://scripts/util/asset_loader.gd")

var cfg: Dictionary = {}   # theme.background


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func configure(background_cfg: Dictionary) -> void:
	cfg = background_cfg
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var s := size
	var rect := Rect2(Vector2.ZERO, s)
	var base := Color.from_string(str(cfg.get("color", "#1b1f3b")), Color(0.1, 0.1, 0.2))
	match str(cfg.get("type", "gradient")):
		"image":
			draw_rect(rect, base)
			var tex := AssetLoader.texture(str(cfg.get("image", "")))
			if tex != null:
				draw_texture_rect(tex, _image_rect(tex.get_size(), s, str(cfg.get("image_fit", "cover"))), false)
		"gradient":
			_draw_gradient(s)
		_:
			draw_rect(rect, base)


## Γραμμική διαβάθμιση σε οποιαδήποτε γωνία: χρώμα ανά κορυφή, που
## παρεμβάλλεται γραμμικά — ακριβές για γραμμική διαβάθμιση.
func _draw_gradient(s: Vector2) -> void:
	var c1 := Color.from_string(str(cfg.get("gradient_from", "#232a5c")), Color.BLACK)
	var c2 := Color.from_string(str(cfg.get("gradient_to", "#5a2a6e")), Color.BLACK)
	var a := deg_to_rad(float(cfg.get("gradient_angle", 90.0)))
	var dir := Vector2(cos(a), sin(a))
	var corners := [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]
	var lo := INF
	var hi := -INF
	for p in corners:
		var d: float = p.dot(dir)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	var span := maxf(hi - lo, 0.001)
	var colors := PackedColorArray()
	for p in corners:
		colors.append(c1.lerp(c2, (p.dot(dir) - lo) / span))
	draw_polygon(PackedVector2Array(corners), colors)


static func _image_rect(img: Vector2, screen: Vector2, fit: String) -> Rect2:
	if img.x <= 0.0 or img.y <= 0.0:
		return Rect2(Vector2.ZERO, screen)
	var k := screen.x / img.x
	var k2 := screen.y / img.y
	k = maxf(k, k2) if fit == "cover" else minf(k, k2)
	var sz := img * k
	return Rect2((screen - sz) * 0.5, sz)

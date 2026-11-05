## Γραμματοσειρές: ενσωματωμένες επιλογές (όλες με πλήρη ελληνικά) και
## γραμματοσειρές που εισήγαγε ο διαχειριστής (user://media/fonts/…).
extends RefCounted

const DEFAULT_ID := "default"

## [id, όνομα για το admin, αρχείο]
const BUILTIN := [
	["default", "DejaVu Sans Bold (προεπιλογή)", "res://assets/fonts/DejaVuSans-Bold.ttf"],
	["dejavu_sans", "DejaVu Sans", "res://assets/fonts/DejaVuSans.ttf"],
	["dejavu_serif", "DejaVu Serif Bold", "res://assets/fonts/DejaVuSerif-Bold.ttf"],
	["liberation_sans", "Liberation Sans Bold", "res://assets/fonts/LiberationSans-Bold.ttf"],
	["liberation_serif", "Liberation Serif Bold", "res://assets/fonts/LiberationSerif-Bold.ttf"],
	["carlito", "Carlito Bold", "res://assets/fonts/Carlito-Bold.ttf"],
]

static var _cache := {}


static func is_builtin(id: String) -> bool:
	for b in BUILTIN:
		if b[0] == id:
			return true
	return false


static func label_for(id: String) -> String:
	for b in BUILTIN:
		if b[0] == id:
			return b[1]
	return "Δική μου: " + id.get_file()


## Font για το id (ενσωματωμένο ή διαδρομή αρχείου). Πάντα επιστρέφει κάτι.
static func font_for(id: String) -> Font:
	if _cache.has(id):
		return _cache[id]
	var f: Font = null
	for b in BUILTIN:
		if b[0] == id:
			f = load(b[2]) as Font
	if f == null and id.begins_with("user://") and FileAccess.file_exists(id):
		var ff := FontFile.new()
		if ff.load_dynamic_font(id) == OK:
			f = ff
	if f == null and id != DEFAULT_ID:
		f = font_for(DEFAULT_ID)
	_cache[id] = f
	return f


## Theme με αυτή τη γραμματοσειρά ως προεπιλογή (για το root window).
static func theme_for(id: String) -> Theme:
	var t := Theme.new()
	t.default_font = font_for(id)
	return t

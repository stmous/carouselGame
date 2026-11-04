## Σχήμα ρυθμίσεων (config schema) με εκδόσεις.
##
## Όλες οι ρυθμίσεις του παιχνιδιού ζουν σε ένα Dictionary που αποθηκεύεται ως
## `user://config.json`. Εδώ ορίζονται οι προεπιλογές, η συγχώνευση ενός
## (πιθανώς παλιού ή ελλιπούς) αρχείου πάνω στις προεπιλογές, και οι
## μεταφορές (migrations) από παλαιότερες εκδόσεις του σχήματος.
##
## Pure λογική, χωρίς εξάρτηση από σκηνές, ώστε να ελέγχεται με unit tests.
extends RefCounted

const SCHEMA_VERSION := 1

const MODE_ONE_CORRECT := "one_correct"
const MODE_WHEEL := "wheel"

const MIN_ATTEMPTS := 1
const MAX_ATTEMPTS := 5
const MIN_SPEED := 0.2   # πλάτη οθόνης / δευτερόλεπτο
const MAX_SPEED := 3.0

const DEMO_ICON_DIR := "res://assets/demo/icons/"
const DEMO_POPUP_DIR := "res://assets/demo/popups/"


static func _demo_icon(id: String, name: String, replay: bool = false) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"image": DEMO_ICON_DIR + id + ".png",
		# Ρυθμίσεις «Τροχού της τύχης» ανά εικονίδιο:
		"popup": DEMO_POPUP_DIR + "prize_" + id + ".png",
		"sound": "",
		"replay": replay,
	}


## Πλήρεις εργοστασιακές ρυθμίσεις (demo θέμα).
static func defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"mode": MODE_ONE_CORRECT,
		"theme": {
			"background": {
				"type": "gradient",          # "color" | "gradient" | "image"
				"color": "#1b1f3b",
				"gradient_from": "#232a5c",
				"gradient_to": "#5a2a6e",
				"gradient_angle": 90.0,       # μοίρες: 90 = κάθετη
				"image": "",
				"image_fit": "cover",        # "cover" | "contain"
			},
			"logo": {"image": "", "size_pct": 25.0, "position": "top"},
			"circle": {
				"color": "#ffffff",
				"thickness": 10.0,           # px σε ύψος αναφοράς 1080
				"size_pct": 26.0,            # διάμετρος σε % ύψους οθόνης
				"fill_color": "#ffffff",
				"fill_alpha": 0.10,
				"glow": true,
				"glow_color": "#8fd3ff",
				"glow_intensity": 0.6,
				"image": "",
				"highlight_color": "#ffe14d",
			},
			"text_color": "#ffffff",
			"accent_color": "#ffe14d",
			"font": "default",
			"strip": {"enabled": true, "color": "#000000", "alpha": 0.25, "height_pct": 24.0},
		},
		"icons": {
			"list": [
				_demo_icon("star", "Αστέρι"),
				_demo_icon("heart", "Καρδιά"),
				_demo_icon("moon", "Φεγγάρι"),
				_demo_icon("sun", "Ήλιος"),
				_demo_icon("clover", "Τριφύλλι"),
				_demo_icon("diamond", "Διαμάντι"),
				_demo_icon("drop", "Σταγόνα"),
				_demo_icon("bolt", "Κεραυνός", true),
			],
			"size_pct": 18.0,                # σε % ύψους οθόνης
			"gap_pct": 6.0,                  # σε % ύψους οθόνης
			"shadow": true,
		},
		"modes": {
			MODE_ONE_CORRECT: {
				"target_id": "star",
				"attempts": 3,
				"speeds": [0.70, 0.50, 0.35, 0.30, 0.25],
				"tolerance_pct": 40.0,       # % της ακτίνας του κύκλου
				"win_popup": DEMO_POPUP_DIR + "win.png",
				"lose_popup": DEMO_POPUP_DIR + "lose.png",
				"retry_messages": [
					"Δεύτερη ευκαιρία!",
					"Τρίτη ευκαιρία!",
					"Τέταρτη ευκαιρία!",
					"Πέμπτη ευκαιρία!",
				],
			},
			MODE_WHEEL: {
				"speed": 0.60,
				"replay_speed": 0.50,
			},
		},
		"stop": {
			"mode": "ease",                  # "instant" | "ease"
			"ease_duration": 0.35,           # δευτερόλεπτα
		},
		"flow": {
			"attract_text": "Πάτα για να παίξεις",
			"countdown": true,
			"idle_timeout": 45.0,
			"popup_auto_close": 6.0,
			"retry_banner_duration": 1.6,
		},
		"effects": {
			"preset": "normal",              # "minimal" | "normal" | "arcade"
			"confetti": true,
			"glow": true,
			"bounce": true,
			"screen_shake": false,
			"circle_pulse": true,
		},
		"audio": {
			"master_mute": false,
			"music": {"file": "", "volume": 0.6, "enabled": true},
			"countdown": {"file": "", "volume": 0.8, "enabled": true},
			"stop": {"file": "", "volume": 0.8, "enabled": true},
			"win": {"file": "", "volume": 0.9, "enabled": true},
			"lose": {"file": "", "volume": 0.8, "enabled": true},
		},
		"admin": {"pin": "1234"},
		"kiosk": {"fullscreen": true, "hide_cursor": true, "keep_screen_on": true},
	}


## Συγχωνεύει αναδρομικά το `loaded` πάνω στο `base`.
## - Κλειδιά που λείπουν από το `loaded` παίρνουν την προεπιλογή.
## - Τιμές λάθος τύπου αγνοούνται (κρατιέται η προεπιλογή).
## - Πίνακες (Array) αντικαθίστανται ολόκληροι.
## - Άγνωστα κλειδιά του `loaded` διατηρούνται (forward compatibility).
static func merge(base: Dictionary, loaded: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in loaded.keys():
		var value = loaded[key]
		if not out.has(key):
			out[key] = value
			continue
		var current = out[key]
		if current is Dictionary:
			if value is Dictionary:
				out[key] = merge(current, value)
		elif current is Array:
			if value is Array:
				out[key] = value.duplicate(true)
		elif _is_number(current):
			if _is_number(value):
				out[key] = value
		elif typeof(current) == typeof(value):
			out[key] = value
	return out


static func _is_number(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## Μεταφέρει ένα dictionary από παλαιότερη έκδοση σχήματος στην τρέχουσα.
## Κάθε νέα έκδοση προσθέτει ένα βήμα `if version < N:` εδώ.
static func migrate(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var version := int(out.get("schema_version", 0))
	if version < 1:
		# Έκδοση 0 = αρχεία χωρίς αριθμό έκδοσης. Δεν υπάρχει τίποτα να
		# μετονομαστεί ακόμα· απλώς σημειώνουμε την έκδοση.
		version = 1
	out["schema_version"] = version
	return out


## Φορτώνει, μεταφέρει, συγχωνεύει και διορθώνει (sanitize) δεδομένα χρήστη.
static func from_user_data(data: Dictionary) -> Dictionary:
	var cfg := merge(defaults(), migrate(data))
	cfg["schema_version"] = SCHEMA_VERSION
	return sanitize(cfg)


## Επιβάλλει όρια και συνέπεια ώστε το παιχνίδι να μη «σπάει» ποτέ.
static func sanitize(cfg: Dictionary) -> Dictionary:
	if cfg["mode"] != MODE_ONE_CORRECT and cfg["mode"] != MODE_WHEEL:
		cfg["mode"] = MODE_ONE_CORRECT

	var oc: Dictionary = cfg["modes"][MODE_ONE_CORRECT]
	oc["attempts"] = clampi(int(oc["attempts"]), MIN_ATTEMPTS, MAX_ATTEMPTS)
	var speeds: Array = oc["speeds"]
	var fixed: Array = []
	for i in MAX_ATTEMPTS:
		var s := 0.5
		if i < speeds.size() and _is_number(speeds[i]):
			s = float(speeds[i])
		elif fixed.size() > 0:
			s = fixed[fixed.size() - 1]
		fixed.append(clampf(s, MIN_SPEED, MAX_SPEED))
	oc["speeds"] = fixed
	oc["tolerance_pct"] = clampf(float(oc["tolerance_pct"]), 1.0, 100.0)
	var msgs: Array = oc["retry_messages"]
	var default_msgs: Array = defaults()["modes"][MODE_ONE_CORRECT]["retry_messages"]
	while msgs.size() < MAX_ATTEMPTS - 1:
		msgs.append(default_msgs[msgs.size()])

	var wh: Dictionary = cfg["modes"][MODE_WHEEL]
	wh["speed"] = clampf(float(wh["speed"]), MIN_SPEED, MAX_SPEED)
	wh["replay_speed"] = clampf(float(wh["replay_speed"]), MIN_SPEED, MAX_SPEED)

	var stop: Dictionary = cfg["stop"]
	if stop["mode"] != "instant" and stop["mode"] != "ease":
		stop["mode"] = "ease"
	stop["ease_duration"] = clampf(float(stop["ease_duration"]), 0.05, 3.0)

	# Εικονίδια: κάθε στοιχείο πρέπει να έχει όλα τα πεδία και μοναδικό id.
	var clean: Array = []
	var seen := {}
	for item in cfg["icons"]["list"]:
		if not (item is Dictionary):
			continue
		var icon := merge({"id": "", "name": "", "image": "", "popup": "", "sound": "", "replay": false}, item)
		var id := str(icon["id"])
		if id == "" or seen.has(id):
			id = _unique_id(seen)
			icon["id"] = id
		seen[id] = true
		clean.append(icon)
	cfg["icons"]["list"] = clean
	cfg["icons"]["size_pct"] = clampf(float(cfg["icons"]["size_pct"]), 3.0, 60.0)
	cfg["icons"]["gap_pct"] = clampf(float(cfg["icons"]["gap_pct"]), 0.0, 60.0)

	# Ο στόχος πρέπει να υπάρχει στη λίστα.
	if not seen.has(str(oc["target_id"])) and clean.size() > 0:
		oc["target_id"] = clean[0]["id"]
	return cfg


static func _unique_id(seen: Dictionary) -> String:
	var n := seen.size() + 1
	while seen.has("icon_%d" % n):
		n += 1
	return "icon_%d" % n


## Επιστρέφει το εικονίδιο με το δοσμένο id ή κενό Dictionary.
static func find_icon(cfg: Dictionary, id: String) -> Dictionary:
	for icon in cfg["icons"]["list"]:
		if icon["id"] == id:
			return icon
	return {}


## Ids εικονιδίων του «Τροχού» που δεν έχουν popup (για προειδοποίηση στο admin).
static func icons_missing_popup(cfg: Dictionary) -> Array:
	var out: Array = []
	for icon in cfg["icons"]["list"]:
		if str(icon["popup"]) == "":
			out.append(icon["id"])
	return out

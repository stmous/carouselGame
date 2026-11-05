## Προφίλ θεμάτων: όλο το θέμα (ρυθμίσεις + αρχεία) σε ένα .zip, για μεταφορά
## από PC σε tablet ή γρήγορη εναλλαγή μεταξύ πελατών/εκδηλώσεων.
##
## Περιεχόμενο του zip:
##   profile.json   {"format": "stamata-theme", "format_version": 1, "name", "created",
##                   "app_version", "schema_version", "config": {...}}
##   media/...      τα αρχεία που χρησιμοποιεί το θέμα (εικόνες, ήχοι, γραμματοσειρές)
##
## Στο profile.json οι διαδρομές user://media/... γράφονται ως media/... .
## Δεν περιλαμβάνονται το PIN και οι ρυθμίσεις kiosk (αφορούν τη συσκευή).
extends RefCounted

const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const MediaImport = preload("res://scripts/util/media_import.gd")

const DIR := "user://profiles/"
const FORMAT := "stamata-theme"
const FORMAT_VERSION := 1
const EXCLUDED_KEYS := ["admin", "kiosk"]
const ALLOWED_EXTS := ["png", "jpg", "jpeg", "webp", "ogg", "wav", "mp3", "ttf", "otf"]
const MAX_ENTRY_BYTES := 64 * 1024 * 1024


# ------------------------------------------------------------ pure helpers ---

## Αντίγραφο του config χωρίς τα κλειδιά της συσκευής και με σχετικές
## διαδρομές. Επιστρέφει {"cfg": ..., "files": [user://media/... που χρειάζονται]}.
static func relativize(cfg: Dictionary) -> Dictionary:
	var out := cfg.duplicate(true)
	for k in EXCLUDED_KEYS:
		out.erase(k)
	var files := {}
	out = _rel(out, files)
	return {"cfg": out, "files": files.keys()}


## Αντίστροφο του relativize: media/... → user://media/... . Διαδρομές που
## δεν περιλαμβάνονται στο `available` (αρχεία που δεν βρέθηκαν) γίνονται "".
static func absolutize(cfg: Dictionary, available: Dictionary) -> Dictionary:
	return _abs(cfg, available)


static func _rel(v, files: Dictionary):
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _rel(v[k], files)
		return d
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_rel(x, files))
		return a
	if v is String and v.begins_with(MediaImport.MEDIA_ROOT):
		files[v] = true
		return "media/" + v.trim_prefix(MediaImport.MEDIA_ROOT)
	return v


static func _abs(v, available: Dictionary):
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _abs(v[k], available)
		return d
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_abs(x, available))
		return a
	if v is String and v.begins_with("media/"):
		if available.has(v):
			return MediaImport.MEDIA_ROOT + v.trim_prefix("media/")
		return ""
	return v


## Ασφαλές όνομα αρχείου μέσα στο zip: μόνο media/..., χωρίς «..», χωρίς
## απόλυτες διαδρομές, μόνο γνωστές καταλήξεις.
static func is_safe_entry(entry: String) -> bool:
	if not entry.begins_with("media/") or entry.contains("..") or entry.contains("\\") or entry.contains(":"):
		return false
	var parts := entry.split("/")
	if parts.size() != 3 or not ["images", "sounds", "fonts"].has(parts[1]) or parts[2] == "":
		return false
	return ALLOWED_EXTS.has(entry.get_extension().to_lower())


## Όνομα προφίλ → όνομα αρχείου (επιτρέπονται ελληνικά, όχι ειδικοί χαρακτήρες).
static func safe_profile_name(profile_name: String) -> String:
	var out := ""
	for ch in profile_name.strip_edges():
		out += "_" if "<>:\"/\\|?*".contains(ch) or ch.unicode_at(0) < 32 else ch
	out = out.strip_edges().trim_prefix(".")
	if out == "":
		out = "θέμα"
	return out.substr(0, 60)


# ----------------------------------------------------------------- zip ---

## Γράφει το θέμα σε zip. Επιστρέφει "" ή μήνυμα σφάλματος.
static func pack(cfg: Dictionary, zip_path: String, profile_name: String) -> String:
	var rel := relativize(cfg)
	DirAccess.make_dir_recursive_absolute(zip_path.get_base_dir())
	var zp := ZIPPacker.new()
	if zp.open(zip_path) != OK:
		return "Δεν ήταν δυνατή η δημιουργία του αρχείου zip."
	var manifest := {
		"format": FORMAT,
		"format_version": FORMAT_VERSION,
		"name": profile_name,
		"created": Time.get_datetime_string_from_system(),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"schema_version": ConfigSchema.SCHEMA_VERSION,
		"config": rel["cfg"],
	}
	zp.start_file("profile.json")
	zp.write_file(JSON.stringify(manifest, "\t").to_utf8_buffer())
	zp.close_file()
	for f in rel["files"]:
		if not FileAccess.file_exists(f):
			continue
		zp.start_file("media/" + str(f).trim_prefix(MediaImport.MEDIA_ROOT))
		zp.write_file(FileAccess.get_file_as_bytes(f))
		zp.close_file()
	zp.close()
	return ""


## Διαβάζει θέμα από zip, αντιγράφει τα αρχεία του στο user://media/ και
## επιστρέφει {"cfg": πλήρες config, "name": ..., "error": "", "warning": ""}.
## Το PIN και οι ρυθμίσεις kiosk κρατιούνται από το `current_cfg`.
static func unpack(zip_path: String, current_cfg: Dictionary) -> Dictionary:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return {"error": "Το αρχείο δεν είναι έγκυρο zip."}
	var files := zr.get_files()
	if not files.has("profile.json"):
		zr.close()
		return {"error": "Το zip δεν περιέχει θέμα (λείπει το profile.json)."}
	var manifest = JSON.parse_string(zr.read_file("profile.json").get_string_from_utf8())
	if not (manifest is Dictionary) or manifest.get("format", "") != FORMAT or not (manifest.get("config") is Dictionary):
		zr.close()
		return {"error": "Το zip δεν είναι θέμα αυτού του παιχνιδιού."}
	var warning := ""
	if int(manifest.get("schema_version", 0)) > ConfigSchema.SCHEMA_VERSION:
		warning = "Το θέμα φτιάχτηκε με νεότερη έκδοση της εφαρμογής· κάποιες ρυθμίσεις ίσως αγνοηθούν."

	var available := {}
	for entry in files:
		if entry == "profile.json" or entry.ends_with("/"):
			continue
		if not is_safe_entry(entry):
			push_warning("Αγνοήθηκε μη ασφαλές αρχείο στο zip: " + entry)
			continue
		var bytes := zr.read_file(entry)
		if bytes.size() > MAX_ENTRY_BYTES:
			continue
		var dest: String = MediaImport.MEDIA_ROOT + entry.trim_prefix("media/")
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var f := FileAccess.open(dest, FileAccess.WRITE)
		if f == null:
			continue
		f.store_buffer(bytes)
		f.close()
		available[entry] = true
	zr.close()

	var cfg: Dictionary = absolutize(manifest["config"], available)
	for k in EXCLUDED_KEYS:
		if current_cfg.has(k):
			cfg[k] = current_cfg[k].duplicate(true)
	cfg = ConfigSchema.from_user_data(cfg)
	return {"cfg": cfg, "name": str(manifest.get("name", zip_path.get_file().get_basename())),
		"error": "", "warning": warning}


## Αποθηκευμένα προφίλ: [{"name", "path", "modified"}], νεότερο πρώτο.
static func list() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension().to_lower() != "zip":
			continue
		var p := DIR + f
		out.append({"name": f.get_basename(), "path": p, "modified": FileAccess.get_modified_time(p)})
	# Ταξινόμηση: νεότερο πρώτο (insertion sort — λίγα στοιχεία).
	for i in range(1, out.size()):
		var item = out[i]
		var j := i - 1
		while j >= 0 and int(out[j]["modified"]) < int(item["modified"]):
			out[j + 1] = out[j]
			j -= 1
		out[j + 1] = item
	return out


static func path_for(profile_name: String) -> String:
	return DIR + safe_profile_name(profile_name) + ".zip"

## Εισαγωγή αρχείων του διαχειριστή (εικόνες, ήχοι, γραμματοσειρές).
##
## Κάθε αρχείο ΑΝΤΙΓΡΑΦΕΤΑΙ στο user://media/, ώστε το παιχνίδι να μην
## εξαρτάται από το αρχικό αρχείο (που μπορεί να σβηστεί ή να είναι σε USB).
## Οι πολύ μεγάλες εικόνες σμικρύνονται αυτόματα κατά την εισαγωγή.
## Το όνομα προορισμού περιέχει hash του περιεχομένου ⇒ το ίδιο αρχείο δεν
## αντιγράφεται δύο φορές και η cache εικόνων δεν «μπερδεύεται».
extends RefCounted

const MEDIA_ROOT := "user://media/"

## Μέγιστες διαστάσεις ανά είδος εικόνας (μεγαλύτερες σμικρύνονται).
const LIMITS := {
	"backdrop": Vector2i(2560, 1600),
	"logo": Vector2i(1600, 1000),
	"icon": Vector2i(768, 768),
	"popup": Vector2i(1600, 1200),
	"circle": Vector2i(1024, 1024),
}

## Βοήθεια με τα προτεινόμενα μεγέθη (εμφανίζεται στο admin).
const HELP := {
	"backdrop": "Προτείνεται 1920×1080 (ή 2560×1600 για tablet). PNG/JPG/WebP.",
	"logo": "PNG με διαφάνεια, έως 1600 px πλάτος.",
	"icon": "Τετράγωνο PNG με διαφάνεια, 512×512.",
	"popup": "PNG, έως 1600×1200.",
	"circle": "Τετράγωνο PNG με διαφάνεια (π.χ. 1024×1024). Αντικαθιστά τον ζωγραφιστό κύκλο.",
	"sound": "OGG, WAV ή MP3. Για τη μουσική προτείνεται OGG.",
	"font": "Αρχείο .ttf ή .otf που υποστηρίζει ελληνικά.",
}

const IMAGE_EXTS := ["png", "jpg", "jpeg", "webp"]
const SOUND_EXTS := ["ogg", "wav", "mp3"]
const FONT_EXTS := ["ttf", "otf"]


# ------------------------------------------------------------ pure helpers ---

## Νέες διαστάσεις ώστε η εικόνα να χωράει στο όριο, χωρίς μεγέθυνση και
## χωρίς παραμόρφωση.
static func fit_size(w: int, h: int, max_w: int, max_h: int) -> Vector2i:
	if w <= 0 or h <= 0:
		return Vector2i(maxi(w, 0), maxi(h, 0))
	if w <= max_w and h <= max_h:
		return Vector2i(w, h)
	var k := minf(float(max_w) / w, float(max_h) / h)
	return Vector2i(maxi(1, int(round(w * k))), maxi(1, int(round(h * k))))


## Ασφαλές όνομα αρχείου (λατινικά, αριθμοί, _ και -). Ελληνικά/κενά → _.
static func safe_name(file_name: String) -> String:
	var base := file_name.get_file().get_basename().to_lower()
	var out := ""
	for ch in base:
		var c := ch.unicode_at(0)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or ch == "-" or ch == "_"
		out += ch if ok else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.strip_edges().trim_prefix("_").trim_suffix("_")
	if out == "":
		out = "file"
	return out.substr(0, 32)


## Αναγνώριση τύπου εικόνας από τα πρώτα bytes (όχι από την κατάληξη).
static func detect_image_format(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		return "png"
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		return "jpg"
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
			and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	return ""


static func detect_audio_format(bytes: PackedByteArray) -> String:
	if bytes.size() >= 4 and bytes.slice(0, 4).get_string_from_ascii() == "OggS":
		return "ogg"
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
			and bytes.slice(8, 12).get_string_from_ascii() == "WAVE":
		return "wav"
	if bytes.size() >= 3 and bytes.slice(0, 3).get_string_from_ascii() == "ID3":
		return "mp3"
	if bytes.size() >= 2 and bytes[0] == 0xFF and (bytes[1] & 0xE0) == 0xE0:
		return "mp3"
	return ""


static func detect_font_format(bytes: PackedByteArray) -> String:
	if bytes.size() < 4:
		return ""
	var head := bytes.slice(0, 4)
	if head == PackedByteArray([0, 1, 0, 0]) or head.get_string_from_ascii() == "true":
		return "ttf"
	if head.get_string_from_ascii() == "OTTO":
		return "otf"
	return ""


static func _hash(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 10)


## Όλα τα αρχεία user://media/ που αναφέρονται κάπου στις ρυθμίσεις.
static func referenced_media(data) -> Dictionary:
	var out := {}
	_collect(data, out)
	return out


static func _collect(v, out: Dictionary) -> void:
	if v is Dictionary:
		for k in v:
			_collect(v[k], out)
	elif v is Array:
		for x in v:
			_collect(x, out)
	elif v is String and v.begins_with(MEDIA_ROOT):
		out[v] = true


# --------------------------------------------------------------- εισαγωγή ---

static func _read(src: String) -> PackedByteArray:
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	return f.get_buffer(f.get_length())


static func _write(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return true


## Εισάγει εικόνα. Επιστρέφει {"path", "error", "resized", "size"}.
static func import_image(src: String, kind: String) -> Dictionary:
	var bytes := _read(src)
	if bytes.is_empty():
		return {"path": "", "error": "Δεν ήταν δυνατή η ανάγνωση του αρχείου."}
	var fmt := detect_image_format(bytes)
	if fmt == "":
		return {"path": "", "error": "Μη υποστηριζόμενη εικόνα. Χρησιμοποίησε PNG, JPG ή WebP."}
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match fmt:
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
	if err != OK or img.is_empty():
		return {"path": "", "error": "Η εικόνα είναι κατεστραμμένη ή δεν διαβάζεται."}

	var limit: Vector2i = LIMITS.get(kind, Vector2i(2048, 2048))
	var target := fit_size(img.get_width(), img.get_height(), limit.x, limit.y)
	var resized := target != Vector2i(img.get_width(), img.get_height())
	var base_name := safe_name(src) + "_" + _hash(bytes)
	var dest: String
	if resized:
		img.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute(MEDIA_ROOT + "images")
		if fmt == "jpg":
			dest = MEDIA_ROOT + "images/" + base_name + ".jpg"
			err = img.save_jpg(dest, 0.9)
		else:
			dest = MEDIA_ROOT + "images/" + base_name + ".png"
			err = img.save_png(dest)
		if err != OK:
			return {"path": "", "error": "Αποτυχία αποθήκευσης της εικόνας."}
	else:
		dest = MEDIA_ROOT + "images/" + base_name + "." + fmt
		if not _write(dest, bytes):
			return {"path": "", "error": "Αποτυχία αντιγραφής της εικόνας."}
	return {"path": dest, "error": "", "resized": resized, "size": target}


static func import_sound(src: String) -> Dictionary:
	var bytes := _read(src)
	if bytes.is_empty():
		return {"path": "", "error": "Δεν ήταν δυνατή η ανάγνωση του αρχείου."}
	var fmt := detect_audio_format(bytes)
	if fmt == "":
		return {"path": "", "error": "Μη υποστηριζόμενος ήχος. Χρησιμοποίησε OGG, WAV ή MP3."}
	var dest := MEDIA_ROOT + "sounds/" + safe_name(src) + "_" + _hash(bytes) + "." + fmt
	if not _write(dest, bytes):
		return {"path": "", "error": "Αποτυχία αντιγραφής του ήχου."}
	return {"path": dest, "error": ""}


static func import_font(src: String) -> Dictionary:
	var bytes := _read(src)
	if bytes.is_empty():
		return {"path": "", "error": "Δεν ήταν δυνατή η ανάγνωση του αρχείου."}
	var fmt := detect_font_format(bytes)
	if fmt == "":
		return {"path": "", "error": "Μη υποστηριζόμενη γραμματοσειρά. Χρησιμοποίησε .ttf ή .otf."}
	var dest := MEDIA_ROOT + "fonts/" + safe_name(src) + "_" + _hash(bytes) + "." + fmt
	if not _write(dest, bytes):
		return {"path": "", "error": "Αποτυχία αντιγραφής της γραμματοσειράς."}
	var test := FontFile.new()
	if test.load_dynamic_font(dest) != OK:
		DirAccess.remove_absolute(dest)
		return {"path": "", "error": "Η γραμματοσειρά δεν διαβάζεται."}
	return {"path": dest, "error": ""}


## Σβήνει αρχεία του user://media/ που δεν χρησιμοποιούνται πια.
## Επιστρέφει πόσα σβήστηκαν.
static func collect_garbage(data) -> int:
	var used := referenced_media(data)
	var removed := 0
	for sub in ["images", "sounds", "fonts"]:
		var dir_path: String = MEDIA_ROOT + sub
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for f in dir.get_files():
			var p := dir_path + "/" + f
			if not used.has(p):
				if DirAccess.remove_absolute(p) == OK:
					removed += 1
	return removed

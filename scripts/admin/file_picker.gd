## Επιλογή αρχείου με native dialog (Windows: Explorer, Android: επιλογέας
## αρχείων του συστήματος). Αν η πλατφόρμα δεν έχει native dialog, ή αν το
## αρχείο που επιστράφηκε δεν διαβάζεται, ανοίγει το ενσωματωμένο FileDialog
## του Godot (σε Android ζητά πρώτα άδεια πρόσβασης στα αρχεία).
extends Node

const FILTERS := {
	"image": ["*.png, *.jpg, *.jpeg, *.webp ; Εικόνες (PNG, JPG, WebP)"],
	"sound": ["*.ogg, *.wav, *.mp3 ; Ήχοι (OGG, WAV, MP3)"],
	"font": ["*.ttf, *.otf ; Γραμματοσειρές (TTF, OTF)"],
	"zip": ["*.zip ; Θέμα (ZIP)"],
}
const TITLES := {
	"image": "Επιλογή εικόνας",
	"sound": "Επιλογή ήχου",
	"font": "Επιλογή γραμματοσειράς",
	"zip": "Επιλογή αρχείου θέματος",
}

var _callback: Callable
var _kind := ""
var _dialog: FileDialog


static func _start_dir(kind: String) -> String:
	var d := ""
	match kind:
		"image":
			d = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		"sound":
			d = OS.get_system_dir(OS.SYSTEM_DIR_MUSIC)
		_:
			d = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if d == "" or not DirAccess.dir_exists_absolute(d):
		d = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	return d


## Ανοίγει επιλογή αρχείου. `callback(path: String)` καλείται μόνο αν
## επιλεγεί αρχείο.
func pick(kind: String, callback: Callable) -> void:
	_kind = kind
	_callback = callback
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var err := DisplayServer.file_dialog_show(TITLES.get(kind, "Επιλογή αρχείου"), _start_dir(kind), "",
			false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(FILTERS.get(kind, [])),
			_on_native_done)
		if err == OK:
			return
	_open_builtin()


## (Το callback μπορεί να έρθει εκτός κύριου νήματος σε κάποιες πλατφόρμες ⇒
## ό,τι αγγίζει το scene tree γίνεται με call_deferred.)
func _on_native_done(status: bool, paths: PackedStringArray, _filter_index: int) -> void:
	if not status or paths.is_empty():
		return
	var path := paths[0]
	# Ορισμένες εκδόσεις Android επιστρέφουν διαδρομή που δεν ανοίγει απευθείας·
	# τότε πέφτουμε στο ενσωματωμένο dialog.
	if FileAccess.file_exists(path) or FileAccess.open(path, FileAccess.READ) != null:
		_callback.call_deferred(path)
	else:
		push_warning("Το native dialog επέστρεψε μη αναγνώσιμη διαδρομή: " + path)
		_open_builtin.call_deferred()


func _open_builtin() -> void:
	if OS.get_name() == "Android":
		OS.request_permissions()
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.use_native_dialog = false
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.file_selected.connect(func(p: String): _callback.call(p))
		add_child(_dialog)
	_dialog.title = TITLES.get(_kind, "Επιλογή αρχείου")
	_dialog.filters = PackedStringArray(FILTERS.get(_kind, []))
	_dialog.current_dir = _start_dir(_kind)
	_dialog.popup_centered_ratio(0.85)

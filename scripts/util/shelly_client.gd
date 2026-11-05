## Ασύγχρονος πελάτης για το τοπικό HTTP RPC API του Shelly.
##
## - Κάθε κλήση είναι ένα HTTPRequest στο παρασκήνιο (σε δικό του thread):
##   ο καλών ΔΕΝ περιμένει ποτέ και το παιχνίδι δεν «κολλάει».
## - Timeout 2 δευτερόλεπτα και (προαιρετικά) μία επανάληψη στο παρασκήνιο.
## - Αν το Shelly ζητήσει κωδικό (401), απαντά με HTTP Digest (SHA-256).
## - Οι αποτυχίες γράφονται στο user://logs/light.log (και στο log του Godot),
##   ποτέ στην οθόνη του παίκτη.
extends Node

const ShellyRpc = preload("res://scripts/core/shelly_rpc.gd")

const TIMEOUT := 2.0
const RETRY_DELAY := 0.3
const LOG_PATH := "user://logs/light.log"
const LOG_MAX_BYTES := 256 * 1024

## Μπορεί να μικρύνει στα tests (για γρήγορες δοκιμές timeout).
var timeout := TIMEOUT
## Πόσα αιτήματα είναι σε εξέλιξη (για tests/διαγνωστικά).
var in_flight := 0
## Πόσες HTTP προσπάθειες έχουν ξεκινήσει συνολικά (για tests).
var attempts_started := 0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Στέλνει GET `path` στο Shelly που περιγράφουν οι `settings` (ip, username,
## password). `done(ok: bool, code: int, body: String)` καλείται όταν τελειώσει
## (ή αν η διεύθυνση δεν είναι έγκυρη). `retries`: επιπλέον προσπάθειες.
func send(settings: Dictionary, path: String, done: Callable = Callable(), retries: int = 1) -> void:
	var host := ShellyRpc.normalize_host(str(settings.get("ip", "")))
	if host == "":
		log_line("Μη έγκυρη διεύθυνση Shelly: «%s»" % str(settings.get("ip", "")))
		if done.is_valid():
			done.call_deferred(false, 0, "invalid address")
		return
	in_flight += 1
	var job := {
		"url": "http://" + host + path,
		"path": path,
		"user": str(settings.get("username", "")),
		"password": str(settings.get("password", "")),
		"done": done,
		"retries": retries,
		"auth": "",
		"nc": 0,
	}
	_attempt(job)


func _attempt(job: Dictionary) -> void:
	attempts_started += 1
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.use_threads = true
	add_child(req)
	req.request_completed.connect(_on_completed.bind(req, job))
	var headers := PackedStringArray()
	if str(job["auth"]) != "":
		headers.append(job["auth"])
	var err := req.request(job["url"], headers, HTTPClient.METHOD_GET)
	if err != OK:
		req.queue_free()
		_attempt_failed(job, "αποτυχία έναρξης αιτήματος (%d)" % err, 0)


func _on_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray,
		req: HTTPRequest, job: Dictionary) -> void:
	req.queue_free()
	var text := body.get_string_from_utf8()
	# 401 με κωδικό ⇒ ξανά αμέσως με digest (δεν μετράει ως επανάληψη).
	if result == HTTPRequest.RESULT_SUCCESS and code == 401 and str(job["password"]) != "" \
			and str(job["auth"]) == "":
		var challenge := ShellyRpc.header_value(headers, "WWW-Authenticate")
		job["nc"] = int(job["nc"]) + 1
		job["auth"] = ShellyRpc.authorization_header(challenge, job["user"], job["password"], "GET",
			job["path"], "%08x%08x" % [_rng.randi(), _rng.randi()], "%08x" % int(job["nc"]))
		if str(job["auth"]) != "":
			_attempt(job)
			return
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		_finish(job, true, code, text)
		return
	var reason := _describe(result, code)
	_attempt_failed(job, reason, code)


func _attempt_failed(job: Dictionary, reason: String, code: int) -> void:
	if int(job["retries"]) > 0:
		job["retries"] = int(job["retries"]) - 1
		job["auth"] = ""
		log_line("%s → %s· νέα προσπάθεια" % [job["url"], reason])
		await get_tree().create_timer(RETRY_DELAY).timeout
		if is_inside_tree():
			_attempt(job)
		return
	log_line("%s → %s" % [job["url"], reason])
	_finish(job, false, code, reason)


func _finish(job: Dictionary, ok: bool, code: int, body: String) -> void:
	in_flight = maxi(in_flight - 1, 0)
	var done: Callable = job["done"]
	if done.is_valid():
		done.call(ok, code, body)


static func _describe(result: int, code: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			if code == 401:
				return "HTTP 401 (απαιτείται κωδικός ή λάθος κωδικός)"
			return "HTTP %d" % code
		HTTPRequest.RESULT_TIMEOUT:
			return "timeout"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "δεν έγινε σύνδεση"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "άγνωστη διεύθυνση"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "σφάλμα σύνδεσης"
	return "σφάλμα δικτύου (%d)" % result


## Γραμμή στο log (με ώρα). Το αρχείο «ανακυκλώνεται» όταν μεγαλώσει.
static func log_line(text: String) -> void:
	push_warning("[Φως] " + text)
	DirAccess.make_dir_recursive_absolute(LOG_PATH.get_base_dir())
	if FileAccess.file_exists(LOG_PATH):
		var size_check := FileAccess.open(LOG_PATH, FileAccess.READ)
		if size_check != null and size_check.get_length() > LOG_MAX_BYTES:
			size_check.close()
			DirAccess.rename_absolute(LOG_PATH, LOG_PATH + ".old")
	var f: FileAccess
	if FileAccess.file_exists(LOG_PATH):
		f = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("%s  %s" % [Time.get_datetime_string_from_system(), text])
	f.close()

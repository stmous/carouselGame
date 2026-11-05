## Autoload «Light»: εξωτερικό φως μέσω ρελέ Shelly (τοπικό δίκτυο, χωρίς cloud).
##
## - Στην εκκίνηση στέλνει «σβήσιμο», ώστε να μη μείνει αναμμένο από προηγούμενη φορά.
## - Στη νίκη (βλ. LightRules) στέλνει «άναμμα για Ν δευτερόλεπτα»· το σβήσιμο
##   το κάνει ο χρονοδιακόπτης του ίδιου του Shelly (toggle_after).
## - Όλες οι κλήσεις είναι ασύγχρονες: το παιχνίδι δεν περιμένει ποτέ.
## - Αν η λειτουργία είναι απενεργοποιημένη, δεν γίνεται καμία δικτυακή κλήση.
extends Node

const ShellyRpc = preload("res://scripts/core/shelly_rpc.gd")
const LightRules = preload("res://scripts/core/light_rules.gd")
const ShellyClient = preload("res://scripts/util/shelly_client.gd")

var client: ShellyClient


func _ready() -> void:
	client = ShellyClient.new()
	add_child(client)
	_startup_off.call_deferred()


func _settings() -> Dictionary:
	return Config.data["light"]


func _startup_off() -> void:
	var s := _settings()
	if bool(s["enabled"]):
		client.send(s, ShellyRpc.switch_set_path(int(s["output"]), false), Callable(), 1)


## Καλείται από το παιχνίδι όταν εμφανίζεται ένα αποτέλεσμα. Επιστρέφει
## αμέσως· αν πρέπει, ανάβει το φως στο παρασκήνιο.
func on_result(outcome: int, icon_id: String) -> void:
	if LightRules.should_light(Config.data, outcome, icon_id):
		turn_on(_settings())


## Άναμμα για `duration` δευτερόλεπτα (με μία επανάληψη στο παρασκήνιο).
func turn_on(settings: Dictionary, done: Callable = Callable()) -> void:
	if not bool(settings.get("enabled", false)):
		return
	client.send(settings,
		ShellyRpc.switch_set_path(int(settings["output"]), true, int(settings["duration"])), done, 1)


## Έλεγχος σύνδεσης (Shelly.GetStatus) για την οθόνη ρυθμίσεων.
## `done(ok: bool, code: int, body: String)`.
func check_status(settings: Dictionary, done: Callable) -> void:
	if not bool(settings.get("enabled", false)):
		return
	client.send(settings, ShellyRpc.STATUS_PATH, done, 0)

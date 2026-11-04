## Ροή ενός παιχνιδιού (ενός παίκτη) για κάθε λειτουργία.
##
## «Ένα σωστό»:  στόχος → WIN· αλλιώς RETRY (αν μένουν προσπάθειες) ή LOSE.
## «Τροχός»:     κάθε αποτέλεσμα είναι έγκυρο → WHEEL, ή WHEEL_REPLAY αν το
##               εικονίδιο έχει σήμανση «Ξαναπαίξε».
##
## Κρατά και την καταγραφή του παιχνιδιού (για τα στατιστικά).
## Pure λογική, ελέγχεται με unit tests.
extends RefCounted

const ConfigSchema = preload("res://scripts/core/config_schema.gd")

enum Outcome { NONE, WIN, RETRY, LOSE, WHEEL, WHEEL_REPLAY }

var mode := ConfigSchema.MODE_ONE_CORRECT
var attempt := 0               # 0-based δείκτης τρέχουσας προσπάθειας
var finished := false
var is_test := false           # δοκιμαστικό παιχνίδι: δεν μετράει στα στατιστικά
var results: Array = []        # id εικονιδίου ανά προσπάθεια ("" = αστόχηση)
var won := false
var win_attempt := 0           # 1-based, 0 = καμία νίκη
var started_at := ""

var _cfg: Dictionary
var _replay_next := false


func _init(cfg: Dictionary, test_game: bool = false, timestamp: String = "") -> void:
	_cfg = cfg
	mode = cfg["mode"]
	is_test = test_game
	started_at = timestamp


func _mode_cfg() -> Dictionary:
	return _cfg["modes"][mode]


func is_one_correct() -> bool:
	return mode == ConfigSchema.MODE_ONE_CORRECT


## Μέγιστος αριθμός προσπαθειών («Τροχός»: 1, εκτός από τα «Ξαναπαίξε»).
func max_attempts() -> int:
	if is_one_correct():
		return int(_mode_cfg()["attempts"])
	return 1


## Ταχύτητα (πλάτη οθόνης / δευτερόλεπτο) της τρέχουσας προσπάθειας.
func current_speed() -> float:
	if is_one_correct():
		var speeds: Array = _mode_cfg()["speeds"]
		return float(speeds[mini(attempt, speeds.size() - 1)])
	if attempt > 0 and _replay_next:
		return float(_mode_cfg()["replay_speed"])
	return float(_mode_cfg()["speed"])


## Αν επιτρέπεται αστόχηση (εκτός ανοχής) στην τρέχουσα λειτουργία.
func allows_miss() -> bool:
	return is_one_correct()


func tolerance_pct() -> float:
	if is_one_correct():
		return float(_mode_cfg()["tolerance_pct"])
	return 100.0


func target_id() -> String:
	return str(_cfg["modes"][ConfigSchema.MODE_ONE_CORRECT]["target_id"])


## Καταχωρεί το αποτέλεσμα μιας προσπάθειας. `icon_id == ""` σημαίνει αστόχηση.
func submit(icon_id: String) -> int:
	if finished:
		return Outcome.NONE
	results.append(icon_id)
	if is_one_correct():
		if icon_id != "" and icon_id == target_id():
			won = true
			win_attempt = attempt + 1
			finished = true
			return Outcome.WIN
		if attempt + 1 < max_attempts():
			attempt += 1
			return Outcome.RETRY
		finished = true
		return Outcome.LOSE
	# Τροχός της τύχης
	var icon := ConfigSchema.find_icon(_cfg, icon_id)
	if not icon.is_empty() and bool(icon["replay"]):
		attempt += 1
		_replay_next = true
		return Outcome.WHEEL_REPLAY
	finished = true
	return Outcome.WHEEL


## Μήνυμα πριν από την τρέχουσα προσπάθεια (π.χ. «Δεύτερη ευκαιρία!»).
## Κενό για την 1η προσπάθεια ή στον «Τροχό».
func retry_message() -> String:
	if not is_one_correct() or attempt == 0:
		return ""
	var msgs: Array = _mode_cfg()["retry_messages"]
	var i := attempt - 1
	if i < msgs.size():
		return str(msgs[i])
	return "Ευκαιρία %d!" % (attempt + 1)


## Εγγραφή για τα στατιστικά.
func record() -> Dictionary:
	return {
		"time": started_at,
		"mode": mode,
		"results": results.duplicate(),
		"won": won,
		"win_attempt": win_attempt,
		"test": is_test,
	}

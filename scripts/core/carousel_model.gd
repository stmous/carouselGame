## Μοντέλο της κινούμενης σειράς εικονιδίων, ανεξάρτητο από ανάλυση.
##
## Οι θέσεις μετρώνται σε «βήματα» (u): 1 u = μέγεθος εικονιδίου + κενό.
## u = 0 είναι το κέντρο του κύκλου, θετικό u = δεξιά.
## Η θυρίδα (slot) j βρίσκεται στο u = scroll - j. Η θυρίδα 0 είναι η πιο
## δεξιά· νέες θυρίδες προστίθενται αριστερά και η σειρά κινείται προς τα
## δεξιά (το scroll αυξάνει).
##
## Η κίνηση είναι frame-rate independent: η επιβράδυνση υπολογίζεται
## αναλυτικά από τον χρόνο (όχι με άθροιση v·dt), οπότε η τελική θέση δεν
## εξαρτάται από τα fps.
extends RefCounted

enum State { IDLE, RUNNING, STOPPING, STOPPED }

var state: int = State.IDLE
var scroll := 0.0
var slots: Array = []          # δείκτες εικονιδίων ανά θυρίδα
var half_span := 5.0           # μισό ορατό πλάτος σε u (+ περιθώριο)
var speed := 0.0               # u / δευτερόλεπτο
## Πόσες θυρίδες έχουν αφαιρεθεί συνολικά από δεξιά. Απόλυτος δείκτης
## θυρίδας = popped_total + j (σταθερός όσο ζει η θυρίδα).
var popped_total := 0

var _sequencer
var _v0 := 0.0
var _decel_t := 0.0
var _decel_T := 0.0


func _init(sequencer = null, visible_half_span: float = 5.0) -> void:
	_sequencer = sequencer
	half_span = visible_half_span
	rebuild()


## Ξαναγεμίζει τη σειρά από την αρχή (π.χ. μετά από αλλαγή εικονιδίων).
func rebuild() -> void:
	slots.clear()
	popped_total = 0
	scroll = half_span
	state = State.IDLE
	_fill()


func set_half_span(value: float) -> void:
	half_span = maxf(value, 1.0)
	_trim_and_fill()


## Ξεκινά (ή ξαναξεκινά) την κίνηση με σταθερή ταχύτητα.
func start(speed_u: float) -> void:
	speed = speed_u
	state = State.RUNNING


## Ζητά σταμάτημα. `ease_duration <= 0` = άμεσο σταμάτημα.
## Επιστρέφει false αν η κίνηση δεν έτρεχε (π.χ. διπλό πάτημα).
func request_stop(ease_duration: float) -> bool:
	if state != State.RUNNING:
		return false
	if ease_duration <= 0.0 or speed == 0.0:
		state = State.STOPPED
		return true
	_v0 = speed
	_decel_T = ease_duration
	_decel_t = 0.0
	state = State.STOPPING
	return true


## Απόσταση (σε u) που θα διανυθεί κατά την επιβράδυνση.
static func ease_distance(v0: float, duration: float) -> float:
	return v0 * duration * 0.5


## Προωθεί τον χρόνο. Επιστρέφει true στο frame όπου η κίνηση μόλις σταμάτησε.
func update(dt: float) -> bool:
	match state:
		State.RUNNING:
			advance(speed * dt)
		State.STOPPING:
			var t0 := _decel_t
			var t1 := minf(_decel_t + dt, _decel_T)
			advance(_ease_pos(t1) - _ease_pos(t0))
			_decel_t = t1
			if t1 >= _decel_T:
				state = State.STOPPED
				speed = 0.0
				return true
	return false


## Θέση κατά την επιβράδυνση: v(t) = v0·(1 − t/T)  ⇒  x(t) = v0·(t − t²/2T).
func _ease_pos(t: float) -> float:
	return _v0 * (t - t * t / (2.0 * _decel_T))


## Μετακινεί τη σειρά κατά `du` (μπορεί να είναι και αρνητικό, για «κούμπωμα»).
func advance(du: float) -> void:
	scroll += du
	_trim_and_fill()


func _trim_and_fill() -> void:
	# Αφαίρεση θυρίδων που βγήκαν από δεξιά (κρατά το scroll μικρό αριθμό).
	while slots.size() > 1 and scroll > half_span + 1.0:
		slots.pop_front()
		popped_total += 1
		scroll -= 1.0
	_fill()


func _fill() -> void:
	if _sequencer == null or _sequencer.count() == 0:
		return
	while slots.is_empty() or scroll - float(slots.size() - 1) > -half_span:
		slots.append(_sequencer.next())


## Λίστα ορατών εικονιδίων: [{"slot": j, "u": θέση, "icon": δείκτης}, ...]
func items() -> Array:
	var out: Array = []
	for j in slots.size():
		out.append({"slot": j, "u": scroll - float(j), "icon": slots[j]})
	return out


## Θέσεις (u) όλων των θυρίδων, για τον ResultDetector.
func offsets() -> Array:
	var out: Array = []
	for j in slots.size():
		out.append(scroll - float(j))
	return out


func icon_at(slot: int) -> int:
	if slot < 0 or slot >= slots.size():
		return -1
	return slots[slot]


func is_moving() -> bool:
	return state == State.RUNNING or state == State.STOPPING

## Ενιαία ανίχνευση «πατήματος»: Space, αριστερό κλικ ή άγγιγμα.
##
## Σε Android, ένα άγγιγμα παράγει ΚΑΙ InputEventScreenTouch ΚΑΙ (εξομοιωμένο)
## InputEventMouseButton. Κρατάμε όποιο φτάσει πρώτο (ελάχιστη καθυστέρηση) και
## αγνοούμε όσα ακολουθούν μέσα στο παράθυρο debounce.
extends RefCounted

const DEBOUNCE_MS := 150

static var _last_press_ms := -100000
## Τελευταία αλληλεπίδραση (για idle timeout). Ενημερώνεται και από πατήματα
## που «καταναλώνει» κάποια άλλη οθόνη (π.χ. το popup).
static var last_activity_ms := 0


static func mark_activity() -> void:
	last_activity_ms = Time.get_ticks_msec()


## True αν το event είναι πάτημα (χωρίς έλεγχο debounce).
static func is_press(event: InputEvent) -> bool:
	if is_activity(event):
		mark_activity()
	if event is InputEventKey:
		var k := event as InputEventKey
		return k.pressed and not k.echo \
			and (k.keycode == KEY_SPACE or k.physical_keycode == KEY_SPACE)
	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		return m.pressed and m.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


## True αν το event είναι πάτημα ΚΑΙ δεν είναι διπλότυπο (debounce).
static func accept(event: InputEvent) -> bool:
	if not is_press(event):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_press_ms < DEBOUNCE_MS:
		return false
	_last_press_ms = now
	return true


## Οποιαδήποτε αλληλεπίδραση (για το idle timeout).
static func is_activity(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton \
		or event is InputEventScreenTouch or event is InputEventScreenDrag

## Βάση για unit tests (χωρίς εξωτερικά addons, τρέχει headless).
## Κάθε μέθοδος που αρχίζει με `test_` είναι ένα test.
extends RefCounted

var failures: Array = []
var current_test := ""
var assertions := 0


func _fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "") -> void:
	assertions += 1
	if not cond:
		_fail("αναμενόταν true. " + msg)


func assert_false(cond: bool, msg: String = "") -> void:
	assertions += 1
	if cond:
		_fail("αναμενόταν false. " + msg)


func assert_eq(actual, expected, msg: String = "") -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) and not (_num(actual) and _num(expected)):
		_fail("τύπος %s != %s (%s vs %s). %s" % [type_string(typeof(actual)), type_string(typeof(expected)), str(actual), str(expected), msg])
	elif actual != expected:
		_fail("%s != %s. %s" % [str(actual), str(expected), msg])


func assert_near(actual: float, expected: float, eps: float = 1e-6, msg: String = "") -> void:
	assertions += 1
	if absf(actual - expected) > eps:
		_fail("%f != %f (±%f). %s" % [actual, expected, eps, msg])


func _num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

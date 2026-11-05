## Εκτελεί όλα τα unit tests από τη γραμμή εντολών:
##
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Exit code 0 = όλα πέρασαν, 1 = υπάρχουν αποτυχίες.
## (Μέσα στον editor: άνοιξε το tests/run_tests.tscn και πάτα F6.)
extends SceneTree

const TestSuite = preload("res://tests/test_suite.gd")


func _initialize() -> void:
	var lines: Array = []
	var r := TestSuite.run(lines)
	for l in lines:
		if l[1]:
			print("  ", l[0])
		else:
			printerr("  ", l[0])
	print("")
	print("Tests: %d, αποτυχίες: %d, assertions: %d" % [r["total"], r["failed"], r["asserts"]])
	quit(1 if r["failed"] > 0 else 0)

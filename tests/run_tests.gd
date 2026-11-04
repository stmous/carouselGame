## Εκτελεί όλα τα unit tests στο tests/unit/.
##
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Exit code 0 = όλα πέρασαν, 1 = υπάρχουν αποτυχίες.
extends SceneTree

const TEST_DIR := "res://tests/unit/"


func _initialize() -> void:
	var files: Array = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		printerr("Δεν βρέθηκε ο φάκελος ", TEST_DIR)
		quit(1)
		return
	for f in dir.get_files():
		# Σε export τα .gd μπορεί να εμφανίζονται ως .gd.remap / .gdc.
		var name := f.trim_suffix(".remap")
		if name.begins_with("test_") and name.ends_with(".gd"):
			files.append(name)
	files.sort()

	var total := 0
	var failed := 0
	var asserts := 0
	for f in files:
		var script: GDScript = load(TEST_DIR + f)
		if script == null:
			printerr("✗ Δεν φορτώθηκε: ", f)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			var t = script.new()
			t.current_test = f.get_basename() + "." + mname
			if t.has_method("before_each"):
				t.before_each()
			t.call(mname)
			total += 1
			asserts += t.assertions
			if t.failures.is_empty():
				print("  ✓ ", t.current_test)
			else:
				failed += 1
				for msg in t.failures:
					printerr("  ✗ ", msg)

	print("")
	print("Tests: %d, αποτυχίες: %d, assertions: %d" % [total, failed, asserts])
	quit(1 if failed > 0 else 0)

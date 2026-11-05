## Κοινή λογική εκτέλεσης tests (χρησιμοποιείται από το run_tests.gd για
## γραμμή εντολών και από τη σκηνή run_tests.tscn μέσα στον editor).
extends RefCounted

const TEST_DIR := "res://tests/unit/"


## Τρέχει όλα τα tests. Γράφει γραμμές αποτελεσμάτων στο `lines`
## (κάθε στοιχείο: [κείμενο, πέρασε: bool]) και επιστρέφει {total, failed, asserts}.
static func run(lines: Array) -> Dictionary:
	var files: Array = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		lines.append(["Δεν βρέθηκε ο φάκελος " + TEST_DIR, false])
		return {"total": 0, "failed": 1, "asserts": 0}
	for f in dir.get_files():
		# Σε export τα .gd μπορεί να εμφανίζονται ως .gd.remap.
		var fname := f.trim_suffix(".remap")
		if fname.begins_with("test_") and fname.ends_with(".gd"):
			files.append(fname)
	files.sort()

	var total := 0
	var failed := 0
	var asserts := 0
	for f in files:
		var script: GDScript = load(TEST_DIR + f)
		if script == null or not script.can_instantiate():
			lines.append(["✗ Δεν φορτώθηκε (σφάλμα στο script): " + f, false])
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
				lines.append(["✓ " + t.current_test, true])
			else:
				failed += 1
				for msg in t.failures:
					lines.append(["✗ " + msg, false])
	return {"total": total, "failed": failed, "asserts": asserts}

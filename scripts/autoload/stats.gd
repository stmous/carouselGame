## Autoload «Stats»: καταγραφή κάθε παιχνιδιού στο user://stats.jsonl.
##
## Μορφή JSON Lines (μία εγγραφή ανά γραμμή, μόνο προσθήκη στο τέλος): μια
## διακοπή ρεύματος μπορεί το πολύ να χαλάσει την τελευταία γραμμή, που απλώς
## αγνοείται κατά τη φόρτωση. Τα δοκιμαστικά παιχνίδια δεν καταγράφονται.
extends Node

const PATH := "user://stats.jsonl"

signal changed

var records: Array = []


func _ready() -> void:
	load_records()


func load_records() -> void:
	records.clear()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var r = JSON.parse_string(line)
		if r is Dictionary:
			records.append(r)
	changed.emit()


## Καταγράφει ένα παιχνίδι. Συμπληρώνει τα ονόματα των εικονιδίων εκείνης
## της στιγμής (ώστε μετονομασίες/διαγραφές να μην «χαλάνε» τα παλιά στοιχεία).
func add(record: Dictionary) -> void:
	if record.is_empty() or bool(record.get("test", false)):
		return
	var r := record.duplicate(true)
	r.erase("test")
	var names := {}
	for icon in Config.icons():
		names[icon["id"]] = icon["name"]
	var used := {}
	for id in r.get("results", []):
		if str(id) != "" and names.has(id):
			used[id] = names[id]
	r["names"] = used
	records.append(r)
	var f: FileAccess
	if FileAccess.file_exists(PATH):
		f = FileAccess.open(PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("Αποτυχία εγγραφής στατιστικών")
		return
	f.store_line(JSON.stringify(r))
	f.close()
	changed.emit()


## Μηδενισμός (διαγραφή όλων των εγγραφών).
func reset() -> void:
	records.clear()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	changed.emit()

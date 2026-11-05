## Αποθήκευση αρχείων (CSV, θέματα) σε φάκελο προσβάσιμο από τον χρήστη:
##   Windows: Έγγραφα (Documents), αλλιώς Λήψεις (Downloads)
##   Android: Λήψεις (Download), αλλιώς Έγγραφα (Documents)
## Αν αποτύχουν όλα, γράφεται στον φάκελο δεδομένων της εφαρμογής.
extends RefCounted


static func candidate_dirs() -> Array:
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var out: Array = []
	if OS.get_name() == "Android":
		out = [downloads, docs]
	else:
		out = [docs, downloads]
	var cleaned: Array = []
	for d in out:
		if str(d) != "":
			cleaned.append(str(d))
	cleaned.append(ProjectSettings.globalize_path("user://exports"))
	return cleaned


## Γράφει τα bytes και επιστρέφει την πλήρη διαδρομή, ή "" αν απέτυχε παντού.
static func write(file_name: String, bytes: PackedByteArray) -> String:
	if OS.get_name() == "Android":
		OS.request_permissions()
	for d in candidate_dirs():
		DirAccess.make_dir_recursive_absolute(d)
		var path: String = d.path_join(file_name)
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			continue
		f.store_buffer(bytes)
		f.close()
		if FileAccess.file_exists(path):
			return path
	return ""


## Χρονοσφραγίδα για ονόματα αρχείων: 2026-11-05_14-03
static func stamp() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d-%02d" % [t["year"], t["month"], t["day"], t["hour"], t["minute"]]

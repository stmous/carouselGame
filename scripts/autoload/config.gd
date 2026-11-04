## Autoload «Config»: φόρτωση/αποθήκευση ρυθμίσεων στο user://config.json.
##
## Όλα τα υπόλοιπα κομμάτια διαβάζουν από `Config.data` και ακούν το σήμα
## `changed` για ζωντανή ενημέρωση (π.χ. προεπισκόπηση στο admin).
extends Node

const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const CONFIG_PATH := "user://config.json"

signal changed

var data: Dictionary = {}


func _ready() -> void:
	load_config()


func load_config() -> void:
	var loaded := {}
	if FileAccess.file_exists(CONFIG_PATH):
		var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				loaded = parsed
			else:
				push_warning("Μη έγκυρο config.json — χρήση προεπιλογών.")
	data = ConfigSchema.from_user_data(loaded)
	changed.emit()


## Αποθηκεύει ατομικά (πρώτα σε προσωρινό αρχείο, μετά μετονομασία), ώστε μια
## διακοπή ρεύματος να μην αφήσει κατεστραμμένο αρχείο.
func save_config() -> bool:
	data = ConfigSchema.sanitize(data)
	var tmp := CONFIG_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Αποτυχία εγγραφής ρυθμίσεων: %d" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists("config.json"):
		dir.remove("config.json")
	var err := dir.rename("config.json.tmp", "config.json")
	changed.emit()
	return err == OK


func reset_to_defaults() -> void:
	data = ConfigSchema.defaults()
	save_config()


## Αντικαθιστά τις ρυθμίσεις χωρίς αποθήκευση (π.χ. ζωντανή προεπισκόπηση).
func apply(new_data: Dictionary) -> void:
	data = ConfigSchema.sanitize(ConfigSchema.merge(ConfigSchema.defaults(), new_data))
	changed.emit()


func mode() -> String:
	return data["mode"]


func icons() -> Array:
	return data["icons"]["list"]

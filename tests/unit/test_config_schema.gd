extends "res://tests/test_case.gd"

const ConfigSchema = preload("res://scripts/core/config_schema.gd")


func test_defaults_are_valid() -> void:
	var d := ConfigSchema.defaults()
	var s := ConfigSchema.sanitize(d.duplicate(true))
	assert_eq(s["schema_version"], ConfigSchema.SCHEMA_VERSION)
	assert_eq(s["mode"], "one_correct")
	assert_true(s["icons"]["list"].size() >= 2)
	assert_false(ConfigSchema.find_icon(s, s["modes"]["one_correct"]["target_id"]).is_empty())
	assert_eq(ConfigSchema.icons_missing_popup(s), [], "το demo θέμα έχει όλα τα popups")


func test_empty_user_data_gives_defaults() -> void:
	var c := ConfigSchema.from_user_data({})
	assert_eq(c["admin"]["pin"], "1234")
	assert_eq(c["modes"]["one_correct"]["attempts"], 3)


func test_merge_keeps_missing_keys_and_ignores_wrong_types() -> void:
	var base := {"a": 1, "b": {"c": "x", "d": true}, "arr": [1, 2]}
	var m := ConfigSchema.merge(base, {"a": 5.5, "b": {"c": 3}, "arr": [9], "extra": "keep"})
	assert_eq(m["a"], 5.5, "αριθμός → αριθμός επιτρέπεται")
	assert_eq(m["b"]["c"], "x", "λάθος τύπος αγνοείται")
	assert_eq(m["b"]["d"], true, "κλειδί που λείπει παίρνει προεπιλογή")
	assert_eq(m["arr"], [9], "οι πίνακες αντικαθίστανται")
	assert_eq(m["extra"], "keep", "άγνωστα κλειδιά διατηρούνται")
	assert_eq(base["a"], 1, "η βάση δεν αλλάζει")


func test_sanitize_clamps_values() -> void:
	var c := ConfigSchema.defaults()
	c["mode"] = "nonsense"
	c["modes"]["one_correct"]["attempts"] = 99
	c["modes"]["one_correct"]["speeds"] = [10.0, 0.01]
	c["modes"]["one_correct"]["tolerance_pct"] = 0.0
	c["modes"]["wheel"]["speed"] = -1.0
	c["stop"]["mode"] = "???"
	c = ConfigSchema.sanitize(c)
	assert_eq(c["mode"], "one_correct")
	assert_eq(c["modes"]["one_correct"]["attempts"], 5)
	var sp: Array = c["modes"]["one_correct"]["speeds"]
	assert_eq(sp.size(), 5, "μία ταχύτητα για κάθε πιθανή προσπάθεια")
	assert_near(sp[0], 3.0)
	assert_near(sp[1], 0.2)
	assert_near(sp[4], 0.2, 1e-9, "οι ελλείπουσες παίρνουν την τελευταία")
	assert_near(c["modes"]["one_correct"]["tolerance_pct"], 1.0)
	assert_near(c["modes"]["wheel"]["speed"], 0.2)
	assert_eq(c["stop"]["mode"], "ease")


func test_sanitize_fixes_icons_and_target() -> void:
	var c := ConfigSchema.defaults()
	c["icons"]["list"] = [{"id": "a", "name": "Α"}, {"id": "a", "name": "Β"}, {"name": "Γ"}, "σκουπίδι"]
	c["modes"]["one_correct"]["target_id"] = "missing"
	c = ConfigSchema.sanitize(c)
	var ids := {}
	for icon in c["icons"]["list"]:
		ids[icon["id"]] = true
		assert_true(icon.has("popup") and icon.has("replay") and icon.has("image"))
	assert_eq(c["icons"]["list"].size(), 3)
	assert_eq(ids.size(), 3, "μοναδικά ids")
	assert_eq(c["modes"]["one_correct"]["target_id"], "a", "ο στόχος πρέπει να υπάρχει")
	assert_eq(ConfigSchema.icons_missing_popup(c).size(), 3)


func test_modes_keep_separate_settings() -> void:
	# Η εναλλαγή λειτουργίας δεν σβήνει τις ρυθμίσεις της άλλης.
	var c := ConfigSchema.defaults()
	c["modes"]["wheel"]["speed"] = 1.7
	c["modes"]["one_correct"]["attempts"] = 2
	c["mode"] = "wheel"
	c = ConfigSchema.sanitize(c)
	c["mode"] = "one_correct"
	c = ConfigSchema.sanitize(c)
	assert_near(c["modes"]["wheel"]["speed"], 1.7)
	assert_eq(c["modes"]["one_correct"]["attempts"], 2)


func test_json_roundtrip() -> void:
	var c := ConfigSchema.defaults()
	c["modes"]["one_correct"]["attempts"] = 4
	c["theme"]["circle"]["color"] = "#ff0000"
	var text := JSON.stringify(c, "\t")
	var parsed = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	var back := ConfigSchema.from_user_data(parsed)
	# Το JSON επιστρέφει αριθμούς ως float· το sanitize τα επαναφέρει σωστά.
	assert_eq(back["modes"]["one_correct"]["attempts"], 4)
	assert_eq(typeof(back["modes"]["one_correct"]["attempts"]), TYPE_INT)
	assert_eq(back["theme"]["circle"]["color"], "#ff0000")
	assert_eq(back["icons"]["list"].size(), c["icons"]["list"].size())


func test_migrate_from_unversioned() -> void:
	var c := ConfigSchema.from_user_data({"mode": "wheel"})
	assert_eq(c["schema_version"], ConfigSchema.SCHEMA_VERSION)
	assert_eq(c["mode"], "wheel")

## «Smoke test» της οθόνης ρυθμίσεων: χτίζει κάθε ενότητα και στις δύο
## λειτουργίες, μέσα στο πραγματικό scene tree. Χρειάζεται τα autoloads
## (Config, Sfx), άρα τρέχει από τη σκηνή tests/run_tests.tscn (F6).
extends "res://tests/test_case.gd"

const AdminScreen = preload("res://scripts/admin/admin_screen.gd")
const PinPad = preload("res://scripts/admin/pin_pad.gd")
const ConfigSchema = preload("res://scripts/core/config_schema.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _has_autoloads() -> bool:
	var t := _tree()
	return t != null and t.root.has_node("Config") and t.root.has_node("Sfx")


func test_all_sections_build_in_both_modes() -> void:
	if not _has_autoloads():
		assert_true(true, "παραλείπεται χωρίς autoloads")
		return
	var admin := AdminScreen.new()
	_tree().root.add_child(admin)
	admin.open()
	for mode in [ConfigSchema.MODE_ONE_CORRECT, ConfigSchema.MODE_WHEEL]:
		admin.draft["mode"] = mode
		for s in AdminScreen.SECTIONS:
			admin._show_section(s[0])
			assert_true(admin._content.get_child_count() > 0, "%s / %s" % [mode, s[0]])
	# Τύποι φόντου και επιλογές που αλλάζουν τη δομή της ενότητας.
	for bg in ["color", "gradient", "image"]:
		admin.draft["theme"]["background"]["type"] = bg
		admin._show_section("theme")
		assert_true(admin._content.get_child_count() > 0, "φόντο " + bg)
	admin.draft["stop"]["mode"] = "instant"
	admin._show_section("speed")
	assert_true(admin._content.get_child_count() > 0)
	admin._finish(false)
	admin.queue_free()


func test_icon_list_edits_on_draft() -> void:
	if not _has_autoloads():
		assert_true(true)
		return
	var admin := AdminScreen.new()
	_tree().root.add_child(admin)
	admin.open()
	var n: int = admin.draft["icons"]["list"].size()
	var first: String = admin.draft["icons"]["list"][0]["id"]
	admin._move_icon(0, 1)
	assert_eq(admin.draft["icons"]["list"][1]["id"], first, "μετακίνηση κάτω")
	admin._delete_icon(1)
	assert_eq(admin.draft["icons"]["list"].size(), n - 1)
	assert_true(admin.dirty)
	# Τα αποθηκευμένα εικονίδια δεν άλλαξαν.
	assert_eq(Config.data["icons"]["list"].size(), n)
	admin._finish(false)
	admin.queue_free()


func test_effect_preset_applies_switches() -> void:
	if not _has_autoloads():
		assert_true(true)
		return
	var admin := AdminScreen.new()
	_tree().root.add_child(admin)
	admin.open()
	admin._apply_effect_preset("arcade")
	assert_true(admin.draft["effects"]["screen_shake"])
	admin._apply_effect_preset("minimal")
	assert_false(admin.draft["effects"]["confetti"])
	admin._finish(false)
	admin.queue_free()


func test_pin_pad() -> void:
	if not _has_autoloads():
		assert_true(true)
		return
	var pad := PinPad.new()
	_tree().root.add_child(pad)
	var ok := [false]
	pad.accepted.connect(func(): ok[0] = true)
	for ch in str(Config.data["admin"]["pin"]):
		pad._on_key(ch)
	pad._on_key("OK")
	assert_true(ok[0], "σωστό PIN")
	pad.queue_free()

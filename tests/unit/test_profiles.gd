extends "res://tests/test_case.gd"

const Profiles = preload("res://scripts/util/profiles.gd")
const ConfigSchema = preload("res://scripts/core/config_schema.gd")


func test_relativize_and_absolutize() -> void:
	var cfg := {"admin": {"pin": "9999"}, "kiosk": {"fullscreen": true},
		"theme": {"logo": {"image": "user://media/images/logo_ab.png"}, "font": "user://media/fonts/f_1.ttf"},
		"icons": {"list": [{"image": "res://assets/demo/icons/star.png", "popup": "user://media/images/p_2.png"}]}}
	var r := Profiles.relativize(cfg)
	var rc: Dictionary = r["cfg"]
	assert_false(rc.has("admin"), "το PIN δεν μπαίνει στο θέμα")
	assert_false(rc.has("kiosk"))
	assert_eq(rc["theme"]["logo"]["image"], "media/images/logo_ab.png")
	assert_eq(rc["icons"]["list"][0]["image"], "res://assets/demo/icons/star.png", "τα ενσωματωμένα μένουν")
	assert_eq((r["files"] as Array).size(), 3)
	assert_eq(cfg["theme"]["logo"]["image"], "user://media/images/logo_ab.png", "το αρχικό δεν αλλάζει")
	var back := Profiles.absolutize(rc, {"media/images/logo_ab.png": true, "media/fonts/f_1.ttf": true})
	assert_eq(back["theme"]["logo"]["image"], "user://media/images/logo_ab.png")
	assert_eq(back["icons"]["list"][0]["popup"], "", "αρχείο που λείπει από το zip ⇒ κενό")


func test_zip_entry_safety() -> void:
	assert_true(Profiles.is_safe_entry("media/images/a_1.png"))
	assert_true(Profiles.is_safe_entry("media/sounds/x.ogg"))
	assert_false(Profiles.is_safe_entry("media/../config.json"))
	assert_false(Profiles.is_safe_entry("/etc/passwd"))
	assert_false(Profiles.is_safe_entry("media/images/../../x.png"))
	assert_false(Profiles.is_safe_entry("media/images/x.exe"))
	assert_false(Profiles.is_safe_entry("media/other/x.png"))
	assert_false(Profiles.is_safe_entry("media/images/sub/x.png"))
	assert_false(Profiles.is_safe_entry("C:/x/media/images/a.png"))


func test_safe_profile_name() -> void:
	assert_eq(Profiles.safe_profile_name("Πελάτης Χ: Έκθεση 2026"), "Πελάτης Χ_ Έκθεση 2026")
	assert_eq(Profiles.safe_profile_name("  a/b\\c?  "), "a_b_c_")
	assert_eq(Profiles.safe_profile_name("   "), "θέμα")


func test_pack_unpack_roundtrip() -> void:
	# Προσωρινό αρχείο media με μοναδικό όνομα (δεν αγγίζει τα αρχεία του χρήστη).
	var media := "user://media/images/_unit_test_%d.png" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(media.get_base_dir())
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	assert_eq(img.save_png(media), OK)
	var original_bytes := FileAccess.get_file_as_bytes(media)

	var cfg := ConfigSchema.defaults()
	cfg["theme"]["logo"]["image"] = media
	cfg["modes"]["one_correct"]["attempts"] = 4
	cfg["admin"]["pin"] = "5555"
	var zip := "user://_test_tmp/_unit_profile_%d.zip" % Time.get_ticks_usec()
	assert_eq(Profiles.pack(cfg, zip, "Δοκιμή"), "")
	assert_true(FileAccess.file_exists(zip))

	# Σβήνουμε το media για να βεβαιωθούμε ότι επανέρχεται από το zip.
	DirAccess.remove_absolute(media)
	var current := ConfigSchema.defaults()
	current["admin"]["pin"] = "1111"
	var r := Profiles.unpack(zip, current)
	assert_eq(r["error"], "")
	assert_eq(r["name"], "Δοκιμή")
	var c: Dictionary = r["cfg"]
	assert_eq(c["theme"]["logo"]["image"], media)
	assert_eq(c["modes"]["one_correct"]["attempts"], 4)
	assert_eq(c["admin"]["pin"], "1111", "το PIN της συσκευής μένει")
	assert_true(FileAccess.file_exists(media))
	assert_eq(FileAccess.get_file_as_bytes(media), original_bytes)

	DirAccess.remove_absolute(media)
	DirAccess.remove_absolute(zip)


func test_unpack_rejects_non_theme_zip() -> void:
	var zip := "user://_test_tmp/_unit_bad_%d.zip" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(zip.get_base_dir())
	var zp := ZIPPacker.new()
	assert_eq(zp.open(zip), OK)
	zp.start_file("hello.txt")
	zp.write_file("γεια".to_utf8_buffer())
	zp.close_file()
	zp.close()
	assert_true(str(Profiles.unpack(zip, {})["error"]) != "")
	DirAccess.remove_absolute(zip)
	assert_true(str(Profiles.unpack("user://_test_tmp/missing.zip", {})["error"]) != "")

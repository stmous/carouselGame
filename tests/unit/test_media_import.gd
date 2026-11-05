extends "res://tests/test_case.gd"

const MediaImport = preload("res://scripts/util/media_import.gd")
const CfgPath = preload("res://scripts/core/cfg_path.gd")
const Fonts = preload("res://scripts/util/fonts.gd")

const TMP := "user://_test_tmp/"


func test_fit_size_downscales_keeping_aspect() -> void:
	assert_eq(MediaImport.fit_size(4000, 2000, 1600, 1200), Vector2i(1600, 800))
	assert_eq(MediaImport.fit_size(1000, 3000, 768, 768), Vector2i(256, 768))
	assert_eq(MediaImport.fit_size(2048, 2048, 512, 512), Vector2i(512, 512))


func test_fit_size_never_upscales() -> void:
	assert_eq(MediaImport.fit_size(300, 200, 1600, 1200), Vector2i(300, 200))
	assert_eq(MediaImport.fit_size(1600, 1200, 1600, 1200), Vector2i(1600, 1200))


func test_safe_name() -> void:
	assert_eq(MediaImport.safe_name("C:/Users/x/Λογότυπο Πελάτη 2024.PNG"), "2024")
	assert_eq(MediaImport.safe_name("/sdcard/My Icon (1).png"), "my_icon_1")
	assert_eq(MediaImport.safe_name("Δώρο.png"), "file")
	assert_true(MediaImport.safe_name("a".repeat(100) + ".png").length() <= 32)


func test_detect_formats_by_content() -> void:
	var png := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
	var jpg := PackedByteArray([0xFF, 0xD8, 0xFF, 0xE0])
	var webp := "RIFF0000WEBP".to_ascii_buffer()
	assert_eq(MediaImport.detect_image_format(png), "png")
	assert_eq(MediaImport.detect_image_format(jpg), "jpg")
	assert_eq(MediaImport.detect_image_format(webp), "webp")
	assert_eq(MediaImport.detect_image_format("hello world!".to_ascii_buffer()), "")
	assert_eq(MediaImport.detect_audio_format("OggS....".to_ascii_buffer()), "ogg")
	assert_eq(MediaImport.detect_audio_format("RIFF0000WAVE".to_ascii_buffer()), "wav")
	assert_eq(MediaImport.detect_audio_format("ID3.....".to_ascii_buffer()), "mp3")
	assert_eq(MediaImport.detect_audio_format(PackedByteArray([0xFF, 0xFB, 0x90, 0x00])), "mp3")
	assert_eq(MediaImport.detect_audio_format("RIFF0000WEBP".to_ascii_buffer()), "")
	assert_eq(MediaImport.detect_font_format(PackedByteArray([0, 1, 0, 0, 9])), "ttf")
	assert_eq(MediaImport.detect_font_format("OTTO".to_ascii_buffer()), "otf")


func test_referenced_media() -> void:
	var cfg := {"a": "user://media/images/x.png", "b": ["res://y.png", {"c": "user://media/sounds/s.ogg"}], "d": 5}
	var refs := MediaImport.referenced_media(cfg)
	assert_eq(refs.size(), 2)
	assert_true(refs.has("user://media/images/x.png"))
	assert_true(refs.has("user://media/sounds/s.ogg"))


func test_import_large_image_is_resized_and_copied() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var src := TMP + "big_icon.png"
	var img := Image.create(2000, 1000, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 0.5))
	assert_eq(img.save_png(src), OK)
	var r := MediaImport.import_image(src, "icon")
	assert_eq(r["error"], "")
	var dest: String = r["path"]
	assert_true(dest.begins_with("user://media/images/"))
	assert_true(r["resized"])
	var back := Image.load_from_file(dest)
	assert_true(back != null)
	if back != null:
		assert_eq(Vector2i(back.get_width(), back.get_height()), Vector2i(768, 384))
	# Το αρχικό μπορεί να σβηστεί: το παιχνίδι χρησιμοποιεί το αντίγραφο.
	DirAccess.remove_absolute(src)
	assert_true(FileAccess.file_exists(dest))
	DirAccess.remove_absolute(dest)


func test_import_rejects_non_images() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var src := TMP + "fake.png"
	var f := FileAccess.open(src, FileAccess.WRITE)
	f.store_string("not really a png")
	f.close()
	var r := MediaImport.import_image(src, "icon")
	assert_eq(r["path"], "")
	assert_true(str(r["error"]) != "")
	DirAccess.remove_absolute(src)
	assert_eq(MediaImport.import_image(TMP + "does_not_exist.png", "icon")["path"], "")


func test_cfg_path_get_set() -> void:
	var d := {"theme": {"circle": {"color": "#fff"}}, "icons": {"list": [{"name": "Α"}, {"name": "Β"}]}}
	assert_eq(CfgPath.get_at(d, ["theme", "circle", "color"]), "#fff")
	assert_eq(CfgPath.get_at(d, ["icons", "list", 1, "name"]), "Β")
	assert_eq(CfgPath.get_at(d, ["icons", "list", 5, "name"], "x"), "x")
	assert_eq(CfgPath.get_at(d, ["nope", "x"], 7), 7)
	assert_true(CfgPath.set_at(d, ["theme", "circle", "color"], "#000"))
	assert_eq(d["theme"]["circle"]["color"], "#000")
	assert_true(CfgPath.set_at(d, ["icons", "list", 0, "name"], "Γ"))
	assert_eq(d["icons"]["list"][0]["name"], "Γ")
	assert_true(CfgPath.set_at(d, ["new", "deep", "key"], 1))
	assert_eq(d["new"]["deep"]["key"], 1)
	assert_false(CfgPath.set_at(d, ["icons", "list", 9, "name"], "x"))


func test_builtin_fonts_load() -> void:
	for b in Fonts.BUILTIN:
		var f := Fonts.font_for(b[0])
		assert_true(f != null, b[0])
	# Άγνωστη/χαμένη γραμματοσειρά ⇒ πέφτει στην προεπιλογή.
	assert_true(Fonts.font_for("user://media/fonts/missing.ttf") != null)

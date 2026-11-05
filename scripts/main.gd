## Κύρια σκηνή: φόντο + οθόνη έλξης + παιχνίδι.
##
## Οθόνη έλξης: λογότυπο, κινούμενο μήνυμα «Πάτα για να παίξεις» και
## εικονίδια που περνούν αργά στο φόντο. Space / κλικ / άγγιγμα ξεκινά.
## Idle timeout: χωρίς αλληλεπίδραση για Ν δευτερόλεπτα ⇒ επιστροφή εδώ.
extends Control

const PressInput = preload("res://scripts/util/press_input.gd")
const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const AssetLoader = preload("res://scripts/util/asset_loader.gd")
const Backdrop = preload("res://scripts/game/backdrop.gd")
const CarouselView = preload("res://scripts/game/carousel_view.gd")
const Game = preload("res://scripts/game/game.gd")

enum Screen { ATTRACT, GAME }

const ATTRACT_ICON_SPEED := 0.05    # πλάτη οθόνης / δ — αργά, διακριτικά
const ATTRACT_ICON_OPACITY := 0.28
const TRANSITION := 0.35

var screen: int = Screen.ATTRACT

var backdrop: Backdrop
var attract: Control
var attract_icons: CarouselView
var logo: TextureRect
var attract_label: Label
var debug_label: Label
var game: Game

var _time := 0.0
var _input_block_until := 0
var _screen_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	backdrop = Backdrop.new()
	add_child(backdrop)

	attract = Control.new()
	attract.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	attract.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(attract)

	attract_icons = CarouselView.new()
	attract.add_child(attract_icons)
	attract_icons.opacity = ATTRACT_ICON_OPACITY

	logo = TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attract.add_child(logo)

	attract_label = _make_label()
	attract.add_child(attract_label)

	debug_label = _make_label()
	debug_label.visible = OS.is_debug_build()
	add_child(debug_label)

	game = Game.new()
	game.visible = false
	add_child(game)
	game.finished.connect(_on_game_finished)

	Config.changed.connect(_apply_config)
	_apply_config()
	_show_attract(false)


func _make_label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _apply_config() -> void:
	var cfg: Dictionary = Config.data
	backdrop.configure(cfg["theme"]["background"])
	attract_label.text = str(cfg["flow"]["attract_text"])
	logo.texture = AssetLoader.texture(str(cfg["theme"]["logo"]["image"]))
	logo.visible = logo.texture != null
	# Τα εικονίδια του φόντου: χωρίς λωρίδα και χωρίς σκιά, για να μένουν διακριτικά.
	attract_icons.configure(cfg["icons"]["list"], cfg["icons"], {"enabled": false})
	attract_icons.shadow_enabled = false
	attract_icons.visible = bool(cfg["flow"]["attract_icons"])
	if screen == Screen.ATTRACT and attract_icons.visible:
		attract_icons.start(ATTRACT_ICON_SPEED)
	if game.phase == Game.Phase.IDLE:
		game.apply_config()
	_update_debug_label()
	_layout()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if attract_label != null:
				_layout()
		NOTIFICATION_APPLICATION_PAUSED:
			# Android: η εφαρμογή πήγε στο παρασκήνιο ⇒ καθαρή επιστροφή στην οθόνη έλξης.
			if screen == Screen.GAME:
				game.abort()
				_show_attract(false)
		NOTIFICATION_APPLICATION_RESUMED:
			Sfx.resume_music()
			PressInput.mark_activity()


func _layout() -> void:
	var s := size
	var cfg: Dictionary = Config.data
	var text_col := Color.from_string(str(cfg["theme"]["text_color"]), Color.WHITE)
	var logo_cfg: Dictionary = cfg["theme"]["logo"]
	var pos := str(logo_cfg["position"])

	# Λογότυπο: ύψος = size_pct% της οθόνης, πλάτος έως 90%.
	var lh := float(logo_cfg["size_pct"]) / 100.0 * s.y
	logo.size = Vector2(s.x * 0.9, lh)
	logo.pivot_offset = logo.size * 0.5
	var logo_y := s.y * 0.07
	if pos == "center":
		logo_y = s.y * 0.42 - lh * 0.5
	elif pos == "bottom":
		logo_y = s.y * 0.93 - lh
	logo.position = Vector2(s.x * 0.05, logo_y)

	# Μήνυμα: κάτω, εκτός αν το λογότυπο είναι κάτω.
	var fs := int(s.y * 0.085)
	attract_label.add_theme_font_size_override("font_size", fs)
	attract_label.add_theme_constant_override("outline_size", maxi(4, int(fs / 8.0)))
	attract_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	attract_label.add_theme_color_override("font_color", text_col)
	attract_label.size = Vector2(s.x * 0.9, fs * 2.6)
	var label_cy := s.y * (0.22 if pos == "bottom" else 0.80)
	attract_label.position = Vector2(s.x * 0.05, label_cy - attract_label.size.y * 0.5)
	attract_label.pivot_offset = attract_label.size * 0.5

	var ds := int(s.y * 0.022)
	debug_label.add_theme_font_size_override("font_size", ds)
	debug_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	debug_label.size = Vector2(s.x - ds, ds * 1.6)
	debug_label.position = Vector2(0, s.y - ds * 1.8)


func _process(delta: float) -> void:
	_time += delta
	if screen == Screen.ATTRACT:
		var k := 1.0 + 0.05 * sin(_time * TAU * 0.8)
		attract_label.scale = Vector2(k, k)
		attract_label.modulate.a = 0.8 + 0.2 * sin(_time * TAU * 0.8)
		# Το λογότυπο «αιωρείται» ελαφρά.
		logo.rotation = deg_to_rad(1.2 * sin(_time * 0.9))
	_check_idle()


## Idle timeout: χωρίς αλληλεπίδραση ⇒ επιστροφή στην οθόνη έλξης.
func _check_idle() -> void:
	if screen != Screen.GAME:
		return
	var timeout := float(Config.data["flow"]["idle_timeout"])
	if timeout <= 0.0:
		return
	if Time.get_ticks_msec() - PressInput.last_activity_ms > int(timeout * 1000.0):
		game.abort()
		_show_attract()


func _input(event: InputEvent) -> void:
	if PressInput.is_activity(event):
		PressInput.mark_activity()
	if OS.is_debug_build() and _debug_keys(event):
		return
	if screen != Screen.ATTRACT:
		return
	if Time.get_ticks_msec() < _input_block_until:
		if PressInput.is_press(event):
			get_viewport().set_input_as_handled()
		return
	if PressInput.accept(event):
		get_viewport().set_input_as_handled()
		_start_game()


func _start_game() -> void:
	screen = Screen.GAME
	PressInput.mark_activity()
	_kill_screen_tween()
	game.visible = true
	game.modulate.a = 0.0
	_screen_tween = create_tween().set_parallel(true)
	_screen_tween.tween_property(attract, "modulate:a", 0.0, TRANSITION)
	_screen_tween.tween_property(attract, "scale", Vector2(1.08, 1.08), TRANSITION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_screen_tween.tween_property(game, "modulate:a", 1.0, TRANSITION)
	_screen_tween.chain().tween_callback(_hide_attract)
	game.start_game()


func _hide_attract() -> void:
	attract.visible = false
	attract_icons.request_stop(0.0)


func _on_game_finished(_record: Dictionary) -> void:
	# Φάση 4: εδώ θα καταγράφεται το `_record` στα στατιστικά.
	_show_attract()


func _show_attract(animated: bool = true) -> void:
	screen = Screen.ATTRACT
	# Μικρό διάστημα ώστε ένα «ξεχασμένο» πάτημα να μην ξεκινήσει αμέσως νέο παιχνίδι.
	_input_block_until = Time.get_ticks_msec() + 600
	_kill_screen_tween()
	attract.visible = true
	attract.pivot_offset = size * 0.5
	if attract_icons.visible:
		attract_icons.start(ATTRACT_ICON_SPEED)
	if not animated:
		attract.modulate.a = 1.0
		attract.scale = Vector2.ONE
		game.visible = false
		return
	attract.modulate.a = 0.0
	attract.scale = Vector2(0.94, 0.94)
	_screen_tween = create_tween().set_parallel(true)
	_screen_tween.tween_property(attract, "modulate:a", 1.0, TRANSITION)
	_screen_tween.tween_property(attract, "scale", Vector2.ONE, TRANSITION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if game.visible:
		_screen_tween.tween_property(game, "modulate:a", 0.0, TRANSITION)
		_screen_tween.chain().tween_callback(func(): game.visible = false)


func _kill_screen_tween() -> void:
	if _screen_tween != null and _screen_tween.is_valid():
		_screen_tween.kill()


func _update_debug_label() -> void:
	if not debug_label.visible:
		return
	var cfg: Dictionary = Config.data
	var mode_name := "Ένα σωστό" if cfg["mode"] == ConfigSchema.MODE_ONE_CORRECT else "Τροχός της τύχης"
	debug_label.text = "%s · σταμάτημα: %s · εφέ: %s · αντ. μέτρηση: %s · ήχος: %s    [F2–F8]" % [
		mode_name,
		"επιβράδυνση" if cfg["stop"]["mode"] == "ease" else "άμεσο",
		cfg["effects"]["preset"],
		"ναι" if cfg["flow"]["countdown"] else "όχι",
		"όχι" if cfg["audio"]["master_mute"] else "ναι",
	]


## Πλήκτρα δοκιμών (μόνο σε debug build, μέχρι να έρθει η οθόνη ρυθμίσεων):
##   F2 = λειτουργία, F3 = άμεσο σταμάτημα / επιβράδυνση,
##   F4 = εφέ Μίνιμαλ → Κανονικό → Arcade, F5 = επαναφόρτωση config.json,
##   F6 = αντίστροφη μέτρηση on/off, F7 = mute, F8 = εικονίδια στο φόντο on/off
func _debug_keys(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return false
	var cfg: Dictionary = Config.data
	match k.keycode:
		KEY_F2:
			cfg["mode"] = ConfigSchema.MODE_WHEEL if cfg["mode"] == ConfigSchema.MODE_ONE_CORRECT \
				else ConfigSchema.MODE_ONE_CORRECT
		KEY_F3:
			cfg["stop"]["mode"] = "instant" if cfg["stop"]["mode"] == "ease" else "ease"
		KEY_F4:
			var presets: Array = ConfigSchema.EFFECT_PRESETS
			var i := (presets.find(cfg["effects"]["preset"]) + 1) % presets.size()
			cfg["effects"] = ConfigSchema.effect_preset(presets[i])
		KEY_F5:
			Config.load_config()
			return true
		KEY_F6:
			cfg["flow"]["countdown"] = not bool(cfg["flow"]["countdown"])
		KEY_F7:
			cfg["audio"]["master_mute"] = not bool(cfg["audio"]["master_mute"])
		KEY_F8:
			cfg["flow"]["attract_icons"] = not bool(cfg["flow"]["attract_icons"])
		_:
			return false
	Config.save_config()
	return true

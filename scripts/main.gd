## Κύρια σκηνή: φόντο + οθόνη έλξης + παιχνίδι.
##
## Οθόνη έλξης: λογότυπο, κινούμενο μήνυμα «Πάτα για να παίξεις» και
## εικονίδια που περνούν αργά στο φόντο. Space / κλικ / άγγιγμα ξεκινά.
## Idle timeout: χωρίς αλληλεπίδραση για Ν δευτερόλεπτα ⇒ επιστροφή εδώ.
##
## Ρυθμίσεις: πάτημα 3 δ. στην πάνω αριστερή γωνία της οθόνης έλξης ή
## Ctrl+Shift+A ⇒ PIN ⇒ οθόνη ρυθμίσεων.
extends Control

const PressInput = preload("res://scripts/util/press_input.gd")
const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const AssetLoader = preload("res://scripts/util/asset_loader.gd")
const Backdrop = preload("res://scripts/game/backdrop.gd")
const CarouselView = preload("res://scripts/game/carousel_view.gd")
const Game = preload("res://scripts/game/game.gd")
const PinPad = preload("res://scripts/admin/pin_pad.gd")
const AdminScreen = preload("res://scripts/admin/admin_screen.gd")
const Fonts = preload("res://scripts/util/fonts.gd")
const Kiosk = preload("res://scripts/util/kiosk.gd")
const LightAccess = preload("res://scripts/util/light_access.gd")

const CURSOR_HIDE_MS := 2500        # ο κέρσορας κρύβεται μετά από τόση ακινησία

enum Screen { ATTRACT, GAME, PIN, ADMIN }

const CORNER_FRAC := 0.12           # μέγεθος κρυφής γωνίας (κλάσμα του ύψους)
const CORNER_HOLD_MS := 3000
const ADMIN_MIN_IDLE := 120.0       # το admin κλείνει μόνο του μετά από τουλάχιστον 2 λεπτά

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
var admin: AdminScreen
var pin_pad: PinPad
var corner_indicator: Control
var corner_hotspot: Control

var _time := 0.0
var _input_block_until := 0
var _screen_tween: Tween
var _corner_down_ms := -1
var _test_mode := false             # δοκιμαστικό παιχνίδι από το admin
var _font_id := ""
var _last_mouse_move_ms := 0


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
	# Γραμμή κατάστασης και πλήκτρα F2–F11 μόνο μέσα από τον editor, ποτέ στο .exe/.apk.
	debug_label.visible = Kiosk.in_editor()
	add_child(debug_label)

	game = Game.new()
	game.visible = false
	add_child(game)
	game.finished.connect(_on_game_finished)

	corner_indicator = Control.new()
	corner_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner_indicator.draw.connect(_draw_corner_indicator)
	add_child(corner_indicator)

	# Αόρατη «ζώνη» στην πάνω αριστερή γωνία. Ως Control με MOUSE_FILTER_STOP
	# «καταπίνει» το κλικ/άγγιγμα μέσω του GUI του Godot, οπότε δεν φτάνει ποτέ
	# στο _unhandled_input που ξεκινά το παιχνίδι.
	corner_hotspot = Control.new()
	corner_hotspot.mouse_filter = Control.MOUSE_FILTER_STOP
	corner_hotspot.gui_input.connect(_on_corner_gui_input)
	corner_hotspot.mouse_exited.connect(_cancel_corner)
	add_child(corner_hotspot)

	Config.changed.connect(_apply_config)
	_apply_config()
	# Εξωτερικό φως: εξασφαλίζει ότι η υπηρεσία υπάρχει (και στέλνει το «σβήσιμο»
	# της εκκίνησης) ακόμα κι αν λείπει το autoload από το project.godot.
	_ensure_light.call_deferred()
	_show_attract(false)


func _ensure_light() -> void:
	LightAccess.service(get_tree())


func _make_label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _apply_config() -> void:
	var cfg: Dictionary = Config.data
	# Γραμματοσειρά παιχνιδιού (το admin έχει δική του, πάντα ευανάγνωστη).
	var fid := str(cfg["theme"]["font"])
	if fid != _font_id:
		_font_id = fid
		get_tree().root.theme = Fonts.theme_for(fid)
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
	Kiosk.apply(get_tree(), cfg["kiosk"])
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
				_abort_game()
				_show_attract(false)
		NOTIFICATION_APPLICATION_RESUMED:
			Sfx.resume_music()
			PressInput.mark_activity()
			Kiosk.apply(get_tree(), Config.data["kiosk"])
		NOTIFICATION_WM_CLOSE_REQUEST:
			# Με «Αποτροπή κλεισίματος» το Alt+F4 / X αγνοείται (έξοδος μόνο από τις ρυθμίσεις).
			if get_tree().auto_accept_quit:
				_abort_game()


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

	var cs := s.y * CORNER_FRAC
	corner_hotspot.position = Vector2.ZERO
	corner_hotspot.size = Vector2(cs, cs)

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
	if _corner_down_ms >= 0:
		corner_indicator.queue_redraw()
		if Time.get_ticks_msec() - _corner_down_ms >= CORNER_HOLD_MS:
			_corner_down_ms = -1
			_open_pin()
	_update_cursor()
	_check_idle()


## Κέρσορας: κρυφός στην οθόνη έλξης και στο παιχνίδι όταν το ποντίκι μένει
## ακίνητο· πάντα ορατός στις ρυθμίσεις και στο PIN.
func _update_cursor() -> void:
	var hide_now := bool(Config.data["kiosk"]["hide_cursor"]) \
		and (screen == Screen.ATTRACT or screen == Screen.GAME) \
		and Time.get_ticks_msec() - _last_mouse_move_ms > CURSOR_HIDE_MS
	var want := Input.MOUSE_MODE_HIDDEN if hide_now else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


## Διακοπή του τρέχοντος παιχνιδιού. Αν έγινε τουλάχιστον μία προσπάθεια,
## καταγράφεται στα στατιστικά (ως «διακόπηκε», εκτός αν είχε ήδη τελειώσει).
func _abort_game() -> void:
	if not _test_mode:
		Stats.add(game.take_unrecorded())
	game.abort()


## Idle timeout: χωρίς αλληλεπίδραση ⇒ επιστροφή στην οθόνη έλξης.
func _check_idle() -> void:
	if screen == Screen.ATTRACT:
		return
	var timeout := float(Config.data["flow"]["idle_timeout"])
	if timeout <= 0.0:
		return
	if screen == Screen.PIN or screen == Screen.ADMIN:
		timeout = maxf(timeout, ADMIN_MIN_IDLE)
	if Time.get_ticks_msec() - PressInput.last_activity_ms <= int(timeout * 1000.0):
		return
	match screen:
		Screen.GAME:
			_abort_game()
			if _test_mode:
				_back_to_admin()
			else:
				_show_attract()
		Screen.PIN:
			_close_pin()
		Screen.ADMIN:
			# Ξεχασμένο ανοιχτό admin: κλείνει χωρίς αποθήκευση (ασφάλεια kiosk).
			admin._finish(false)


func _input(event: InputEvent) -> void:
	if PressInput.is_activity(event):
		PressInput.mark_activity()
	if event is InputEventMouseMotion:
		_last_mouse_move_ms = Time.get_ticks_msec()
	if _is_admin_shortcut(event) and (screen == Screen.ATTRACT or (screen == Screen.GAME and not _test_mode)):
		get_viewport().set_input_as_handled()
		_abort_game()
		_open_pin()
		return
	if screen == Screen.GAME and _test_mode and event is InputEventKey \
			and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		game.abort()
		_back_to_admin()
		return
	if screen == Screen.ADMIN or screen == Screen.PIN:
		return
	if Kiosk.in_editor() and _debug_keys(event):
		return


## Η οθόνη έλξης ξεκινά παιχνίδι μόνο με πατήματα που ΔΕΝ «έπιασε» κάποιο
## στοιχείο του GUI (π.χ. η κρυφή γωνία των ρυθμίσεων).
func _unhandled_input(event: InputEvent) -> void:
	if screen != Screen.ATTRACT:
		return
	# Σε αφή ακολουθεί πάντα εξομοιωμένο κλικ (που περνά από το GUI)· χρησιμοποιούμε εκείνο.
	if event is InputEventScreenTouch:
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


func _on_game_finished(record: Dictionary) -> void:
	# Τα δοκιμαστικά παιχνίδια (από τις ρυθμίσεις) δεν καταγράφονται.
	if not _test_mode:
		Stats.add(record)
	if _test_mode:
		_back_to_admin()
		return
	_show_attract()


# ----------------------------------------------------- πρόσβαση στο admin ---

static func _is_admin_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var k := event as InputEventKey
	# physical_keycode: δουλεύει και με ελληνική διάταξη πληκτρολογίου (όπου το
	# πλήκτρο A δίνει «α» και το keycode δεν είναι KEY_A).
	return k.pressed and not k.echo and k.ctrl_pressed and k.shift_pressed \
		and (k.physical_keycode == KEY_A or k.keycode == KEY_A)


## Κλικ/άγγιγμα στην κρυφή γωνία: ξεκινά τη χρονομέτρηση· άφημα την ακυρώνει.
func _on_corner_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		corner_hotspot.accept_event()
		if screen != Screen.ATTRACT:
			return
		if (event as InputEventMouseButton).pressed:
			if _corner_down_ms < 0:
				_corner_down_ms = Time.get_ticks_msec()
		else:
			_cancel_corner()


func _cancel_corner() -> void:
	if _corner_down_ms >= 0:
		_corner_down_ms = -1
		corner_indicator.queue_redraw()


## Διακριτικός δακτύλιος προόδου όσο κρατιέται πατημένη η γωνία.
func _draw_corner_indicator() -> void:
	if _corner_down_ms < 0:
		return
	var t := float(Time.get_ticks_msec() - _corner_down_ms) / CORNER_HOLD_MS
	if t < 0.15:
		return
	var c := Vector2.ONE * size.y * CORNER_FRAC * 0.5
	var r := size.y * CORNER_FRAC * 0.3
	corner_indicator.draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 6.0, true)
	corner_indicator.draw_arc(c, r, -PI / 2, -PI / 2 + TAU * clampf(t, 0.0, 1.0), 48, Color(1, 1, 1, 0.6), 6.0, true)


func _open_pin() -> void:
	if pin_pad != null:
		return
	screen = Screen.PIN
	PressInput.mark_activity()
	attract_icons.request_stop(0.0)
	pin_pad = PinPad.new()
	add_child(pin_pad)
	pin_pad.accepted.connect(_on_pin_accepted)
	pin_pad.cancelled.connect(_close_pin)


func _close_pin() -> void:
	if pin_pad != null:
		pin_pad.queue_free()
		pin_pad = null
	_show_attract()


func _on_pin_accepted() -> void:
	if pin_pad != null:
		pin_pad.queue_free()
		pin_pad = null
	_open_admin(false)


func _open_admin(keep_draft: bool) -> void:
	screen = Screen.ADMIN
	PressInput.mark_activity()
	game.visible = false
	attract.visible = false
	attract_icons.request_stop(0.0)
	if admin == null:
		admin = AdminScreen.new()
		add_child(admin)
		admin.closed.connect(_on_admin_closed)
		admin.test_requested.connect(_on_admin_test)
	admin.visible = true
	admin.open(keep_draft)


func _on_admin_closed(saved: bool) -> void:
	admin.visible = false
	_test_mode = false
	if not saved:
		# Επαναφορά: αναιρεί και ό,τι εφαρμόστηκε προσωρινά για δοκιμαστικό παιχνίδι.
		Config.load_config()
	_show_attract()


## Δοκιμαστικό παιχνίδι με τις μη αποθηκευμένες ρυθμίσεις.
func _on_admin_test(draft: Dictionary) -> void:
	admin.visible = false
	_test_mode = true
	Config.apply(draft)
	screen = Screen.GAME
	PressInput.mark_activity()
	_kill_screen_tween()
	attract.visible = false
	game.visible = true
	game.modulate.a = 1.0
	game.start_game(true)


func _back_to_admin() -> void:
	_test_mode = false
	game.visible = false
	_open_admin(true)


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
	debug_label.text = "v%s · %s · σταμάτημα: %s · εφέ: %s · αντ. μέτρηση: %s · ήχος: %s    [F2–F8]" % [
		str(ProjectSettings.get_setting("application/config/version", "?")),
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
		KEY_F11:
			Kiosk.toggle_fullscreen()
			return true
		_:
			return false
	Config.save_config()
	return true

## Κύρια σκηνή: φόντο + οθόνη έλξης + παιχνίδι.
##
## Φάση 1: απλή οθόνη έλξης (κείμενο που πάλλεται). Η πλήρης οθόνη έλξης,
## η αντίστροφη μέτρηση, το idle timeout, τα εφέ και οι ήχοι έρχονται στη Φάση 2.
extends Control

const PressInput = preload("res://scripts/util/press_input.gd")
const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const Backdrop = preload("res://scripts/game/backdrop.gd")
const Game = preload("res://scripts/game/game.gd")

enum Screen { ATTRACT, GAME }

var screen: int = Screen.ATTRACT

var backdrop: Backdrop
var attract: Control
var attract_label: Label
var mode_label: Label
var game: Game

var _time := 0.0
var _input_block_until := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	backdrop = Backdrop.new()
	add_child(backdrop)

	game = Game.new()
	game.visible = false
	add_child(game)
	game.finished.connect(_on_game_finished)

	attract = Control.new()
	attract.set_anchors_preset(Control.PRESET_FULL_RECT)
	attract.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(attract)

	attract_label = _make_label()
	attract.add_child(attract_label)
	mode_label = _make_label()
	attract.add_child(mode_label)

	Config.changed.connect(_apply_config)
	_apply_config()
	_show_attract()


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
	var mode_name := "Ένα σωστό" if cfg["mode"] == ConfigSchema.MODE_ONE_CORRECT else "Τροχός της τύχης"
	mode_label.text = mode_name
	if game.phase == Game.Phase.IDLE:
		game.apply_config()
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and attract_label != null:
		_layout()


func _layout() -> void:
	var s := size
	var text_col := Color.from_string(str(Config.data["theme"]["text_color"]), Color.WHITE)
	var fs := int(s.y * 0.09)
	attract_label.add_theme_font_size_override("font_size", fs)
	attract_label.add_theme_constant_override("outline_size", maxi(4, fs / 8))
	attract_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	attract_label.add_theme_color_override("font_color", text_col)
	attract_label.size = Vector2(s.x * 0.9, fs * 2.6)
	attract_label.position = Vector2(s.x * 0.05, s.y * 0.5 - fs * 1.3)
	attract_label.pivot_offset = attract_label.size * 0.5
	var ms := int(s.y * 0.04)
	mode_label.add_theme_font_size_override("font_size", ms)
	mode_label.add_theme_color_override("font_color", Color(text_col, 0.7))
	mode_label.size = Vector2(s.x, ms * 1.6)
	mode_label.position = Vector2(0, s.y * 0.8)


func _process(delta: float) -> void:
	_time += delta
	if screen == Screen.ATTRACT:
		var k := 1.0 + 0.05 * sin(_time * TAU * 0.8)
		attract_label.scale = Vector2(k, k)


func _input(event: InputEvent) -> void:
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
	var tw := create_tween()
	tw.tween_property(attract, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): attract.visible = false)
	game.visible = true
	game.modulate.a = 0.0
	create_tween().tween_property(game, "modulate:a", 1.0, 0.25)
	game.start_game()


func _on_game_finished(_record: Dictionary) -> void:
	# Φάση 4: εδώ θα καταγράφεται το `_record` στα στατιστικά.
	_show_attract()


func _show_attract() -> void:
	screen = Screen.ATTRACT
	# Μικρό διάστημα ώστε ένα «ξεχασμένο» πάτημα να μην ξεκινήσει αμέσως νέο παιχνίδι.
	_input_block_until = Time.get_ticks_msec() + 600
	attract.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(attract, "modulate:a", 1.0, 0.3)
	if game.visible:
		tw.tween_property(game, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(func(): game.visible = false)


## Πλήκτρα δοκιμών (μόνο σε debug build, μέχρι να έρθει η οθόνη ρυθμίσεων):
##   F2 = εναλλαγή λειτουργίας, F3 = άμεσο σταμάτημα / επιβράδυνση,
##   F4 = εναλλαγή εφέ bounce (Μίνιμαλ/Κανονικό), F5 = επαναφόρτωση config.json
func _debug_keys(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return false
	match k.keycode:
		KEY_F2:
			Config.data["mode"] = ConfigSchema.MODE_WHEEL if Config.mode() == ConfigSchema.MODE_ONE_CORRECT \
				else ConfigSchema.MODE_ONE_CORRECT
		KEY_F3:
			Config.data["stop"]["mode"] = "instant" if Config.data["stop"]["mode"] == "ease" else "ease"
			print("Σταμάτημα: ", Config.data["stop"]["mode"])
		KEY_F4:
			Config.data["effects"]["preset"] = "minimal" if Config.data["effects"]["preset"] != "minimal" else "normal"
			print("Εφέ: ", Config.data["effects"]["preset"])
		KEY_F5:
			Config.load_config()
			return true
		_:
			return false
	Config.save_config()
	return true

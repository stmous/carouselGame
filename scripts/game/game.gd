## Ένα παιχνίδι (ένας παίκτης): κίνηση → σταμάτημα → αποτέλεσμα → popup,
## με τις ευκαιρίες του «Ένα σωστό» και το «Ξαναπαίξε» του «Τροχού».
##
## Εκπέμπει `finished(record)` όταν τελειώσει, ώστε η κύρια σκηνή να γυρίσει
## στην οθόνη έλξης, και `result_shown(...)` για ήχους/εφέ.
extends Control

const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const GameFlow = preload("res://scripts/core/game_flow.gd")
const ResultDetector = preload("res://scripts/core/result_detector.gd")
const AssetLoader = preload("res://scripts/util/asset_loader.gd")
const PressInput = preload("res://scripts/util/press_input.gd")
const TargetCircle = preload("res://scripts/game/target_circle.gd")
const CarouselView = preload("res://scripts/game/carousel_view.gd")
const ResultPopup = preload("res://scripts/game/result_popup.gd")
const Confetti = preload("res://scripts/game/confetti.gd")

signal finished(record: Dictionary)
signal stop_pressed
signal result_shown(outcome: int, icon_id: String)

enum Phase { IDLE, COUNTDOWN, BANNER, RUNNING, STOPPING, RESOLVING, POPUP }

const SNAP_DURATION := 0.18
const RESULT_DELAY := 0.75         # χρόνος να δει ο παίκτης πού σταμάτησε
const MISS_COLOR := Color("#ff5a5a")
const COUNTDOWN_STEP := 0.8        # δευτερόλεπτα ανά αριθμό

var phase: int = Phase.IDLE
var flow: GameFlow

var circle_back: TargetCircle
var carousel: CarouselView
var circle_front: TargetCircle
var banner: Label
var popup: ResultPopup
var countdown_label: Label
var confetti: Confetti

var _token := 0                    # ακυρώνει εκκρεμείς callbacks μετά από abort
var _pending_icon := ""
var _pending_outcome: int = GameFlow.Outcome.NONE
var _hl_tween: Tween
var _banner_tween: Tween
var _time := 0.0
var _shake_t := 0.0
var _shake_dur := 0.0
var _shake_amp := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	circle_back = TargetCircle.new()
	circle_back.layer = TargetCircle.Layer.BACK
	add_child(circle_back)

	carousel = CarouselView.new()
	add_child(carousel)
	carousel.stopped.connect(_on_carousel_stopped)

	circle_front = TargetCircle.new()
	circle_front.layer = TargetCircle.Layer.FRONT
	add_child(circle_front)

	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	add_child(banner)

	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.visible = false
	add_child(countdown_label)

	popup = ResultPopup.new()
	add_child(popup)
	popup.closed.connect(_on_popup_closed)

	confetti = Confetti.new()      # πάνω από το popup
	add_child(confetti)
	_rng.randomize()

	apply_config()


## Εφαρμόζει τις τρέχουσες ρυθμίσεις (χρώματα, εικονίδια κ.λπ.).
func apply_config() -> void:
	var cfg: Dictionary = Config.data
	var glow_on := bool(cfg["effects"]["glow"])
	var boost := ConfigSchema.effect_intensity(str(cfg["effects"]["preset"]))
	circle_back.configure(cfg["theme"]["circle"], glow_on, boost)
	circle_front.configure(cfg["theme"]["circle"], glow_on, boost)
	carousel.configure(cfg["icons"]["list"], cfg["icons"], cfg["theme"]["strip"])
	_layout_banner()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and banner != null:
		_layout_banner()


func _layout_banner() -> void:
	var s := size
	var fs := int(s.y * 0.10)
	banner.add_theme_font_size_override("font_size", fs)
	banner.add_theme_constant_override("outline_size", maxi(4, int(fs / 7.0)))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	banner.add_theme_color_override("font_color", _color("accent_color", Color.YELLOW))
	banner.size = Vector2(s.x, fs * 1.6)
	banner.position = Vector2(0, s.y * 0.12)
	banner.pivot_offset = banner.size * 0.5
	var cs := int(s.y * 0.26)
	countdown_label.add_theme_font_size_override("font_size", cs)
	countdown_label.add_theme_constant_override("outline_size", maxi(6, int(cs / 10.0)))
	countdown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	countdown_label.add_theme_color_override("font_color", _color("text_color", Color.WHITE))
	countdown_label.size = Vector2(s.x, cs * 1.4)
	countdown_label.position = Vector2(0, s.y * 0.5 - cs * 0.7)
	countdown_label.pivot_offset = countdown_label.size * 0.5


func _color(key: String, fallback: Color) -> Color:
	return Color.from_string(str(Config.data["theme"].get(key, "")), fallback)


# ---------------------------------------------------------------- ροή ---

## Ξεκινά νέο παιχνίδι. `test_game`: δοκιμαστικό, δεν μετράει στα στατιστικά.
func start_game(test_game: bool = false) -> void:
	abort()
	apply_config()
	flow = GameFlow.new(Config.data, test_game, Time.get_datetime_string_from_system())
	if Config.icons().is_empty():
		push_warning("Δεν υπάρχουν εικονίδια στη λίστα.")
		_show_popup(null, "Δεν έχουν οριστεί εικονίδια.\nΆνοιξε τις ρυθμίσεις.", null)
		_pending_outcome = GameFlow.Outcome.LOSE
		return
	if bool(Config.data["flow"]["countdown"]):
		_countdown_step(3)
	else:
		_begin_attempt()


## Διακόπτει ό,τι τρέχει (idle timeout, είσοδος στο admin κ.λπ.).
func abort() -> void:
	_token += 1
	phase = Phase.IDLE
	if carousel != null:
		carousel.request_stop(0.0)
	if popup != null and popup.visible:
		popup.visible = false
	if banner != null:
		banner.visible = false
	if countdown_label != null:
		countdown_label.visible = false
	if confetti != null:
		confetti.clear()
	_shake_t = 0.0
	position = Vector2.ZERO
	_set_highlight(0.0, 0.0)


# ------------------------------------------------------ αντίστροφη μέτρηση ---

func _countdown_step(n: int) -> void:
	phase = Phase.COUNTDOWN
	if n <= 0:
		_pop_countdown("Πάμε!")
		Sfx.play("countdown", 1.5)
		_after(0.5, _end_countdown)
		return
	_pop_countdown(str(n))
	Sfx.play("countdown")
	_after(COUNTDOWN_STEP, _countdown_step.bind(n - 1))


func _pop_countdown(text: String) -> void:
	_layout_banner()
	countdown_label.text = text
	countdown_label.visible = true
	countdown_label.modulate.a = 0.0
	countdown_label.scale = Vector2(1.7, 1.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(countdown_label, "modulate:a", 1.0, 0.15)
	var bounce := _fx_bounce()
	tw.tween_property(countdown_label, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK if bounce else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(countdown_label, "modulate:a", 0.0, 0.2).set_delay(COUNTDOWN_STEP - 0.6)


func _end_countdown() -> void:
	countdown_label.visible = false
	_begin_attempt()


func _begin_attempt() -> void:
	_set_highlight(0.0, 0.25)
	var msg := flow.retry_message()
	if msg == "":
		_run()
		return
	phase = Phase.BANNER
	_show_banner(msg)
	_after(float(Config.data["flow"]["retry_banner_duration"]), _hide_banner_and_run)


func _hide_banner_and_run() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.2)
	_banner_tween.tween_callback(func(): banner.visible = false)
	_run()


func _run() -> void:
	phase = Phase.RUNNING
	carousel.start(flow.current_speed())


func _input(event: InputEvent) -> void:
	if phase != Phase.RUNNING:
		return
	if PressInput.accept(event):
		get_viewport().set_input_as_handled()
		_stop()


func _stop() -> void:
	var stop_cfg: Dictionary = Config.data["stop"]
	var ease_time := 0.0
	if stop_cfg["mode"] == "ease":
		ease_time = float(stop_cfg["ease_duration"])
	if not carousel.request_stop(ease_time):
		return
	phase = Phase.STOPPING
	Sfx.play("stop")
	stop_pressed.emit()
	if ease_time <= 0.0:
		_resolve()


func _on_carousel_stopped() -> void:
	if phase == Phase.STOPPING:
		_resolve()


func _resolve() -> void:
	phase = Phase.RESOLVING
	var radius := TargetCircle.radius_for(Config.data["theme"]["circle"], carousel.size.y)
	var res := ResultDetector.evaluate(carousel.offsets_px(), radius, flow.tolerance_pct(), flow.allows_miss())
	var index: int = res["index"]
	if index >= 0:
		var icon_idx := carousel.model.icon_at(index)
		_pending_icon = str(Config.icons()[icon_idx]["id"])
		carousel.snap_to(index, SNAP_DURATION, _fx_bounce())
		circle_front.highlight_color = _circle_highlight_color()
		circle_back.highlight_color = circle_front.highlight_color
	else:
		_pending_icon = ""
		circle_front.highlight_color = MISS_COLOR
		circle_back.highlight_color = MISS_COLOR
	_set_highlight(1.0, 0.15)
	_after(RESULT_DELAY, _show_result)


func _show_result() -> void:
	_pending_outcome = flow.submit(_pending_icon)
	var mode_cfg: Dictionary = Config.data["modes"][flow.mode]
	var o := _pending_outcome
	if o == GameFlow.Outcome.WIN:
		var target := ConfigSchema.find_icon(Config.data, _pending_icon)
		_show_popup(AssetLoader.texture(str(mode_cfg["win_popup"])), "Συγχαρητήρια!\nΚέρδισες!",
			_icon_texture(target))
		Sfx.play("win")
		_celebrate()
	elif o == GameFlow.Outcome.RETRY or o == GameFlow.Outcome.LOSE:
		_show_popup(AssetLoader.texture(str(mode_cfg["lose_popup"])), "Δεν πέτυχε!", null)
		Sfx.play("lose")
	elif o == GameFlow.Outcome.WHEEL or o == GameFlow.Outcome.WHEEL_REPLAY:
		var icon := ConfigSchema.find_icon(Config.data, _pending_icon)
		var text := str(icon.get("name", ""))
		if o == GameFlow.Outcome.WHEEL_REPLAY:
			text += "\nΞαναπαίξε!"
		_show_popup(AssetLoader.texture(str(icon.get("popup", ""))), text, _icon_texture(icon))
		# Ήχος του εικονιδίου αν έχει οριστεί, αλλιώς ο ήχος νίκης.
		var icon_sound := str(icon.get("sound", ""))
		if icon_sound != "":
			Sfx.play_file(icon_sound, float(Config.data["audio"]["win"]["volume"]))
		else:
			Sfx.play("win")
		_celebrate()
	result_shown.emit(_pending_outcome, _pending_icon)


func _show_popup(tex: Texture2D, fallback_text: String, fallback_icon: Texture2D) -> void:
	phase = Phase.POPUP
	popup.open(tex, fallback_text, fallback_icon, _fx_bounce(),
		float(Config.data["flow"]["popup_auto_close"]), _color("text_color", Color.WHITE))


func _on_popup_closed() -> void:
	if phase != Phase.POPUP:
		return
	if _pending_outcome == GameFlow.Outcome.RETRY or _pending_outcome == GameFlow.Outcome.WHEEL_REPLAY:
		_begin_attempt()
	else:
		_finish()


func _finish() -> void:
	phase = Phase.IDLE
	_set_highlight(0.0, 0.3)
	finished.emit(flow.record())


# ------------------------------------------------------------ βοηθητικά ---

func _icon_texture(icon: Dictionary) -> Texture2D:
	if icon.is_empty():
		return null
	return AssetLoader.texture(str(icon["image"]))


func _circle_highlight_color() -> Color:
	return Color.from_string(str(Config.data["theme"]["circle"].get("highlight_color", "#ffe14d")), Color.YELLOW)


func _fx_bounce() -> bool:
	var fx: Dictionary = Config.data["effects"]
	return bool(fx["bounce"]) and fx["preset"] != "minimal"


## Εφέ νίκης: confetti και (αν είναι ενεργό) screen shake.
func _celebrate() -> void:
	var fx: Dictionary = Config.data["effects"]
	var k := ConfigSchema.effect_intensity(str(fx["preset"]))
	if bool(fx["confetti"]):
		confetti.burst(size * 0.5, int(90 * k), 0.8 + 0.2 * k)
		if fx["preset"] == "arcade":
			confetti.cannons(70)
	if bool(fx["screen_shake"]):
		_shake(size.y * 0.012 * k, 0.5)


func _shake(amplitude: float, duration: float) -> void:
	_shake_amp = amplitude
	_shake_dur = duration
	_shake_t = duration


func _show_banner(text: String) -> void:
	_layout_banner()
	banner.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.4, 0.4)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween().set_parallel(true)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_highlight(value: float, duration: float) -> void:
	if _hl_tween != null and _hl_tween.is_valid():
		_hl_tween.kill()
	if circle_front == null:
		return
	if duration <= 0.0:
		circle_front.highlight = value
		circle_back.highlight = value
		return
	_hl_tween = create_tween().set_parallel(true)
	_hl_tween.tween_property(circle_front, "highlight", value, duration)
	_hl_tween.tween_property(circle_back, "highlight", value, duration)


## Εκτελεί `cb` μετά από `seconds`, εκτός αν στο μεταξύ έγινε abort().
func _after(seconds: float, cb: Callable) -> void:
	var tok := _token
	await get_tree().create_timer(seconds).timeout
	if tok == _token and is_inside_tree():
		cb.call()


func _process(delta: float) -> void:
	_time += delta
	# Διακριτικός παλμός του κύκλου όσο τρέχει η κίνηση.
	var fx: Dictionary = Config.data["effects"]
	var p := 1.0
	if phase == Phase.RUNNING and bool(fx["circle_pulse"]):
		p = 1.0 + 0.015 * sin(_time * TAU * 1.2)
	if circle_front.pulse != p:
		circle_front.pulse = p
		circle_back.pulse = p
	# Screen shake με φθίνουσα ένταση.
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta, 0.0)
		var a := _shake_amp * (_shake_t / _shake_dur)
		position = Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a))
	elif position != Vector2.ZERO:
		position = Vector2.ZERO

## Οθόνη ρυθμίσεων (admin).
##
## Όλες οι αλλαγές γίνονται σε ένα «πρόχειρο» (draft) αντίγραφο των ρυθμίσεων
## και φαίνονται αμέσως στη ζωντανή προεπισκόπηση. Τίποτα δεν αποθηκεύεται
## μέχρι να πατηθεί «Αποθήκευση». Το «Δοκιμαστικό παιχνίδι» τρέχει έναν γύρο
## με το πρόχειρο, χωρίς να μετράει στα στατιστικά.
extends Control

const UI = preload("res://scripts/admin/ui.gd")
const AdminPreview = preload("res://scripts/admin/admin_preview.gd")
const FilePicker = preload("res://scripts/admin/file_picker.gd")
const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const CfgPath = preload("res://scripts/core/cfg_path.gd")
const MediaImport = preload("res://scripts/util/media_import.gd")
const AssetLoader = preload("res://scripts/util/asset_loader.gd")
const Fonts = preload("res://scripts/util/fonts.gd")

signal closed(saved: bool)
signal test_requested(draft: Dictionary)

const SECTIONS := [
	["theme", "Θέμα & χρώματα"],
	["mode", "Λειτουργία"],
	["icons", "Εικονίδια"],
	["speed", "Ταχύτητα & ευκαιρίες"],
	["effects", "Εφέ"],
	["sounds", "Ήχοι"],
	["flow", "Οθόνη έλξης & ροή"],
	["system", "Σύστημα"],
]
const SOUND_NAMES := {
	"music": "Μουσική υπόκρουσης (loop)",
	"countdown": "Αντίστροφη μέτρηση",
	"stop": "Σταμάτημα",
	"win": "Νίκη",
	"lose": "Αποτυχία",
}
const ORDINALS := ["1η", "2η", "3η", "4η", "5η"]

var draft: Dictionary = {}
var dirty := false

var _section := "theme"
var _nav: Dictionary = {}
var _scroll: ScrollContainer
var _content: VBoxContainer
var _preview: AdminPreview
var _picker: FilePicker
var _dirty_label: Label
var _rebuild_pending := false


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_picker = FilePicker.new()
	add_child(_picker)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# Πάνω μπάρα
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := UI.label("Ρυθμίσεις", "TitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_dirty_label = UI.label("", "MutedLabel")
	_dirty_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_dirty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_dirty_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	# Πλοήγηση
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(290, 0)
	nav.add_theme_constant_override("separation", 6)
	body.add_child(nav)
	var group := ButtonGroup.new()
	for s in SECTIONS:
		var b := UI.button(s[1], "NavButton")
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show_section.bind(s[0]))
		nav.add_child(b)
		_nav[s[0]] = b

	# Περιεχόμενο
	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_stretch_ratio = 1.5
	body.add_child(content_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	_scroll.add_child(_content)

	# Δεξιά: προεπισκόπηση + ενέργειες
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	body.add_child(right)
	right.add_child(UI.label("Ζωντανή προεπισκόπηση", "HeadingLabel"))
	_preview = AdminPreview.new()
	right.add_child(_preview)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var test_btn := UI.button("▶  Δοκιμαστικό παιχνίδι")
	test_btn.pressed.connect(_on_test)
	right.add_child(test_btn)
	right.add_child(UI.help("Ένας γύρος με τις τρέχουσες (και μη αποθηκευμένες) ρυθμίσεις. Δεν μετράει στα στατιστικά."))
	var save_btn := UI.button("Αποθήκευση", "AccentButton")
	save_btn.pressed.connect(_on_save)
	right.add_child(save_btn)
	var close_btn := UI.button("Κλείσιμο ρυθμίσεων")
	close_btn.pressed.connect(_on_close)
	right.add_child(close_btn)


## Ανοίγει την οθόνη. `keep_draft`: επιστροφή από δοκιμαστικό παιχνίδι.
func open(keep_draft: bool = false) -> void:
	if not keep_draft or draft.is_empty():
		draft = Config.data.duplicate(true)
		dirty = false
	_update_dirty()
	_preview.refresh(draft)
	Sfx.preview_audio(draft["audio"])
	_show_section(_section)


# ------------------------------------------------------------- ενέργειες ---

func _on_test() -> void:
	test_requested.emit(ConfigSchema.sanitize(draft.duplicate(true)))


func _on_save(then_close: bool = false) -> void:
	draft = ConfigSchema.sanitize(draft)
	if draft["mode"] == ConfigSchema.MODE_WHEEL:
		var missing := ConfigSchema.icons_missing_popup(draft)
		if not missing.is_empty():
			var names: Array = []
			for id in missing:
				names.append(str(ConfigSchema.find_icon(draft, id).get("name", id)))
			UI.modal(self, "Λείπουν popups",
				"Στον «Τροχό της τύχης» τα παρακάτω εικονίδια δεν έχουν δικό τους popup:\n\n• "
				+ "\n• ".join(names) + "\n\nΑν βγουν, θα εμφανίζεται μόνο η εικόνα και το όνομά τους.",
				[["Άκυρο", Callable(), ""], ["Αποθήκευση έτσι", _do_save.bind(then_close), "AccentButton"]])
			return
	_do_save(then_close)


func _do_save(then_close: bool) -> void:
	Config.data = draft.duplicate(true)
	if not Config.save_config():
		UI.toast(self, "Η αποθήκευση απέτυχε!", UI.DANGER)
		return
	MediaImport.collect_garbage(Config.data)
	dirty = false
	_update_dirty()
	if then_close:
		_finish(true)
	else:
		UI.toast(self, "Οι ρυθμίσεις αποθηκεύτηκαν.")


func _on_close() -> void:
	if not dirty:
		_finish(false)
		return
	UI.modal(self, "Μη αποθηκευμένες αλλαγές", "Θέλεις να αποθηκεύσεις τις αλλαγές πριν κλείσεις;",
		[["Άκυρο", Callable(), ""], ["Απόρριψη", _finish.bind(false), "DangerButton"],
		["Αποθήκευση", _on_save.bind(true), "AccentButton"]])


func _finish(saved: bool) -> void:
	Sfx.clear_preview()
	draft = {}
	dirty = false
	closed.emit(saved)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_close()


# ---------------------------------------------------------- draft & binding ---

func _v(path: Array, default_value = null):
	return CfgPath.get_at(draft, path, default_value)


func _set_value(path: Array, value, rebuild: bool = false) -> void:
	CfgPath.set_at(draft, path, value)
	_changed(rebuild)


func _changed(rebuild: bool = false) -> void:
	dirty = true
	_update_dirty()
	_preview.refresh(draft)
	Sfx.preview_audio(draft["audio"])
	if rebuild and not _rebuild_pending:
		_rebuild_pending = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_pending = false
	_show_section(_section, true)


func _update_dirty() -> void:
	_dirty_label.text = "● Μη αποθηκευμένες αλλαγές" if dirty else "Όλα αποθηκευμένα"
	_dirty_label.add_theme_color_override("font_color", UI.ACCENT if dirty else UI.MUTED)


# ------------------------------------------------------------- widgets ---

func _slider(path: Array, min_v: float, max_v: float, step: float, fmt: Callable,
		on_change: Callable = Callable()) -> HBoxContainer:
	var h := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = float(_v(path, min_v))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(160, UI.ROW_H)
	h.add_child(s)
	var l := UI.label(fmt.call(s.value))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(190, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	var is_int := step >= 1.0 and is_equal_approx(step, round(step))
	s.value_changed.connect(func(v: float):
		l.text = fmt.call(v)
		var stored: Variant = v
		if is_int:
			stored = int(round(v))
		_set_value(path, stored)
		if on_change.is_valid():
			on_change.call(v))
	return h


func _toggle(path: Array, rebuild: bool = false) -> Button:
	var b := UI.button("", "SegButton", 160)
	b.toggle_mode = true
	b.button_pressed = bool(_v(path, false))
	b.text = "Ναι" if b.button_pressed else "Όχι"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.toggled.connect(func(on: bool):
		b.text = "Ναι" if on else "Όχι"
		_set_value(path, on, rebuild))
	return b


## Επιλογή μίας τιμής από λίγες (κουμπιά δίπλα-δίπλα). `options`: [[τιμή, κείμενο], ...]
func _segmented(path: Array, options: Array, rebuild: bool = false, on_change: Callable = Callable()) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	var current = _v(path)
	for opt in options:
		var b := UI.button(str(opt[1]), "SegButton")
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = opt[0] == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value = opt[0]
		b.pressed.connect(func():
			if on_change.is_valid():
				on_change.call(value)
			else:
				_set_value(path, value, rebuild))
		h.add_child(b)
	return h


func _color(path: Array) -> ColorPickerButton:
	var c := ColorPickerButton.new()
	c.color = Color.from_string(str(_v(path, "#ffffff")), Color.WHITE)
	c.edit_alpha = false
	c.custom_minimum_size = Vector2(180, UI.ROW_H)
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.color_changed.connect(func(col: Color): _set_value(path, "#" + col.to_html(false)))
	return c


func _text(path: Array, placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.text = str(_v(path, ""))
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(200, UI.ROW_H)
	e.text_changed.connect(func(t: String): _set_value(path, t))
	return e


static func _display_name(path: String) -> String:
	if path == "":
		return "—"
	if path.begins_with("res://"):
		return "Ενσωματωμένο: " + path.get_file()
	return path.get_file()


## Επιλογή αρχείου. `kind`: είδος εικόνας ("backdrop", "logo", "icon", "popup",
## "circle") ή "sound". `sound_key`: για κουμπί δοκιμαστικής ακρόασης.
func _file(path: Array, kind: String, sound_key: String = "", volume_path: Array = []) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	v.add_child(h)
	var current := str(_v(path, ""))
	if kind != "sound":
		var thumb := TextureRect.new()
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(96, 72)
		thumb.texture = AssetLoader.texture(current)
		h.add_child(thumb)
	var name_label := UI.label(_display_name(current) if not (kind == "sound" and current == "") else "Ενσωματωμένος ήχος")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(name_label)
	if kind == "sound" and sound_key != "":
		var play := UI.button("▶", "", 72)
		play.pressed.connect(func():
			var vol := float(_v(volume_path, 1.0)) if not volume_path.is_empty() else 1.0
			Sfx.preview(sound_key, str(_v(path, "")), vol))
		h.add_child(play)
	elif kind == "sound":
		var play2 := UI.button("▶", "", 72)
		play2.disabled = current == ""
		play2.pressed.connect(func(): Sfx.play_file(str(_v(path, "")), 1.0))
		h.add_child(play2)
	var pick := UI.button("Επιλογή…", "", 150)
	pick.pressed.connect(func(): _pick_and_import(path, kind))
	h.add_child(pick)
	var clear := UI.button("×", "", 64)
	clear.tooltip_text = "Καθαρισμός"
	clear.disabled = current == ""
	clear.pressed.connect(func(): _set_value(path, "", true))
	h.add_child(clear)
	var help_key := "sound" if kind == "sound" else kind
	if MediaImport.HELP.has(help_key):
		v.add_child(UI.help(MediaImport.HELP[help_key]))
	return v


func _pick_and_import(path: Array, kind: String, on_done: Callable = Callable()) -> void:
	var picker_kind := "sound" if kind == "sound" else ("font" if kind == "font" else "image")
	_picker.pick(picker_kind, func(src: String):
		var r: Dictionary
		if kind == "sound":
			r = MediaImport.import_sound(src)
		elif kind == "font":
			r = MediaImport.import_font(src)
		else:
			r = MediaImport.import_image(src, kind)
		if str(r["error"]) != "":
			UI.toast(self, r["error"], UI.DANGER)
			return
		if r.get("resized", false):
			var sz: Vector2i = r["size"]
			UI.toast(self, "Η εικόνα σμικρύνθηκε αυτόματα σε %d×%d." % [sz.x, sz.y])
		if on_done.is_valid():
			on_done.call(str(r["path"]))
		else:
			_set_value(path, str(r["path"]), true))


func _add_card(title: String, help_text: String = "") -> VBoxContainer:
	var c := UI.card()
	_content.add_child(c)
	var b := UI.body(c)
	b.add_child(UI.heading(title))
	if help_text != "":
		b.add_child(UI.help(help_text))
	return b


func _pct(v: float) -> String:
	return "%d%%" % int(round(v))


func _px(v: float) -> String:
	return "%d px" % int(round(v))


func _num2(v: float) -> String:
	return "%.2f" % v


func _sec(v: float) -> String:
	return "%.2f δ" % v


# ------------------------------------------------------------- ενότητες ---

func _show_section(id: String, keep_scroll: bool = false) -> void:
	_section = id
	if _nav.has(id):
		(_nav[id] as Button).button_pressed = true
	var scroll_pos := _scroll.scroll_vertical
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match id:
		"theme":
			_build_theme()
		"mode":
			_build_mode()
		"icons":
			_build_icons()
		"speed":
			_build_speed()
		"effects":
			_build_effects()
		"sounds":
			_build_sounds()
		"flow":
			_build_flow()
		"system":
			_build_system()
	if keep_scroll:
		_restore_scroll.call_deferred(scroll_pos)
	else:
		_scroll.scroll_vertical = 0


func _restore_scroll(pos: int) -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = pos


func _build_theme() -> void:
	var bg_path := ["theme", "background"]
	var b := _add_card("Φόντο")
	b.add_child(UI.row("Τύπος", _segmented(bg_path + ["type"],
		[["color", "Χρώμα"], ["gradient", "Διαβάθμιση"], ["image", "Εικόνα"]], true)))
	match str(_v(bg_path + ["type"])):
		"color":
			b.add_child(UI.row("Χρώμα", _color(bg_path + ["color"])))
		"gradient":
			b.add_child(UI.row("Χρώμα 1", _color(bg_path + ["gradient_from"])))
			b.add_child(UI.row("Χρώμα 2", _color(bg_path + ["gradient_to"])))
			b.add_child(UI.row("Γωνία", _slider(bg_path + ["gradient_angle"], 0, 360, 5, func(x): return "%d°" % int(x))))
		"image":
			b.add_child(_file(bg_path + ["image"], "backdrop"))
			b.add_child(UI.row("Προσαρμογή", _segmented(bg_path + ["image_fit"],
				[["cover", "Γέμισμα (cover)"], ["contain", "Ολόκληρη (contain)"]])))
			b.add_child(UI.row("Χρώμα γύρω", _color(bg_path + ["color"])))

	var logo := ["theme", "logo"]
	b = _add_card("Λογότυπο οθόνης έλξης")
	b.add_child(_file(logo + ["image"], "logo"))
	b.add_child(UI.row("Μέγεθος (ύψος)", _slider(logo + ["size_pct"], 5, 60, 1, _pct)))
	b.add_child(UI.row("Θέση", _segmented(logo + ["position"],
		[["top", "Πάνω"], ["center", "Κέντρο"], ["bottom", "Κάτω"]])))

	var c := ["theme", "circle"]
	b = _add_card("Κύκλος-στόχος")
	b.add_child(UI.row("Χρώμα περιγράμματος", _color(c + ["color"])))
	b.add_child(UI.row("Πάχος περιγράμματος", _slider(c + ["thickness"], 1, 40, 1, _px)))
	b.add_child(UI.row("Μέγεθος (διάμετρος)", _slider(c + ["size_pct"], 10, 60, 1, func(x): return "%d%% ύψους" % int(x))))
	b.add_child(UI.row("Γέμισμα", _color(c + ["fill_color"])))
	b.add_child(UI.row("Διαφάνεια γεμίσματος", _slider(c + ["fill_alpha"], 0, 1, 0.05, func(x): return _pct(x * 100.0))))
	b.add_child(UI.row("Glow", _toggle(c + ["glow"])))
	b.add_child(UI.row("Χρώμα glow", _color(c + ["glow_color"])))
	b.add_child(UI.row("Ένταση glow", _slider(c + ["glow_intensity"], 0, 1, 0.05, func(x): return _pct(x * 100.0))))
	b.add_child(UI.row("Χρώμα έμφασης (μετά το σταμάτημα)", _color(c + ["highlight_color"])))
	b.add_child(UI.label("Εικόνα αντί για κύκλο (προαιρετικό)"))
	b.add_child(_file(c + ["image"], "circle"))

	b = _add_card("Κείμενα & γραμματοσειρά")
	b.add_child(UI.row("Χρώμα κειμένων", _color(["theme", "text_color"])))
	b.add_child(UI.row("Χρώμα έμφασης (μηνύματα)", _color(["theme", "accent_color"])))
	var fonts := OptionButton.new()
	fonts.custom_minimum_size = Vector2(0, UI.ROW_H)
	var current_font := str(_v(["theme", "font"], Fonts.DEFAULT_ID))
	var ids: Array = []
	for f in Fonts.BUILTIN:
		fonts.add_item(f[1])
		ids.append(f[0])
	if not Fonts.is_builtin(current_font):
		fonts.add_item(Fonts.label_for(current_font))
		ids.append(current_font)
	fonts.select(maxi(ids.find(current_font), 0))
	fonts.item_selected.connect(func(i: int): _set_value(["theme", "font"], ids[i]))
	b.add_child(UI.row("Γραμματοσειρά", fonts))
	var import_font := UI.button("Εισαγωγή γραμματοσειράς (.ttf / .otf)…")
	import_font.pressed.connect(func(): _pick_and_import(["theme", "font"], "font"))
	b.add_child(import_font)
	b.add_child(UI.help(MediaImport.HELP["font"] + " Η γραμματοσειρά εφαρμόζεται στο παιχνίδι μετά την αποθήκευση."))

	var st := ["theme", "strip"]
	b = _add_card("Λωρίδα πίσω από τα εικονίδια")
	b.add_child(UI.row("Εμφάνιση", _toggle(st + ["enabled"], true)))
	if bool(_v(st + ["enabled"], false)):
		b.add_child(UI.row("Χρώμα", _color(st + ["color"])))
		b.add_child(UI.row("Αδιαφάνεια", _slider(st + ["alpha"], 0, 1, 0.05, func(x): return _pct(x * 100.0))))
		b.add_child(UI.row("Ύψος", _slider(st + ["height_pct"], 5, 60, 1, func(x): return "%d%% ύψους" % int(x))))


func _build_mode() -> void:
	var modes := [
		[ConfigSchema.MODE_ONE_CORRECT, "Ένα σωστό",
			"Ένα εικονίδιο είναι ο στόχος. Αν ο παίκτης σταματήσει τον στόχο μέσα στον κύκλο κερδίζει, "
			+ "αλλιώς χάνει. Μπορεί να έχει έως 5 προσπάθειες, η καθεμία με δική της ταχύτητα."],
		[ConfigSchema.MODE_WHEEL, "Τροχός της τύχης",
			"Κάθε εικονίδιο είναι ένα δώρο με δικό του popup. Όποιο σταματήσει στον κύκλο, αυτό κερδίζει: "
			+ "δεν υπάρχει νίκη ή ήττα. Εικονίδια με σήμανση «Ξαναπαίξε» δίνουν νέα προσπάθεια."],
	]
	_content.add_child(UI.help("Κάθε λειτουργία κρατά τις δικές της ρυθμίσεις· η εναλλαγή δεν σβήνει τίποτα."))
	for m in modes:
		var b := _add_card(m[1], m[2])
		var selected: bool = draft["mode"] == m[0]
		var btn := UI.button("✓ Επιλεγμένη" if selected else "Επιλογή", "AccentButton" if selected else "", 240)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn.disabled = selected
		var mode_id: String = m[0]
		btn.pressed.connect(func(): _set_value(["mode"], mode_id, true))
		b.add_child(btn)


func _build_icons() -> void:
	var list: Array = draft["icons"]["list"]
	var is_oc: bool = draft["mode"] == ConfigSchema.MODE_ONE_CORRECT
	var oc := ["modes", ConfigSchema.MODE_ONE_CORRECT]

	var b := _add_card("Γενικά")
	b.add_child(UI.row("Μέγεθος εικονιδίων", _slider(["icons", "size_pct"], 5, 40, 1, func(x): return "%d%% ύψους" % int(x))))
	b.add_child(UI.row("Απόσταση μεταξύ τους", _slider(["icons", "gap_pct"], 0, 30, 1, func(x): return "%d%% ύψους" % int(x))))
	b.add_child(UI.row("Σκιά", _toggle(["icons", "shadow"])))
	b.add_child(UI.help(MediaImport.HELP["icon"]))

	if is_oc:
		b = _add_card("«Ένα σωστό»: popups & μηνύματα")
		b.add_child(UI.label("Popup νίκης"))
		b.add_child(_file(oc + ["win_popup"], "popup"))
		b.add_child(UI.label("Popup αποτυχίας"))
		b.add_child(_file(oc + ["lose_popup"], "popup"))
		for i in ConfigSchema.MAX_ATTEMPTS - 1:
			b.add_child(UI.row("Μήνυμα πριν την %s προσπάθεια" % ORDINALS[i + 1],
				_text(oc + ["retry_messages", i], "π.χ. Δεύτερη ευκαιρία!")))
	else:
		var missing := ConfigSchema.icons_missing_popup(draft)
		if not missing.is_empty():
			var warn := PanelContainer.new()
			warn.theme_type_variation = "WarnPanel"
			var names: Array = []
			for id in missing:
				names.append(str(ConfigSchema.find_icon(draft, id).get("name", id)))
			warn.add_child(UI.label("Χωρίς popup: " + ", ".join(names)))
			_content.add_child(warn)

	b = _add_card("Λίστα εικονιδίων (%d)" % list.size(),
		"Η σειρά εδώ δεν επηρεάζει τη σειρά στο παιχνίδι (εκεί είναι τυχαία)." if list.size() > 1 else "")
	for i in list.size():
		b.add_child(_icon_row(i, list.size(), is_oc))
	var add := UI.button("+  Προσθήκη εικονιδίου", "AccentButton")
	add.pressed.connect(_on_add_icon)
	b.add_child(add)


func _icon_row(i: int, count: int, is_oc: bool) -> Control:
	var icon: Dictionary = draft["icons"]["list"][i]
	var p := ["icons", "list", i]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI._box(UI.FIELD, 12, 14, 12))
	var v := VBoxContainer.new()
	card.add_child(v)

	var h := HBoxContainer.new()
	v.add_child(h)
	var thumb := TextureRect.new()
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(96, 96)
	thumb.texture = AssetLoader.texture(str(icon["image"]))
	h.add_child(thumb)
	var name_edit := _text(p + ["name"], "Όνομα")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name_edit)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	v.add_child(actions)
	var img_btn := UI.button("Εικόνα…", "", 140)
	img_btn.pressed.connect(func(): _pick_and_import(p + ["image"], "icon"))
	actions.add_child(img_btn)
	var up := UI.button("▲", "", 64)
	up.disabled = i == 0
	up.pressed.connect(func(): _move_icon(i, -1))
	actions.add_child(up)
	var down := UI.button("▼", "", 64)
	down.disabled = i == count - 1
	down.pressed.connect(func(): _move_icon(i, 1))
	actions.add_child(down)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var del := UI.button("Διαγραφή", "DangerButton", 140)
	del.disabled = count <= 1
	del.pressed.connect(func(): _confirm_delete_icon(i))
	actions.add_child(del)

	if is_oc:
		var is_target: bool = icon["id"] == draft["modes"][ConfigSchema.MODE_ONE_CORRECT]["target_id"]
		var t := UI.button("★ Στόχος" if is_target else "Ορισμός ως στόχος", "AccentButton" if is_target else "SegButton")
		t.disabled = is_target
		var icon_id: String = icon["id"]
		t.pressed.connect(func(): _set_value(["modes", ConfigSchema.MODE_ONE_CORRECT, "target_id"], icon_id, true))
		v.add_child(t)
	else:
		v.add_child(UI.label("Popup δώρου"))
		v.add_child(_file(p + ["popup"], "popup"))
		v.add_child(UI.label("Δικός του ήχος (προαιρετικό — αλλιώς ο ήχος νίκης)"))
		v.add_child(_file(p + ["sound"], "sound"))
		v.add_child(UI.row("«Ξαναπαίξε»", _toggle(p + ["replay"])))
	return card


func _move_icon(i: int, dir: int) -> void:
	var list: Array = draft["icons"]["list"]
	var j := i + dir
	if j < 0 or j >= list.size():
		return
	var tmp = list[i]
	list[i] = list[j]
	list[j] = tmp
	_changed(true)


func _confirm_delete_icon(i: int) -> void:
	var icon: Dictionary = draft["icons"]["list"][i]
	UI.modal(self, "Διαγραφή εικονιδίου", "Να διαγραφεί το «%s»;" % str(icon["name"]),
		[["Άκυρο", Callable(), ""], ["Διαγραφή", _delete_icon.bind(i), "DangerButton"]])


func _delete_icon(i: int) -> void:
	var list: Array = draft["icons"]["list"]
	if list.size() <= 1 or i < 0 or i >= list.size():
		return
	list.remove_at(i)
	draft = ConfigSchema.sanitize(draft)   # π.χ. νέος στόχος αν σβήστηκε ο στόχος
	_changed(true)


func _on_add_icon() -> void:
	_pick_and_import([], "icon", func(path: String):
		var list: Array = draft["icons"]["list"]
		var seen := {}
		for ic in list:
			seen[ic["id"]] = true
		var n := list.size() + 1
		while seen.has("icon_%d" % n):
			n += 1
		list.append({"id": "icon_%d" % n, "name": "Εικονίδιο %d" % (list.size() + 1), "image": path,
			"popup": "", "sound": "", "replay": false})
		_changed(true)
		_scroll_to_bottom.call_deferred())


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _speed_fmt(v: float) -> String:
	var ips := AdminPreview.icons_per_second(draft, v, get_viewport_rect().size)
	return "%.2f · %.1f εικ./δ" % [v, ips]


func _build_speed() -> void:
	var speed_help := "Η ταχύτητα μετριέται σε «πλάτη οθόνης ανά δευτερόλεπτο» (ίδια αίσθηση σε κάθε οθόνη). " \
		+ "Δίπλα φαίνεται και πόσα εικονίδια περνούν από τον κύκλο κάθε δευτερόλεπτο."
	if draft["mode"] == ConfigSchema.MODE_ONE_CORRECT:
		var oc := ["modes", ConfigSchema.MODE_ONE_CORRECT]
		var b := _add_card("Προσπάθειες", speed_help)
		b.add_child(UI.row("Αριθμός προσπαθειών", _segmented(oc + ["attempts"],
			[[1, "1"], [2, "2"], [3, "3"], [4, "4"], [5, "5"]], true)))
		var attempts := int(_v(oc + ["attempts"], 3))
		for i in attempts:
			var caption := "Ταχύτητα %s προσπάθειας" % ORDINALS[i]
			b.add_child(UI.row(caption, _slider(oc + ["speeds", i], ConfigSchema.MIN_SPEED, ConfigSchema.MAX_SPEED,
				0.05, _speed_fmt, func(x): _preview.show_speed(x, caption))))
		_preview.show_speed(float(_v(oc + ["speeds", 0], 0.5)), "Ταχύτητα 1η προσπάθειας")

		b = _add_card("Ανοχή στόχευσης",
			"Πόσο μακριά από το κέντρο του κύκλου μπορεί να είναι το κέντρο του εικονιδίου, ως ποσοστό της "
			+ "ακτίνας. Μικρότερη τιμή = πιο δύσκολο. Δοκίμασέ το αγγίζοντας την προεπισκόπηση.")
		b.add_child(UI.row("Ανοχή", _slider(oc + ["tolerance_pct"], 1, 100, 1, func(x): return "%d%% ακτίνας" % int(x))))
	else:
		var wh := ["modes", ConfigSchema.MODE_WHEEL]
		var b2 := _add_card("Ταχύτητα «Τροχού της τύχης»", speed_help)
		b2.add_child(UI.row("Κύρια προσπάθεια", _slider(wh + ["speed"], ConfigSchema.MIN_SPEED, ConfigSchema.MAX_SPEED,
			0.05, _speed_fmt, func(x): _preview.show_speed(x, "Κύρια προσπάθεια"))))
		b2.add_child(UI.row("Μετά από «Ξαναπαίξε»", _slider(wh + ["replay_speed"], ConfigSchema.MIN_SPEED,
			ConfigSchema.MAX_SPEED, 0.05, _speed_fmt, func(x): _preview.show_speed(x, "«Ξαναπαίξε»"))))
		_preview.show_speed(float(_v(wh + ["speed"], 0.5)), "Κύρια προσπάθεια")

	var st := _add_card("Τρόπος σταματήματος",
		"Η επιβράδυνση διανύει πάντα την ίδια απόσταση, οπότε ο παίκτης μπορεί να τη μάθει — "
		+ "το αποτέλεσμα εξαρτάται μόνο από τη στιγμή του πατήματος.")
	st.add_child(UI.row("Σταμάτημα", _segmented(["stop", "mode"], [["instant", "Άμεσο"], ["ease", "Με επιβράδυνση"]], true)))
	if _v(["stop", "mode"]) == "ease":
		st.add_child(UI.row("Διάρκεια επιβράδυνσης", _slider(["stop", "ease_duration"], 0.05, 1.5, 0.05, _sec)))


func _build_effects() -> void:
	var b := _add_card("Επίπεδο εφέ",
		"Μίνιμαλ: λιτά και κομψά. Κανονικό: confetti, glow και bounce. "
		+ "Arcade: έντονα — περισσότερο confetti, δυνατό glow, bounce και κούνημα οθόνης στη νίκη. "
		+ "Μετά την επιλογή επιπέδου μπορείς να αλλάξεις μεμονωμένα εφέ.")
	b.add_child(_segmented(["effects", "preset"],
		[["minimal", "Μίνιμαλ"], ["normal", "Κανονικό"], ["arcade", "Arcade"]], true,
		_apply_effect_preset))
	b = _add_card("Μεμονωμένα εφέ")
	var names := {"confetti": "Confetti στη νίκη", "glow": "Glow στον κύκλο", "bounce": "Bounce (κούμπωμα & popup)",
		"screen_shake": "Κούνημα οθόνης στη νίκη", "circle_pulse": "Παλμός κύκλου"}
	for key in ConfigSchema.EFFECT_KEYS:
		b.add_child(UI.row(names[key], _toggle(["effects", key])))


func _apply_effect_preset(preset) -> void:
	draft["effects"] = ConfigSchema.effect_preset(str(preset))
	_changed(true)


func _build_sounds() -> void:
	var b := _add_card("Γενικά")
	b.add_child(UI.row("Σίγαση όλων (mute)", _toggle(["audio", "master_mute"])))
	b.add_child(UI.help(MediaImport.HELP["sound"] + " Χωρίς αρχείο παίζει ο ενσωματωμένος ήχος."))
	for key in ConfigSchema.SOUND_KEYS:
		var p := ["audio", key]
		b = _add_card(SOUND_NAMES[key])
		b.add_child(UI.row("Ενεργός", _toggle(p + ["enabled"])))
		b.add_child(UI.row("Ένταση", _slider(p + ["volume"], 0, 1, 0.05, func(x): return _pct(x * 100.0))))
		b.add_child(_file(p + ["file"], "sound", key, p + ["volume"]))


func _build_flow() -> void:
	var b := _add_card("Οθόνη έλξης")
	b.add_child(UI.row("Κείμενο προτροπής", _text(["flow", "attract_text"], "Πάτα για να παίξεις")))
	b.add_child(UI.row("Εικονίδια στο φόντο", _toggle(["flow", "attract_icons"])))
	b = _add_card("Ροή παιχνιδιού")
	b.add_child(UI.row("Αντίστροφη μέτρηση 3-2-1", _toggle(["flow", "countdown"])))
	b.add_child(UI.row("Επιστροφή στην αρχή αν δεν πατηθεί τίποτα", _slider(["flow", "idle_timeout"], 0, 300, 5,
		func(x): return "ανενεργό" if x <= 0 else "%d δ" % int(x))))
	b.add_child(UI.row("Αυτόματο κλείσιμο popup", _slider(["flow", "popup_auto_close"], 0, 30, 0.5,
		func(x): return "μόνο με πάτημα" if x <= 0 else "%.1f δ" % x)))
	b.add_child(UI.row("Διάρκεια μηνύματος «Δεύτερη ευκαιρία»", _slider(["flow", "retry_banner_duration"], 0.5, 5, 0.1,
		func(x): return "%.1f δ" % x)))


func _build_system() -> void:
	var b := _add_card("PIN διαχειριστή",
		"4 έως 8 ψηφία. Το νέο PIN ισχύει μετά την αποθήκευση. "
		+ "Πρόσβαση στις ρυθμίσεις: πάτημα 3 δευτερολέπτων στην πάνω αριστερή γωνία της οθόνης έλξης, ή Ctrl+Shift+A.")
	var pin1 := LineEdit.new()
	pin1.secret = true
	pin1.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	pin1.placeholder_text = "Νέο PIN"
	pin1.custom_minimum_size = Vector2(0, UI.ROW_H)
	var pin2 := LineEdit.new()
	pin2.secret = true
	pin2.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	pin2.placeholder_text = "Επανάληψη νέου PIN"
	pin2.custom_minimum_size = Vector2(0, UI.ROW_H)
	b.add_child(UI.row("Νέο PIN", pin1))
	b.add_child(UI.row("Επανάληψη", pin2))
	var change := UI.button("Αλλαγή PIN")
	change.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	change.pressed.connect(func():
		var p := pin1.text.strip_edges()
		if not p.is_valid_int() or p.length() < 4 or p.length() > 8 or p.begins_with("-"):
			UI.toast(self, "Το PIN πρέπει να έχει 4 έως 8 ψηφία.", UI.DANGER)
		elif p != pin2.text.strip_edges():
			UI.toast(self, "Τα δύο PIN δεν ταιριάζουν.", UI.DANGER)
		else:
			_set_value(["admin", "pin"], p)
			pin1.text = ""
			pin2.text = ""
			UI.toast(self, "Το PIN θα αλλάξει με την αποθήκευση."))
	b.add_child(change)

	b = _add_card("Εφαρμογή")
	b.add_child(UI.help("Φάκελος δεδομένων: " + ProjectSettings.globalize_path("user://")))
	b.add_child(UI.help("Έκδοση εφαρμογής: %s · σχήμα ρυθμίσεων: %d" % [
		str(ProjectSettings.get_setting("application/config/version", "?")), ConfigSchema.SCHEMA_VERSION]))
	var quit := UI.button("Έξοδος από την εφαρμογή", "DangerButton")
	quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit.pressed.connect(func():
		UI.modal(self, "Έξοδος", "Να κλείσει η εφαρμογή; Μη αποθηκευμένες αλλαγές θα χαθούν.",
			[["Άκυρο", Callable(), ""], ["Έξοδος", func(): get_tree().quit(), "DangerButton"]]))
	b.add_child(quit)

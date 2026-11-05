## Ρυθμίσεις kiosk της συσκευής.
##
## Windows: πλήρης οθόνη χωρίς πλαίσιο, το παράθυρο δεν κλείνει με Alt+F4 / X
##          (έξοδος μόνο από τις ρυθμίσεις). Το Esc δεν κλείνει ποτέ την εφαρμογή.
## Android: immersive πλήρης οθόνη, οθόνη πάντα αναμμένη, το «Πίσω» δεν κλείνει
##          την εφαρμογή. Ο προσανατολισμός κλειδώνεται σε landscape από το project.
## Όταν η εφαρμογή τρέχει μέσα από τον editor του Godot, η πλήρης οθόνη και το
## μπλοκάρισμα κλεισίματος ΔΕΝ εφαρμόζονται (για άνετες δοκιμές).
extends RefCounted


static func in_editor() -> bool:
	return OS.has_feature("editor")


static func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"


static func apply(tree: SceneTree, kiosk: Dictionary) -> void:
	DisplayServer.screen_set_keep_on(bool(kiosk.get("keep_screen_on", true)))
	tree.quit_on_go_back = false
	tree.auto_accept_quit = in_editor() or not bool(kiosk.get("block_close", true))
	if in_editor():
		return
	var want_full := is_mobile() or bool(kiosk.get("fullscreen", true))
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not want_full and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Εναλλαγή πλήρους οθόνης (πλήκτρο F11 στις δοκιμές).
static func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

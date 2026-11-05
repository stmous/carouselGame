## Σκηνή για εκτέλεση των tests μέσα από τον editor:
## άνοιξε το tests/run_tests.tscn και πάτα F6 (Run Current Scene).
extends Control

const TestSuite = preload("res://tests/test_suite.gd")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var text := RichTextLabel.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 24
	text.offset_top = 24
	text.offset_right = -24
	text.offset_bottom = -24
	text.bbcode_enabled = true
	text.scroll_following = false
	text.add_theme_font_size_override("normal_font_size", 22)
	add_child(text)

	var lines: Array = []
	var r := TestSuite.run(lines)
	var ok: bool = r["failed"] == 0
	var head := "[b][color=%s]%s[/color][/b]\nTests: %d   αποτυχίες: %d   assertions: %d\n\n" % [
		"#6fe07a" if ok else "#ff6b6b",
		"ΟΛΑ ΤΑ TESTS ΠΕΡΑΣΑΝ" if ok else "ΥΠΑΡΧΟΥΝ ΑΠΟΤΥΧΙΕΣ",
		r["total"], r["failed"], r["asserts"]]
	var body := ""
	# Πρώτα οι αποτυχίες, για να φαίνονται αμέσως.
	for l in lines:
		if not l[1]:
			body += "[color=#ff6b6b]%s[/color]\n" % str(l[0]).replace("[", "[lb]")
			printerr(l[0])
	for l in lines:
		if l[1]:
			body += "[color=#9aa4b2]%s[/color]\n" % str(l[0]).replace("[", "[lb]")
	text.text = head + body
	print("Tests: %d, αποτυχίες: %d" % [r["total"], r["failed"]])

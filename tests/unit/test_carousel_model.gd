extends "res://tests/test_case.gd"

const IconSequencer = preload("res://scripts/core/icon_sequencer.gd")
const CarouselModel = preload("res://scripts/core/carousel_model.gd")


func _model(n: int = 6, span: float = 5.0, seed_value: int = 9) -> CarouselModel:
	return CarouselModel.new(IconSequencer.new(n, seed_value), span)


func test_initial_fill_covers_visible_area() -> void:
	var m := _model()
	var offs := m.offsets()
	assert_true(offs.size() > 0)
	assert_true(float(offs[0]) >= m.half_span, "δεξιά άκρη καλυμμένη")
	assert_true(float(offs[offs.size() - 1]) <= -m.half_span, "αριστερή άκρη καλυμμένη")


func test_moves_left_to_right() -> void:
	var m := _model()
	var before: float = m.offsets()[3]
	var icon: int = m.slots[3]
	m.start(2.0)
	m.update(0.1)
	# Το ίδιο εικονίδιο βρίσκεται τώρα 0.2 u πιο δεξιά.
	var found := false
	for it in m.items():
		if it["icon"] == icon and absf(float(it["u"]) - (before + 0.2)) < 1e-9:
			found = true
	assert_true(found)


func test_coverage_maintained_while_running() -> void:
	var m := _model(5, 4.0)
	m.start(7.3)
	for i in 2000:
		m.update(1.0 / 60.0)
		var offs := m.offsets()
		assert_true(float(offs[0]) >= m.half_span - 1e-9)
		assert_true(float(offs[offs.size() - 1]) <= -m.half_span + 1e-9)
		# Το scroll μένει μικρό (ανακύκλωση θυρίδων ⇒ καμία συσσώρευση).
		assert_true(m.scroll <= m.half_span + 1.0 + 1e-9)
	assert_true(m.slots.size() < 20, "οι θυρίδες δεν συσσωρεύονται")


func test_icons_pass_center_in_sequencer_order() -> void:
	# Η σειρά με την οποία περνούν από το κέντρο (u = 0) πρέπει να είναι ακριβώς
	# η σειρά του sequencer ⇒ ισχύει η εγγύηση «κάθε εικονίδιο μία φορά ανά κύκλο».
	var n := 5
	var reference := IconSequencer.new(n, 31)
	var expected: Array = []
	for i in 80:
		expected.append(reference.next())
	var m := CarouselModel.new(IconSequencer.new(n, 31), 4.0)
	# Η απόλυτη θυρίδα k περνά από το κέντρο όταν scroll + popped_total = k.
	var abs_scroll := m.scroll + float(m.popped_total)
	var next_k := int(floor(abs_scroll)) + 1
	var passed: Array = []
	m.start(3.0)
	for f in 1500:
		m.update(1.0 / 60.0)
		abs_scroll = m.scroll + float(m.popped_total)
		while float(next_k) <= abs_scroll:
			passed.append(m.slots[next_k - m.popped_total])
			next_k += 1
	assert_true(passed.size() > 40)
	var first := int(floor(4.0)) + 1   # πρώτη θυρίδα που ξεκίνησε αριστερά του κέντρου
	for i in mini(passed.size(), 60):
		assert_eq(passed[i], expected[first + i], "διέλευση %d" % i)


func test_ease_stop_distance_is_frame_rate_independent() -> void:
	var v0 := 4.0
	var T := 0.6
	var results: Array = []
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0, 0.05]:
		var m := _model(6, 5.0)
		m.start(v0)
		m.update(0.25)
		var total := 0.0
		assert_true(m.request_stop(T))
		var guard := 0
		var stopped_flag := false
		while not stopped_flag and guard < 10000:
			var s_before := m.scroll
			var p_before := m.popped_total
			stopped_flag = m.update(dt)
			total += m.scroll - s_before + float(m.popped_total - p_before)
			guard += 1
		assert_true(stopped_flag)
		results.append(total)
		assert_near(total, CarouselModel.ease_distance(v0, T), 1e-9, "dt=%f" % dt)
		assert_eq(m.state, CarouselModel.State.STOPPED)
	assert_near(results[0], results[2], 1e-9)


func test_ease_stop_with_irregular_frames() -> void:
	var m := _model()
	m.start(3.0)
	m.request_stop(0.5)
	var total := 0.0
	var dts := [0.003, 0.041, 0.017, 0.1, 0.009, 0.2, 0.3]
	for dt in dts:
		var s_before := m.scroll
		var p_before := m.popped_total
		m.update(dt)
		total += m.scroll - s_before + float(m.popped_total - p_before)
	assert_near(total, 0.75, 1e-9)


func test_instant_stop_freezes_immediately() -> void:
	var m := _model()
	m.start(3.0)
	m.update(0.1)
	assert_true(m.request_stop(0.0))
	var s := m.scroll
	m.update(0.5)
	assert_eq(m.scroll, s)
	assert_false(m.is_moving())


func test_double_stop_is_ignored() -> void:
	var m := _model()
	m.start(3.0)
	assert_true(m.request_stop(0.4))
	assert_false(m.request_stop(0.4), "δεύτερο πάτημα κατά την επιβράδυνση")
	m.update(1.0)
	assert_false(m.request_stop(0.4), "πάτημα αφού σταμάτησε")


func test_stop_before_start_is_ignored() -> void:
	var m := _model()
	assert_false(m.request_stop(0.3))


func test_snap_brings_slot_to_center() -> void:
	var m := _model()
	m.start(2.7)
	m.update(0.37)
	m.request_stop(0.0)
	var offs := m.offsets()
	var best := 0
	for i in offs.size():
		if absf(float(offs[i])) < absf(float(offs[best])):
			best = i
	var icon: int = m.slots[best]
	m.advance(-float(offs[best]))
	# Το ίδιο εικονίδιο βρίσκεται τώρα ακριβώς στο κέντρο.
	var centered := false
	for it in m.items():
		if absf(float(it["u"])) < 1e-9 and it["icon"] == icon:
			centered = true
	assert_true(centered)


func test_resize_keeps_strip_filled() -> void:
	var m := _model(4, 3.0)
	m.set_half_span(9.0)
	var offs := m.offsets()
	assert_true(float(offs[offs.size() - 1]) <= -9.0)

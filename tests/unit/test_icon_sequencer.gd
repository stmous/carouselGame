extends "res://tests/test_case.gd"

const IconSequencer = preload("res://scripts/core/icon_sequencer.gd")


func test_empty_list_returns_minus_one() -> void:
	var s := IconSequencer.new(0, 1)
	assert_eq(s.next(), -1)


func test_single_icon_always_zero() -> void:
	var s := IconSequencer.new(1, 1)
	for i in 20:
		assert_eq(s.next(), 0)


func test_every_cycle_is_a_permutation() -> void:
	# Κάθε εικονίδιο (άρα και ο στόχος) περνά ακριβώς μία φορά ανά κύκλο.
	for n in range(1, 13):
		for seed_value in [1, 7, 42, 999]:
			var s := IconSequencer.new(n, seed_value)
			for cycle in 50:
				var seen := {}
				for i in n:
					var v := s.next()
					assert_true(v >= 0 and v < n, "εκτός ορίων: %d" % v)
					assert_false(seen.has(v), "διπλό μέσα στον κύκλο (n=%d)" % n)
					seen[v] = true
				assert_eq(seen.size(), n)


func test_no_same_icon_twice_in_a_row() -> void:
	for n in range(2, 10):
		for seed_value in [3, 11, 2024]:
			var s := IconSequencer.new(n, seed_value)
			var prev := s.next()
			for i in 5000:
				var v := s.next()
				if v == prev:
					_fail("ίδιο εικονίδιο δύο φορές στη σειρά (n=%d, θέση %d)" % [n, i])
					return
				prev = v
			assert_true(true)


func test_two_icons_alternate() -> void:
	var s := IconSequencer.new(2, 5)
	var prev := s.next()
	for i in 200:
		var v := s.next()
		assert_eq(v, 1 - prev)
		prev = v


func test_target_gap_is_bounded() -> void:
	# Ο στόχος εμφανίζεται το πολύ κάθε 2n-1 εικονίδια ⇒ πάντα πραγματική ευκαιρία.
	var n := 8
	var target := 3
	var s := IconSequencer.new(n, 77)
	var since := 0
	var max_gap := 0
	for i in 20000:
		since += 1
		if s.next() == target:
			max_gap = maxi(max_gap, since)
			since = 0
	assert_true(max_gap <= 2 * n - 1, "μέγιστο κενό %d" % max_gap)


func test_order_is_random() -> void:
	# Οι κύκλοι δεν είναι όλοι ίδιοι, και κάθε εικονίδιο εμφανίζεται πρώτο κάποια στιγμή.
	var n := 6
	var s := IconSequencer.new(n, 123)
	var cycles := {}
	var firsts := {}
	for c in 300:
		var cyc: Array = []
		for i in n:
			cyc.append(s.next())
		cycles[str(cyc)] = true
		firsts[cyc[0]] = true
	assert_true(cycles.size() > 50, "πολύ λίγες διαφορετικές σειρές: %d" % cycles.size())
	assert_eq(firsts.size(), n)


func test_same_seed_is_deterministic() -> void:
	var a := IconSequencer.new(7, 555)
	var b := IconSequencer.new(7, 555)
	for i in 100:
		assert_eq(a.next(), b.next())


func test_reset_changes_count() -> void:
	var s := IconSequencer.new(3, 1)
	s.next()
	s.reset(5)
	var seen := {}
	for i in 5:
		seen[s.next()] = true
	assert_eq(seen.size(), 5)

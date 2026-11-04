extends "res://tests/test_case.gd"

const ResultDetector = preload("res://scripts/core/result_detector.gd")


func test_picks_closest_icon() -> void:
	var r := ResultDetector.evaluate([300.0, 40.0, -220.0], 100.0, 50.0, true)
	assert_eq(r["index"], 1)
	assert_eq(r["closest"], 1)
	assert_true(r["within"])
	assert_near(r["offset"], 40.0)


func test_negative_offsets_use_absolute_distance() -> void:
	var r := ResultDetector.evaluate([120.0, -15.0, -260.0], 100.0, 50.0, true)
	assert_eq(r["index"], 1)
	assert_near(r["offset"], -15.0)


func test_tolerance_boundary_is_inclusive() -> void:
	# ανοχή = 40% της ακτίνας 100 = 40 px
	assert_eq(ResultDetector.evaluate([40.0], 100.0, 40.0, true)["index"], 0)
	assert_eq(ResultDetector.evaluate([-40.0], 100.0, 40.0, true)["index"], 0)
	assert_eq(ResultDetector.evaluate([40.01], 100.0, 40.0, true)["index"], -1)


func test_miss_when_outside_tolerance_in_one_correct() -> void:
	var r := ResultDetector.evaluate([130.0, -129.0], 100.0, 30.0, true)
	assert_eq(r["index"], -1, "αστόχηση")
	assert_eq(r["closest"], 1, "το πιο κοντινό εξακολουθεί να αναφέρεται")
	assert_false(r["within"])


func test_wheel_always_returns_closest() -> void:
	# Στον «Τροχό» δεν υπάρχει αστόχηση.
	var r := ResultDetector.evaluate([130.0, -129.0], 100.0, 1.0, false)
	assert_eq(r["index"], 1)
	assert_false(r["within"])


func test_empty_list() -> void:
	var r := ResultDetector.evaluate([], 100.0, 50.0, false)
	assert_eq(r["index"], -1)
	assert_eq(r["closest"], -1)


func test_tie_keeps_first() -> void:
	var r := ResultDetector.evaluate([-50.0, 50.0], 100.0, 60.0, true)
	assert_eq(r["index"], 0)


func test_exact_center() -> void:
	var r := ResultDetector.evaluate([259.0, 0.0, -259.0], 130.0, 1.0, true)
	assert_eq(r["index"], 1)
	assert_true(r["within"])


func test_tolerance_is_clamped() -> void:
	# >100% λογίζεται ως 100%, <0% ως 0%.
	assert_eq(ResultDetector.evaluate([100.0], 100.0, 500.0, true)["index"], 0)
	assert_eq(ResultDetector.evaluate([100.5], 100.0, 500.0, true)["index"], -1)
	assert_eq(ResultDetector.evaluate([0.5], 100.0, -10.0, true)["index"], -1)

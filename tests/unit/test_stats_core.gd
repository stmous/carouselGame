extends "res://tests/test_case.gd"

const StatsCore = preload("res://scripts/core/stats_core.gd")


func _records() -> Array:
	return [
		{"time": "2026-11-04T10:00:00", "mode": "one_correct", "results": ["star"], "won": true, "win_attempt": 1,
			"abandoned": false, "names": {"star": "Αστέρι"}},
		{"time": "2026-11-04T10:05:00", "mode": "one_correct", "results": ["", "heart", "star"], "won": true,
			"win_attempt": 3, "abandoned": false, "names": {"heart": "Καρδιά", "star": "Αστέρι"}},
		{"time": "2026-11-05T09:00:00", "mode": "one_correct", "results": ["moon", "moon", "moon"], "won": false,
			"win_attempt": 0, "abandoned": false, "names": {"moon": "Φεγγάρι"}},
		{"time": "2026-11-05T09:10:00", "mode": "wheel", "results": ["bolt", "sun"], "won": false, "win_attempt": 0,
			"abandoned": false, "names": {"bolt": "Κεραυνός", "sun": "Ήλιος"}},
		{"time": "2026-11-05T09:20:00", "mode": "wheel", "results": ["sun"], "won": false, "win_attempt": 0,
			"abandoned": false, "names": {"sun": "Ήλιος"}},
		{"time": "2026-11-05T09:30:00", "mode": "one_correct", "results": ["heart"], "won": false, "win_attempt": 0,
			"abandoned": true, "names": {"heart": "Καρδιά"}},
	]


func test_days_newest_first() -> void:
	assert_eq(StatsCore.days(_records()), ["2026-11-05", "2026-11-04"])
	assert_eq(StatsCore.count_on_day(_records(), "2026-11-05"), 4)


func test_filter_by_day_and_mode() -> void:
	var r := _records()
	assert_eq(StatsCore.filter(r).size(), 6)
	assert_eq(StatsCore.filter(r, "2026-11-04").size(), 2)
	assert_eq(StatsCore.filter(r, "", "wheel").size(), 2)
	assert_eq(StatsCore.filter(r, "2026-11-05", "one_correct").size(), 2)


func test_summary_totals() -> void:
	var s := StatsCore.summarize(_records())
	assert_eq(s["games"], 6)
	assert_eq(s["by_mode"]["one_correct"], 4)
	assert_eq(s["by_mode"]["wheel"], 2)
	assert_eq(s["oc_games"], 4)
	assert_eq(s["wins"], 2)
	assert_near(s["win_rate"], 0.5)
	assert_eq(s["wins_per_attempt"], [1, 0, 1, 0, 0])
	assert_eq(s["misses"], 1)
	assert_eq(s["abandoned"], 1)
	assert_eq(s["icon_counts"]["star"], 2)
	assert_eq(s["icon_counts"]["moon"], 3)
	assert_eq(s["icon_counts"]["sun"], 2)
	assert_eq(s["icon_counts"]["heart"], 2)
	assert_eq(s["wheel_prizes"], {"sun": 2})
	assert_eq(s["icon_names"]["sun"], "Ήλιος")


func test_empty_summary() -> void:
	var s := StatsCore.summarize([])
	assert_eq(s["games"], 0)
	assert_near(s["win_rate"], 0.0)


func test_csv_format() -> void:
	var csv := StatsCore.to_csv(_records())
	assert_true(csv.begins_with(StatsCore.BOM), "UTF-8 BOM για το Excel")
	var bytes := csv.to_utf8_buffer()
	assert_eq([bytes[0], bytes[1], bytes[2]], [0xEF, 0xBB, 0xBF])
	var lines := csv.trim_prefix(StatsCore.BOM).split("\r\n", false)
	assert_eq(lines.size(), 7, "επικεφαλίδα + 6 παιχνίδια")
	assert_eq(lines[0], "Ημερομηνία;Ώρα;Λειτουργία;Αποτέλεσμα;Νίκη στην προσπάθεια;Διακόπηκε;Προσπάθεια 1;Προσπάθεια 2;Προσπάθεια 3")
	assert_eq(lines[2], "2026-11-04;10:05:00;Ένα σωστό;Νίκη;3;Όχι;Αστόχηση;Καρδιά;Αστέρι")
	assert_eq(lines[4], "2026-11-05;09:10:00;Τροχός της τύχης;Ήλιος;;Όχι;Κεραυνός;Ήλιος;")
	assert_eq(lines[6], "2026-11-05;09:30:00;Ένα σωστό;Ήττα;;Ναι;Καρδιά;;")


func test_csv_escapes_separators() -> void:
	var r := [{"time": "2026-01-01T00:00:00", "mode": "wheel", "results": ["x"], "names": {"x": "Δώρο; \"μεγάλο\""}}]
	var lines := StatsCore.to_csv(r).trim_prefix(StatsCore.BOM).split("\r\n", false)
	assert_true(lines[1].ends_with(";\"Δώρο; \"\"μεγάλο\"\"\""), lines[1])

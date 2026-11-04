## Ολοκληρωμένο σενάριο χωρίς γραφικά: μοντέλο κίνησης + ανίχνευση + ροή.
## Αποδεικνύει ότι το αποτέλεσμα εξαρτάται ΜΟΝΟ από τη στιγμή του πατήματος.
extends "res://tests/test_case.gd"

const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const IconSequencer = preload("res://scripts/core/icon_sequencer.gd")
const CarouselModel = preload("res://scripts/core/carousel_model.gd")
const ResultDetector = preload("res://scripts/core/result_detector.gd")
const GameFlow = preload("res://scripts/core/game_flow.gd")

const PITCH_PX := 259.0
const RADIUS_PX := 140.0
const DT := 1.0 / 60.0


## Τρέχει την κίνηση και πατά «σταμάτημα» όταν το εικονίδιο-στόχος θα
## καταλήξει (μετά την επιβράδυνση) σε απόσταση `aim_offset_u` από το κέντρο.
## Επιστρέφει το id που ανιχνεύθηκε ("" = αστόχηση).
func _play(cfg: Dictionary, flow: GameFlow, aim_offset_u: float, seed_value: int) -> String:
	var icons: Array = cfg["icons"]["list"]
	var target_idx := -1
	for i in icons.size():
		if icons[i]["id"] == flow.target_id():
			target_idx = i
	var m := CarouselModel.new(IconSequencer.new(icons.size(), seed_value), 5.0)
	var v := flow.current_speed() * 4.0      # u/s (αυθαίρετη μετατροπή για το test)
	var ease_t: float = cfg["stop"]["ease_duration"]
	var travel := CarouselModel.ease_distance(v, ease_t)
	m.start(v)
	for f in 5000:
		m.update(DT)
		var offs := m.offsets()
		var pressed := false
		for j in offs.size():
			if m.slots[j] != target_idx:
				continue
			var final_u := float(offs[j]) + travel
			if final_u >= aim_offset_u and final_u < aim_offset_u + v * DT:
				pressed = true
		if pressed:
			break
	m.request_stop(ease_t)
	while m.is_moving():
		m.update(DT)
	var px: Array = []
	for u in m.offsets():
		px.append(float(u) * PITCH_PX)
	var r := ResultDetector.evaluate(px, RADIUS_PX, flow.tolerance_pct(), flow.allows_miss())
	if r["index"] < 0:
		return ""
	return str(icons[m.slots[r["index"]]]["id"])


func _cfg() -> Dictionary:
	var c := ConfigSchema.defaults()
	c["mode"] = ConfigSchema.MODE_ONE_CORRECT
	c["modes"]["one_correct"]["tolerance_pct"] = 40.0
	c["modes"]["one_correct"]["attempts"] = 3
	c["stop"]["mode"] = "ease"
	c["stop"]["ease_duration"] = 0.35
	return ConfigSchema.sanitize(c)


func test_perfect_timing_wins() -> void:
	for seed_value in [1, 2, 3, 4, 5]:
		var c := _cfg()
		var flow := GameFlow.new(c)
		var got := _play(c, flow, 0.0, seed_value)
		assert_eq(got, "star")
		assert_eq(flow.submit(got), GameFlow.Outcome.WIN)


func test_slightly_off_still_wins_within_tolerance() -> void:
	# 40% της ακτίνας 140 = 56 px = 0.216 u. Στοχεύουμε 0.15 u.
	var c := _cfg()
	var flow := GameFlow.new(c)
	assert_eq(_play(c, flow, 0.15, 8), "star")


func test_bad_timing_is_a_miss_then_retry_then_win() -> void:
	var c := _cfg()
	var flow := GameFlow.new(c)
	# Μισό βήμα εκτός: ανάμεσα σε δύο εικονίδια ⇒ αστόχηση.
	var got := _play(c, flow, 0.5, 11)
	assert_eq(got, "")
	assert_eq(flow.submit(got), GameFlow.Outcome.RETRY)
	assert_eq(flow.retry_message(), "Δεύτερη ευκαιρία!")
	got = _play(c, flow, 0.0, 12)
	assert_eq(flow.submit(got), GameFlow.Outcome.WIN)
	assert_eq(flow.win_attempt, 2)


func test_wheel_never_misses() -> void:
	var c := _cfg()
	c["mode"] = ConfigSchema.MODE_WHEEL
	var flow := GameFlow.new(c)
	# Ακόμα και ανάμεσα σε δύο εικονίδια, ο «Τροχός» δίνει πάντα αποτέλεσμα.
	var got := _play(c, flow, 0.45, 21)
	assert_true(got != "")

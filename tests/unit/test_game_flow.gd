extends "res://tests/test_case.gd"

const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const GameFlow = preload("res://scripts/core/game_flow.gd")

var cfg: Dictionary


func before_each() -> void:
	cfg = ConfigSchema.defaults()
	cfg["modes"]["one_correct"]["target_id"] = "star"
	cfg["modes"]["one_correct"]["attempts"] = 3
	cfg["modes"]["one_correct"]["speeds"] = [1.5, 1.0, 0.5, 0.4, 0.3]
	cfg["modes"]["wheel"]["speed"] = 0.9
	cfg["modes"]["wheel"]["replay_speed"] = 0.4
	cfg = ConfigSchema.sanitize(cfg)


func _one_correct() -> GameFlow:
	cfg["mode"] = ConfigSchema.MODE_ONE_CORRECT
	return GameFlow.new(cfg)


func _wheel() -> GameFlow:
	cfg["mode"] = ConfigSchema.MODE_WHEEL
	return GameFlow.new(cfg)


# ------------------------------------------------------------ Ένα σωστό ---

func test_win_on_first_attempt() -> void:
	var f := _one_correct()
	assert_near(f.current_speed(), 1.5)
	assert_eq(f.retry_message(), "")
	assert_eq(f.submit("star"), GameFlow.Outcome.WIN)
	assert_true(f.finished)
	assert_true(f.won)
	assert_eq(f.win_attempt, 1)


func test_wrong_icon_then_win_on_second() -> void:
	var f := _one_correct()
	assert_eq(f.submit("heart"), GameFlow.Outcome.RETRY)
	assert_false(f.finished)
	assert_eq(f.attempt, 1)
	assert_near(f.current_speed(), 1.0, 1e-9, "2η προσπάθεια με δική της ταχύτητα")
	assert_eq(f.retry_message(), "Δεύτερη ευκαιρία!")
	assert_eq(f.submit("star"), GameFlow.Outcome.WIN)
	assert_eq(f.win_attempt, 2)
	assert_eq(f.record()["results"], ["heart", "star"])


func test_miss_counts_as_failure() -> void:
	var f := _one_correct()
	assert_eq(f.submit(""), GameFlow.Outcome.RETRY, "αστόχηση = αποτυχία")
	assert_eq(f.submit(""), GameFlow.Outcome.RETRY)
	assert_eq(f.retry_message(), "Τρίτη ευκαιρία!")
	assert_near(f.current_speed(), 0.5)
	assert_eq(f.submit(""), GameFlow.Outcome.LOSE)
	assert_true(f.finished)
	assert_false(f.won)
	assert_eq(f.win_attempt, 0)


func test_lose_after_all_attempts() -> void:
	cfg["modes"]["one_correct"]["attempts"] = 5
	var f := _one_correct()
	var speeds: Array = []
	for i in 4:
		speeds.append(f.current_speed())
		assert_eq(f.submit("moon"), GameFlow.Outcome.RETRY)
	speeds.append(f.current_speed())
	assert_eq(f.retry_message(), "Πέμπτη ευκαιρία!")
	assert_eq(f.submit("moon"), GameFlow.Outcome.LOSE)
	assert_eq(speeds, [1.5, 1.0, 0.5, 0.4, 0.3])
	assert_eq(f.record()["results"].size(), 5)


func test_single_attempt_loses_immediately() -> void:
	cfg["modes"]["one_correct"]["attempts"] = 1
	var f := _one_correct()
	assert_eq(f.submit("heart"), GameFlow.Outcome.LOSE)


func test_submit_after_finish_is_ignored() -> void:
	var f := _one_correct()
	f.submit("star")
	assert_eq(f.submit("star"), GameFlow.Outcome.NONE)
	assert_eq(f.record()["results"].size(), 1)


func test_custom_retry_messages() -> void:
	cfg["modes"]["one_correct"]["retry_messages"] = ["Ξανά!", "Πάλι!"]
	cfg = ConfigSchema.sanitize(cfg)
	var f := _one_correct()
	f.submit("")
	assert_eq(f.retry_message(), "Ξανά!")
	f.submit("")
	assert_eq(f.retry_message(), "Πάλι!")


func test_one_correct_allows_miss_with_tolerance() -> void:
	cfg["modes"]["one_correct"]["tolerance_pct"] = 35.0
	var f := _one_correct()
	assert_true(f.allows_miss())
	assert_near(f.tolerance_pct(), 35.0)


# ------------------------------------------------------ Τροχός της τύχης ---

func test_wheel_every_result_is_valid() -> void:
	var f := _wheel()
	assert_false(f.allows_miss())
	assert_near(f.current_speed(), 0.9)
	assert_eq(f.submit("heart"), GameFlow.Outcome.WHEEL)
	assert_true(f.finished)
	assert_eq(f.record()["mode"], "wheel")


func test_wheel_replay_uses_replay_speed() -> void:
	var f := _wheel()
	# Στο demo θέμα το «bolt» έχει σήμανση «Ξαναπαίξε».
	assert_eq(f.submit("bolt"), GameFlow.Outcome.WHEEL_REPLAY)
	assert_false(f.finished)
	assert_near(f.current_speed(), 0.4)
	assert_eq(f.retry_message(), "")
	assert_eq(f.submit("sun"), GameFlow.Outcome.WHEEL)
	assert_true(f.finished)
	assert_eq(f.record()["results"], ["bolt", "sun"])


func test_wheel_replay_can_chain() -> void:
	var f := _wheel()
	assert_eq(f.submit("bolt"), GameFlow.Outcome.WHEEL_REPLAY)
	assert_eq(f.submit("bolt"), GameFlow.Outcome.WHEEL_REPLAY)
	assert_eq(f.submit("star"), GameFlow.Outcome.WHEEL)


func test_wheel_unknown_icon_finishes() -> void:
	var f := _wheel()
	assert_eq(f.submit("does_not_exist"), GameFlow.Outcome.WHEEL)


func test_record_marks_test_games() -> void:
	cfg["mode"] = ConfigSchema.MODE_ONE_CORRECT
	var f := GameFlow.new(cfg, true, "2026-01-01T10:00:00")
	f.submit("star")
	var r := f.record()
	assert_true(r["test"])
	assert_eq(r["time"], "2026-01-01T10:00:00")
	assert_true(r["won"])

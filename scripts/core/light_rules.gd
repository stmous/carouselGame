## Πότε ανάβει το εξωτερικό φως (pure λογική, με tests).
##   «Ένα σωστό»:       σε κάθε νίκη.
##   «Τροχός της τύχης»: μόνο για εικονίδια με «Ανάβει το φως».
##   Ποτέ όταν η λειτουργία είναι απενεργοποιημένη.
extends RefCounted

const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const GameFlow = preload("res://scripts/core/game_flow.gd")


static func should_light(cfg: Dictionary, outcome: int, icon_id: String) -> bool:
	var light: Dictionary = cfg.get("light", {})
	if not bool(light.get("enabled", false)):
		return false
	if outcome == GameFlow.Outcome.WIN:
		return true
	if outcome == GameFlow.Outcome.WHEEL or outcome == GameFlow.Outcome.WHEEL_REPLAY:
		var icon := ConfigSchema.find_icon(cfg, icon_id)
		return not icon.is_empty() and bool(icon.get("light", false))
	return false

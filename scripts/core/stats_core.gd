## Στατιστικά: φιλτράρισμα, σύνολα και εξαγωγή CSV (pure λογική, με tests).
##
## Μορφή εγγραφής (μία ανά παιχνίδι):
##   {"time": "2026-11-05T14:03:22", "mode": "one_correct" | "wheel",
##    "results": ["star", "", ...]   # id ανά προσπάθεια, "" = αστόχηση
##    "won": bool, "win_attempt": int (1-based, 0 = καμία νίκη),
##    "abandoned": bool,             # διακόπηκε (idle, παύση εφαρμογής κ.λπ.)
##    "names": {"star": "Αστέρι", ...}}   # ονόματα τη στιγμή του παιχνιδιού
extends RefCounted

const ConfigSchema = preload("res://scripts/core/config_schema.gd")

const MODE_NAMES := {
	"one_correct": "Ένα σωστό",
	"wheel": "Τροχός της τύχης",
}
const MISS_TEXT := "Αστόχηση"
const SEP := ";"          # Το ελληνικό Excel χρησιμοποιεί «;» ως διαχωριστικό λίστας.
const BOM := "﻿"     # UTF-8 BOM ⇒ το Excel διαβάζει σωστά τα ελληνικά.


static func day_of(record: Dictionary) -> String:
	return str(record.get("time", "")).substr(0, 10)


## Όλες οι ημέρες με παιχνίδια, νεότερη πρώτη.
static func days(records: Array) -> Array:
	var seen := {}
	for r in records:
		var d := day_of(r)
		if d != "":
			seen[d] = seen.get(d, 0) + 1
	var out: Array = seen.keys()
	out.sort()
	out.reverse()
	return out


static func count_on_day(records: Array, day: String) -> int:
	var n := 0
	for r in records:
		if day_of(r) == day:
			n += 1
	return n


## Φίλτρο ανά ημέρα ("" = όλες) και λειτουργία ("" = όλες).
static func filter(records: Array, day: String = "", mode: String = "") -> Array:
	var out: Array = []
	for r in records:
		if day != "" and day_of(r) != day:
			continue
		if mode != "" and str(r.get("mode", "")) != mode:
			continue
		out.append(r)
	return out


## Σύνολα για την οθόνη στατιστικών.
static func summarize(records: Array) -> Dictionary:
	var s := {
		"games": records.size(),
		"by_mode": {"one_correct": 0, "wheel": 0},
		"icon_counts": {},       # id → πόσες φορές βγήκε (σε όλες τις προσπάθειες)
		"icon_names": {},        # id → τελευταίο γνωστό όνομα
		"misses": 0,
		"abandoned": 0,
		"oc_games": 0,
		"wins": 0,
		"win_rate": 0.0,         # 0..1, μόνο «Ένα σωστό»
		"wins_per_attempt": [0, 0, 0, 0, 0],
		"wheel_prizes": {},      # id → πόσες φορές ήταν το τελικό αποτέλεσμα στον «Τροχό»
	}
	for r in records:
		var mode := str(r.get("mode", ""))
		if s["by_mode"].has(mode):
			s["by_mode"][mode] += 1
		if bool(r.get("abandoned", false)):
			s["abandoned"] += 1
		var names: Dictionary = r.get("names", {})
		for id in names:
			s["icon_names"][id] = names[id]
		var results: Array = r.get("results", [])
		for id in results:
			if str(id) == "":
				s["misses"] += 1
			else:
				s["icon_counts"][id] = s["icon_counts"].get(id, 0) + 1
		if mode == ConfigSchema.MODE_ONE_CORRECT:
			s["oc_games"] += 1
			if bool(r.get("won", false)):
				s["wins"] += 1
				var a := int(r.get("win_attempt", 0))
				if a >= 1 and a <= 5:
					s["wins_per_attempt"][a - 1] += 1
		elif mode == ConfigSchema.MODE_WHEEL and not results.is_empty() and not bool(r.get("abandoned", false)):
			var last := str(results[results.size() - 1])
			if last != "":
				s["wheel_prizes"][last] = s["wheel_prizes"].get(last, 0) + 1
	if s["oc_games"] > 0:
		s["win_rate"] = float(s["wins"]) / float(s["oc_games"])
	return s


static func _name(record: Dictionary, id: String) -> String:
	if id == "":
		return MISS_TEXT
	var names: Dictionary = record.get("names", {})
	return str(names.get(id, id))


static func _cell(v: String) -> String:
	if v.contains(SEP) or v.contains("\"") or v.contains("\n") or v.contains("\r") or v.contains(","):
		return "\"" + v.replace("\"", "\"\"") + "\""
	return v


static func _join_row(cells: Array) -> String:
	var parts := PackedStringArray()
	for c in cells:
		parts.append(_cell(str(c)))
	return SEP.join(parts)


## CSV (UTF-8 με BOM, «;», CRLF) για άνοιγμα στο Excel.
static func to_csv(records: Array) -> String:
	var max_attempts := 1
	for r in records:
		max_attempts = maxi(max_attempts, (r.get("results", []) as Array).size())
	var header: Array = ["Ημερομηνία", "Ώρα", "Λειτουργία", "Αποτέλεσμα", "Νίκη στην προσπάθεια", "Διακόπηκε"]
	for i in max_attempts:
		header.append("Προσπάθεια %d" % (i + 1))
	var lines: Array = [_join_row(header)]
	for r in records:
		var t := str(r.get("time", ""))
		var mode := str(r.get("mode", ""))
		var results: Array = r.get("results", [])
		var outcome := ""
		if mode == ConfigSchema.MODE_ONE_CORRECT:
			outcome = "Νίκη" if bool(r.get("won", false)) else "Ήττα"
		elif not results.is_empty():
			outcome = _name(r, str(results[results.size() - 1]))
		var win_at := int(r.get("win_attempt", 0))
		var row: Array = [
			t.substr(0, 10),
			t.substr(11, 8),
			str(MODE_NAMES.get(mode, mode)),
			outcome,
			str(win_at) if win_at > 0 else "",
			"Ναι" if bool(r.get("abandoned", false)) else "Όχι",
		]
		for i in max_attempts:
			if i < results.size():
				row.append(_name(r, str(results[i])))
			else:
				row.append("")
		lines.append(_join_row(row))
	return BOM + "\r\n".join(PackedStringArray(lines)) + "\r\n"

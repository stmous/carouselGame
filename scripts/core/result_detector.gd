## Ανίχνευση αποτελέσματος μετά το σταμάτημα.
##
## Κανόνας: κερδίζει το εικονίδιο του οποίου το κέντρο είναι πιο κοντά στο
## κέντρο του κύκλου. Στη λειτουργία «Ένα σωστό» πρέπει επιπλέον η απόσταση
## να είναι μέσα στην ανοχή (% της ακτίνας)· αλλιώς είναι αστόχηση.
## Στον «Τροχό της τύχης» (`allow_miss = false`) επιστρέφεται πάντα το πιο
## κοντινό.
##
## Καμία τυχαιότητα, καμία χειραγώγηση: καθαρά γεωμετρία.
extends RefCounted


## `offsets_px`: απόσταση (με πρόσημο) του κέντρου κάθε εικονιδίου από το
##               κέντρο του κύκλου, σε pixels.
## Επιστρέφει: {"index": int (-1 = αστόχηση), "closest": int, "offset": float,
##             "within": bool}
static func evaluate(offsets_px: Array, radius_px: float, tolerance_pct: float, allow_miss: bool) -> Dictionary:
	var best := -1
	var best_abs := INF
	for i in offsets_px.size():
		var d := absf(float(offsets_px[i]))
		# Σε ισοπαλία κρατάμε το πρώτο (σταθερό, προβλέψιμο αποτέλεσμα).
		if d < best_abs:
			best_abs = d
			best = i
	if best == -1:
		return {"index": -1, "closest": -1, "offset": 0.0, "within": false}
	var tolerance_px := maxf(radius_px, 0.0) * clampf(tolerance_pct, 0.0, 100.0) / 100.0
	var within := best_abs <= tolerance_px
	var index := best
	if allow_miss and not within:
		index = -1
	return {"index": index, "closest": best, "offset": float(offsets_px[best]), "within": within}

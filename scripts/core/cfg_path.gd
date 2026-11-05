## Ανάγνωση/εγγραφή τιμών σε εμφωλευμένα Dictionary/Array με «διαδρομή»,
## π.χ. ["theme", "circle", "color"] ή ["icons", "list", 2, "name"].
## Τη χρησιμοποιεί η οθόνη ρυθμίσεων για να «δένει» κάθε πεδίο σε μια ρύθμιση.
extends RefCounted


static func get_at(data, path: Array, default_value = null):
	var cur = data
	for key in path:
		if cur is Dictionary:
			if not cur.has(key):
				return default_value
			cur = cur[key]
		elif cur is Array:
			var i := int(key)
			if i < 0 or i >= cur.size():
				return default_value
			cur = cur[i]
		else:
			return default_value
	return cur


## Ορίζει την τιμή. Δημιουργεί ενδιάμεσα Dictionary αν λείπουν.
## Επιστρέφει false αν η διαδρομή δεν είναι έγκυρη (π.χ. δείκτης εκτός ορίων).
static func set_at(data, path: Array, value) -> bool:
	if path.is_empty():
		return false
	var cur = data
	for n in path.size() - 1:
		var key = path[n]
		if cur is Dictionary:
			if not cur.has(key) or not (cur[key] is Dictionary or cur[key] is Array):
				cur[key] = {}
			cur = cur[key]
		elif cur is Array:
			var i := int(key)
			if i < 0 or i >= cur.size():
				return false
			cur = cur[i]
		else:
			return false
	var last = path[path.size() - 1]
	if cur is Dictionary:
		cur[last] = value
		return true
	if cur is Array:
		var j := int(last)
		if j < 0 or j >= cur.size():
			return false
		cur[j] = value
		return true
	return false

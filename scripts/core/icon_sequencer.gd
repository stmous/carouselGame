## Παράγει τη σειρά με την οποία περνούν τα εικονίδια από τον κύκλο.
##
## Αλγόριθμος «shuffle bag»: κάθε κύκλος είναι μια τυχαία μετάθεση ΟΛΩΝ των
## εικονιδίων. Έτσι:
##  - κάθε εικονίδιο (άρα και ο στόχος) περνά ακριβώς μία φορά ανά κύκλο,
##  - η σειρά είναι τυχαία,
##  - στο όριο δύο κύκλων, αν το πρώτο της νέας μετάθεσης είναι ίδιο με το
##    τελευταίο της προηγούμενης, ανταλλάσσεται με άλλο, ώστε να μην
##    εμφανίζεται ποτέ το ίδιο εικονίδιο δύο φορές στη σειρά (για n ≥ 2).
##
## Επιστρέφει δείκτες (0..count-1) στη λίστα εικονιδίων.
extends RefCounted

var _count := 0
var _bag: Array = []
var _last := -1
var _rng := RandomNumberGenerator.new()


func _init(count: int = 0, seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	reset(count)


## Ξεκινά από την αρχή με νέο πλήθος εικονιδίων.
func reset(count: int) -> void:
	_count = maxi(count, 0)
	_bag.clear()
	_last = -1


func count() -> int:
	return _count


## Επόμενος δείκτης εικονιδίου, ή -1 αν η λίστα είναι κενή.
func next() -> int:
	if _count == 0:
		return -1
	if _bag.is_empty():
		_refill()
	_last = _bag.pop_front()
	return _last


func _refill() -> void:
	_bag = range(_count)
	# Fisher–Yates με δικό μας RNG ώστε τα tests να είναι ντετερμινιστικά.
	for i in range(_count - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = tmp
	if _count >= 2 and _bag[0] == _last:
		var k := _rng.randi_range(1, _count - 1)
		var tmp2 = _bag[0]
		_bag[0] = _bag[k]
		_bag[k] = tmp2

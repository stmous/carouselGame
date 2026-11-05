## Confetti: απλά σωματίδια (ορθογώνια/κύκλοι) με βαρύτητα, αντίσταση αέρα και
## περιστροφή. Ένα draw pass για όλα ⇒ φθηνό και σε tablet.
extends Control

const COLORS := [
	Color("#ffd640"), Color("#ff6982"), Color("#6eebf0"), Color("#78dc78"),
	Color("#c88cff"), Color("#ffffff"), Color("#ff9a3c"),
]

var _parts: Array = []   # [pos, vel, rot, rot_speed, size, color, life, shape]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	set_process(false)


## Έκρηξη από το σημείο `origin` (σε pixels). `amount` ≈ πλήθος σωματιδίων.
func burst(origin: Vector2, amount: int, power: float = 1.0) -> void:
	var h := maxf(size.y, 1.0)
	for i in amount:
		var ang := _rng.randf_range(-PI, 0.0) + _rng.randf_range(-0.35, 0.35)
		var spd := _rng.randf_range(0.35, 1.15) * h * power
		var s := _rng.randf_range(0.010, 0.020) * h
		_parts.append([
			origin + Vector2(_rng.randf_range(-0.03, 0.03), _rng.randf_range(-0.03, 0.03)) * h,
			Vector2(cos(ang), sin(ang)) * spd,
			_rng.randf_range(0.0, TAU),
			_rng.randf_range(-9.0, 9.0),
			Vector2(s, s * _rng.randf_range(0.45, 0.8)),
			COLORS[_rng.randi_range(0, COLORS.size() - 1)],
			_rng.randf_range(2.2, 3.4),
			_rng.randi_range(0, 3),   # 0 = κύκλος, αλλιώς ορθογώνιο
		])
	set_process(true)


## Δύο «κανόνια» από τις κάτω γωνίες (για Arcade).
func cannons(amount: int) -> void:
	var s := size
	for side in [0, 1]:
		var origin := Vector2(s.x * (0.02 if side == 0 else 0.98), s.y * 1.02)
		for i in amount:
			var ang := deg_to_rad(_rng.randf_range(-80.0, -55.0) if side == 0 else _rng.randf_range(-125.0, -100.0))
			var spd := _rng.randf_range(0.9, 1.6) * s.y
			var sz := _rng.randf_range(0.010, 0.020) * s.y
			_parts.append([origin, Vector2(cos(ang), sin(ang)) * spd, _rng.randf_range(0.0, TAU),
				_rng.randf_range(-9.0, 9.0), Vector2(sz, sz * 0.6),
				COLORS[_rng.randi_range(0, COLORS.size() - 1)], _rng.randf_range(2.5, 3.6),
				_rng.randi_range(0, 3)])
	set_process(true)


func clear() -> void:
	_parts.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	var g := size.y * 1.6
	var alive: Array = []
	for p in _parts:
		var vel: Vector2 = p[1]
		vel.y += g * dt
		vel *= pow(0.25, dt)          # αντίσταση αέρα
		vel.x += sin(p[2] * 2.0) * size.y * 0.08 * dt   # ελαφρύ «φτερούγισμα»
		p[1] = vel
		p[0] = p[0] + vel * dt
		p[2] = p[2] + p[3] * dt
		p[6] = p[6] - dt
		if p[6] > 0.0 and p[0].y < size.y * 1.1:
			alive.append(p)
	_parts = alive
	queue_redraw()
	if _parts.is_empty():
		set_process(false)


func _draw() -> void:
	for p in _parts:
		var col: Color = p[5]
		col.a = clampf(p[6] / 0.6, 0.0, 1.0)
		var sz: Vector2 = p[4]
		# «Γύρισμα» στον αέρα: το πλάτος αυξομειώνεται με την περιστροφή.
		var flip := absf(cos(p[2] * 1.7))
		draw_set_transform(p[0], p[2], Vector2(maxf(flip, 0.15), 1.0))
		if p[7] == 0:
			draw_circle(Vector2.ZERO, sz.y * 0.6, col)
		else:
			draw_rect(Rect2(-sz * 0.5, sz), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

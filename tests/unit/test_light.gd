## Εξωτερικό φως (Shelly): εντολές, digest auth, κανόνες, timeout/retry
## και ότι το παιχνίδι δεν περιμένει ποτέ το Shelly.
extends "res://tests/test_case.gd"

const ShellyRpc = preload("res://scripts/core/shelly_rpc.gd")
const LightRules = preload("res://scripts/core/light_rules.gd")
const ShellyClient = preload("res://scripts/util/shelly_client.gd")
const ConfigSchema = preload("res://scripts/core/config_schema.gd")
const GameFlow = preload("res://scripts/core/game_flow.gd")
const Profiles = preload("res://scripts/util/profiles.gd")
const ShellyMock = preload("res://tests/support/shelly_mock.gd")
const Game = preload("res://scripts/game/game.gd")
const LightAccess = preload("res://scripts/util/light_access.gd")


# ------------------------------------------------------------ εντολές ---

func test_switch_set_command() -> void:
	assert_eq(ShellyRpc.switch_set_path(0, true, 5), "/rpc/Switch.Set?id=0&on=true&toggle_after=5")
	assert_eq(ShellyRpc.switch_set_path(1, true, 120), "/rpc/Switch.Set?id=1&on=true&toggle_after=120")
	assert_eq(ShellyRpc.switch_set_path(0, false), "/rpc/Switch.Set?id=0&on=false", "σβήσιμο χωρίς χρονοδιακόπτη")
	assert_eq(ShellyRpc.STATUS_PATH, "/rpc/Shelly.GetStatus")


func test_normalize_host() -> void:
	assert_eq(ShellyRpc.normalize_host("192.168.33.1"), "192.168.33.1")
	assert_eq(ShellyRpc.normalize_host("  http://192.168.1.50/ "), "192.168.1.50")
	assert_eq(ShellyRpc.normalize_host("127.0.0.1:8080"), "127.0.0.1:8080")
	assert_eq(ShellyRpc.normalize_host("shelly1g3-aabb.local"), "shelly1g3-aabb.local")
	assert_eq(ShellyRpc.normalize_host(""), "")
	assert_eq(ShellyRpc.normalize_host("192.168.1.50/rpc"), "")
	assert_eq(ShellyRpc.normalize_host("1.2.3.4:99999"), "")
	assert_eq(ShellyRpc.normalize_host("https://192.168.1.50"), "", "το Shelly μιλά απλό HTTP")
	assert_eq(ShellyRpc.normalize_host("bad host"), "")
	assert_eq(ShellyRpc.normalize_host("ελληνικά"), "")


func test_status_ok() -> void:
	assert_true(ShellyRpc.is_status_ok(200, "{\"sys\": {}}"))
	assert_false(ShellyRpc.is_status_ok(200, "not json"))
	assert_false(ShellyRpc.is_status_ok(401, "{}"))


# ------------------------------------------------------------- digest ---

func test_parse_challenge() -> void:
	var c := ShellyRpc.parse_challenge("Digest qop=\"auth\", realm=\"shellypro4pm-f008d1d8b8b8\", nonce=\"AAAAAABn+Q==\", algorithm=SHA-256")
	assert_eq(c["qop"], "auth")
	assert_eq(c["realm"], "shellypro4pm-f008d1d8b8b8")
	assert_eq(c["nonce"], "AAAAAABn+Q==")
	assert_eq(c["algorithm"], "SHA-256")
	assert_true(ShellyRpc.parse_challenge("Basic realm=\"x\"").is_empty())


func test_digest_matches_reference_vector() -> void:
	# Τιμές υπολογισμένες ανεξάρτητα (Python hashlib), κατά RFC 7616 / τεκμηρίωση Shelly.
	var uri := "/rpc/Switch.Set?id=0&on=true&toggle_after=5"
	assert_eq(ShellyRpc.digest_response("admin", "shelly1g3-aabbccddeeff", "secret", "GET", uri,
		"6a1b2c3d", "00000001", "0a4f113b", "auth", "SHA-256"),
		"9669cff11d005edfbd5d5b8086b3dd320c1aa5691ab7c8f3c6a5221d4019786c")
	assert_eq(ShellyRpc.digest_response("admin", "shelly1g3-aabbccddeeff", "secret", "GET", uri,
		"6a1b2c3d", "00000001", "0a4f113b", "auth", "MD5"),
		"08095df084b30f55c42c016d818d9d33")


func test_authorization_header() -> void:
	var uri := "/rpc/Switch.Set?id=0&on=true&toggle_after=5"
	var h := ShellyRpc.authorization_header(
		"Digest qop=\"auth\", realm=\"shelly1g3-aabbccddeeff\", nonce=\"6a1b2c3d\", algorithm=SHA-256",
		"", "secret", "GET", uri, "0a4f113b")
	assert_true(h.begins_with("Authorization: Digest "))
	assert_true(h.contains("username=\"admin\""), "κενό όνομα ⇒ admin")
	assert_true(h.contains("response=\"9669cff11d005edfbd5d5b8086b3dd320c1aa5691ab7c8f3c6a5221d4019786c\""))
	assert_true(h.contains("uri=\"%s\"" % uri))
	assert_true(h.contains("qop=auth") and h.contains("nc=00000001"))
	assert_eq(ShellyRpc.authorization_header("Basic realm=\"x\"", "", "p", "GET", "/", "c"), "")


# ------------------------------------------------- κανόνες & ρυθμίσεις ---

func _cfg(enabled: bool) -> Dictionary:
	var c := ConfigSchema.defaults()
	c["light"]["enabled"] = enabled
	c["icons"]["list"][0]["light"] = true    # «star» ανάβει το φως στον «Τροχό»
	return ConfigSchema.sanitize(c)


func test_light_rules() -> void:
	var on := _cfg(true)
	assert_true(LightRules.should_light(on, GameFlow.Outcome.WIN, "star"), "«Ένα σωστό»: κάθε νίκη")
	assert_false(LightRules.should_light(on, GameFlow.Outcome.LOSE, ""))
	assert_false(LightRules.should_light(on, GameFlow.Outcome.RETRY, "heart"))
	assert_true(LightRules.should_light(on, GameFlow.Outcome.WHEEL, "star"), "εικονίδιο με «Ανάβει το φως»")
	assert_false(LightRules.should_light(on, GameFlow.Outcome.WHEEL, "heart"), "εικονίδιο χωρίς")
	assert_true(LightRules.should_light(on, GameFlow.Outcome.WHEEL_REPLAY, "star"))
	var off := _cfg(false)
	assert_false(LightRules.should_light(off, GameFlow.Outcome.WIN, "star"), "απενεργοποιημένο ⇒ ποτέ")
	assert_false(LightRules.should_light(off, GameFlow.Outcome.WHEEL, "star"))


func test_light_config_defaults_and_sanitize() -> void:
	var d := ConfigSchema.from_user_data({})
	assert_false(d["light"]["enabled"], "προεπιλογή: off")
	assert_eq(d["light"]["connection"], "ap")
	assert_eq(d["light"]["ip"], "192.168.33.1")
	assert_eq(d["light"]["output"], 0)
	for icon in d["icons"]["list"]:
		assert_false(icon["light"], "προεπιλογή ανά εικονίδιο: off")
	# Παλιό config.json χωρίς τις νέες ρυθμίσεις: συμπληρώνονται.
	var old := ConfigSchema.from_user_data({"icons": {"list": [{"id": "a", "name": "Α"}]}})
	assert_false(old["icons"]["list"][0]["light"])
	var c := ConfigSchema.defaults()
	c["light"]["connection"] = "???"
	c["light"]["duration"] = 0
	c["light"]["output"] = -3
	c["light"]["ip"] = "  192.168.1.9 "
	c = ConfigSchema.sanitize(c)
	assert_eq(c["light"]["connection"], "ap")
	assert_eq(c["light"]["duration"], 1)
	assert_eq(c["light"]["output"], 0)
	assert_eq(c["light"]["ip"], "192.168.1.9")


func test_light_settings_travel_with_themes() -> void:
	var c := _cfg(true)
	c["light"]["ip"] = "192.168.1.77"
	var rel: Dictionary = Profiles.relativize(c)["cfg"]
	assert_true(rel.has("light"), "οι ρυθμίσεις φωτός περιλαμβάνονται στο θέμα")
	assert_eq(rel["light"]["ip"], "192.168.1.77")
	assert_true(rel["icons"]["list"][0]["light"])


# ------------------------------------------- δίκτυο (με mock Shelly) ---

var _mock: ShellyMock
var _client: ShellyClient
var _t0 := 0


func _setup() -> bool:
	_mock = ShellyMock.new()
	tree().root.add_child(_mock)
	_client = ShellyClient.new()
	tree().root.add_child(_client)
	_t0 = Time.get_ticks_msec()
	if not _mock.start():
		_fail("ο mock server δεν βρήκε ελεύθερη θύρα")
		return false
	return true


func _teardown() -> void:
	if _client != null:
		_client.queue_free()
	if _mock != null:
		_mock.queue_free()


func _settings(extra: Dictionary = {}) -> Dictionary:
	var s := {"enabled": true, "ip": _mock.address(), "output": 0, "duration": 7, "username": "", "password": ""}
	s.merge(extra, true)
	return s


signal _reply

var _last: Array = []


func _on_reply(ok: bool, code: int, body: String) -> void:
	_last = [ok, code, body]
	_reply.emit()


## Στέλνει και περιμένει το τέλος της κλήσης. Επιστρέφει [ok, code, body].
func _send(settings: Dictionary, path: String, retries: int = 1) -> Array:
	_last = []
	_client.send(settings, path, _on_reply, retries)
	if _last.is_empty():
		await _reply
	return _last


func test_async_switch_on_reaches_shelly() -> void:
	if not _setup():
		finish()
		return
	var r: Array = await _send(_settings(), ShellyRpc.switch_set_path(0, true, 7))
	assert_true(r[0], "απάντηση %d %s" % [r[1], r[2]])
	assert_eq(_mock.requests.size(), 1)
	if _mock.requests.size() > 0:
		var req: Dictionary = _mock.requests[0]
		assert_eq(req["path"], "/rpc/Switch.Set")
		assert_eq(req["query"], {"id": "0", "on": "true", "toggle_after": "7"})
	assert_true(_mock.outputs[0], "το φως άναψε")
	assert_true(str(r[2]).contains("was_on"))
	_teardown()
	finish()


func test_async_timeout_then_one_retry_then_gives_up() -> void:
	if not _setup():
		finish()
		return
	_mock.silent = true
	_client.timeout = 0.5          # (στο παιχνίδι: 2 δευτερόλεπτα)
	assert_near(ShellyClient.TIMEOUT, 2.0, 1e-9, "προεπιλεγμένο timeout 2 δ")
	var r: Array = await _send(_settings(), ShellyRpc.switch_set_path(0, true, 7))
	var elapsed := (Time.get_ticks_msec() - _t0) / 1000.0
	assert_false(r[0], "χωρίς απάντηση ⇒ αποτυχία")
	assert_eq(_client.attempts_started, 2, "1 προσπάθεια + 1 επανάληψη")
	assert_eq(_mock.connections, 2)
	assert_true(elapsed >= 0.9 and elapsed < 5.0, "χρόνος %.2f δ" % elapsed)
	assert_eq(_client.in_flight, 0)
	_teardown()
	finish()


func test_async_retry_succeeds_after_failure() -> void:
	if not _setup():
		finish()
		return
	_mock.fail_first = 1
	var r: Array = await _send(_settings(), ShellyRpc.switch_set_path(0, true, 7))
	assert_true(r[0], "η επανάληψη πέτυχε")
	assert_eq(_client.attempts_started, 2)
	assert_true(_mock.outputs[0])
	_teardown()
	finish()


func test_async_digest_authentication() -> void:
	if not _setup():
		finish()
		return
	_mock.password = "secret"
	var r: Array = await _send(_settings({"password": "secret"}), ShellyRpc.STATUS_PATH)
	assert_true(r[0] and ShellyRpc.is_status_ok(r[1], r[2]), "σωστός κωδικός ⇒ OK (%d)" % r[1])
	assert_eq(_mock.requests.size(), 2, "πρώτα 401, μετά με digest")
	if _mock.requests.size() == 2:
		assert_false(_mock.requests[0]["auth"])
		assert_true(_mock.requests[1]["auth"])
	# Λάθος κωδικός ⇒ αποτυχία με 401.
	var wrong: Array = await _send(_settings({"password": "wrong"}), ShellyRpc.STATUS_PATH, 0)
	assert_false(wrong[0])
	assert_eq(wrong[1], 401)
	# Χωρίς κωδικό σε Shelly που ζητά ⇒ 401.
	var none: Array = await _send(_settings(), ShellyRpc.STATUS_PATH, 0)
	assert_eq(none[1], 401)
	_teardown()
	finish()


func test_async_invalid_address_makes_no_request() -> void:
	if not _setup():
		finish()
		return
	var r: Array = await _send(_settings({"ip": "not an ip!"}), ShellyRpc.STATUS_PATH)
	assert_false(r[0])
	assert_eq(_client.attempts_started, 0)
	assert_eq(_mock.connections, 0)
	_teardown()
	finish()


func test_async_game_never_waits_for_shelly() -> void:
	var root := tree().root
	if not (root.has_node("Config") and root.has_node("Sfx")):
		assert_true(true, "παραλείπεται χωρίς autoloads (τρέξε από το run_tests.tscn)")
		finish()
		return
	if not _setup():
		finish()
		return
	_mock.silent = true                       # το Shelly «κρεμάει» χωρίς απάντηση
	var config_node := root.get_node("Config")
	var light_node := LightAccess.service(tree())
	var backup: Dictionary = config_node.data.duplicate(true)
	var cfg := ConfigSchema.defaults()
	cfg["mode"] = ConfigSchema.MODE_ONE_CORRECT
	cfg["flow"]["countdown"] = false
	cfg["light"] = _settings()
	config_node.data = ConfigSchema.sanitize(cfg)

	# Απενεργοποιημένο ⇒ καμία δικτυακή κλήση.
	config_node.data["light"]["enabled"] = false
	var before: int = light_node.client.attempts_started
	light_node.on_result(GameFlow.Outcome.WIN, "star")
	assert_eq(light_node.client.attempts_started, before, "off ⇒ καμία κλήση")
	config_node.data["light"]["enabled"] = true

	var game := Game.new()
	root.add_child(game)
	game.start_game()
	game._pending_icon = str(config_node.data["modes"]["one_correct"]["target_id"])
	var t0 := Time.get_ticks_usec()
	game._show_result()                       # νίκη ⇒ popup + φως
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_true(game.popup.visible, "το popup νίκης εμφανίστηκε αμέσως")
	assert_true(ms < 100.0, "δεν περίμενε το Shelly (%.1f ms)" % ms)
	assert_eq(light_node.client.attempts_started, before + 1, "στάλθηκε εντολή ανάμματος")

	# Το παιχνίδι συνεχίζει κανονικά όσο το Shelly δεν απαντά.
	await wait(0.6)
	assert_true(_mock.connections >= 1, "το αίτημα έφυγε στο παρασκήνιο")
	assert_eq(game.phase, Game.Phase.POPUP)
	game.popup.close()
	await wait(0.4)
	assert_eq(game.phase, Game.Phase.IDLE, "το popup έκλεισε και το παιχνίδι τελείωσε κανονικά")

	game.abort()
	game.queue_free()
	config_node.data = backup
	_teardown()
	finish()

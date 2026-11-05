## Mock Shelly για τα tests: μικρός HTTP server (TCPServer) στο 127.0.0.1
## που μιμείται τα endpoints Switch.Set και Shelly.GetStatus.
##
## Καταστάσεις για δοκιμές αξιοπιστίας:
##   silent = true     δέχεται τη σύνδεση αλλά δεν απαντά ποτέ (⇒ timeout)
##   fail_first = N    τα πρώτα N αιτήματα παίρνουν HTTP 500
##   password = "…"    απαιτεί HTTP Digest (SHA-256, χρήστης «admin»), όπως το Shelly
extends Node

const ShellyRpc = preload("res://scripts/core/shelly_rpc.gd")

var silent := false
var fail_first := 0
var password := ""
var realm := "shelly1g3-mock"
var nonce := "6a1b2c3d"

var port := 0
var connections := 0
## Κάθε αίτημα: {"path": String, "query": Dictionary, "auth": bool}
var requests: Array = []
var outputs := {0: false}

var _server := TCPServer.new()
var _clients: Array = []    # [{"peer": StreamPeerTCP, "buf": PackedByteArray}]
var _held: Array = []       # συνδέσεις που «κρατάμε» χωρίς απάντηση (silent)


## Ξεκινά σε ελεύθερη θύρα. Επιστρέφει false αν δεν βρέθηκε θύρα.
func start() -> bool:
	for p in range(18080, 18200):
		if _server.listen(p, "127.0.0.1") == OK:
			port = p
			return true
	return false


func address() -> String:
	return "127.0.0.1:%d" % port


func _exit_tree() -> void:
	for c in _clients:
		(c["peer"] as StreamPeerTCP).disconnect_from_host()
	for p in _held:
		(p as StreamPeerTCP).disconnect_from_host()
	_server.stop()


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var peer := _server.take_connection()
		connections += 1
		_clients.append({"peer": peer, "buf": PackedByteArray()})
	for c in _clients.duplicate():
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(c)
			continue
		var n := peer.get_available_bytes()
		if n > 0:
			var r: Array = peer.get_data(n)
			if r[0] == OK:
				var buf: PackedByteArray = c["buf"]
				buf.append_array(r[1])
				c["buf"] = buf
		var text: String = (c["buf"] as PackedByteArray).get_string_from_utf8()
		if text.contains("\r\n\r\n"):
			_clients.erase(c)
			_handle(peer, text)


func _handle(peer: StreamPeerTCP, text: String) -> void:
	var lines := text.split("\r\n")
	var first := lines[0].split(" ")
	var target := first[1] if first.size() > 1 else "/"
	var headers := PackedStringArray()
	for i in range(1, lines.size()):
		if lines[i] == "":
			break
		headers.append(lines[i])
	var path := target.split("?")[0]
	var query := _parse_query(target)
	var auth_header := ShellyRpc.header_value(headers, "Authorization")
	requests.append({"path": path, "query": query, "auth": auth_header != ""})

	if silent:
		_held.append(peer)
		return
	if fail_first > 0:
		fail_first -= 1
		_respond(peer, 500, "{\"code\":-1,\"message\":\"mock failure\"}")
		return
	if password != "" and not _auth_ok(auth_header, target):
		_respond(peer, 401, "", PackedStringArray([
			"WWW-Authenticate: Digest qop=\"auth\", realm=\"%s\", nonce=\"%s\", algorithm=SHA-256" % [realm, nonce]]))
		return

	match path:
		"/rpc/Switch.Set":
			var id := int(query.get("id", "0"))
			var was_on: bool = outputs.get(id, false)
			outputs[id] = str(query.get("on", "")) == "true"
			_respond(peer, 200, JSON.stringify({"was_on": was_on}))
		"/rpc/Shelly.GetStatus":
			_respond(peer, 200, JSON.stringify({
				"sys": {"mac": "AABBCCDDEEFF", "uptime": 123},
				"switch:0": {"id": 0, "output": outputs.get(0, false)},
			}))
		_:
			_respond(peer, 404, "{\"code\":404,\"message\":\"No handler\"}")


func _auth_ok(auth_header: String, uri: String) -> bool:
	if auth_header == "":
		return false
	var a := ShellyRpc.parse_challenge(auth_header)   # ίδια μορφή «Digest k=v, …»
	if a.get("username", "") != "admin" or a.get("uri", "") != uri:
		return false
	var expected := ShellyRpc.digest_response("admin", realm, password, "GET", uri, nonce,
		str(a.get("nc", "")), str(a.get("cnonce", "")), str(a.get("qop", "")), "SHA-256")
	return a.get("response", "") == expected


static func _parse_query(target: String) -> Dictionary:
	var out := {}
	var q := target.split("?")
	if q.size() < 2:
		return out
	for pair in q[1].split("&"):
		var kv := pair.split("=")
		if kv.size() == 2:
			out[kv[0].uri_decode()] = kv[1].uri_decode()
	return out


func _respond(peer: StreamPeerTCP, code: int, body: String, extra: PackedStringArray = PackedStringArray()) -> void:
	var reasons := {200: "OK", 401: "Unauthorized", 404: "Not Found", 500: "Internal Server Error"}
	var bytes := body.to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\n" % [code, reasons.get(code, "Error")]
	for h in extra:
		head += h + "\r\n"
	head += "Content-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()
	var out := head.to_utf8_buffer()
	out.append_array(bytes)
	peer.put_data(out)
	peer.disconnect_from_host()

## Τοπικό HTTP RPC API του Shelly (Gen2+): δημιουργία εντολών και digest
## authentication. Pure λογική, χωρίς δίκτυο — ελέγχεται με unit tests.
##
## Τεκμηρίωση: https://shelly-api-docs.shelly.cloud/gen2/
##   GET /rpc/Switch.Set?id=<id>&on=true&toggle_after=<δευτερόλεπτα>
##   GET /rpc/Shelly.GetStatus
## Authentication: HTTP Digest (RFC 7616), SHA-256, username πάντα "admin",
## realm = id της συσκευής.
extends RefCounted

const STATUS_PATH := "/rpc/Shelly.GetStatus"
const DEFAULT_USER := "admin"


## Εντολή ανάμματος/σβησίματος. Με `toggle_after` > 0 το ίδιο το Shelly
## γυρίζει την έξοδο στην αντίθετη κατάσταση μετά από τόσα δευτερόλεπτα
## (σβήνει μόνο του, ακόμα κι αν χαθεί η σύνδεση με το παιχνίδι).
static func switch_set_path(output: int, on: bool, toggle_after: int = 0) -> String:
	var path := "/rpc/Switch.Set?id=%d&on=%s" % [maxi(output, 0), "true" if on else "false"]
	if toggle_after > 0:
		path += "&toggle_after=%d" % toggle_after
	return path


## Καθαρίζει τη διεύθυνση που έγραψε ο διαχειριστής: «http://192.168.33.1/» →
## «192.168.33.1». Επιτρέπεται IPv4 ή όνομα host, με προαιρετική θύρα
## (π.χ. «127.0.0.1:8080» για τον mock server). Μη έγκυρη ⇒ "".
static func normalize_host(raw: String) -> String:
	var h := raw.strip_edges()
	if h.begins_with("http://"):
		h = h.substr(7)
	elif h.begins_with("https://"):
		return ""   # το Shelly μιλά τοπικά απλό HTTP
	while h.ends_with("/"):
		h = h.substr(0, h.length() - 1)
	if h == "" or h.contains("/") or h.contains("@") or h.contains(" "):
		return ""
	var host := h
	var parts := h.split(":")
	if parts.size() > 2:
		return ""
	if parts.size() == 2:
		host = parts[0]
		if not parts[1].is_valid_int():
			return ""
		var port := int(parts[1])
		if port < 1 or port > 65535:
			return ""
	if host == "":
		return ""
	for ch in host:
		var c := ch.unicode_at(0)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or ch == "." or ch == "-"
		if not ok:
			return ""
	return h


## Αν η απάντηση του Shelly.GetStatus μοιάζει με έγκυρη κατάσταση συσκευής.
static func is_status_ok(code: int, body: String) -> bool:
	if code != 200:
		return false
	var parsed = JSON.parse_string(body)
	return parsed is Dictionary


# ------------------------------------------------------------ digest auth ---

## Τιμή μιας κεφαλίδας (χωρίς διάκριση πεζών/κεφαλαίων) ή "".
static func header_value(headers: PackedStringArray, header_name: String) -> String:
	var prefix := header_name.to_lower() + ":"
	for line in headers:
		if line.to_lower().begins_with(prefix):
			return line.substr(prefix.length()).strip_edges()
	return ""


## Ανάλυση «Digest qop="auth", realm="...", nonce="...", algorithm=SHA-256».
static func parse_challenge(header: String) -> Dictionary:
	var out := {}
	var h := header.strip_edges()
	if not h.to_lower().begins_with("digest"):
		return out
	h = h.substr(6)
	var i := 0
	var n := h.length()
	while i < n:
		while i < n and (h[i] == " " or h[i] == ","):
			i += 1
		var key := ""
		while i < n and h[i] != "=" and h[i] != ",":
			key += h[i]
			i += 1
		key = key.strip_edges().to_lower()
		if i >= n or h[i] != "=":
			continue
		i += 1
		var value := ""
		if i < n and h[i] == "\"":
			i += 1
			while i < n and h[i] != "\"":
				if h[i] == "\\" and i + 1 < n:
					i += 1
				value += h[i]
				i += 1
			i += 1
		else:
			while i < n and h[i] != ",":
				value += h[i]
				i += 1
			value = value.strip_edges()
		if key != "":
			out[key] = value
	return out


static func _hash(text: String, algorithm: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5 if algorithm.to_upper() == "MD5" else HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


## Η τιμή `response` του digest (RFC 7616, qop=auth):
##   HA1 = H(user:realm:password), HA2 = H(method:uri)
##   response = H(HA1:nonce:nc:cnonce:qop:HA2)
static func digest_response(user: String, realm: String, password: String, method: String, uri: String,
		nonce: String, nc: String, cnonce: String, qop: String, algorithm: String = "SHA-256") -> String:
	var ha1 := _hash("%s:%s:%s" % [user, realm, password], algorithm)
	var ha2 := _hash("%s:%s" % [method, uri], algorithm)
	if qop == "":
		return _hash("%s:%s:%s" % [ha1, nonce, ha2], algorithm)
	return _hash("%s:%s:%s:%s:%s:%s" % [ha1, nonce, nc, cnonce, qop, ha2], algorithm)


## Πλήρης κεφαλίδα «Authorization: Digest …» ως απάντηση σε ένα 401.
## Επιστρέφει "" αν η πρόκληση δεν είναι digest.
static func authorization_header(challenge_header: String, user: String, password: String, method: String,
		uri: String, cnonce: String, nc: String = "00000001") -> String:
	var ch := parse_challenge(challenge_header)
	if not ch.has("realm") or not ch.has("nonce"):
		return ""
	var u := user if user != "" else DEFAULT_USER
	var algorithm := str(ch.get("algorithm", "SHA-256"))
	var qop := ""
	if ch.has("qop"):
		qop = "auth"   # το Shelly προσφέρει μόνο qop="auth"
	var response := digest_response(u, ch["realm"], password, method, uri, ch["nonce"], nc, cnonce, qop, algorithm)
	var parts := PackedStringArray([
		"username=\"%s\"" % u,
		"realm=\"%s\"" % ch["realm"],
		"nonce=\"%s\"" % ch["nonce"],
		"uri=\"%s\"" % uri,
		"algorithm=%s" % algorithm,
		"response=\"%s\"" % response,
	])
	if qop != "":
		parts.append("qop=%s" % qop)
		parts.append("nc=%s" % nc)
		parts.append("cnonce=\"%s\"" % cnonce)
	return "Authorization: Digest " + ", ".join(parts)

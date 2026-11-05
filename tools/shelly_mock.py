#!/usr/bin/env python3
"""Mock Shelly (Gen2+ HTTP RPC) για δοκιμή του «Εξωτερικού φωτός» χωρίς τη συσκευή.

Μιμείται:
  GET /rpc/Switch.Set?id=0&on=true&toggle_after=5   → {"was_on": false}
  GET /rpc/Shelly.GetStatus                         → {"sys": {...}, "switch:0": {...}}
και τυπώνει στην οθόνη πότε «ανάβει» και πότε «σβήνει» το φως (και ο
χρονοδιακόπτης toggle_after, όπως στο πραγματικό Shelly).

Χρήση (μόνο Python 3, χωρίς επιπλέον πακέτα):
  python tools/shelly_mock.py                      # θύρα 8080
  python tools/shelly_mock.py --port 9000
  python tools/shelly_mock.py --password secret    # digest auth όπως το Shelly (χρήστης admin)
  python tools/shelly_mock.py --delay 5            # αργή απάντηση (δοκιμή timeout)
  python tools/shelly_mock.py --silent             # δεν απαντά ποτέ
  python tools/shelly_mock.py --fail-first 1       # το 1ο αίτημα παίρνει HTTP 500 (δοκιμή επανάληψης)

Στο παιχνίδι: Ρυθμίσεις → Εξωτερικό φως → «Μέσω router», IP: 127.0.0.1:8080
(ή <IP του υπολογιστή>:8080 όταν δοκιμάζεις από tablet στο ίδιο δίκτυο,
με --host 0.0.0.0).
"""
import argparse
import hashlib
import json
import secrets
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

REALM = "shelly1g3-mock000000"
STATE = {"outputs": {0: False}, "timers": {}, "fail_first": 0, "lock": threading.Lock()}
ARGS = None


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def parse_digest(header):
    """«Digest a="b", c=d» → dict."""
    out = {}
    if not header or not header.lower().startswith("digest"):
        return out
    rest = header[6:]
    key, val, i, n = "", "", 0, len(rest)
    while i < n:
        while i < n and rest[i] in " ,":
            i += 1
        start = i
        while i < n and rest[i] not in "=,":
            i += 1
        key = rest[start:i].strip().lower()
        if i >= n or rest[i] != "=":
            continue
        i += 1
        if i < n and rest[i] == '"':
            i += 1
            start = i
            while i < n and rest[i] != '"':
                i += 1
            val = rest[start:i]
            i += 1
        else:
            start = i
            while i < n and rest[i] != ",":
                i += 1
            val = rest[start:i].strip()
        out[key] = val
    return out


def digest_ok(header, method, nonces):
    a = parse_digest(header)
    if a.get("username") != "admin" or a.get("nonce") not in nonces:
        return False
    h = (lambda s: hashlib.md5(s.encode()).hexdigest()) if a.get("algorithm", "").upper() == "MD5" \
        else (lambda s: hashlib.sha256(s.encode()).hexdigest())
    ha1 = h(f"admin:{a.get('realm')}:{ARGS.password}")
    ha2 = h(f"{method}:{a.get('uri')}")
    if a.get("qop"):
        expected = h(f"{ha1}:{a['nonce']}:{a.get('nc')}:{a.get('cnonce')}:{a['qop']}:{ha2}")
    else:
        expected = h(f"{ha1}:{a['nonce']}:{ha2}")
    return a.get("response") == expected


NONCES = set()


def set_output(sw_id, on, toggle_after=None):
    with STATE["lock"]:
        was_on = STATE["outputs"].get(sw_id, False)
        STATE["outputs"][sw_id] = on
        old = STATE["timers"].pop(sw_id, None)
        if old:
            old.cancel()
        if toggle_after:
            t = threading.Timer(toggle_after, lambda: (set_output(sw_id, not on),
                                                      log(f"⏱  toggle_after: έξοδος {sw_id} → {'ON' if not on else 'OFF'}")))
            t.daemon = True
            STATE["timers"][sw_id] = t
            t.start()
    return was_on


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):  # σιωπηλό το προεπιλεγμένο log
        pass

    def send_json(self, code, obj, extra=None):
        body = json.dumps(obj).encode()
        self.send_response(code)
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlsplit(self.path)
        q = {k: v[0] for k, v in parse_qs(url.query).items()}
        log(f"← {self.client_address[0]}  GET {self.path}")
        if ARGS.silent:
            time.sleep(3600)
            return
        if ARGS.delay:
            time.sleep(ARGS.delay)
        with STATE["lock"]:
            if STATE["fail_first"] > 0:
                STATE["fail_first"] -= 1
                fail = True
            else:
                fail = False
        if fail:
            log("→ 500 (προσομοίωση αποτυχίας)")
            return self.send_json(500, {"code": -1, "message": "mock failure"})
        if ARGS.password and not digest_ok(self.headers.get("Authorization", ""), "GET", NONCES):
            nonce = secrets.token_hex(8)
            NONCES.add(nonce)
            log("→ 401 (ζητείται digest auth)")
            return self.send_json(401, {"code": 401, "message": "Unauthorized"}, {
                "WWW-Authenticate": f'Digest qop="auth", realm="{REALM}", nonce="{nonce}", algorithm=SHA-256'})
        if url.path == "/rpc/Switch.Set":
            try:
                sw_id = int(q.get("id", "0"))
                on = q.get("on") == "true"
                ta = float(q["toggle_after"]) if "toggle_after" in q else None
            except ValueError:
                return self.send_json(400, {"code": -103, "message": "Invalid argument"})
            was_on = set_output(sw_id, on, ta)
            extra = f" για {ta:g} δ" if ta else ""
            log(f"💡 έξοδος {sw_id} → {'ON' if on else 'OFF'}{extra}")
            return self.send_json(200, {"was_on": was_on})
        if url.path == "/rpc/Shelly.GetStatus":
            with STATE["lock"]:
                out = dict(STATE["outputs"])
            return self.send_json(200, {
                "sys": {"mac": "AABBCCDDEEFF", "uptime": int(time.monotonic())},
                **{f"switch:{k}": {"id": k, "output": v} for k, v in out.items()},
            })
        return self.send_json(404, {"code": 404, "message": "No handler for " + url.path})


def main():
    global ARGS
    p = argparse.ArgumentParser(description="Mock Shelly Gen2+ HTTP RPC")
    p.add_argument("--host", default="127.0.0.1", help="0.0.0.0 για πρόσβαση από άλλες συσκευές")
    p.add_argument("--port", type=int, default=8080)
    p.add_argument("--password", default="", help="ενεργοποιεί digest auth (χρήστης admin)")
    p.add_argument("--delay", type=float, default=0.0, help="καθυστέρηση απάντησης σε δευτερόλεπτα")
    p.add_argument("--silent", action="store_true", help="δεν απαντά ποτέ")
    p.add_argument("--fail-first", type=int, default=0, help="τα πρώτα N αιτήματα παίρνουν HTTP 500")
    ARGS = p.parse_args()
    STATE["fail_first"] = ARGS.fail_first
    srv = ThreadingHTTPServer((ARGS.host, ARGS.port), Handler)
    srv.daemon_threads = True
    log(f"Mock Shelly στο http://{ARGS.host}:{ARGS.port}  (Ctrl+C για τερματισμό)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()

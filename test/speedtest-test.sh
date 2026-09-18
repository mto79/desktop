#!/usr/bin/env bash
# The speed test, against a stand-in for speed.cloudflare.com on localhost.
#
# Each case here is a way the numbers once came out wrong rather than failing loudly:
# curl's -w lines vanishing when the deadline killed it (buffered into a pipe), which made
# a working link read as a failed one; a 403 for an oversized download counted as a
# transfer, which made the link read as 0 Mbit/s; and Cloudflare's hour-long 429, which
# is not the link failing at all and has to say so.
source "$(dirname "$0")/lib.sh"

require python3 curl jq stdbuf || finish

sandbox=$(mktemp -d)
trap 'kill "$server" 2>/dev/null; rm -rf "$sandbox"' EXIT

# MODE is read per request, so one server can play every case.
python3 - "$sandbox" 2>/dev/null <<'PY' &
import http.server, pathlib, sys, time, urllib.parse
sandbox = pathlib.Path(sys.argv[1])

class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a): pass
    def mode(self): return (sandbox / "mode").read_text().strip()
    def reply(self, status, body=b"", headers=()):
        self.send_response(status)
        self.send_header("CF-RAY", "0123456789abcdef-TST")
        for k, v in headers: self.send_header(k, v)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD": self.wfile.write(body)
    def do_HEAD(self): self.reply(200)
    def do_GET(self):
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        size = int(query.get("bytes", ["0"])[0])
        mode = self.mode()
        if size == 0: return self.reply(200)
        if mode == "limited": return self.reply(429, headers=[("Retry-After", "3330")])
        if mode == "forbidden": return self.reply(403, b"x")
        if mode == "slow": time.sleep(0.05)
        self.reply(200, b"\0" * size)
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.mode() == "slow": time.sleep(0.05)
        self.reply(200)

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
(sandbox / "port").write_text(str(server.server_address[1]))
server.serve_forever()
PY
# Quiet: curl killed at a deadline leaves the server writing into closed sockets.
server=$!
for _ in $(seq 50); do [[ -s $sandbox/port ]] && break; sleep 0.1; done

export DESKTOP_SPEEDTEST_URL="http://127.0.0.1:$(cat "$sandbox/port")"
export DESKTOP_SPEEDTEST_CHUNK=100000 DESKTOP_SPEEDTEST_SECONDS=1

run() {
  echo "$1" >"$sandbox/mode"
  DESKTOP_SPEEDTEST_MAX_CHUNKS=${2:-20} "$ROOT/bin/desktop-speedtest" --json >"$sandbox/out"
  echo $? >"$sandbox/status"
  tail -1 "$sandbox/out"
}
field() { jq -r "$1" <<<"$last"; }
holds() { jq -e "$1" <<<"$last" >/dev/null; }

last=$(run fast)
check "a run ends in done, with every line valid JSON" \
  test "$(jq -rs 'map(.stage) | join(" ")' "$sandbox/out")" = "latency download upload done"
check "and names the edge from the CF-RAY header" test "$(field .server)" = TST
check "and measures both directions" holds '.download > 0 and .upload > 0 and .latency >= 0'

# More chunks than the second allows, each slowed down: the deadline kills curl mid-run,
# and what finished before it still has to be counted.
last=$(run slow 1000)
check "a run cut off by its deadline still reports what it measured" holds '.stage == "done" and .download > 0 and .upload > 0'

last=$(run limited)
check "a 429 is reported as Cloudflare's limit, with the wait it gave" \
  test "$(field .error)" = "Rate-limited by Cloudflare, try again in 56 min"
check "and leaves the rate null rather than zero" test "$(field .download)" = null
check "and exits non-zero" test "$(cat "$sandbox/status")" = 1

last=$(run forbidden)
check "a refused download is a failure, not a speed of zero" test "$(field .error)" = "download failed"

DESKTOP_SPEEDTEST_URL=http://127.0.0.1:9 last=$(run fast)
check "an unreachable server is said to be unreachable" grep -q "could not reach" <<<"$(field .error)"

finish

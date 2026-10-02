import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import urlopen

CONNECT_URL = os.getenv("CONNECT_URL", "http://migration-debezium:8083")
BRIDGE_URLS = [u for u in os.getenv("BRIDGE_URLS", "http://migration-bridge:9607,http://migration-recovery-bridge-live:9608").split(",") if u]
EXPECTED_CONNECTORS = [x for x in os.getenv("EXPECTED_CONNECTORS", "cdc-auth,cdc-user,cdc-gig,cdc-order,cdc-payment,cdc-review").split(",") if x]

def fetch(url):
    try:
        with urlopen(url, timeout=3) as response:
            return response.read().decode()
    except Exception:
        return None

def metric(name, value, labels=None):
    suffix = ""
    if labels:
        suffix = "{" + ",".join(f'{k}="{str(v).replace(chr(34), chr(92)+chr(34))}"' for k, v in labels.items()) + "}"
    return f"{name}{suffix} {value}\n"

def render():
    out = ["# HELP ofm_debezium_connector_up Debezium connector state.\n", "# TYPE ofm_debezium_connector_up gauge\n"]
    connectors = fetch(CONNECT_URL + "/connectors")
    names = json.loads(connectors) if connectors else []
    for name in EXPECTED_CONNECTORS:
        status_raw = fetch(CONNECT_URL + "/connectors/" + name + "/status")
        status = json.loads(status_raw) if status_raw else {}
        connector_ok = 1 if status.get("connector", {}).get("state") == "RUNNING" else 0
        out.append(metric("ofm_debezium_connector_up", connector_ok, {"connector": name}))
        out.append(metric("ofm_debezium_connector_errors", 0 if connector_ok else 1, {"connector": name}))
        tasks = status.get("tasks", [])
        for task in tasks:
            task_ok = 1 if task.get("state") == "RUNNING" else 0
            out.append(metric("ofm_debezium_task_up", task_ok, {"connector": name, "task": task.get("id", "0")}))
            if task.get("trace"):
                out.append(metric("ofm_debezium_task_errors", 1, {"connector": name, "task": task.get("id", "0")}))
    out += ["# TYPE ofm_debezium_connect_api_up gauge\n", metric("ofm_debezium_connect_api_up", 1 if connectors is not None else 0)]
    for url in BRIDGE_URLS:
        raw = fetch(url + "/metrics")
        bridge = url.rsplit("/", 1)[-1] or url
        if raw is None:
            out.append(metric("migration_bridge_up", 0, {"bridge": bridge}))
            continue
        for line in raw.splitlines():
            if line.startswith("migration_bridge_") and not line.startswith("migration_bridge_up"):
                out.append(line.rstrip() + "\n")
        out.append(metric("migration_bridge_up", 1, {"bridge": bridge}))
    return "".join(out)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_response(404); self.end_headers(); return
        body = render().encode()
        self.send_response(200); self.send_header("Content-Type", "text/plain; version=0.0.4"); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self, *_):
        return

HTTPServer(("0.0.0.0", int(os.getenv("PORT", "9615"))), Handler).serve_forever()

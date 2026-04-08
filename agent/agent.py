import time
import requests
import socket
import psutil
import os
import json
from datetime import datetime

# ==============================
# CONFIG
# ==============================
BACKEND_URL = os.getenv("BACKEND_URL")

HOSTNAME = socket.gethostname()
IP = socket.gethostbyname(HOSTNAME)

AGENT_ID = f"{HOSTNAME}-{IP}"   # UNIQUE IDENTIFIER

BATCH_SIZE = 20
FLUSH_INTERVAL = 3

OFFSET_FILE = "agent_offsets.json"

LOG_FILES = [
    "/var/log/syslog",
    "/var/log/auth.log",
    "/var/log/dpkg.log"
]

# ==============================
# LOAD / SAVE OFFSETS (IMPORTANT)
# ==============================
def load_offsets():
    if os.path.exists(OFFSET_FILE):
        try:
            with open(OFFSET_FILE, "r") as f:
                content = f.read().strip()
                if not content:
                    return {}   # handle empty file
                return json.loads(content)
        except:
            return {}   # handle corruption
    return {}
def save_offsets(offsets):
    with open(OFFSET_FILE, "w") as f:
        json.dump(offsets, f)

# ==============================
# SYSTEM METRICS
# ==============================
def get_system_metrics():
    return {
        "cpu": psutil.cpu_percent(interval=0.5),
        "memory": psutil.virtual_memory().percent,
        "disk": psutil.disk_usage('/').percent
    }

# ==============================
# FOLLOW FILES (REAL-TIME + NO DUPLICATES)
# ==============================
def follow_files(files):
    file_handlers = {}
    offsets = load_offsets()

    for file in files:
        try:
            f = open(file, "r")

            # resume from last offset (IMPORTANT)
            if file in offsets:
                f.seek(offsets[file])
            else:
                f.seek(0, 2)  # first run → go to end

            file_handlers[file] = f
            print(f"[INFO] Monitoring: {file}")

        except Exception as e:
            print(f"[WARN] Cannot open {file}: {e}")

    while True:
        for file, f in file_handlers.items():
            where = f.tell()
            line = f.readline()

            if not line:
                f.seek(where)
                continue

            offsets[file] = f.tell()

            yield {
                "source": file,
                "log": line.strip(),
                "timestamp": datetime.utcnow().isoformat()
            }

        save_offsets(offsets)
        time.sleep(0.2)

# ==============================
# SEND LOGS (RETRY + SAFE)
# ==============================
def send_logs(batch):
    payload = {
        "agent_id": AGENT_ID,
        "hostname": HOSTNAME,
        "ip": IP,
        "timestamp": datetime.utcnow().isoformat(),
        "metrics": get_system_metrics(),
        "logs": batch
    }

    for attempt in range(3):  # retry
        try:
            response = requests.post(BACKEND_URL, json=payload, timeout=5)

            if response.status_code == 200:
                print(f"[OK] Sent {len(batch)} logs")
                return
            else:
                print(f"[WARN] {response.status_code}: {response.text}")

        except Exception as e:
            print(f"[ERROR] Attempt {attempt+1}: {e}")

        time.sleep(1)

    print("[FAIL] Dropping batch after retries")

# ==============================
# MAIN LOOP (REAL-TIME FEEL)
# ==============================
def main():
    batch = []
    last_flush = time.time()

    log_stream = follow_files(LOG_FILES)

    for entry in log_stream:
        batch.append(entry)

        # send immediately if batch full
        if len(batch) >= BATCH_SIZE:
            send_logs(batch)
            batch = []
            last_flush = time.time()

        # OR flush quickly (live feel)
        elif time.time() - last_flush >= FLUSH_INTERVAL:
            if batch:
                send_logs(batch)
                batch = []
            last_flush = time.time()

# ==============================
# ENTRY
# ==============================
if __name__ == "__main__":
    print(f"[START] Agent running on {HOSTNAME} ({IP})")
    main()

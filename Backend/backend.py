import os
import logging
from datetime import datetime
from typing import List, Dict

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

import psycopg2
from psycopg2 import pool, extras

# ==============================
# CONFIG
# ==============================
DB_CONFIG = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": "5432"
}

MIN_CONN = 2
MAX_CONN = 10

# ==============================
# LOGGING
# ==============================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("backend")

# ==============================
# FASTAPI
# ==============================
app = FastAPI()

# ==============================
# DB POOL
# ==============================
db_pool = psycopg2.pool.SimpleConnectionPool(
    MIN_CONN,
    MAX_CONN,
    **DB_CONFIG
)

# ==============================
# MODELS (UPDATED)
# ==============================
class LogItem(BaseModel):
    source: str
    log: str
    timestamp: str  # FROM AGENT

class LogBatch(BaseModel):
    agent_id: str
    hostname: str
    ip: str
    logs: List[LogItem]
    metrics: Dict
    timestamp: str


# ==============================
# CLASSIFICATION (IMPROVED)
# ==============================
def classify_log(source: str, log: str) -> str:
    log_lower = log.lower()

    if any(x in log_lower for x in [
        "failed password", "invalid user", "authentication failure",
        "sudo", "not in sudoers", "permission denied"
    ]):
        return "authentication"

    if any(x in log_lower for x in [
        "install", "installed", "upgrade", "setting up"
    ]):
        return "installation"

    if "ufw" in source or "iptables" in log_lower or "port" in log_lower:
        return "network"

    if any(x in log_lower for x in [
        "error", "failed", "panic", "segfault", "crash"
    ]):
        return "system_error"

    if any(x in log_lower for x in [
        "deleted", "removed", "unlink", "moved", "renamed"
    ]):
        return "file_activity"

    return "info"


# ==============================
# INGEST ENDPOINT (FIXED)
# ==============================
@app.post("/logs")
def ingest_logs(batch: LogBatch):
    conn = None

    try:
        conn = db_pool.getconn()
        records = []

        cpu = batch.metrics.get("cpu", 0)
        memory = batch.metrics.get("memory", 0)
        disk = batch.metrics.get("disk", 0)

        for item in batch.logs:
            category = classify_log(item.source, item.log)

            records.append((
                batch.agent_id,
                batch.hostname,
                batch.ip,
                item.log,
                category,
                cpu,
                memory,
                disk,
                item.timestamp  # ✅ USE AGENT TIME
            ))

        with conn.cursor() as cursor:
            extras.execute_values(
                cursor,
                """
                INSERT INTO logs
                (agent_id, hostname, ip, log_text, category, cpu, memory, disk, created_at)
                VALUES %s
                """,
                records
            )

        conn.commit()
        return {"status": "success"}

    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f"ERROR: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    finally:
        if conn:
            db_pool.putconn(conn)


# ==============================
# 🔥 IMPORTANT: UNIQUE VM VIEW
# ==============================
@app.get("/vms")
def get_vms():
    conn = db_pool.getconn()

    try:
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cursor:
            cursor.execute("""
                SELECT DISTINCT ON (agent_id)
                    agent_id,
                    hostname,
                    ip,
                    cpu,
                    memory,
                    disk,
                    created_at
                FROM logs
                ORDER BY agent_id, created_at DESC
            """)

            return cursor.fetchall()

    finally:
        db_pool.putconn(conn)


# ==============================
# 🔥 CATEGORY COUNTS (LIVE)
# ==============================
@app.get("/stats")
def get_stats():
    conn = db_pool.getconn()

    try:
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cursor:
            cursor.execute("""
                SELECT category, COUNT(*) as count
                FROM logs
                WHERE created_at > NOW() - INTERVAL '5 minutes'
                GROUP BY category
            """)

            return cursor.fetchall()

    finally:
        db_pool.putconn(conn)


# ==============================
# HEALTH
# ==============================
@app.get("/health")
def health():
    return {"status": "ok"}

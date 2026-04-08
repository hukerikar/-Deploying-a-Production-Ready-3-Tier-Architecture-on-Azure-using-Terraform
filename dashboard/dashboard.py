import streamlit as st
import psycopg2
import pandas as pd
from datetime import datetime
import time
import warnings
import os
# ==============================
# FIX WARNINGS
# ==============================
warnings.filterwarnings("ignore", category=UserWarning)

# ==============================
# CONFIG
# =============================

DB_CONFIG = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": "5432"
}

REFRESH_INTERVAL = 3

# ==============================
# DB CONNECTION
# ==============================
def get_connection():
    return psycopg2.connect(**DB_CONFIG)

# ==============================
# FETCH LOGS (FOR TABLE)
# ==============================
def fetch_logs(category=None):
    conn = get_connection()

    if category and category != "ALL":
        query = """
            SELECT hostname, log_text, category, created_at
            FROM logs
            WHERE category = %s
            ORDER BY created_at DESC
            LIMIT 300
        """
        df = pd.read_sql(query, conn, params=(category,))
    else:
        query = """
            SELECT hostname, log_text, category, created_at
            FROM logs
            ORDER BY created_at DESC
            LIMIT 300
        """
        df = pd.read_sql(query, conn)

    conn.close()
    return df


# ==============================
# FETCH ALL LOGS (FOR METRICS)
# ==============================
def fetch_all_logs():
    conn = get_connection()

    query = """
        SELECT category
        FROM logs
        WHERE created_at > NOW() - INTERVAL '5 minutes'
    """

    df = pd.read_sql(query, conn)
    conn.close()
    return df


# ==============================
# FETCH VM HEALTH (FINAL FIX)
# ==============================
def fetch_vm_health():
    conn = get_connection()

    query = """
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
    """

    df = pd.read_sql(query, conn)
    conn.close()
    return df


# ==============================
# UI CONFIG
# ==============================
st.set_page_config(page_title="SIEM Dashboard", layout="wide")
st.title("🛡️ SIEM Dashboard")

# ==============================
# SIDEBAR
# ==============================
category = st.sidebar.selectbox(
    "Category",
    ["ALL", "authentication", "installation", "file_activity", "system_error", "network", "info"]
)

search = st.sidebar.text_input("Search Logs")

# ==============================
# FETCH DATA
# ==============================
df = fetch_logs(category)
all_logs_df = fetch_all_logs()
vm_df = fetch_vm_health()

# SEARCH FILTER
if search:
    df = df[df["log_text"].str.contains(search, case=False, na=False)]

# ==============================
# METRICS (FIXED)
# ==============================
col1, col2, col3, col4, col5 = st.columns(5)

col1.metric("Total Logs", len(all_logs_df))
col2.metric("Auth", len(all_logs_df[all_logs_df["category"] == "authentication"]))
col3.metric("Install", len(all_logs_df[all_logs_df["category"] == "installation"]))
col4.metric("Errors", len(all_logs_df[all_logs_df["category"] == "system_error"]))
col5.metric("Network", len(all_logs_df[all_logs_df["category"] == "network"]))

st.markdown("---")

# ==============================
# VM HEALTH (FINAL FIXED UI)
# ==============================
st.subheader("🖥️ VM Health")

if not vm_df.empty:
    cols = st.columns(3)

    for i, row in vm_df.iterrows():
        with cols[i % 3]:
            st.markdown(f"### {row['hostname']} ({row['ip']})")

            st.metric("CPU", f"{int(row['cpu'])}%")
            st.progress(min(row["cpu"] / 100, 1.0))

            st.metric("RAM", f"{int(row['memory'])}%")
            st.progress(min(row["memory"] / 100, 1.0))

            st.metric("Disk", f"{int(row['disk'])}%")
            st.progress(min(row["disk"] / 100, 1.0))

else:
    st.info("No VM data available")

st.markdown("---")

# ==============================
# LOG TABLE
# ==============================
st.subheader("📜 Live Logs")

st.dataframe(df, use_container_width=True)

st.caption(f"Last refresh: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

# ==============================
# AUTO REFRESH
# ==============================
time.sleep(REFRESH_INTERVAL)
st.rerun()

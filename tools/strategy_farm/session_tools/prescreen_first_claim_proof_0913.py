"""PRESCREEN first-claim proof runner (Orchestrator 2026-09-13 13:4xZ), run detached.

Waits until every worker carries the PRESCREEN flag (chunk 73/73b reload complete: the given log shows
"T9 new pid"), then enqueues the canonical append-only rerun of the refused proof cell d4c790e7
(farmctl enqueue-backtest --append-only-rerun-of), and polls the successor until it reaches a verdict.
Writes everything to D:/QM/strategy_farm/logs/prescreen_proof_0913.log. Never releases the remaining
346 holds - that stays an orchestrator decision after reading the verdict (must be a PRESCREEN verdict
with verdict_taxonomy prescreen_measurement, never MEASURED).
"""
from __future__ import annotations

import datetime as dt
import re
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

REPO = Path("C:/QM/repo")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
CHUNK_LOG = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("D:/QM/strategy_farm/logs/reload_chunk73b.log")
WAIT_FOR = sys.argv[2] if len(sys.argv) > 2 else "T9 new pid"
PROOF_CELL = "d4c790e7-2dfa-5420-a192-1f1e3c40a30c"
OUT = Path("D:/QM/strategy_farm/logs/prescreen_proof_0913.log")
UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")


def log(msg: str) -> None:
    with OUT.open("a", encoding="utf-8") as fh:
        fh.write(f"{dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds')} {msg}\n")


def main() -> int:
    log(f"start; waiting for '{WAIT_FOR}' in {CHUNK_LOG}")
    deadline = time.time() + 6 * 3600
    while time.time() < deadline:
        try:
            if WAIT_FOR in CHUNK_LOG.read_text(encoding="utf-8", errors="replace"):
                break
        except OSError:
            pass
        time.sleep(30)
    else:
        log("timeout waiting for the reload; no rerun enqueued")
        return 1
    log("reload complete; enqueue append-only rerun")
    successor = None
    for _ in range(12):
        p = subprocess.run([sys.executable, "-X", "utf8", "tools/strategy_farm/farmctl.py", "enqueue-backtest",
                            "--append-only-rerun-of", PROOF_CELL], capture_output=True, text=True, cwd=str(REPO))
        text = (p.stdout or "") + (p.stderr or "")
        ids = [u for u in UUID_RE.findall(text) if u != PROOF_CELL]
        log(f"enqueue rc={p.returncode} tail={text.strip()[-300:]!r}")
        if p.returncode == 0 and ids:
            successor = ids[0]
            break
        time.sleep(20)
    if not successor:
        log("no successor id; stop")
        return 1
    log(f"successor {successor}; polling")
    for _ in range(90):
        conn = sqlite3.connect(DB, uri=True)
        row = conn.execute("SELECT status, verdict, verdict_taxonomy, evidence_path, claimed_by, updated_at "
                           "FROM work_items WHERE id=?", (successor,)).fetchone()
        conn.close()
        log(f"poll {row}")
        if row and row[0] in ("done", "failed"):
            log(f"RESULT successor={successor} status={row[0]} verdict={row[1]} taxonomy={row[2]} evidence={row[3]}")
            return 0
        time.sleep(40)
    log("poll timeout")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

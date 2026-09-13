"""Detached read-only poller: log every COMPILE_EA row that changes after start until 90 min pass (wave 2, 2026-09-13)."""
import datetime as dt, sqlite3, time
from pathlib import Path
OUT = Path("D:/QM/strategy_farm/logs/compile_wave_poll_0913.log"); DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
start = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
seen = {}
deadline = time.time() + 90 * 60
while time.time() < deadline:
    try:
        c = sqlite3.connect(DB, uri=True)
        rows = c.execute("select id,ea_id,status,verdict,claimed_by,updated_at,json_extract(payload_json,'$.verdict_reason') from work_items where phase='COMPILE_EA' and updated_at>=?", (start[:19],)).fetchall(); c.close()
        for r in rows:
            key = (r[0], r[2], r[3])
            if seen.get(r[0]) != key:
                seen[r[0]] = key
                with OUT.open("a", encoding="utf-8") as fh:
                    fh.write(f"{dt.datetime.now(dt.timezone.utc).strftime('%H:%M:%SZ')} {r[0][:8]} {r[1]} {r[2]} {r[3]} {r[4]} {r[6]}\n")
    except Exception as e:
        with OUT.open("a", encoding="utf-8") as fh: fh.write(f"err {e!r}\n")
    time.sleep(30)

"""Governed first-Q02 intakes for a compile wave under the CPU rule (CEO loop 2026-09-06).

For each `<compile_work_item_id> <ea_id>` line in the list file, sample the CPU
(5 x 1 s) and only when the maximum stays below the ceiling run
`farmctl intake-first-q02 --compile-work-item-id <id> --apply`.  Stops at the
row cap, on a CPU breach, or when D: free falls below the floor (the intake
writes a governed state backup per call).  Rows that already carry a Q02 row
are refused idempotently by farmctl and counted as skipped.

Usage: python intake_wave.py <list-file> <max-rows> [cpu-ceiling=97] [d-floor-gb=100]
"""
from __future__ import annotations

import datetime
import pathlib
import shutil
import subprocess
import sys

import psutil

REPO = pathlib.Path(r"C:\QM\repo")
list_file = pathlib.Path(sys.argv[1])
max_rows = int(sys.argv[2])
cpu_ceiling = float(sys.argv[3]) if len(sys.argv) > 3 else 97.0
d_floor = float(sys.argv[4]) if len(sys.argv) > 4 else 100.0


def log(msg: str) -> None:
    print(f"{datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')} {msg}", flush=True)


done = skipped = 0
for line in list_file.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    wid, ea = line.split()[:2]
    if done >= max_rows:
        log(f"cap {max_rows} reached")
        break
    free = shutil.disk_usage("D:/").free / 2**30
    if free < d_floor:
        log(f"STOP: D: free {free:.1f} GB < floor {d_floor}")
        break
    samples = [psutil.cpu_percent(interval=1) for _ in range(5)]
    if max(samples) >= cpu_ceiling:
        log(f"STOP: cpu {samples} >= {cpu_ceiling}")
        break
    r = subprocess.run([sys.executable, str(REPO / "tools/strategy_farm/farmctl.py"), "intake-first-q02",
                        "--compile-work-item-id", wid, "--apply"], capture_output=True, text=True, cwd=str(REPO))
    out = (r.stdout + r.stderr)
    ok = '"applied": true' in out
    if ok:
        done += 1
    else:
        skipped += 1
    tail = out.strip().splitlines()[-1][:160] if out.strip() else ""
    log(f"{ea} {wid[:8]} rc={r.returncode} ok={ok} cpu_max={max(samples)} D={free:.1f} | {tail}")
log(f"finished: intakes={done} skipped={skipped}")

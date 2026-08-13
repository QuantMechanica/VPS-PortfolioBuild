"""Finish tonight's containment release: sweep the dead-holder lease, release.

Step 2 of the 2026-08-13 T8 recovery. OWNER already opened the recovery window
(owner_window_receipt_t8_restore.json, open until 2026-08-14T08:03Z) and the
first release attempt stopped fail-closed on the last guard: the global lease
record. Its holder (pythonw pid 19420, T8, acquired 19:55:29Z during the OFF
drain) is dead; this script re-proves that before touching anything.

    ! python C:/QM/repo/tools/strategy_farm/finish_containment_release.py

Refuses unless: the recorded holder pid is dead AND no pythonw.exe processes
exist at all. Sweeps the lease aside with the established dead-holder suffix
(precedent: custom_history_global.lease.stale_t1_pid15696_dead_20260810T082502Z),
then runs the governed release-containment and prints the final mode.
"""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

A = Path(r'D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809')
LEASE = Path(r'D:\QM\strategy_farm\state\custom_history_global.lease')
MODE_JSON = Path(r'D:\QM\strategy_farm\state\custom_history_containment_mode.json')
MIGRATION = Path(r'C:\QM\repo\tools\strategy_farm\custom_history_migration.py')


def pid_alive(pid: int) -> bool:
    out = subprocess.run(
        ['tasklist', '/FI', f'PID eq {pid}', '/FO', 'CSV', '/NH'],
        capture_output=True, text=True, timeout=30).stdout
    return str(pid) in out


def pythonw_count() -> int:
    out = subprocess.run(
        ['tasklist', '/FI', 'IMAGENAME eq pythonw.exe', '/FO', 'CSV', '/NH'],
        capture_output=True, text=True, timeout=30).stdout
    return out.count('pythonw.exe')


def main() -> int:
    if LEASE.exists():
        rec = json.loads(LEASE.read_text(encoding='utf-8'))
        pid = int(rec.get('owner_pid') or 0)
        print(f'lease holder pid={pid} terminal={rec.get("terminal")} '
              f'work_item={rec.get("work_item_id")}')
        if pid and pid_alive(pid):
            print(f'REFUSING: lease holder pid {pid} is ALIVE — this lease is not stale')
            return 2
        n = pythonw_count()
        if n:
            print(f'REFUSING: {n} pythonw.exe process(es) still running — drain first')
            return 2
        ts = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        target = LEASE.with_name(f'{LEASE.name}.stale_t8_pid{pid}_dead_{ts}')
        LEASE.rename(target)
        print(f'lease swept aside: {target.name}')
    else:
        print('lease record already absent')

    cmd = [sys.executable, str(MIGRATION), 'release-containment',
           '--manifest', str(A / 'archive_manifest_owner_approved_t8_restore.json'),
           '--owner-receipt', str(A / 'owner_window_receipt_t8_restore.json'),
           '--audit', str(A / 'isolation_audit_3.json'),
           '--audit', str(A / 'isolation_audit_4.json'),
           '--reason', 't8_manifest_archives_restored_content_verified_from_canonical_t1',
           '--execute']
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600,
                          cwd=r'C:\QM\repo')
    print((proc.stdout or '').strip()[-2000:])
    if (proc.stderr or '').strip():
        print((proc.stderr or '').strip()[-800:])
    if proc.returncode != 0:
        print(f'release-containment FAILED with exit {proc.returncode}')
        return proc.returncode

    mode = json.loads(MODE_JSON.read_text(encoding='utf-8'))
    print(f'containment enabled = {mode.get("enabled")}  (must be False)')
    return 0 if mode.get('enabled') is False else 1


if __name__ == '__main__':
    sys.exit(main())

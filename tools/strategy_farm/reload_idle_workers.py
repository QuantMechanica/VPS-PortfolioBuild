"""Bounded, identity-checked rolling reload; never stop a runner or terminal.

Run from the existing interactive factory session. All stops are serialized
against worker claims, require no active DB row and no child process, and are
followed by the normal resource-governed missing-worker starter. Receipt-only
default; --apply explicitly enables the rolling reload.
"""
from __future__ import annotations
import argparse
import ctypes
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import time
import psutil
from factory_mutation_lock import FactoryMutationLock

REPO = Path(__file__).resolve().parents[2]
ROOT = Path('D:/QM/strategy_farm')
WORKER = REPO / 'tools/strategy_farm/terminal_worker.py'


def terminal_for(args: list[str]) -> str | None:
    if not any(Path(a).resolve() == WORKER.resolve() for a in args if a.endswith('terminal_worker.py')):
        return None
    if '--root' not in args or Path(args[args.index('--root') + 1]).resolve() != ROOT.resolve():
        return None
    try:
        terminal = args[args.index('--terminal') + 1].upper()
    except (ValueError, IndexError):
        return None
    return terminal if re.fullmatch(r'T(?:[1-9]|10)', terminal) else None


def workers() -> dict[str, psutil.Process]:
    found = {}
    for proc in psutil.process_iter(['cmdline']):
        try:
            term = terminal_for(proc.info['cmdline'] or [])
            if term:
                if term in found:
                    raise RuntimeError(f'Duplicate worker for {term}; refusing reload')
                found[term] = proc
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return found


def idle(term: str, proc: psutil.Process) -> bool:
    if terminal_for(proc.cmdline()) != term or proc.children(recursive=True):
        return False
    with sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True, timeout=2) as conn:
        if conn.execute("SELECT 1 FROM work_items WHERE status='active' AND claimed_by=? LIMIT 1", (term,)).fetchone():
            return False
    for child in psutil.process_iter(['name', 'exe']):
        if (child.info['name'] or '').lower() == 'terminal64.exe':
            exe = (child.info['exe'] or '').replace('\\', '/').lower()
            if re.fullmatch(rf'[cd]:/qm/mt5/{term.lower()}/(?:mt5_base/)?terminal64.exe', exe):
                return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--terminals', nargs='+', required=True)
    parser.add_argument('--max-minutes', type=float, default=45)
    parser.add_argument('--spacing-seconds', type=float, default=150)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    targets = list(dict.fromkeys(t.upper() for t in args.terminals))
    if any(not re.fullmatch(r'T(?:[1-9]|10)', t) for t in targets):
        raise ValueError('Only T1-T10 are in scope')
    if args.spacing_seconds < 150 or not 0 < args.max_minutes <= 120:
        raise ValueError('Require >=150 s spacing and a bounded <=120 min window')
    sid = ctypes.c_ulong()
    if not ctypes.windll.kernel32.ProcessIdToSessionId(os.getpid(), ctypes.byref(sid)) or not sid.value:
        raise RuntimeError('An existing nonzero interactive session is required')
    source_sha = hashlib.sha256(WORKER.read_bytes()).hexdigest()
    receipt = {'started_at': dt.datetime.now(dt.UTC).isoformat(), 'apply': args.apply,
               'worker_sha256': source_sha, 'session_id': sid.value, 'reloaded': [], 'pending': targets}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    def publish():
        args.out.write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    publish()
    if not args.apply:
        print(json.dumps(receipt)); return 0
    deadline = time.monotonic() + args.max_minutes * 60
    while targets and time.monotonic() < deadline:
        if (ROOT/'state/FACTORY_OFF.flag').exists() or (ROOT/'state/FACTORY_OFF_REQUEST.flag').exists():
            receipt['stopped_reason'] = 'factory_off'; break
        if hashlib.sha256(WORKER.read_bytes()).hexdigest() != source_sha:
            receipt['stopped_reason'] = 'worker_source_changed'; break
        picked = None
        for term, proc in workers().items():
            if term not in targets:
                continue
            try:
                if not idle(term, proc):
                    continue
                # Capture only the worker's runtime environment; never print it.
                env = proc.environ()
                with FactoryMutationLock(owner=f'bounded_idle_reload:{term}'):
                    if (ROOT/'state/FACTORY_OFF.flag').exists() or not idle(term, proc):
                        continue
                    before = {'terminal': term, 'old_pid': proc.pid, 'old_created': proc.create_time()}
                    proc.terminate()  # psutil checks PID reuse; no recursive/tree stop
                    proc.wait(timeout=5)
                    picked = before
                break
            except (RuntimeError, psutil.NoSuchProcess, psutil.TimeoutExpired):
                continue
        if picked is None:
            time.sleep(10); continue
        for key in ('PYTHONHOME', 'PYTHONPATH'):
            env.pop(key, None)
        starter = subprocess.run([sys.executable, str(REPO/'tools/strategy_farm/start_terminal_workers.py'), '--dedupe'],
                                 cwd=REPO, env=env, capture_output=True, text=True, timeout=60,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        time.sleep(5)
        after = workers().get(picked['terminal'])
        picked.update(new_pid=after.pid if after else None, starter_exit=starter.returncode,
                      at_utc=dt.datetime.now(dt.UTC).isoformat())
        receipt['reloaded'].append(picked)
        if starter.returncode or after is None or after.pid == picked['old_pid']:
            receipt['stopped_reason'] = 'replacement_not_verified'; publish(); break
        targets.remove(picked['terminal']); publish(); print(json.dumps(picked), flush=True)
        if targets:
            time.sleep(args.spacing_seconds)
    receipt['finished_at'] = dt.datetime.now(dt.UTC).isoformat(); publish()
    return 0 if not targets else 2


if __name__ == '__main__':
    raise SystemExit(main())

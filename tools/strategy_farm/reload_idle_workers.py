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
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import time
import psutil
try:
    from factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))
from tools.strategy_farm import identity_hash  # noqa: E402
ROOT = Path('D:/QM/strategy_farm')
WORKER = REPO / 'tools/strategy_farm/terminal_worker.py'
MEMORY_LIMIT_FLAG = 'QM_TESTER_MEMORY_LIMIT_V1'
MEMORY_LIMIT_CANARY_ID = 'QM_TESTER_MEMORY_LIMIT_CANARY_WORK_ITEM_ID'
MEMORY_LIMIT_CANARY_BYTES = 'QM_TESTER_MEMORY_LIMIT_CANARY_BYTES'
MEMORY_LIMIT_A2_PRODUCTION = 'QM_TESTER_MEMORY_LIMIT_A2_PRODUCTION_V1'
MEMORY_LIMIT_ENV_KEYS = (
    MEMORY_LIMIT_FLAG,
    MEMORY_LIMIT_CANARY_ID,
    MEMORY_LIMIT_CANARY_BYTES,
    MEMORY_LIMIT_A2_PRODUCTION,
)


def memory_limit_reload_environment(
    environ: dict[str, str],
    *,
    canary_work_item_id: str | None = None,
    canary_limit_bytes: int | None = None,
    disable: bool = False,
    production_a2: bool = False,
) -> tuple[dict[str, str], dict[str, str]]:
    """Return the exact worker env and its non-secret memory-limit receipt."""

    if sum(bool(value) for value in (disable, canary_work_item_id, production_a2)) > 1:
        raise ValueError('canary, production, and rollback are mutually exclusive')
    updated = dict(environ)
    if disable:
        updated[MEMORY_LIMIT_FLAG] = '0'
        updated.pop(MEMORY_LIMIT_CANARY_ID, None)
        updated.pop(MEMORY_LIMIT_CANARY_BYTES, None)
        updated.pop(MEMORY_LIMIT_A2_PRODUCTION, None)
    elif canary_work_item_id:
        work_item_id = str(canary_work_item_id).strip()
        try:
            limit_bytes = int(canary_limit_bytes or 0)
        except (TypeError, ValueError):
            limit_bytes = 0
        if not work_item_id:
            raise ValueError('canary work-item id must be non-empty')
        if limit_bytes < 64 * 1024 ** 2:
            raise ValueError('canary limit must be at least 64 MiB')
        updated[MEMORY_LIMIT_FLAG] = '1'
        updated[MEMORY_LIMIT_CANARY_ID] = work_item_id
        updated[MEMORY_LIMIT_CANARY_BYTES] = str(limit_bytes)
        updated.pop(MEMORY_LIMIT_A2_PRODUCTION, None)
    elif production_a2:
        updated[MEMORY_LIMIT_FLAG] = '1'
        updated[MEMORY_LIMIT_A2_PRODUCTION] = '1'
        updated.pop(MEMORY_LIMIT_CANARY_ID, None)
        updated.pop(MEMORY_LIMIT_CANARY_BYTES, None)
    expected = {
        key: updated[key]
        for key in MEMORY_LIMIT_ENV_KEYS
        if key in updated
    }
    return updated, expected


def routine_reload_memory_limit_refusal(
    environ: dict[str, str],
) -> dict[str, object] | None:
    """Require an explicit rollback before reloading a canary-bound worker."""

    enabled = str(environ.get(MEMORY_LIMIT_FLAG, "")).strip() == "1"
    canary_work_item_id = str(
        environ.get(MEMORY_LIMIT_CANARY_ID, "")
    ).strip()
    canary_bytes_configured = bool(
        str(environ.get(MEMORY_LIMIT_CANARY_BYTES, "")).strip()
    )
    if not (enabled or canary_work_item_id or canary_bytes_configured):
        return None
    return {
        "reason": "memory_limit_canary_requires_explicit_off",
        "memory_limit_enabled": enabled,
        "canary_work_item_id": canary_work_item_id or None,
        "canary_bytes_configured": canary_bytes_configured,
        "required_option": "--memory-limit-off",
    }


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
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--memory-limit-canary-work-item-id')
    mode.add_argument(
        '--memory-limit-a2-production', action='store_true',
        help='restart one idle worker in cap-1, Track-A2-only production mode',
    )
    mode.add_argument(
        '--memory-limit-off',
        action='store_true',
        help='restart one idle worker with the feature disabled and canary binding removed',
    )
    parser.add_argument('--memory-limit-canary-bytes', type=int)
    args = parser.parse_args()
    targets = list(dict.fromkeys(t.upper() for t in args.terminals))
    if any(not re.fullmatch(r'T(?:[1-9]|10)', t) for t in targets):
        raise ValueError('Only T1-T10 are in scope')
    if args.spacing_seconds < 150 or not 0 < args.max_minutes <= 120:
        raise ValueError('Require >=150 s spacing and a bounded <=120 min window')
    if bool(args.memory_limit_canary_work_item_id) != bool(
        args.memory_limit_canary_bytes
    ):
        raise ValueError(
            '--memory-limit-canary-work-item-id and '
            '--memory-limit-canary-bytes are required together'
        )
    memory_limit_mode = bool(
        args.memory_limit_canary_work_item_id or args.memory_limit_off
        or args.memory_limit_a2_production
    )
    if memory_limit_mode and len(targets) != 1:
        raise ValueError('memory-limit activation/rollback requires exactly one terminal')
    _, requested_memory_env = memory_limit_reload_environment(
        {},
        canary_work_item_id=args.memory_limit_canary_work_item_id,
        canary_limit_bytes=args.memory_limit_canary_bytes,
        disable=args.memory_limit_off,
        production_a2=args.memory_limit_a2_production,
    )
    sid = ctypes.c_ulong()
    if not ctypes.windll.kernel32.ProcessIdToSessionId(os.getpid(), ctypes.byref(sid)) or not sid.value:
        raise RuntimeError('An existing nonzero interactive session is required')
    source_sha = identity_hash.identity_sha256(
        WORKER, kind=identity_hash.TRACKED_TEXT
    )
    receipt = {'started_at': dt.datetime.now(dt.UTC).isoformat(), 'apply': args.apply,
               'worker_sha256': source_sha, 'session_id': sid.value, 'reloaded': [], 'pending': targets,
               'memory_limit_mode': (
                   'canary' if args.memory_limit_canary_work_item_id
                   else 'a2_production' if args.memory_limit_a2_production
                   else 'off' if args.memory_limit_off else 'unchanged'
               ),
               'memory_limit_canary_work_item_id': args.memory_limit_canary_work_item_id,
               'memory_limit_canary_bytes': args.memory_limit_canary_bytes,
               'memory_limit_requested_environment': requested_memory_env}
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
        if identity_hash.identity_sha256(
            WORKER, kind=identity_hash.TRACKED_TEXT
        ) != source_sha:
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
                if not memory_limit_mode:
                    routine_refusal = routine_reload_memory_limit_refusal(env)
                    if routine_refusal is not None:
                        receipt['stopped_reason'] = routine_refusal['reason']
                        receipt['refused_terminal'] = term
                        receipt['routine_reload_refusal'] = routine_refusal
                        receipt['finished_at'] = dt.datetime.now(dt.UTC).isoformat()
                        publish()
                        return 2
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
        env, expected_memory_env = memory_limit_reload_environment(
            env,
            canary_work_item_id=args.memory_limit_canary_work_item_id,
            canary_limit_bytes=args.memory_limit_canary_bytes,
            disable=args.memory_limit_off,
            production_a2=args.memory_limit_a2_production,
        )
        starter = subprocess.run([sys.executable, str(REPO/'tools/strategy_farm/start_terminal_workers.py'),
                                  '--dedupe', '--only-terminal', picked['terminal'],
                                  '--expected-count', '1'],
                                 cwd=REPO, env=env, capture_output=True, text=True, timeout=60,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        time.sleep(5)
        after = workers().get(picked['terminal'])
        actual_memory_env = None
        if after is not None:
            try:
                after_env = after.environ()
                actual_memory_env = {
                    key: after_env[key]
                    for key in MEMORY_LIMIT_ENV_KEYS
                    if key in after_env
                }
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                actual_memory_env = None
        picked.update(new_pid=after.pid if after else None, starter_exit=starter.returncode,
                      at_utc=dt.datetime.now(dt.UTC).isoformat(),
                      memory_limit_env_expected=expected_memory_env,
                      memory_limit_env_actual=actual_memory_env,
                      memory_limit_env_verified=(actual_memory_env == expected_memory_env))
        receipt['reloaded'].append(picked)
        if (starter.returncode or after is None or after.pid == picked['old_pid']
                or actual_memory_env != expected_memory_env):
            receipt['stopped_reason'] = 'replacement_not_verified'; publish(); break
        targets.remove(picked['terminal']); publish(); print(json.dumps(picked), flush=True)
        if targets:
            time.sleep(args.spacing_seconds)
    receipt['finished_at'] = dt.datetime.now(dt.UTC).isoformat(); publish()
    return 0 if not targets else 2


if __name__ == '__main__':
    raise SystemExit(main())

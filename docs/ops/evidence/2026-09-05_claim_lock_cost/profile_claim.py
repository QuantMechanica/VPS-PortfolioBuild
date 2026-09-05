"""Profile claim SQL on an online SQLite backup; never operate a terminal."""
import argparse
import contextlib
import json
import io
import os
from pathlib import Path
import sqlite3
import sys
import tempfile
import time
from unittest.mock import patch
from urllib.parse import urlparse
from urllib.request import url2pathname

ap = argparse.ArgumentParser()
ap.add_argument("--repo", required=True)
ap.add_argument("--label", required=True)
args = ap.parse_args()
repo = Path(args.repo)
out = Path("C:/QM/repo/docs/ops/evidence/2026-09-05_claim_lock_cost")
scratch = Path(tempfile.gettempdir()) / "qm_claim_lock_cost_20260905"
scratch.mkdir(exist_ok=True)
root = scratch / args.label
(root / "state").mkdir(parents=True, exist_ok=True)
base = scratch / "snapshot.sqlite"
original_connect = sqlite3.connect
if not base.exists():
    with original_connect(Path("D:/QM/strategy_farm/state/farm_state.sqlite").as_uri() + "?mode=ro", uri=True) as source:
        with original_connect(base) as destination:
            source.backup(destination, pages=2048)
with original_connect(base) as source, original_connect(root / "state/farm_state.sqlite") as destination:
    source.backup(destination)
sys.path.insert(0, str(repo))
sys.path.insert(0, str(repo / "tools/strategy_farm"))
import farmctl
import terminal_worker as worker

sql_records = []
transactions = []
lock_holds = []
held = False


class TimedCursor(sqlite3.Cursor):
    record = None

    def execute(self, sql, parameters=()):
        started = time.perf_counter()
        in_txn = self.connection.in_transaction
        try:
            return super().execute(sql, parameters)
        finally:
            self.record = {"sql": sql, "in_factory_lock": held, "in_transaction": in_txn,
                           "seconds": time.perf_counter() - started, "plan": []}
            if held:
                sql_records.append(self.record)
                try:
                    raw = sqlite3.Connection.execute(self.connection, "EXPLAIN QUERY PLAN " + sql, parameters)
                    self.record["plan"] = [list(r) for r in raw.fetchall()]
                except sqlite3.Error as exc:
                    self.record["plan_error"] = str(exc)
            if sql.strip().upper() == "BEGIN IMMEDIATE":
                self.connection.tx_started = time.perf_counter()

    def fetchall(self):
        started = time.perf_counter()
        try:
            return super().fetchall()
        finally:
            if self.record is not None:
                self.record["seconds"] += time.perf_counter() - started

    def fetchone(self):
        started = time.perf_counter()
        try:
            return super().fetchone()
        finally:
            if self.record is not None:
                self.record["seconds"] += time.perf_counter() - started


class TimedConnection(sqlite3.Connection):
    tx_started = None

    def execute(self, sql, parameters=()):
        return self.cursor(factory=TimedCursor).execute(sql, parameters)

    def commit(self):
        super().commit()
        if self.tx_started is not None:
            transactions.append(time.perf_counter() - self.tx_started)
            self.tx_started = None

    def rollback(self):
        super().rollback()
        self.tx_started = None


def connect(database, *positional, **kwargs):
    # Any accidental cross-root connection during the replay fails closed.
    path = url2pathname(urlparse(str(database)).path) if str(database).startswith("file:") else str(database)
    if path != ":memory:" and not Path(path).resolve().is_relative_to(scratch.resolve()):
        raise RuntimeError("Replay refused connection outside its disposable DB root")
    kwargs["factory"] = TimedConnection
    return original_connect(database, *positional, **kwargs)


real_lock = worker.FactoryMutationLock


class TimedLock(real_lock):
    def __enter__(self):
        global held
        super().__enter__()
        self.started = time.perf_counter()
        held = True
        return self

    def __exit__(self, *args):
        global held
        lock_holds.append(time.perf_counter() - self.started)
        held = False
        return super().__exit__(*args)


with contextlib.ExitStack() as stack:
    stack.enter_context(patch.object(sqlite3, "connect", connect))
    stack.enter_context(patch.object(worker, "FactoryMutationLock", TimedLock))
    for name, value in {"_commit_headroom_gb": 10000.0, "_free_ram_gb": 10000.0,
                        "_process_private_snapshot": ({}, {}, set()), "_multisymbol_ea_ids": frozenset(),
                        "_drain_window_enabled": False, "_is_governed_dl089_census_payload": False,
                        "_governed_analytic_claim_block": None,
                        "_p2_history_claimable": (True, {})}.items():
        if hasattr(worker, name):
            stack.enter_context(patch.object(worker, name, return_value=value))
    stack.enter_context(patch.object(worker.opt_census_pruning, "pruning_enabled", return_value=False))
    stack.enter_context(patch.object(farmctl, "_news_calendar_preflight", return_value={"ok": True}))
    stack.enter_context(patch.dict(os.environ, {worker.TEST_FREE_RAM_GB_ENV: "10000", "QM_DRAIN_WINDOW": "0", "QM_CLAIM_ORDER_CACHE_TTL_MS": "0"}))
    started = time.perf_counter()
    with contextlib.redirect_stdout(io.StringIO()):
        result = worker.claim_atomic(root, "T99")
    total = time.perf_counter() - started

receipt = {"label": args.label, "source_checkout": str(repo), "snapshot_bytes": base.stat().st_size,
           "total_seconds": total, "factory_lock_seconds": lock_holds,
           "write_transaction_seconds": transactions,
           "result": {k: (len(v) if isinstance(v, list) else v) for k, v in result.items() if k != "item"},
           "claimed_item_id": result.get("item", {}).get("id"),
           "sql": sql_records,
           "scope": "Disposable snapshot; OS resources and external sealed-ledger preflights stubbed; no runner or live DB write"}
(out / (args.label + ".json")).write_text(json.dumps(receipt, indent=2, default=str) + "\n", encoding="utf-8")
print(json.dumps({k: v for k, v in receipt.items() if k != "sql"}, indent=2, default=str))
print("SQL leaders:", [(r["seconds"], r["sql"][:110]) for r in sorted(sql_records, key=lambda x: -x["seconds"])[:8]])

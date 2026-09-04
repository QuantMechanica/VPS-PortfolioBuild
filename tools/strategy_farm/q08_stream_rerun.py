"""Append-only Q08 stream recovery after a terminal Q14 identity (task ccea329e).

The CLI is read-only. Only the canonical pump calls service(apply=True), under
the factory mutation lock. Bundle binding and Q08 verdict policies are unchanged.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import json
import os
import sqlite3
import sys
import time
import uuid
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import assemble_stream_bundle as bundle
from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock

SCHEMA = "qm.q08-stream-auto-rerun/v1"
STATE_NAME = "q08_stream_auto_rerun_watermark.json"
DISABLE_ENV = "QM_DISABLE_Q08_STREAM_AUTO_RERUN"
EPOCH = "1970-01-01T00:00:00+00:00"


def _cursor(timestamp: str, row_id: str) -> tuple[dt.datetime, str]:
    if not isinstance(timestamp, str) or not isinstance(row_id, str):
        raise ValueError("Q14 watermark timestamp and id must be strings")
    value = dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    if value.tzinfo is None:
        raise ValueError("Q14 watermark/timestamp must include a UTC offset")
    return value.astimezone(dt.timezone.utc), row_id


def _read_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"schema": SCHEMA, "updated_at": EPOCH, "q14_work_item_id": "", "retry_q14_ids": []}
    state = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(state, dict) or state.get("schema") != SCHEMA or not isinstance(state.get("retry_q14_ids"), list):
        raise ValueError("invalid Q08 stream rerun watermark schema")
    _cursor(state["updated_at"], state["q14_work_item_id"])
    if not all(isinstance(item, str) for item in state["retry_q14_ids"]):
        raise ValueError("invalid retry Q14 ids")
    return state


def _write_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(state, indent=2, sort_keys=True) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def rerun_reason(identity: dict[str, Any], timestamp: str) -> str:
    return (
        f"Q08 sealed-stream re-emission after Q14 {identity['q14_verdict']} {timestamp}: "
        "current-identity daily-PnL bytes missing from sleeve_streams; append-only "
        "rerun to reproduce the seal for the book-path bundle (D4)."
    )


def inspect_trigger(con, trigger: dict[str, Any], farm) -> dict[str, Any]:
    """Plan one exact rerun, with no bundle, queue, or state writes."""
    ea, symbol = trigger["ea_id"], trigger["symbol"]
    result = {"ea_id": ea, "symbol": symbol, "q14_work_item_id": trigger["id"]}
    identity = bundle.resolve_identity(con, ea, symbol)
    if not identity:
        return {**result, "action": "defer", "reason": "no_terminal_q14_identity"}
    if identity["q14_work_item_id"] != trigger["id"]:
        return {**result, "action": "skip", "reason": "superseded_q14_trigger"}
    result.update(identity)
    bound = bundle.find_bound_q08(con, ea, symbol, identity["identity_ex5_sha256"])
    if bound:
        return {**result, "action": "skip", "reason": "stream_already_bound", **bound}
    open_row = con.execute(
        "SELECT id FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q08' "
        "AND status IN ('pending','active') ORDER BY id LIMIT 1", (ea, symbol),
    ).fetchone()
    if open_row:
        return {**result, "action": "skip", "reason": "q08_pending_or_active", "existing_q08_id": open_row["id"]}
    reason = rerun_reason(identity, trigger["updated_at"])
    # Covers enqueue success followed by a process crash before event/watermark
    # persistence, including a rerun that already finished before the next cycle.
    prior = con.execute(
        "SELECT id FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q08' "
        "AND json_valid(payload_json) "
        "AND json_extract(payload_json,'$.rerun_reason')=? "
        "AND json_extract(payload_json,'$.expected_current_ex5_sha256')=? LIMIT 1",
        (ea, symbol, reason, identity["identity_ex5_sha256"]),
    ).fetchone()
    if prior:
        return {**result, "action": "skip", "reason": "trigger_rerun_already_recorded", "existing_q08_id": prior["id"]}
    predecessor = con.execute(
        "SELECT id FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q07' "
        "AND status='done' AND verdict='PASS' "
        "ORDER BY julianday(updated_at) DESC, updated_at DESC, id DESC LIMIT 1", (ea, symbol),
    ).fetchone()
    verdicts = tuple(sorted(bundle.Q08_STREAM_PASS_VERDICTS))
    target = con.execute(
        "SELECT id FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q08' "
        "AND status='done' AND verdict IN (" + ",".join("?" for _ in verdicts) + ") "
        "ORDER BY julianday(updated_at) DESC, updated_at DESC, id DESC LIMIT 1",
        (ea, symbol, *verdicts),
    ).fetchone()
    if not predecessor or not target:
        return {**result, "action": "defer", "reason": "missing_q07_pass_or_q08_pass_class_predecessor"}
    directory = farm._preferred_ea_dir(ea)
    binary = directory / f"{directory.name}.ex5" if directory else None
    if binary is None or not binary.is_file():
        return {**result, "action": "defer", "reason": "current_ex5_missing_or_ambiguous"}
    digest = bundle.sha256_file(binary)
    if digest != identity["identity_ex5_sha256"]:
        return {**result, "action": "defer", "reason": "current_binary_differs_from_q14_identity", "current_ex5_sha256": digest}
    return {**result, "action": "would_enqueue", "reason": "no_q08_stream_bound_to_identity",
        "enqueue_kwargs": {"ea_id": ea, "phase": "Q08",
            "predecessor_work_item_id": predecessor["id"], "append_only_rerun_of": target["id"],
            "expected_current_ex5_sha256": digest, "rerun_reason": reason}}


def service(root: Path, *, apply: bool = False, limit: int = 16,
            deadline_monotonic: float | None = None, farm_module=None) -> dict[str, Any]:
    if farm_module is None:
        from tools.strategy_farm import farmctl as farm_module
    farm = farm_module
    root = Path(root)
    state_path = root / "state" / STATE_NAME
    result: dict[str, Any] = {"schema": SCHEMA, "applied": apply, "watermark_path": str(state_path),
        "items": [], "created_count": 0, "would_enqueue_count": 0}
    if os.environ.get(DISABLE_ENV) == "1":
        return {**result, "applied": False, "reason": "disabled_by_environment"}
    if limit < 1:
        raise ValueError("limit must be positive")
    if apply:
        farm._assert_canonical_checkout()
    lock = FactoryMutationLock(root / "state" / "FACTORY_MUTATION.lock", owner="q08_stream_auto_rerun")
    try:
        with lock if apply else contextlib.nullcontext():
            # Check OFF while holding the same boundary as Factory_OFF/ON.
            if (root / "FACTORY_OFF.flag").exists():
                return {**result, "applied": False, "reason": "factory_off"}
            state = _read_state(state_path)
            highwater = _cursor(state["updated_at"], state["q14_work_item_id"])
            retry = set(state["retry_q14_ids"])
            retry_order = list(dict.fromkeys(state["retry_q14_ids"]))
            result["watermark_before"] = dict(state)
            con = bundle.open_ro(root / "state" / "farm_state.sqlite")
            try:
                verdicts = tuple(sorted(bundle.TERMINAL_PASS_VERDICTS))
                rows = [dict(row) for row in con.execute(
                    "SELECT id, ea_id, symbol, updated_at FROM work_items WHERE phase='Q14' "
                    "AND status='done' AND verdict IN (" + ",".join("?" for _ in verdicts) + ")",
                    verdicts,
                )]
                new_rows = sorted((row for row in rows if
                    _cursor(row["updated_at"], row["id"]) > highwater),
                    key=lambda row: _cursor(row["updated_at"], row["id"]))
                by_id = {row["id"]: row for row in rows}
                retry_rows = [by_id[wid] for wid in retry_order if wid in by_id and
                    _cursor(by_id[wid]["updated_at"], wid) <= highwater]
                retry_limit = min(len(retry_rows), limit // 2 if new_rows else limit)
                rows = retry_rows[:retry_limit] + new_rows[:limit - retry_limit]
                for trigger in rows:
                    if deadline_monotonic is not None and time.monotonic() >= deadline_monotonic:
                        result["budget_exhausted"] = True
                        break
                    if os.environ.get(DISABLE_ENV) == "1" or (root / "FACTORY_OFF.flag").exists():
                        result["stopped_before_next_trigger"] = True
                        break
                    item = inspect_trigger(con, trigger, farm)
                    if item["action"] == "would_enqueue":
                        result["would_enqueue_count"] += 1
                        if apply:
                            answer = farm.enqueue_cascade_backtest_for_ea(root, **item["enqueue_kwargs"])
                            item["enqueue_result"] = answer
                            created = answer.get("created", [])
                            if len(created) == 1 and not answer.get("requeued"):
                                item.update(action="enqueued", new_q08_work_item_id=created[0]["id"])
                                result["created_count"] += 1
                                with farm.connect(root) as writer:
                                    farm.event(writer, "work_item", created[0]["id"],
                                        "q08_stream_rerun_auto_minted", {
                                            "ea_id": trigger["ea_id"], "symbol": trigger["symbol"],
                                            "q14_work_item_id": trigger["id"],
                                            "q07_work_item_id": item["enqueue_kwargs"]["predecessor_work_item_id"],
                                            "q08_rerun_of_work_item_id": item["enqueue_kwargs"]["append_only_rerun_of"],
                                            "new_q08_work_item_id": created[0]["id"],
                                            "expected_current_ex5_sha256": item["identity_ex5_sha256"],
                                        })
                                    writer.commit()
                            else:
                                # farmctl can report enqueued=True for a refusal;
                                # only an actual created row counts as delivery.
                                item.update(action="defer", reason="governed_enqueue_created_no_single_row")
                    result["items"].append(item)
                    if trigger["id"] in retry_order:
                        retry_order.remove(trigger["id"])
                    if item["action"] == "defer":
                        retry.add(trigger["id"])
                        retry_order.append(trigger["id"])
                    else:
                        retry.discard(trigger["id"])
                    cursor = _cursor(trigger["updated_at"], trigger["id"])
                    if cursor > highwater:
                        highwater = cursor
                        state.update(updated_at=trigger["updated_at"], q14_work_item_id=trigger["id"])
                    state["retry_q14_ids"] = retry_order.copy()
                    if apply:
                        _write_state(state_path, state)
            finally:
                con.close()
            result["watermark_after" if apply else "proposed_watermark"] = state
            return result
    except (OSError, RuntimeError, ValueError, KeyError, sqlite3.Error) as exc:
        return {**result, "error": f"{type(exc).__name__}: {exc}", "reason": "q08_stream_service_deferred"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path("D:/QM/strategy_farm"))
    parser.add_argument("--limit", type=int, default=100)
    args = parser.parse_args()
    result = service(args.root, limit=args.limit)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if result.get("error") else 0


if __name__ == "__main__":
    raise SystemExit(main())

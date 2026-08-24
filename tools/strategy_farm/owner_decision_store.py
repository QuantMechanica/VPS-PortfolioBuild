#!/usr/bin/env python3
"""Durable OWNER decision and decision-scoped handoff store.

The queue is a materialized JSON read model. Every OWNER answer is first
appended as an immutable JSONL receipt, then reflected into the queue and the
human-readable Vault. Terminal YES/NO receipts reserve exactly one governed
agent-task identity. They never grant T_Live, AutoTrading, deployment, or
authority beyond the selected effect printed on the decision card.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import hmac
import json
import os
import re
import sys
import threading
import uuid
from pathlib import Path
from typing import Any, Iterator, Mapping


FEED_SCHEMA = "qm.owner-decisions/v2"
LEGACY_RECEIPT_SCHEMA = "qm.owner-decision-receipt/v1"
RECEIPT_SCHEMA = "qm.owner-decision-receipt/v2"
SUPPORTED_RECEIPT_SCHEMAS = frozenset({LEGACY_RECEIPT_SCHEMA, RECEIPT_SCHEMA})
ALLOWED_STATUSES = frozenset({"OPEN", "DEFERRED", "DECIDED"})
ALLOWED_DECISIONS = frozenset({"YES", "NO", "DEFERRED"})
DEFAULT_FEED = Path(r"D:\QM\reports\state\owner_decisions.json")
DEFAULT_RECEIPTS = Path(r"D:\QM\reports\state\owner_decision_receipts.jsonl")
DEFAULT_SEED = Path(__file__).resolve().parent / "config" / "owner_decisions.v2.bootstrap.json"
DEFAULT_VAULT_OWNER = Path(
    r"G:\My Drive\QuantMechanica - Company Reference\12 ToDo\AI ToDos\OWNER.md"
)
DEFAULT_VAULT_INDEX = Path(
    r"G:\My Drive\QuantMechanica - Company Reference\12 ToDo\_INDEX.md"
)
VAULT_QUEUE_START = "<!-- QM:MISSION_CONTROL_DECISIONS:START -->"
VAULT_QUEUE_END = "<!-- QM:MISSION_CONTROL_DECISIONS:END -->"
REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{7,127}$")
_PROCESS_LOCK = threading.RLock()


class DecisionStoreError(RuntimeError):
    """The request or durable decision state failed validation."""


class DecisionConflict(DecisionStoreError):
    """The item has already reached a terminal decision."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def execution_task_id(receipt_id: str) -> str:
    """Reserve one stable router-task UUID for one OWNER receipt."""

    token = str(receipt_id or "").strip()
    try:
        uuid.UUID(token)
    except ValueError as exc:
        raise DecisionStoreError(f"invalid receipt id for execution task: {token!r}") from exc
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"qm.owner-decision-execution:{token}"))


def decision_card_binding(item: Mapping[str, Any]) -> dict[str, Any]:
    """Return the immutable OWNER-visible fields that authorize a follow-up."""

    return {
        "id": str(item.get("id") or ""),
        "question": str(item.get("question") or ""),
        "recommendation": str(item.get("recommendation") or ""),
        "yes_effect": str(item.get("yes_effect") or ""),
        "no_effect": str(item.get("no_effect") or ""),
        "depends_on": sorted(str(value) for value in (item.get("depends_on") or [])),
    }


def decision_card_sha256(item: Mapping[str, Any]) -> str:
    return sha256_bytes(canonical_bytes(decision_card_binding(item)))


def _file_sha(path: Path) -> str | None:
    return sha256_bytes(path.read_bytes()) if path.is_file() else None


def _validate_item(item: Mapping[str, Any]) -> None:
    required = (
        "id", "status", "category", "question", "recommendation",
        "yes_effect", "no_effect", "cost_of_wait", "severity",
    )
    missing = [key for key in required if not str(item.get(key) or "").strip()]
    if missing:
        raise DecisionStoreError(
            f"decision item {item.get('id') or '?'} missing fields: {', '.join(missing)}"
        )
    item_id = str(item["id"])
    if not re.fullmatch(r"[A-Z0-9][A-Z0-9_.:-]{4,127}", item_id):
        raise DecisionStoreError(f"invalid decision id: {item_id}")
    status = str(item["status"]).upper()
    if status not in ALLOWED_STATUSES:
        raise DecisionStoreError(f"invalid status for {item_id}: {status}")
    evidence = item.get("evidence") or []
    if not isinstance(evidence, list) or not all(isinstance(value, str) for value in evidence):
        raise DecisionStoreError(f"invalid evidence list for {item_id}")
    dependencies = item.get("depends_on") or []
    if not isinstance(dependencies, list) or not all(
        isinstance(value, str) for value in dependencies
    ):
        raise DecisionStoreError(f"invalid dependency list for {item_id}")


def validate_feed(feed: Mapping[str, Any]) -> None:
    if feed.get("schema_version") != FEED_SCHEMA:
        raise DecisionStoreError(
            f"unsupported feed schema: {feed.get('schema_version')!r}"
        )
    if not isinstance(feed.get("revision"), int) or int(feed["revision"]) < 0:
        raise DecisionStoreError("feed revision must be a non-negative integer")
    items = feed.get("items")
    if not isinstance(items, list):
        raise DecisionStoreError("feed items must be a list")
    seen: set[str] = set()
    for item in items:
        if not isinstance(item, dict):
            raise DecisionStoreError("feed item must be an object")
        _validate_item(item)
        item_id = str(item["id"])
        if item_id in seen:
            raise DecisionStoreError(f"duplicate decision id: {item_id}")
        seen.add(item_id)
    for item in items:
        item_id = str(item["id"])
        dependencies = list(item.get("depends_on") or [])
        if item_id in dependencies:
            raise DecisionStoreError(f"decision cannot depend on itself: {item_id}")
        unknown = sorted(set(dependencies) - seen)
        if unknown:
            raise DecisionStoreError(
                f"decision {item_id} has unknown dependencies: {', '.join(unknown)}"
            )


def load_feed(path: Path = DEFAULT_FEED) -> dict[str, Any]:
    try:
        feed = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise DecisionStoreError(f"decision feed missing: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise DecisionStoreError(f"decision feed unreadable: {path}: {exc}") from exc
    if not isinstance(feed, dict):
        raise DecisionStoreError("decision feed root must be an object")
    validate_feed(feed)
    return feed


def open_items(feed: Mapping[str, Any]) -> list[dict[str, Any]]:
    return [
        dict(item)
        for item in feed.get("items") or []
        if str(item.get("status") or "").upper() in {"OPEN", "DEFERRED"}
    ]


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f"{path.name}.tmp.{os.getpid()}.{threading.get_ident()}")
    try:
        with temp.open("wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def _write_json(path: Path, value: Mapping[str, Any]) -> None:
    _atomic_write(path, json.dumps(value, indent=2, sort_keys=True).encode("utf-8") + b"\n")


@contextlib.contextmanager
def exclusive_store_lock(feed_path: Path) -> Iterator[None]:
    """Serialize writers in-process and across local service processes."""

    lock_path = feed_path.with_suffix(feed_path.suffix + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with _PROCESS_LOCK, lock_path.open("a+b") as handle:
        handle.seek(0, os.SEEK_END)
        if handle.tell() == 0:
            handle.write(b"0")
            handle.flush()
        handle.seek(0)
        if os.name == "nt":
            import msvcrt

            msvcrt.locking(handle.fileno(), msvcrt.LK_LOCK, 1)
            try:
                yield
            finally:
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:  # pragma: no cover - production is Windows
            import fcntl

            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def _markdown_text(value: Any) -> str:
    return str(value or "").replace("\r", " ").replace("\n", " ").strip()


def render_vault_queue(feed: Mapping[str, Any]) -> str:
    rows = [
        VAULT_QUEUE_START,
        "## Mission-Control-Entscheidungsschlange",
        "",
        "> Diese Sicht wird aus `owner_decisions.json` erzeugt. Antworten werden zuerst",
        "> als Receipt erfasst. JA/NEIN reserviert danach genau einen begrenzten",
        "> Claude-Router-Auftrag; VERTAGT erzeugt keinen Auftrag.",
        "",
    ]
    items = open_items(feed)
    if not items:
        rows.append("_Keine offene oder vertagte OWNER-Entscheidung._")
    for item in items:
        status = str(item["status"]).upper()
        rows.extend(
            [
                f"- [ ] @OWNER `{item['id']}` **{_markdown_text(item['question'])}**",
                f"  - Status: **{status}** · Kategorie: {_markdown_text(item['category'])}",
                f"  - Empfehlung: **{_markdown_text(item['recommendation'])}**",
                f"  - Bei JA: {_markdown_text(item['yes_effect'])}",
                f"  - Bei NEIN: {_markdown_text(item['no_effect'])}",
                f"  - Cost of Wait: {_markdown_text(item['cost_of_wait'])}",
            ]
        )
        evidence = item.get("evidence") or []
        if evidence:
            rows.append("  - Evidenz: " + " · ".join(f"`{_markdown_text(x)}`" for x in evidence))
        dependencies = item.get("depends_on") or []
        if dependencies:
            rows.append(
                "  - Abhaengig von: "
                + " · ".join(f"`{_markdown_text(x)}`" for x in dependencies)
            )
        rows.append("")
    rows.append(VAULT_QUEUE_END)
    return "\n".join(rows)


def _replace_vault_queue(text: str, queue: str, *, bootstrap: bool = False) -> str:
    if VAULT_QUEUE_START in text and VAULT_QUEUE_END in text:
        pattern = re.compile(
            re.escape(VAULT_QUEUE_START) + r".*?" + re.escape(VAULT_QUEUE_END),
            re.DOTALL,
        )
        if len(pattern.findall(text)) != 1:
            raise DecisionStoreError("Vault OWNER queue markers are ambiguous")
        return pattern.sub(queue, text, count=1)
    if not bootstrap:
        raise DecisionStoreError("Vault OWNER queue markers are missing")
    old_queue = re.compile(
        r"## Entscheidungsschlange \(max 5\).*?(?=\n## Arbeitsauftraege|\n## Arbeitsaufträge)",
        re.DOTALL,
    )
    if len(old_queue.findall(text)) != 1:
        raise DecisionStoreError("legacy Vault decision queue anchor is missing or ambiguous")
    text = old_queue.sub(queue + "\n", text, count=1)
    # OWNER-DEC-MQL5CAND moves into the generated queue. Preserve unrelated
    # sections while removing only the old final deferred block.
    text = re.sub(r"\n## Bewusst vertagt\n.*\Z", "\n", text, flags=re.DOTALL)
    return text


def _migrate_vault_index(text: str) -> str:
    replacement = """## Offene OWNER-Entscheidungen (ohne Cap)

Kanonisch: [Mission Control](file:///D:/QM/strategy_farm/dashboards/cockpit_v2.html) ·
[[AI ToDos/OWNER|@OWNER-Dokumentation]]. Mission Control zeigt jede offene oder
vertagte Entscheidung mit Empfehlung, Folgen, Cost-of-Wait und Receipt-Aktionen;
hier wird keine parallele, manuell begrenzte Liste geführt.
"""
    pattern = re.compile(
        r"## Offene OWNER-Entscheidungen \(≤5\).*?(?=\n## Programme)", re.DOTALL
    )
    if len(pattern.findall(text)) != 1:
        raise DecisionStoreError("legacy Vault index decision section is missing or ambiguous")
    return pattern.sub(replacement, text, count=1)


def sync_vault_queue(
    feed: Mapping[str, Any],
    vault_owner_path: Path = DEFAULT_VAULT_OWNER,
    *,
    bootstrap: bool = False,
) -> None:
    try:
        before = vault_owner_path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        raise DecisionStoreError(f"Vault OWNER page unreadable: {exc}") from exc
    after = _replace_vault_queue(before, render_vault_queue(feed), bootstrap=bootstrap)
    if after != before:
        _atomic_write(vault_owner_path, after.encode("utf-8"))


def load_receipts(path: Path = DEFAULT_RECEIPTS) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    rows: list[dict[str, Any]] = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise DecisionStoreError(f"invalid receipt JSONL line {line_no}: {exc}") from exc
        if not isinstance(row, dict) or row.get("schema") not in SUPPORTED_RECEIPT_SCHEMAS:
            raise DecisionStoreError(f"invalid receipt contract on line {line_no}")
        rows.append(row)
    return rows


def _append_receipt(path: Path, receipt: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("ab") as handle:
        handle.write(canonical_bytes(receipt))
        handle.flush()
        os.fsync(handle.fileno())


def _apply_receipt(feed: dict[str, Any], receipt: Mapping[str, Any]) -> None:
    item_id = str(receipt["decision_id"])
    item = next((row for row in feed["items"] if row["id"] == item_id), None)
    if item is None:
        raise DecisionStoreError(f"receipt target disappeared from feed: {item_id}")
    choice = str(receipt["decision"])
    item["status"] = "DEFERRED" if choice == "DEFERRED" else "DECIDED"
    item["last_decision"] = choice
    item["last_decision_at_utc"] = receipt["decided_at_utc"]
    item["last_decision_note"] = receipt["notes"]
    item["last_receipt_id"] = receipt["receipt_id"]
    item["last_receipt_sha256"] = receipt["receipt_sha256"]
    feed["revision"] = int(feed["revision"]) + 1
    feed["updated_at_utc"] = receipt["decided_at_utc"]


def _archive_receipt(vault_owner_path: Path, receipt: Mapping[str, Any]) -> None:
    day = str(receipt["decided_at_utc"])[:10]
    archive = vault_owner_path.parent / "Archive" / f"Entscheidungen {day}.md"
    receipt_id = str(receipt["receipt_id"])
    if archive.is_file():
        text = archive.read_text(encoding="utf-8-sig")
    else:
        text = f"# OWNER-Entscheidungen {day}\n\n"
    if receipt_id in text:
        return
    choice = str(receipt["decision"])
    task_id = receipt.get("execution_task_id")
    if task_id:
        followup = (
            f"- Folgeauftrag: `{task_id}` (Claude-Lane, entscheidungsgebunden; "
            "Status in Mission Control)."
        )
    else:
        followup = "- Folgeauftrag: keiner (`VERTAGT`)."
    block = [
        f"## {receipt['decision_id']} — {choice}",
        "",
        f"- Zeitpunkt: `{receipt['decided_at_utc']}`",
        f"- Receipt: `{receipt_id}` / `{receipt['receipt_sha256']}`",
        f"- Frage: {_markdown_text(receipt['question'])}",
        f"- Empfehlung zum Entscheidzeitpunkt: {_markdown_text(receipt['recommendation'])}",
        f"- OWNER-Entscheidung: **{choice}**",
        f"- Ausgewaehlte Folge: {_markdown_text(receipt.get('selected_effect')) or 'keine'}",
        f"- Kartenbindung SHA-256: `{receipt.get('decision_card_sha256') or 'legacy'}`",
        f"- Ausfuehrungsplan SHA-256: `{receipt.get('execution_plan_sha256') or 'keiner'}`",
        f"- Notiz: {_markdown_text(receipt['notes']) or '—'}",
        followup,
        "- Ausfuehrungsgrenze: nur die ausgewaehlte Kartenfolge; kein T_Live, "
        "AutoTrading oder Deployment durch dieses Receipt.",
        "",
    ]
    _atomic_write(archive, (text.rstrip() + "\n\n" + "\n".join(block)).encode("utf-8"))


def record_decision(
    *,
    decision_id: str,
    decision: str,
    notes: str,
    request_id: str,
    feed_path: Path = DEFAULT_FEED,
    receipts_path: Path = DEFAULT_RECEIPTS,
    vault_owner_path: Path = DEFAULT_VAULT_OWNER,
    decided_at_utc: str | None = None,
    expected_decision_card_sha256: str | None = None,
    execution_plan_sha256: str | None = None,
) -> dict[str, Any]:
    decision_id = str(decision_id).strip().upper()
    decision = str(decision).strip().upper()
    notes = str(notes or "").strip()
    request_id = str(request_id or "").strip()
    if decision not in ALLOWED_DECISIONS:
        raise DecisionStoreError(f"unsupported decision: {decision}")
    if not REQUEST_ID_RE.fullmatch(request_id):
        raise DecisionStoreError("request_id must be 8-128 safe characters")
    if len(notes) > 4000:
        raise DecisionStoreError("notes exceed 4000 characters")
    card_hash = str(expected_decision_card_sha256 or "").strip()
    if not re.fullmatch(r"[0-9a-f]{64}", card_hash):
        raise DecisionStoreError("decision requires the displayed card binding")
    plan_hash = str(execution_plan_sha256 or "").strip()
    if decision in {"YES", "NO"} and not re.fullmatch(r"[0-9a-f]{64}", plan_hash):
        raise DecisionStoreError("terminal decision requires a bound execution plan")

    with exclusive_store_lock(feed_path):
        receipts = load_receipts(receipts_path)
        prior = next((row for row in receipts if row.get("request_id") == request_id), None)
        feed = load_feed(feed_path)
        if prior is not None:
            if prior.get("decision_id") != decision_id or prior.get("decision") != decision:
                raise DecisionConflict("request_id was already used for another decision")
            item = next((row for row in feed["items"] if row["id"] == decision_id), None)
            if item and item.get("last_receipt_id") != prior.get("receipt_id"):
                _apply_receipt(feed, prior)
                _write_json(feed_path, feed)
                sync_vault_queue(feed, vault_owner_path)
                _archive_receipt(vault_owner_path, prior)
            return dict(prior)

        item = next((row for row in feed["items"] if row["id"] == decision_id), None)
        if item is None:
            raise DecisionStoreError(f"unknown decision id: {decision_id}")
        if not hmac.compare_digest(card_hash, decision_card_sha256(item)):
            raise DecisionConflict(
                "OWNER-visible decision card changed; reload Mission Control"
            )
        if str(item["status"]).upper() == "DECIDED":
            raise DecisionConflict(f"decision is already terminal: {decision_id}")
        at = decided_at_utc or utc_now()
        terminal = decision in {"YES", "NO"}
        receipt_id = str(uuid.uuid4())
        selected_effect = (
            str(item["yes_effect"] if decision == "YES" else item["no_effect"])
            if terminal else None
        )
        receipt: dict[str, Any] = {
            "schema": RECEIPT_SCHEMA,
            "receipt_id": receipt_id,
            "request_id": request_id,
            "decision_id": decision_id,
            "decision": decision,
            "notes": notes,
            "decided_by": "OWNER",
            "decided_at_utc": at,
            "feed_revision_before": int(feed["revision"]),
            "question": str(item["question"]),
            "recommendation": str(item["recommendation"]),
            "selected_effect": selected_effect,
            "decision_card_sha256": card_hash,
            "execution_plan_sha256": plan_hash if terminal else None,
            "execution_authorized": terminal,
            "execution_handoff_authorized": terminal,
            "execution_task_id": execution_task_id(receipt_id) if terminal else None,
            "execution_boundary": (
                "DECISION_SCOPED_ROUTER_TASK" if terminal else "DEFERRED_NO_HANDOFF"
            ),
            "live_execution_authorized": False,
            "factory_pause_authorized": False,
            "autotrading_authorized": False,
            "deployment_authorized": False,
            "notes_may_expand_scope": False,
        }
        receipt["receipt_sha256"] = sha256_bytes(canonical_bytes(receipt))
        _append_receipt(receipts_path, receipt)
        _apply_receipt(feed, receipt)
        _write_json(feed_path, feed)
        sync_vault_queue(feed, vault_owner_path)
        _archive_receipt(vault_owner_path, receipt)
        return receipt


def bootstrap_plan(
    *,
    feed_path: Path = DEFAULT_FEED,
    seed_path: Path = DEFAULT_SEED,
    vault_owner_path: Path = DEFAULT_VAULT_OWNER,
    vault_index_path: Path = DEFAULT_VAULT_INDEX,
) -> dict[str, Any]:
    seed = json.loads(seed_path.read_text(encoding="utf-8-sig"))
    validate_feed(seed)
    current = json.loads(feed_path.read_text(encoding="utf-8-sig"))
    current_schema = current.get("schema_version") if isinstance(current, dict) else None
    vault_text = vault_owner_path.read_text(encoding="utf-8-sig")
    vault_index_text = vault_index_path.read_text(encoding="utf-8-sig")
    already = current_schema == FEED_SCHEMA and VAULT_QUEUE_START in vault_text
    return {
        "schema": "qm.owner-decisions-bootstrap-plan/v1",
        "state": "ALREADY_BOOTSTRAPPED" if already else "READY",
        "feed_path": str(feed_path),
        "feed_sha256": _file_sha(feed_path),
        "current_schema": current_schema,
        "seed_path": str(seed_path),
        "seed_sha256": _file_sha(seed_path),
        "seed_item_ids": [item["id"] for item in seed["items"]],
        "vault_owner_path": str(vault_owner_path),
        "vault_sha256": _file_sha(vault_owner_path),
        "vault_index_path": str(vault_index_path),
        "vault_index_sha256": sha256_bytes(vault_index_text.encode("utf-8")),
        "legacy_item_count": len(current.get("items") or []) if isinstance(current, dict) else 0,
    }


def bootstrap_plan_sha256(plan: Mapping[str, Any]) -> str:
    return sha256_bytes(canonical_bytes(plan))


def apply_bootstrap(
    plan: Mapping[str, Any],
    *,
    expected_plan_sha256: str,
    feed_path: Path = DEFAULT_FEED,
    seed_path: Path = DEFAULT_SEED,
    vault_owner_path: Path = DEFAULT_VAULT_OWNER,
    vault_index_path: Path = DEFAULT_VAULT_INDEX,
) -> dict[str, Any]:
    observed_hash = bootstrap_plan_sha256(plan)
    if observed_hash != expected_plan_sha256:
        raise DecisionStoreError(
            f"bootstrap plan hash changed: expected {expected_plan_sha256}, observed {observed_hash}"
        )
    if plan["state"] == "ALREADY_BOOTSTRAPPED":
        return {"applied": False, "idempotent": True}
    if plan["current_schema"] != 1:
        raise DecisionStoreError(
            f"bootstrap only accepts exact legacy schema 1, got {plan['current_schema']!r}"
        )
    with exclusive_store_lock(feed_path):
        current = bootstrap_plan(
            feed_path=feed_path, seed_path=seed_path, vault_owner_path=vault_owner_path,
            vault_index_path=vault_index_path,
        )
        if bootstrap_plan_sha256(current) != expected_plan_sha256:
            raise DecisionStoreError("bootstrap sources changed after dry-run")
        archive_dir = feed_path.parent / "archive"
        archive_dir.mkdir(parents=True, exist_ok=True)
        feed_backup = archive_dir / "owner_decisions_v1_pre_v2_20260824.json"
        vault_backup = vault_owner_path.parent / "Archive" / "OWNER pre Mission Control 2026-08-24.md"
        index_backup = vault_owner_path.parent / "Archive" / "_INDEX pre Mission Control 2026-08-24.md"
        if feed_backup.exists() or vault_backup.exists() or index_backup.exists():
            raise DecisionStoreError("bootstrap backup target already exists")
        _atomic_write(feed_backup, feed_path.read_bytes())
        _atomic_write(vault_backup, vault_owner_path.read_bytes())
        _atomic_write(index_backup, vault_index_path.read_bytes())
        seed = json.loads(seed_path.read_text(encoding="utf-8-sig"))
        seed["revision"] = 1
        seed["updated_at_utc"] = utc_now()
        _write_json(feed_path, seed)
        sync_vault_queue(seed, vault_owner_path, bootstrap=True)
        index_text = vault_index_path.read_text(encoding="utf-8-sig")
        _atomic_write(vault_index_path, _migrate_vault_index(index_text).encode("utf-8"))
        return {
            "applied": True,
            "idempotent": False,
            "feed_backup": str(feed_backup),
            "vault_backup": str(vault_backup),
            "vault_index_backup": str(index_backup),
            "open_count": len(open_items(seed)),
        }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bootstrap", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--feed", type=Path, default=DEFAULT_FEED)
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--vault-owner", type=Path, default=DEFAULT_VAULT_OWNER)
    parser.add_argument("--vault-index", type=Path, default=DEFAULT_VAULT_INDEX)
    args = parser.parse_args(argv)
    if not args.bootstrap:
        parser.error("only --bootstrap is exposed; the HTTP service records decisions")
    plan = bootstrap_plan(
        feed_path=args.feed, seed_path=args.seed, vault_owner_path=args.vault_owner,
        vault_index_path=args.vault_index,
    )
    plan_hash = bootstrap_plan_sha256(plan)
    if args.apply:
        if not args.expected_plan_sha256:
            parser.error("--apply requires --expected-plan-sha256")
        result = apply_bootstrap(
            plan,
            expected_plan_sha256=args.expected_plan_sha256,
            feed_path=args.feed,
            seed_path=args.seed,
            vault_owner_path=args.vault_owner,
            vault_index_path=args.vault_index,
        )
    else:
        result = {"applied": False, "idempotent": plan["state"] == "ALREADY_BOOTSTRAPPED"}
    sys.stdout.write(
        json.dumps(
            {"dry_run": not args.apply, "plan_sha256": plan_hash, "plan": plan, "result": result},
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

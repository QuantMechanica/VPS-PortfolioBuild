#!/usr/bin/env python3
"""Durable OWNER To-Do store (Mission Control).

When the OWNER has to *do* something in the world (open an FTMO demo account,
export a portal statement, flip a terminal into RUNNING), the Orchestrator
records it here as a concrete, numbered instruction. Mission Control renders the
open items as prominent OWNER To-Do cards, and the Vault OWNER.md mirror carries
a marker-delimited section so the human-facing board stays in sync.

The feed is a materialized JSON read model with the schema ``qm.owner-todos/v1``.
A bootstrap config seeds durable items on first load (mirrors
``owner_decision_store``'s bootstrap-merge pattern): any bootstrap id absent from
the feed is merged in. To-Dos are documentation, never execution authority — a
done To-Do is reported back to the Orchestrator, it toggles nothing itself.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
import threading
from pathlib import Path
from typing import Any, Iterator, Mapping

# Reuse the decision store's atomic-write + cross-process lock where importable;
# fall back to a local implementation for standalone use / isolated tests.
try:  # package import (tests, module consumers)
    from tools.strategy_farm.owner_decision_store import (
        DEFAULT_VAULT_OWNER,
        VAULT_QUEUE_START,
        exclusive_store_lock as _shared_lock,
    )

    _HAVE_SHARED_LOCK = True
except Exception:  # pragma: no cover - exercised only without the package on sys.path
    try:
        from owner_decision_store import (  # type: ignore
            DEFAULT_VAULT_OWNER,
            VAULT_QUEUE_START,
            exclusive_store_lock as _shared_lock,
        )

        _HAVE_SHARED_LOCK = True
    except Exception:
        _HAVE_SHARED_LOCK = False
        VAULT_QUEUE_START = "<!-- QM:MISSION_CONTROL_DECISIONS:START -->"
        DEFAULT_VAULT_OWNER = Path(
            r"G:\My Drive\QuantMechanica - Company Reference\12 ToDo\AI ToDos\OWNER.md"
        )


FEED_SCHEMA = "qm.owner-todos/v1"
ALLOWED_STATUSES = frozenset({"OPEN", "DONE", "CANCELLED"})
DEFAULT_FEED = Path(r"D:\QM\reports\state\owner_todos.json")
DEFAULT_SEED = Path(__file__).resolve().parent / "config" / "owner_todos.v1.bootstrap.json"
VAULT_TODOS_START = "<!-- QM:OWNER_TODOS:START -->"
VAULT_TODOS_END = "<!-- QM:OWNER_TODOS:END -->"
ID_RE = re.compile(r"OWNER-TODO-\d{8}-[A-Z0-9][A-Z0-9-]*")
_PROCESS_LOCK = threading.RLock()


class TodoStoreError(RuntimeError):
    """The request or durable To-Do state failed validation."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


# ---------------------------------------------------------------------------
# atomic write + lock (shared with owner_decision_store when importable)
# ---------------------------------------------------------------------------
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


if _HAVE_SHARED_LOCK:
    exclusive_store_lock = _shared_lock
else:  # pragma: no cover - fallback lock for standalone use
    import contextlib

    @contextlib.contextmanager
    def exclusive_store_lock(feed_path: Path) -> Iterator[None]:
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
            else:
                import fcntl

                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
                try:
                    yield
                finally:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


# ---------------------------------------------------------------------------
# validation
# ---------------------------------------------------------------------------
def _validate_item(item: Mapping[str, Any]) -> None:
    required = ("id", "title", "why", "steps", "status", "created_at_utc")
    missing = [key for key in required if item.get(key) in (None, "")]
    if missing:
        raise TodoStoreError(
            f"todo item {item.get('id') or '?'} missing fields: {', '.join(missing)}"
        )
    item_id = str(item["id"])
    if not ID_RE.fullmatch(item_id):
        raise TodoStoreError(f"invalid todo id: {item_id}")
    status = str(item["status"]).upper()
    if status not in ALLOWED_STATUSES:
        raise TodoStoreError(f"invalid status for {item_id}: {status}")
    steps = item.get("steps")
    if not isinstance(steps, list) or not all(isinstance(value, str) for value in steps):
        raise TodoStoreError(f"invalid steps list for {item_id}")


def validate_feed(feed: Mapping[str, Any]) -> None:
    if feed.get("schema") != FEED_SCHEMA:
        raise TodoStoreError(f"unsupported feed schema: {feed.get('schema')!r}")
    if not isinstance(feed.get("revision"), int) or int(feed["revision"]) < 0:
        raise TodoStoreError("feed revision must be a non-negative integer")
    items = feed.get("items")
    if not isinstance(items, list):
        raise TodoStoreError("feed items must be a list")
    seen: set[str] = set()
    for item in items:
        if not isinstance(item, dict):
            raise TodoStoreError("feed item must be an object")
        _validate_item(item)
        item_id = str(item["id"])
        if item_id in seen:
            raise TodoStoreError(f"duplicate todo id: {item_id}")
        seen.add(item_id)


def _normalize_item(item: Mapping[str, Any]) -> dict[str, Any]:
    out = dict(item)
    out.setdefault("due", None)
    out.setdefault("source_decision_id", None)
    out.setdefault("done_at_utc", None)
    out.setdefault("notes", "")
    out["status"] = str(out.get("status") or "OPEN").upper()
    out["steps"] = list(out.get("steps") or [])
    return out


def _empty_feed() -> dict[str, Any]:
    return {
        "schema": FEED_SCHEMA,
        "revision": 0,
        "updated_at_utc": utc_now(),
        "items": [],
    }


# ---------------------------------------------------------------------------
# load / bootstrap-merge / save
# ---------------------------------------------------------------------------
def _merge_bootstrap(feed: dict[str, Any], seed_path: Path) -> bool:
    """Merge any bootstrap id absent from the feed. Returns True if changed."""

    if not seed_path or not Path(seed_path).is_file():
        return False
    try:
        seed = json.loads(Path(seed_path).read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise TodoStoreError(f"bootstrap seed unreadable: {seed_path}: {exc}") from exc
    validate_feed(seed)
    present = {str(item["id"]) for item in feed["items"]}
    changed = False
    for item in seed["items"]:
        if str(item["id"]) not in present:
            feed["items"].append(_normalize_item(item))
            changed = True
    return changed


def load_feed(
    path: Path = DEFAULT_FEED,
    *,
    seed_path: Path | None = DEFAULT_SEED,
    persist_bootstrap: bool = True,
) -> dict[str, Any]:
    """Load the feed, merging any missing bootstrap items on the way.

    A missing feed file starts from an empty feed and is seeded by the bootstrap
    config, so the first load already carries the durable To-Dos.
    """

    try:
        raw = path.read_text(encoding="utf-8-sig")
        feed = json.loads(raw)
        if not isinstance(feed, dict):
            raise TodoStoreError("todo feed root must be an object")
    except FileNotFoundError:
        feed = _empty_feed()
    except (OSError, json.JSONDecodeError) as exc:
        raise TodoStoreError(f"todo feed unreadable: {path}: {exc}") from exc

    feed.setdefault("schema", FEED_SCHEMA)
    feed.setdefault("revision", 0)
    feed.setdefault("updated_at_utc", utc_now())
    feed.setdefault("items", [])
    feed["items"] = [_normalize_item(item) for item in feed["items"]]
    validate_feed(feed)

    changed = _merge_bootstrap(feed, seed_path) if seed_path else False
    if changed and persist_bootstrap:
        feed["revision"] = int(feed["revision"]) + 1
        feed["updated_at_utc"] = utc_now()
        save_feed(feed, path)
    return feed


def save_feed(feed: Mapping[str, Any], path: Path = DEFAULT_FEED) -> None:
    validate_feed(feed)
    _atomic_write(path, json.dumps(feed, indent=2, sort_keys=True, ensure_ascii=False).encode("utf-8") + b"\n")


def open_items(feed: Mapping[str, Any]) -> list[dict[str, Any]]:
    return [
        dict(item)
        for item in feed.get("items") or []
        if str(item.get("status") or "").upper() == "OPEN"
    ]


# ---------------------------------------------------------------------------
# mutations
# ---------------------------------------------------------------------------
def add_item(
    *,
    id: str,
    title: str,
    why: str,
    steps: list[str],
    due: str | None = None,
    source_decision_id: str | None = None,
    status: str = "OPEN",
    notes: str = "",
    created_at_utc: str | None = None,
    feed_path: Path = DEFAULT_FEED,
    seed_path: Path | None = DEFAULT_SEED,
) -> dict[str, Any]:
    item = _normalize_item(
        {
            "id": str(id).strip(),
            "title": str(title),
            "why": str(why),
            "steps": list(steps or []),
            "due": due,
            "status": str(status or "OPEN").upper(),
            "source_decision_id": source_decision_id,
            "created_at_utc": created_at_utc or utc_now(),
            "done_at_utc": None,
            "notes": notes or "",
        }
    )
    _validate_item(item)
    with exclusive_store_lock(feed_path):
        feed = load_feed(feed_path, seed_path=seed_path)
        if any(str(row["id"]) == item["id"] for row in feed["items"]):
            raise TodoStoreError(f"todo id already exists: {item['id']}")
        feed["items"].append(item)
        feed["revision"] = int(feed["revision"]) + 1
        feed["updated_at_utc"] = utc_now()
        save_feed(feed, feed_path)
    return item


def mark_done(
    todo_id: str,
    *,
    feed_path: Path = DEFAULT_FEED,
    seed_path: Path | None = DEFAULT_SEED,
    done_at_utc: str | None = None,
    status: str = "DONE",
) -> dict[str, Any]:
    todo_id = str(todo_id).strip()
    status = str(status or "DONE").upper()
    if status not in {"DONE", "CANCELLED"}:
        raise TodoStoreError(f"mark_done only reaches DONE/CANCELLED, not {status}")
    with exclusive_store_lock(feed_path):
        feed = load_feed(feed_path, seed_path=seed_path)
        item = next((row for row in feed["items"] if str(row["id"]) == todo_id), None)
        if item is None:
            raise TodoStoreError(f"unknown todo id: {todo_id}")
        item["status"] = status
        item["done_at_utc"] = done_at_utc or utc_now()
        feed["revision"] = int(feed["revision"]) + 1
        feed["updated_at_utc"] = utc_now()
        save_feed(feed, feed_path)
        return dict(item)


# ---------------------------------------------------------------------------
# Vault mirror
# ---------------------------------------------------------------------------
def _md(value: Any) -> str:
    return str(value or "").replace("\r", " ").replace("\n", " ").strip()


def render_vault_todos(feed: Mapping[str, Any]) -> str:
    rows = [
        VAULT_TODOS_START,
        "## OWNER To-Dos (Mission Control)",
        "",
        "> Konkrete Handlungen, die nur der OWNER ausfuehren kann. Erzeugt aus",
        "> `owner_todos.json`. Erledigt = dem Orchestrator melden; das To-Do schaltet",
        "> selbst nichts.",
        "",
    ]
    items = open_items(feed)
    if not items:
        rows.append("_Keine offene OWNER-Handlung._")
    for item in items:
        due = _md(item.get("due")) or "ohne Frist"
        rows.append(f"- [ ] @OWNER `{item['id']}` **{_md(item.get('title'))}**")
        rows.append(f"  - Warum: {_md(item.get('why'))}")
        rows.append(f"  - Frist: {due}")
        for index, step in enumerate(item.get("steps") or [], 1):
            rows.append(f"  {index}. {_md(step)}")
        src = _md(item.get("source_decision_id"))
        if src:
            rows.append(f"  - Entscheidung: `{src}`")
        rows.append("")
    rows.append(VAULT_TODOS_END)
    return "\n".join(rows)


def _replace_vault_todos(text: str, block: str) -> str:
    if VAULT_TODOS_START in text and VAULT_TODOS_END in text:
        pattern = re.compile(
            re.escape(VAULT_TODOS_START) + r".*?" + re.escape(VAULT_TODOS_END),
            re.DOTALL,
        )
        if len(pattern.findall(text)) != 1:
            raise TodoStoreError("Vault OWNER todo markers are ambiguous")
        return pattern.sub(lambda _m: block, text, count=1)
    # Insert right before the decisions queue markers if present, else append.
    if VAULT_QUEUE_START in text:
        return text.replace(VAULT_QUEUE_START, block + "\n\n" + VAULT_QUEUE_START, 1)
    trimmed = text.rstrip("\n")
    return (trimmed + "\n\n" + block + "\n") if trimmed else (block + "\n")


def sync_vault_todos(
    feed: Mapping[str, Any],
    vault_owner_path: Path = DEFAULT_VAULT_OWNER,
) -> bool:
    """Write the OWNER To-Dos section into the Vault OWNER.md idempotently."""

    try:
        before = Path(vault_owner_path).read_text(encoding="utf-8-sig")
    except FileNotFoundError:
        before = ""
    except OSError as exc:
        raise TodoStoreError(f"Vault OWNER page unreadable: {exc}") from exc
    after = _replace_vault_todos(before, render_vault_todos(feed))
    if after != before:
        _atomic_write(Path(vault_owner_path), after.encode("utf-8"))
        return True
    return False


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--feed", type=Path, default=DEFAULT_FEED)
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--vault-owner", type=Path, default=DEFAULT_VAULT_OWNER)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="print open OWNER To-Dos as JSON")

    add = sub.add_parser("add", help="add a new OWNER To-Do")
    add.add_argument("--id", required=True)
    add.add_argument("--title", required=True)
    add.add_argument("--why", required=True)
    add.add_argument("--steps-json", required=True, help='JSON array of step strings')
    add.add_argument("--due", default=None)
    add.add_argument("--source-decision", default=None)
    add.add_argument("--notes", default="")

    done = sub.add_parser("done", help="mark a To-Do done")
    done.add_argument("todo_id")

    sub.add_parser("sync-vault", help="write the Vault OWNER.md To-Do section")

    args = parser.parse_args(argv)

    if args.command == "list":
        feed = load_feed(args.feed, seed_path=args.seed)
        payload = {"count": len(open_items(feed)), "items": open_items(feed)}
        sys.stdout.write(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
        return 0

    if args.command == "add":
        try:
            steps = json.loads(args.steps_json)
        except json.JSONDecodeError as exc:
            parser.error(f"--steps-json is not valid JSON: {exc}")
        if not isinstance(steps, list) or not all(isinstance(v, str) for v in steps):
            parser.error("--steps-json must be a JSON array of strings")
        item = add_item(
            id=args.id,
            title=args.title,
            why=args.why,
            steps=steps,
            due=args.due,
            source_decision_id=args.source_decision,
            notes=args.notes,
            feed_path=args.feed,
            seed_path=args.seed,
        )
        sys.stdout.write(json.dumps(item, indent=2, ensure_ascii=False) + "\n")
        return 0

    if args.command == "done":
        item = mark_done(args.todo_id, feed_path=args.feed, seed_path=args.seed)
        sys.stdout.write(json.dumps(item, indent=2, ensure_ascii=False) + "\n")
        return 0

    if args.command == "sync-vault":
        feed = load_feed(args.feed, seed_path=args.seed)
        changed = sync_vault_todos(feed, args.vault_owner)
        sys.stdout.write(
            json.dumps(
                {"synced": True, "changed": changed, "open_count": len(open_items(feed))},
                indent=2,
            )
            + "\n"
        )
        return 0

    parser.error("unknown command")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

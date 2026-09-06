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
import hashlib
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
ALLOWED_KINDS = frozenset({"handlung", "vorlage", "info", "video"})
DEFAULT_FEED = Path(r"D:\QM\reports\state\owner_todos.json")
DEFAULT_SEED = Path(__file__).resolve().parent / "config" / "owner_todos.v1.bootstrap.json"
DEFAULT_VIDEO_MD = Path(DEFAULT_VAULT_OWNER).parent / "OWNER Videoanalysen.md"
VAULT_TODOS_START = "<!-- QM:OWNER_TODOS:START -->"
VAULT_TODOS_END = "<!-- QM:OWNER_TODOS:END -->"
# The three marker blocks whose interiors are OFF-LIMITS to the vault importer:
# the To-Do mirror, the open decision queue, and the decided archive.
VAULT_DECISIONS_START = "<!-- QM:MISSION_CONTROL_DECISIONS:START -->"
VAULT_DECISIONS_END = "<!-- QM:MISSION_CONTROL_DECISIONS:END -->"
VAULT_DECIDED_START = "<!-- QM:MISSION_CONTROL_DECIDED:START -->"
VAULT_DECIDED_END = "<!-- QM:MISSION_CONTROL_DECIDED:END -->"
# Idempotent import ids carry a normalised-line sha1; the classic date-scoped ids
# and the vault-derived ids are both accepted.
ID_RE = re.compile(
    r"OWNER-TODO-(?:\d{8}-[A-Z0-9][A-Z0-9-]*|VAULT-[0-9a-f]{6,})"
)
MIGRATION_LINE = (
    "> Die OWNER-To-Dos wurden am 2026-09-06 in den Mission-Control-Feed "
    "(owner_todos.json) migriert; sie erscheinen unten im Abschnitt "
    "'OWNER To-Dos (Mission Control)'."
)
ARCHIVE_BACKUP_PATH = (
    Path(DEFAULT_VAULT_OWNER).parent
    / "Archive"
    / "OWNER_2026-09-06_pre_todo_migration.md"
)
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
    kind = item.get("kind")
    if kind is not None and str(kind) not in ALLOWED_KINDS:
        raise TodoStoreError(f"invalid kind for {item_id}: {kind}")
    source = item.get("source")
    if source is not None and not isinstance(source, dict):
        raise TodoStoreError(f"invalid source for {item_id}")


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
    out.setdefault("kind", "handlung")
    out.setdefault("source", None)
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
# Vault import (OWNER.md top checklist + OWNER Videoanalysen.md)
# ---------------------------------------------------------------------------
_CHECK_RE = re.compile(r"^- \[([ xX])\]\s+(.*)$")
_BOLD_RE = re.compile(r"\*\*(.+?)\*\*", re.DOTALL)
_PAREN_RE = re.compile(r"\(([^)]*)\)")
_TS_RE = re.compile(r"(\d{2})\.(\d{2})\.\s*(\d{1,2}):(\d{2})\s*Z")
_LEAD_ID_RE = re.compile(r"^@?OWNER\s+`[^`]*`\s*")


def _strip_md(text: str) -> str:
    """Flatten markdown to plain text while KEEPING evidence paths intact.

    Link syntax collapses to its label; emphasis / code fences drop their
    markers but keep the inner text (so ``docs/ops/…`` paths survive)."""

    out = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    out = out.replace("**", "").replace("`", "")
    out = re.sub(r"(?<!\w)\*(?!\s)", "", out)  # stray emphasis stars
    out = out.replace("\r", " ").replace("\n", " ")
    return re.sub(r"\s+", " ", out).strip()


def _normalize_for_hash(body: str) -> str:
    """Stable identity of a checklist item — checkbox state removed, whitespace
    collapsed — so a ``[ ]``→``[x]`` toggle re-imports to the SAME id."""

    stripped = re.sub(r"^\s*[-*]\s*\[[ xX]\]\s*", "", body)
    return re.sub(r"\s+", " ", stripped).strip()


def _line_sha1(body: str) -> str:
    return hashlib.sha1(_normalize_for_hash(body).encode("utf-8")).hexdigest()


def _first_tag(body: str) -> str:
    match = _PAREN_RE.search(body)
    return match.group(1).strip() if match else ""


def _kind_from_tag(tag: str) -> str:
    """Kind from the parenthesised lead tag. The kind token is the field AFTER
    the timestamp (``03.09. 17:00Z, Info + …`` → ``Info``), so we read that
    segment's leading word — never a stray ``…-Vorlage`` inside prose."""

    parts = tag.split(",")
    segment = parts[1] if len(parts) > 1 else (parts[0] if parts else "")
    lead = re.split(r"[\s+/]", segment.strip(), 1)[0].lower() if segment.strip() else ""
    if lead.startswith("vorlage"):
        return "vorlage"
    if lead.startswith("info"):
        return "info"
    return "handlung"


def _created_from_tag(tag: str, *, year: int = 2026) -> str | None:
    match = _TS_RE.search(tag)
    if not match:
        return None
    day, month, hour, minute = match.groups()
    return f"{year}-{month}-{day}T{int(hour):02d}:{minute}:00Z"


def _strip_leading_paren(text: str) -> str:
    """Drop a single leading parenthetical tag, tolerating one nested level
    (``(03.09. → V1(b) …)``) so the real title survives intact."""

    s = text.lstrip()
    if not s.startswith("("):
        return s
    depth = 0
    for i, ch in enumerate(s):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return s[i + 1:].strip()
    return s


def _title_and_why(body: str, *, is_video: bool) -> tuple[str, str]:
    if is_video:
        flat = _strip_md(_LEAD_ID_RE.sub("", body))
        title = re.split(r"(?<=[.!?])\s", flat, 1)[0].strip()
        why = flat.strip() or title
        return title[:140].strip(), why[:600].strip()

    bold = _BOLD_RE.search(body)
    if bold:
        title = _strip_leading_paren(_strip_md(bold.group(1))).strip()
        remainder = body[bold.end():]
    else:
        title = ""
        remainder = body
    remainder_flat = _strip_md(remainder).strip()
    if not title:
        source = remainder_flat or _strip_md(body)
        title = re.split(r"(?<=[.!?])\s", source, 1)[0].strip()
    why = remainder_flat or title
    return title[:140].strip(), why[:600].strip()


def _marker_spans(lines: list[str]) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    pairs = (
        (VAULT_TODOS_START, VAULT_TODOS_END),
        (VAULT_DECISIONS_START, VAULT_DECISIONS_END),
        (VAULT_DECIDED_START, VAULT_DECIDED_END),
    )
    for start_marker, end_marker in pairs:
        start = end = None
        for index, line in enumerate(lines):
            if start_marker in line:
                start = index
            if end_marker in line:
                end = index
        if start is not None and end is not None and end >= start:
            spans.append((start, end))
    return spans


def _inside_spans(index: int, spans: list[tuple[int, int]]) -> bool:
    return any(start <= index <= end for start, end in spans)


_SUBBULLET_RE = re.compile(r"^\s+(?:(\d+)\.|[-*])\s+(.*)$")


def _parse_owner_md(text: str) -> tuple[list[str], list[dict[str, Any]]]:
    """Top-level checklist items OUTSIDE every marker block, in file order.

    Each item records the full set of line indices it owns (header plus any
    indented numbered / dashed sub-bullets, which become its steps) so the
    migration step can remove exactly the imported lines."""

    lines = text.split("\n")
    spans = _marker_spans(lines)
    items: list[dict[str, Any]] = []
    index = 0
    total = len(lines)
    while index < total:
        if _inside_spans(index, spans):
            index += 1
            continue
        match = _CHECK_RE.match(lines[index])
        if not match:
            index += 1
            continue
        owned = [index]
        steps: list[str] = []
        follow = index + 1
        while follow < total and not _inside_spans(follow, spans):
            nxt = lines[follow]
            if nxt.strip() == "" or not nxt.startswith(" ") or _CHECK_RE.match(nxt.strip()):
                break
            sub = _SUBBULLET_RE.match(nxt)
            if not sub:
                break
            steps.append(_strip_md(sub.group(2)))
            owned.append(follow)
            follow += 1
        items.append({
            "idx": index,
            "idxs": owned,
            "lineno": index + 1,
            "body": match.group(2),
            "done": match.group(1).lower() == "x",
            "steps": steps,
        })
        index = follow
    return lines, items


def _parse_video_md(text: str) -> list[dict[str, Any]]:
    """Checklist items in the Videoanalysen page, joining wrapped continuation
    lines (indented, non-empty, not a new block) into one logical item."""

    lines = text.split("\n")
    items: list[dict[str, Any]] = []
    index = 0
    while index < len(lines):
        match = _CHECK_RE.match(lines[index])
        if not match:
            index += 1
            continue
        parts = [match.group(2)]
        follow = index + 1
        while follow < len(lines):
            nxt = lines[follow]
            if nxt.strip() == "" or not nxt.startswith(" "):
                break
            if re.match(r"^\s*(#|[-*]\s|\||>|\d+\.)", nxt):
                break
            parts.append(nxt.strip())
            follow += 1
        items.append({
            "idx": index,
            "lineno": index + 1,
            "body": " ".join(parts),
            "done": match.group(1).lower() == "x",
        })
        index = follow
    return items


def _build_todo(item: Mapping[str, Any], vault_file: str, *, is_video: bool) -> dict[str, Any]:
    body = str(item["body"])
    sha1 = _line_sha1(body)
    tag = _first_tag(body)
    kind = "video" if is_video else _kind_from_tag(tag)
    title, why = _title_and_why(body, is_video=is_video)
    if not title:
        title = f"Vault-Eintrag {vault_file}:{item['lineno']}"
    if not why:
        why = title
    created = _created_from_tag(tag) or utc_now()
    done = bool(item["done"])
    return {
        "id": f"OWNER-TODO-VAULT-{sha1[:10]}",
        "title": title,
        "why": why,
        "steps": [str(s) for s in (item.get("steps") or [])],
        "due": None,
        "status": "DONE" if done else "OPEN",
        "kind": kind,
        "source": {"file": vault_file, "line": int(item["lineno"]), "sha1": sha1},
        "source_decision_id": None,
        "created_at_utc": created,
        # A vault [x] carries no explicit completion time; the tag time is the
        # best available proxy so the Erledigt list can show a date.
        "done_at_utc": created if done else None,
        "notes": "",
    }


def _collect_vault_todos(
    owner_md_path: Path,
    video_md_path: Path,
) -> tuple[list[dict[str, Any]], list[str], list[dict[str, Any]]]:
    """Parse both vault pages into candidate To-Dos.

    Returns ``(todos, owner_lines, owner_items)`` — the split OWNER.md lines and
    its parsed checklist items are handed back so the migration step can rewrite
    exactly the lines that were imported."""

    owner_text = Path(owner_md_path).read_text(encoding="utf-8")
    owner_lines, owner_items = _parse_owner_md(owner_text)
    owner_file = str(owner_md_path)
    todos = [_build_todo(it, owner_file, is_video=False) for it in owner_items]

    try:
        video_text = Path(video_md_path).read_text(encoding="utf-8")
    except FileNotFoundError:
        video_text = ""
    video_file = str(video_md_path)
    for it in _parse_video_md(video_text):
        todos.append(_build_todo(it, video_file, is_video=True))
    return todos, owner_lines, owner_items


def _merge_import(feed: dict[str, Any], todos: list[dict[str, Any]]) -> dict[str, int]:
    """Merge parsed To-Dos into the feed. Idempotent: a DONE item is never
    reopened; an unseen id is added; a seen id refreshes title/why/kind/source
    but keeps its created_at, notes and terminal status."""

    by_id = {str(it["id"]): it for it in feed["items"]}
    counts = {"open": 0, "done": 0, "added": 0, "updated": 0}
    by_kind: dict[str, int] = {}
    changed = False
    for todo in todos:
        todo = _normalize_item(todo)
        kind = str(todo.get("kind") or "handlung")
        by_kind[kind] = by_kind.get(kind, 0) + 1
        vault_done = str(todo["status"]).upper() == "DONE"
        if vault_done:
            counts["done"] += 1
        else:
            counts["open"] += 1
        existing = by_id.get(str(todo["id"]))
        if existing is None:
            feed["items"].append(todo)
            by_id[str(todo["id"])] = todo
            counts["added"] += 1
            changed = True
            continue
        was_done = str(existing.get("status") or "OPEN").upper() == "DONE"
        new_status = "DONE" if (was_done or vault_done) else "OPEN"
        before = dict(existing)
        existing["title"] = todo["title"]
        existing["why"] = todo["why"]
        existing["kind"] = kind
        existing["source"] = todo["source"]
        existing["steps"] = list(todo.get("steps") or [])
        existing["status"] = new_status
        if new_status == "DONE" and not existing.get("done_at_utc"):
            existing["done_at_utc"] = utc_now()
        if existing != before:
            counts["updated"] += 1
            changed = True
    counts["by_kind"] = by_kind  # type: ignore[assignment]
    counts["changed"] = int(changed)  # type: ignore[assignment]
    return counts


def _migrate_owner_md(
    owner_lines: list[str],
    owner_items: list[dict[str, Any]],
    owner_md_path: Path,
    backup_path: Path,
) -> int:
    """Back up OWNER.md byte-exact, then replace the imported top-of-file
    checklist lines with the single migration notice. Every other line stays
    byte-identical. Returns the number of checklist lines removed."""

    idxs: set[int] = set()
    for it in owner_items:
        idxs.update(int(v) for v in (it.get("idxs") or [it["idx"]]))
    if not idxs:
        return 0
    raw = Path(owner_md_path).read_bytes()
    Path(backup_path).parent.mkdir(parents=True, exist_ok=True)
    if not Path(backup_path).exists():
        Path(backup_path).write_bytes(raw)
    first = min(idxs)
    new_lines: list[str] = []
    inserted = False
    for index, line in enumerate(owner_lines):
        if index in idxs:
            if index == first and not inserted:
                new_lines.append(MIGRATION_LINE)
                inserted = True
            continue
        new_lines.append(line)
    _atomic_write(Path(owner_md_path), "\n".join(new_lines).encode("utf-8"))
    return len(idxs)


def import_vault(
    owner_md_path: Path = DEFAULT_VAULT_OWNER,
    video_md_path: Path = DEFAULT_VIDEO_MD,
    *,
    apply: bool,
    feed_path: Path = DEFAULT_FEED,
    seed_path: Path | None = DEFAULT_SEED,
    backup_path: Path = ARCHIVE_BACKUP_PATH,
) -> dict[str, Any]:
    """Import every vault OWNER To-Do into the Mission Control feed.

    ``apply=False`` is a dry run: it parses and reports counts but writes
    nothing. ``apply=True`` persists the merged feed, then backs up OWNER.md and
    replaces the imported top-of-file checklist with the migration notice.
    """

    todos, owner_lines, owner_items = _collect_vault_todos(owner_md_path, video_md_path)
    report: dict[str, Any] = {
        "open": sum(1 for t in todos if str(t["status"]).upper() != "DONE"),
        "done": sum(1 for t in todos if str(t["status"]).upper() == "DONE"),
        "by_kind": {},
        "parsed": len(todos),
        "applied": bool(apply),
        "migrated_lines": 0,
        "backup": False,
    }
    by_kind: dict[str, int] = {}
    for todo in todos:
        kind = str(todo.get("kind") or "handlung")
        by_kind[kind] = by_kind.get(kind, 0) + 1
    report["by_kind"] = by_kind

    if not apply:
        return report

    with exclusive_store_lock(feed_path):
        feed = load_feed(feed_path, seed_path=seed_path)
        merge = _merge_import(feed, todos)
        if merge.get("changed"):
            feed["revision"] = int(feed["revision"]) + 1
            feed["updated_at_utc"] = utc_now()
            save_feed(feed, feed_path)
        report["added"] = merge["added"]
        report["updated"] = merge["updated"]

    report["migrated_lines"] = _migrate_owner_md(
        owner_lines, owner_items, owner_md_path, backup_path
    )
    report["backup"] = Path(backup_path).exists()
    return report


# ---------------------------------------------------------------------------
# Vault mirror
# ---------------------------------------------------------------------------
def _md(value: Any) -> str:
    return str(value or "").replace("\r", " ").replace("\n", " ").strip()


_KIND_HEADINGS = (
    ("handlung", "Handlungen"),
    ("vorlage", "Vorlagen (Entscheidung in Mission Control)"),
    ("info", "Info"),
    ("video", "Videoanalysen"),
)


def _source_ref(item: Mapping[str, Any]) -> str:
    src = item.get("source")
    if not isinstance(src, dict):
        return ""
    name = Path(str(src.get("file") or "")).name or str(src.get("file") or "")
    line = src.get("line")
    return f"{name}:{line}" if line is not None else name


def render_vault_todos(feed: Mapping[str, Any]) -> str:
    rows = [
        VAULT_TODOS_START,
        "## OWNER To-Dos (Mission Control)",
        "",
        "> Alle OWNER-To-Dos, gespiegelt aus `owner_todos.json` und den Vault-Seiten.",
        "> Erledigt = dem Orchestrator melden; das To-Do schaltet selbst nichts.",
        "",
    ]
    items = open_items(feed)
    grouped: dict[str, list[dict[str, Any]]] = {}
    for item in items:
        grouped.setdefault(str(item.get("kind") or "handlung"), []).append(item)

    if not items:
        rows.append("_Keine offene OWNER-Handlung._")
        rows.append("")

    for kind, heading in _KIND_HEADINGS:
        bucket = grouped.get(kind) or []
        if not bucket:
            continue
        rows.append(f"### {heading} ({len(bucket)})")
        rows.append("")
        for item in bucket:
            due = _md(item.get("due")) or "ohne Frist"
            rows.append(f"- [ ] @OWNER `{item['id']}` **{_md(item.get('title'))}**")
            rows.append(f"  - Warum: {_md(item.get('why'))}")
            rows.append(f"  - Frist: {due}")
            ref = _source_ref(item)
            if ref:
                rows.append(f"  - Quelle: {ref}")
            for index, step in enumerate(item.get("steps") or [], 1):
                rows.append(f"  {index}. {_md(step)}")
            src = _md(item.get("source_decision_id"))
            if src:
                rows.append(f"  - Entscheidung: `{src}`")
            rows.append("")

    done = [
        item
        for item in (feed.get("items") or [])
        if str(item.get("status") or "").upper() == "DONE"
    ]
    if done:
        rows.append(f"<details><summary>Erledigt ({len(done)})</summary>")
        rows.append("")
        for item in done:
            when = _md(item.get("done_at_utc"))[:10] or "—"
            rows.append(f"- `{item['id']}` {_md(item.get('title'))} — {when}")
        rows.append("")
        rows.append("</details>")
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
    parser.add_argument("--vault-video", type=Path, default=DEFAULT_VIDEO_MD)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="print open OWNER To-Dos as JSON")

    imp = sub.add_parser(
        "import-vault",
        help="import vault OWNER To-Dos into the feed (dry run unless --apply)",
    )
    imp.add_argument(
        "--apply",
        action="store_true",
        help="persist the feed and migrate the OWNER.md top checklist",
    )

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

    if args.command == "import-vault":
        report = import_vault(
            args.vault_owner,
            args.vault_video,
            apply=args.apply,
            feed_path=args.feed,
            seed_path=args.seed,
        )
        sys.stdout.write(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
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

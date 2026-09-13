#!/usr/bin/env python3
"""Append ONE new OPEN OWNER decision card to the governed decision store.

Generic, reusable session tool. It takes a JSON file holding a single decision
item, validates it with the store's own validators (never re-implemented here),
refuses a duplicate id, appends it under the store's exclusive lock, bumps
``revision`` and ``updated_at_utc`` exactly like the store does, writes the feed
atomically via ``owner_decision_store._write_json`` and then reflects the change
into the Vault OWNER.md queue with ``sync_vault_queue``.

It ONLY adds an OPEN/DEFERRED item. It never records a receipt/answer (that is an
OWNER-only, separately governed workflow), never touches farm_state.sqlite and
never runs git.

Dry-run is the default; pass ``--apply`` to write.

Usage::

    python -X utf8 tools/strategy_farm/session_tools/mint_owner_decision_card.py \
        --item docs/ops/evidence/<...>/owner_decision_card.json
    python -X utf8 tools/strategy_farm/session_tools/mint_owner_decision_card.py \
        --item <...>/owner_decision_card.json --apply
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

STRATEGY_FARM_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(STRATEGY_FARM_DIR))

import owner_decision_store as store  # noqa: E402


def _now_z() -> str:
    """UTC now, second precision, ``...Z`` form (matches the feed convention)."""

    return (
        dt.datetime.now(dt.timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def _load_item(path: Path) -> dict[str, Any]:
    """Read a single decision item from ``path`` (bare item, or wrapped)."""

    raw = path.read_bytes().decode("utf-8-sig")
    data = json.loads(raw)
    if isinstance(data, dict) and "id" in data and "items" not in data:
        return dict(data)
    if isinstance(data, dict) and isinstance(data.get("item"), dict):
        return dict(data["item"])
    if isinstance(data, dict) and isinstance(data.get("items"), list):
        items = data["items"]
        if len(items) != 1:
            raise SystemExit(
                f"expected exactly ONE item, found {len(items)} in {path}"
            )
        return dict(items[0])
    raise SystemExit(f"could not read a single decision item from {path}")


def _read_feed(feed_path: Path) -> tuple[dict[str, Any], str | None]:
    """Return (feed, degraded_reason).

    Prefer the store's validating ``load_feed``; fall back to a raw read when the
    live feed already carries preexisting rows the current validators reject, so
    this tool can still append to a partially-degraded production feed.
    """

    try:
        return store.load_feed(feed_path), None
    except store.DecisionStoreError as exc:
        raw = feed_path.read_bytes().decode("utf-8-sig")
        data = json.loads(raw)
        if not isinstance(data, dict) or not isinstance(data.get("items"), list):
            raise SystemExit(f"feed root/items malformed: {feed_path}") from exc
        return data, str(exc)


def _validate_new_item(item: dict[str, Any], existing_ids: set[str]) -> None:
    """Hard-validate the item with the store's validators + integrity checks."""

    # Item-level rules (required fields, id shape, evidence/deps typing).
    store._validate_item(item)
    # Feed-level rules exercised on the item alone (self-dep, evidence typing).
    store.validate_feed(
        {
            "schema_version": store.FEED_SCHEMA,
            "revision": 0,
            "updated_at_utc": _now_z(),
            "items": [item],
        }
    )
    item_id = str(item["id"])
    if item_id in existing_ids:
        raise SystemExit(f"refusing duplicate decision id: {item_id}")
    unknown = sorted(set(item.get("depends_on") or []) - existing_ids)
    if unknown:
        raise SystemExit(
            f"{item_id} depends on unknown ids: {', '.join(unknown)}"
        )


def _feed_validation_state(
    current: dict[str, Any], new_feed: dict[str, Any]
) -> tuple[bool, str | None]:
    """Guard: only abort if OUR append is what breaks whole-feed validation."""

    def _err(feed: dict[str, Any]) -> str | None:
        try:
            store.validate_feed(feed)
            return None
        except store.DecisionStoreError as exc:
            return str(exc)

    before = _err(current)
    after = _err(new_feed)
    if after and not before:
        raise SystemExit(f"appending this item breaks feed validation: {after}")
    return (after is None), after


def _build_new_feed(current: dict[str, Any], item: dict[str, Any]) -> dict[str, Any]:
    new_feed = dict(current)
    new_feed["items"] = list(current.get("items") or []) + [item]
    new_feed["revision"] = int(current["revision"]) + 1
    new_feed["updated_at_utc"] = _now_z()
    return new_feed


def _open_card_count(feed: dict[str, Any]) -> int:
    return store.render_vault_queue(feed).count("- [ ] @OWNER")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--item", type=Path, required=True, help="JSON file with one item")
    parser.add_argument("--feed", type=Path, default=store.DEFAULT_FEED)
    parser.add_argument("--vault-owner", type=Path, default=store.DEFAULT_VAULT_OWNER)
    parser.add_argument("--apply", action="store_true", help="write (default: dry-run)")
    args = parser.parse_args(argv)

    item = _load_item(args.item)
    item.setdefault("status", "OPEN")
    item.setdefault("created_at_utc", _now_z())
    item.setdefault("depends_on", [])
    if str(item.get("status", "")).upper() not in {"OPEN", "DEFERRED"}:
        raise SystemExit(
            f"this tool only ADDS an open item; got status={item.get('status')!r}"
        )

    current, read_degraded = _read_feed(args.feed)
    existing_ids = {str(row.get("id")) for row in current.get("items") or []}
    _validate_new_item(item, existing_ids)

    revision_before = int(current["revision"])
    new_feed = _build_new_feed(current, item)
    feed_valid, feed_valid_error = _feed_validation_state(current, new_feed)

    summary: dict[str, Any] = {
        "mode": "APPLY" if args.apply else "DRY_RUN",
        "feed": str(args.feed),
        "card_id": str(item["id"]),
        "card_status": str(item["status"]).upper(),
        "revision_before": revision_before,
        "revision_after": revision_before + 1,
        "existing_item_count": len(existing_ids),
        "item_count_after": len(new_feed["items"]),
        "open_cards_before": _open_card_count(current),
        "open_cards_after": _open_card_count(new_feed),
        "whole_feed_validates": feed_valid,
        "read_degraded": read_degraded,
        "whole_feed_validation_error": feed_valid_error,
    }

    if not args.apply:
        summary["written"] = False
        summary["note"] = "dry-run: no file written; re-run with --apply"
        print(json.dumps(summary, indent=2, ensure_ascii=False))
        return 0

    with store.exclusive_store_lock(args.feed):
        # Re-read inside the lock to serialise against concurrent writers.
        current, _ = _read_feed(args.feed)
        existing_ids = {str(row.get("id")) for row in current.get("items") or []}
        if str(item["id"]) in existing_ids:
            raise SystemExit(f"refusing duplicate decision id (concurrent): {item['id']}")
        revision_before = int(current["revision"])
        new_feed = _build_new_feed(current, item)
        store._write_json(args.feed, new_feed)
        store.sync_vault_queue(new_feed, args.vault_owner)

    summary["revision_before"] = revision_before
    summary["revision_after"] = revision_before + 1
    summary["item_count_after"] = len(new_feed["items"])
    summary["open_cards_after"] = _open_card_count(new_feed)
    summary["written"] = True
    summary["vault_owner"] = str(args.vault_owner)
    summary["vault_synced"] = True
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

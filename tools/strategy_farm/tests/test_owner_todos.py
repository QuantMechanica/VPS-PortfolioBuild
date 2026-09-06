from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm import owner_todos as todos


def _seed(path: Path, *, todo_id: str = "OWNER-TODO-20260906-FTMO-DEMO") -> Path:
    path.write_text(
        json.dumps(
            {
                "schema": todos.FEED_SCHEMA,
                "revision": 1,
                "updated_at_utc": "2026-09-06T00:00:00Z",
                "items": [
                    {
                        "id": todo_id,
                        "title": "FTMO Free-Trial-Demokonto anlegen",
                        "why": "Liefert die fehlende Evidenzklasse ohne Geld.",
                        "steps": ["Free Trial anlegen.", "Zugangsdaten privat ablegen."],
                        "due": "2026-09-06",
                        "status": "OPEN",
                        "source_decision_id": "OWNER-DEC-M13-ECONOMIC-TRIAL-20260906",
                        "created_at_utc": "2026-09-06T00:00:00Z",
                        "done_at_utc": None,
                        "notes": "",
                    }
                ],
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return path


def test_feed_roundtrip(tmp_path: Path) -> None:
    feed_path = tmp_path / "owner_todos.json"
    seed = _seed(tmp_path / "seed.json")
    feed = todos.load_feed(feed_path, seed_path=seed)
    todos.validate_feed(feed)
    assert len(feed["items"]) == 1
    assert todos.open_items(feed)[0]["id"] == "OWNER-TODO-20260906-FTMO-DEMO"
    # a fresh load with no seed reads back exactly what was persisted
    reloaded = todos.load_feed(feed_path, seed_path=None)
    assert reloaded["items"] == feed["items"]
    todos.validate_feed(reloaded)


def test_bootstrap_merges_missing_ids(tmp_path: Path) -> None:
    feed_path = tmp_path / "owner_todos.json"
    # pre-existing feed with a DIFFERENT item; bootstrap must merge, not replace
    feed_path.write_text(
        json.dumps(
            {
                "schema": todos.FEED_SCHEMA,
                "revision": 3,
                "updated_at_utc": "2026-09-05T00:00:00Z",
                "items": [
                    {
                        "id": "OWNER-TODO-20260905-OTHER",
                        "title": "Andere Handlung",
                        "why": "Kontext",
                        "steps": ["Schritt eins."],
                        "status": "OPEN",
                        "created_at_utc": "2026-09-05T00:00:00Z",
                    }
                ],
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    seed = _seed(tmp_path / "seed.json")
    feed = todos.load_feed(feed_path, seed_path=seed)
    ids = {item["id"] for item in feed["items"]}
    assert ids == {"OWNER-TODO-20260905-OTHER", "OWNER-TODO-20260906-FTMO-DEMO"}
    # persisted (revision bumped) so a no-seed reload still carries both
    reloaded = todos.load_feed(feed_path, seed_path=None)
    assert {item["id"] for item in reloaded["items"]} == ids
    # merging again is idempotent (no duplicate, no error)
    again = todos.load_feed(feed_path, seed_path=seed)
    assert len(again["items"]) == 2


def test_bootstrap_seeds_missing_feed(tmp_path: Path) -> None:
    feed_path = tmp_path / "does_not_exist.json"
    seed = _seed(tmp_path / "seed.json")
    feed = todos.load_feed(feed_path, seed_path=seed)
    assert feed_path.is_file()
    assert len(todos.open_items(feed)) == 1


def test_add_item_and_mark_done(tmp_path: Path) -> None:
    feed_path = tmp_path / "owner_todos.json"
    item = todos.add_item(
        id="OWNER-TODO-20260906-EXPORT",
        title="Portal-Export liefern",
        why="Ledger braucht die echten Zahlen.",
        steps=["Login.", "Export ziehen."],
        due="2026-09-07",
        source_decision_id=None,
        feed_path=feed_path,
        seed_path=None,
    )
    assert item["status"] == "OPEN"
    feed = todos.load_feed(feed_path, seed_path=None)
    assert len(feed["items"]) == 1

    with pytest.raises(todos.TodoStoreError, match="already exists"):
        todos.add_item(
            id="OWNER-TODO-20260906-EXPORT",
            title="dup",
            why="dup",
            steps=[],
            feed_path=feed_path,
            seed_path=None,
        )

    done = todos.mark_done(
        "OWNER-TODO-20260906-EXPORT", feed_path=feed_path, seed_path=None
    )
    assert done["status"] == "DONE"
    assert done["done_at_utc"]
    feed = todos.load_feed(feed_path, seed_path=None)
    assert todos.open_items(feed) == []

    with pytest.raises(todos.TodoStoreError, match="unknown todo id"):
        todos.mark_done("OWNER-TODO-NOPE-XX", feed_path=feed_path, seed_path=None)


def test_invalid_id_rejected(tmp_path: Path) -> None:
    feed_path = tmp_path / "owner_todos.json"
    with pytest.raises(todos.TodoStoreError, match="invalid todo id"):
        todos.add_item(
            id="not-a-valid-id",
            title="x",
            why="y",
            steps=[],
            feed_path=feed_path,
            seed_path=None,
        )


def test_vault_section_created_when_markers_absent(tmp_path: Path) -> None:
    vault = tmp_path / "OWNER.md"
    vault.write_text(
        "# @OWNER — ToDos\n\nIntro text.\n\n"
        + todos.VAULT_QUEUE_START
        + "\n## Queue\n"
        + "<!-- QM:MISSION_CONTROL_DECISIONS:END -->\n\nAfter queue.\n",
        encoding="utf-8",
    )
    seed = _seed(tmp_path / "seed.json")
    feed = todos.load_feed(tmp_path / "feed.json", seed_path=seed)

    assert todos.sync_vault_todos(feed, vault) is True
    text = vault.read_text(encoding="utf-8")
    assert todos.VAULT_TODOS_START in text and todos.VAULT_TODOS_END in text
    assert "## OWNER To-Dos (Mission Control)" in text
    assert "OWNER-TODO-20260906-FTMO-DEMO" in text
    # inserted BEFORE the decisions queue markers
    assert text.index(todos.VAULT_TODOS_START) < text.index(todos.VAULT_QUEUE_START)
    # existing content preserved
    assert "Intro text." in text and "After queue." in text
    assert "## Queue" in text


def test_vault_section_idempotent_and_updates_in_place(tmp_path: Path) -> None:
    vault = tmp_path / "OWNER.md"
    vault.write_text("# @OWNER\n\nBody.\n", encoding="utf-8")
    seed = _seed(tmp_path / "seed.json")
    feed = todos.load_feed(tmp_path / "feed.json", seed_path=seed)

    assert todos.sync_vault_todos(feed, vault) is True
    first = vault.read_text(encoding="utf-8")
    # a second sync with the same feed changes nothing
    assert todos.sync_vault_todos(feed, vault) is False
    assert vault.read_text(encoding="utf-8") == first
    # exactly one marker pair, no duplication
    assert first.count(todos.VAULT_TODOS_START) == 1
    assert first.count(todos.VAULT_TODOS_END) == 1

    # marking the only todo done empties the section; still one marker pair
    todos.mark_done(
        "OWNER-TODO-20260906-FTMO-DEMO", feed_path=tmp_path / "feed.json", seed_path=None
    )
    feed2 = todos.load_feed(tmp_path / "feed.json", seed_path=None)
    assert todos.sync_vault_todos(feed2, vault) is True
    text = vault.read_text(encoding="utf-8")
    assert text.count(todos.VAULT_TODOS_START) == 1
    assert "Keine offene OWNER-Handlung" in text
    assert "Body." in text

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


# ---------------------------------------------------------------------------
# vault import (import_vault) + migration
# ---------------------------------------------------------------------------
def _fixture_owner_md() -> str:
    return (
        "\n"
        "- [ ] **(03.09. 17:00Z, Info) Erste Info-Zeile.** Details eins mit "
        "`docs/ops/evidence/x.md`.\n"
        "- [x] **(03.09. 18:00Z) Erledigte Handlung.** Wurde ausgefuehrt.\n"
        "- [ ] **(03.09. 19:00Z, Vorlage) Vorlage mit Schritten.** Warum-Text hier.\n"
        "  1. Schritt eins.\n"
        "  2. Schritt zwei.\n"
        "\n"
        "## CEO Log 04.09.\n"
        "Some log line that must survive byte-exact.\n"
        "\n"
        + todos.VAULT_TODOS_START + "\n"
        "## OWNER To-Dos (Mission Control)\n"
        "- [ ] @OWNER `OWNER-TODO-20260906-INSIDE` **darf NICHT importiert werden**\n"
        + todos.VAULT_TODOS_END + "\n"
        + todos.VAULT_DECISIONS_START + "\n"
        "- [ ] @OWNER `OWNER-DEC-X` **auch nicht**\n"
        + todos.VAULT_DECISIONS_END + "\n"
        + todos.VAULT_DECIDED_START + "\n"
        + todos.VAULT_DECIDED_END + "\n"
    )


def _fixture_video_md() -> str:
    return (
        "# @OWNER — Videoanalysen\n\n"
        "Intro prose that is not a checklist item.\n\n"
        "- [ ] @OWNER `OWNER-VID-XAG` Enthaelt eines dieser Videos eine strukturelle "
        "Mechanik?\n"
        "      Zweite Zeile der Frage.\n"
    )


def _write_vault(tmp_path: Path):
    owner = tmp_path / "OWNER.md"
    video = tmp_path / "OWNER Videoanalysen.md"
    owner.write_text(_fixture_owner_md(), encoding="utf-8")
    video.write_text(_fixture_video_md(), encoding="utf-8")
    return owner, video


def test_import_vault_dry_run_counts(tmp_path: Path) -> None:
    owner, video = _write_vault(tmp_path)
    report = todos.import_vault(
        owner, video, apply=False, feed_path=tmp_path / "feed.json", seed_path=None,
        backup_path=tmp_path / "backup.md",
    )
    assert report["applied"] is False
    assert report["parsed"] == 4  # 3 top OWNER.md items + 1 video item
    assert report["open"] == 3 and report["done"] == 1
    assert report["by_kind"] == {"info": 1, "handlung": 1, "vorlage": 1, "video": 1}
    # dry run writes nothing
    assert not (tmp_path / "feed.json").exists()
    assert not (tmp_path / "backup.md").exists()
    assert owner.read_text(encoding="utf-8") == _fixture_owner_md()


def test_import_vault_apply_builds_feed(tmp_path: Path) -> None:
    owner, video = _write_vault(tmp_path)
    feed_path = tmp_path / "feed.json"
    report = todos.import_vault(
        owner, video, apply=True, feed_path=feed_path, seed_path=None,
        backup_path=tmp_path / "backup.md",
    )
    assert report["applied"] is True
    feed = todos.load_feed(feed_path, seed_path=None)
    todos.validate_feed(feed)
    by_kind = {it["kind"] for it in feed["items"]}
    assert by_kind == {"info", "handlung", "vorlage", "video"}
    # the item marked [x] in the vault is DONE in the feed
    done = [it for it in feed["items"] if it["status"] == "DONE"]
    assert len(done) == 1 and done[0]["kind"] == "handlung"
    # the Vorlage item carried its numbered sub-bullets as steps
    vorlage = next(it for it in feed["items"] if it["kind"] == "vorlage")
    assert vorlage["steps"] == ["Schritt eins.", "Schritt zwei."]
    # ids are the stable vault form and pass validation
    assert all(it["id"].startswith("OWNER-TODO-VAULT-") for it in feed["items"])
    # evidence path preserved in the why text
    info = next(it for it in feed["items"] if it["kind"] == "info")
    assert "docs/ops/evidence/x.md" in info["why"]
    # the video item's source points at the video file
    video_item = next(it for it in feed["items"] if it["kind"] == "video")
    assert video_item["source"]["file"] == str(video)


def test_import_vault_is_idempotent(tmp_path: Path) -> None:
    owner, video = _write_vault(tmp_path)
    feed_path = tmp_path / "feed.json"
    todos.import_vault(owner, video, apply=True, feed_path=feed_path, seed_path=None,
                       backup_path=tmp_path / "backup.md")
    first = todos.load_feed(feed_path, seed_path=None)
    first_ids = sorted(it["id"] for it in first["items"])
    # re-run on a FRESH (un-migrated) copy: same ids, no duplicates
    owner2 = tmp_path / "OWNER2.md"
    owner2.write_text(_fixture_owner_md(), encoding="utf-8")
    todos.import_vault(owner2, video, apply=True, feed_path=feed_path, seed_path=None,
                       backup_path=tmp_path / "backup2.md")
    second = todos.load_feed(feed_path, seed_path=None)
    assert sorted(it["id"] for it in second["items"]) == first_ids
    assert len(second["items"]) == len(set(it["id"] for it in second["items"]))


def test_import_vault_never_reopens_done(tmp_path: Path) -> None:
    owner, video = _write_vault(tmp_path)
    feed_path = tmp_path / "feed.json"
    todos.import_vault(owner, video, apply=True, feed_path=feed_path, seed_path=None,
                       backup_path=tmp_path / "backup.md")
    feed = todos.load_feed(feed_path, seed_path=None)
    info = next(it for it in feed["items"] if it["kind"] == "info")
    todos.mark_done(info["id"], feed_path=feed_path, seed_path=None)
    # re-import from a fresh copy where the vault still shows it OPEN
    owner2 = tmp_path / "OWNER2.md"
    owner2.write_text(_fixture_owner_md(), encoding="utf-8")
    todos.import_vault(owner2, video, apply=True, feed_path=feed_path, seed_path=None,
                       backup_path=tmp_path / "backup2.md")
    feed2 = todos.load_feed(feed_path, seed_path=None)
    reimported = next(it for it in feed2["items"] if it["id"] == info["id"])
    assert reimported["status"] == "DONE"  # never reopened


def test_migration_backup_and_replacement_preserve_rest(tmp_path: Path) -> None:
    owner, video = _write_vault(tmp_path)
    original_bytes = owner.read_bytes()
    backup = tmp_path / "Archive" / "OWNER_pre.md"
    report = todos.import_vault(
        owner, video, apply=True, feed_path=tmp_path / "feed.json", seed_path=None,
        backup_path=backup,
    )
    assert report["backup"] is True
    assert report["migrated_lines"] == 5  # 3 headers + 2 sub-bullets
    # backup is byte-exact
    assert backup.read_bytes() == original_bytes
    after = owner.read_text(encoding="utf-8")
    # migration notice present exactly once, imported checklist gone
    assert after.count(todos.MIGRATION_LINE) == 1
    assert "Erste Info-Zeile" not in after
    assert "Vorlage mit Schritten" not in after
    assert "Schritt eins." not in after
    # every other line is byte-identical
    assert "## CEO Log 04.09." in after
    assert "Some log line that must survive byte-exact." in after
    assert todos.VAULT_TODOS_START in after
    assert "OWNER-TODO-20260906-INSIDE" in after  # inside-marker item untouched
    assert todos.VAULT_DECISIONS_START in after
    # the video file is NOT migrated (stays the human list)
    assert video.read_text(encoding="utf-8") == _fixture_video_md()


def test_import_marks_done_from_vault_checkbox(tmp_path: Path) -> None:
    owner, video = _write_vault(tmp_path)
    feed_path = tmp_path / "feed.json"
    todos.import_vault(owner, video, apply=True, feed_path=feed_path, seed_path=None,
                       backup_path=tmp_path / "backup.md")
    feed = todos.load_feed(feed_path, seed_path=None)
    done = next(it for it in feed["items"] if it["status"] == "DONE")
    assert done["done_at_utc"]  # a done timestamp was stamped

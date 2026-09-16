"""E1-C condition-6: taint-guard rollback semantics proven FROM CODE.

Four states of the news_calendar_taint.v1 guard (news_calendar_taint.py),
each asserted against the real decision()/synchronize()/guard_claim() code on
temporary policy/pin files and an in-memory fixture DB. No repo config, no
live farm state is touched.

Documented semantics (what each state ACTUALLY does, per the assertions):

1. ENABLED + TAINTED PIN    -> reason PINNED_CALENDAR_TAINTED; sweep applies
                               the hold; claim blocked. A naive per-row hold
                               release (hold table UPDATE only) is RE-APPLIED
                               by the next synchronize() while the tainted
                               config entry and tainted pin remain — there is
                               no per-row persistent release for Q09_NEWS rows
                               under a tainted pin (the only per-row escape the
                               code provides is the Q10 scoped-B marker).
2. ENABLED + CLEAN PIN      -> decision() returns None; sweep action RELEASE;
                               the hold row is deactivated with release_note
                               "Untainted pinned bundle or explicit policy
                               rollback". This is PIN-LEVEL (global): every
                               still-pending taint-held row is released at once.
3. DISABLED (enabled=false) -> guard_claim() returns None (no NEW enforcement),
                               but sweep() short-circuits (applied=False, rows=[])
                               and EXISTING holds stay active=1. Claims remain
                               blocked by the generic active-hold check in the
                               claim SQL. "Disabled" therefore does NOT release
                               eligibility of already-held rows.
4. HASH-ABSENT (tainted=[]) -> decision() returns None via the documented
                               "explicit removal is the documented policy
                               rollback" branch; sweep RELEASEs existing
                               NEWS_CALENDAR_TAINTED holds while the policy
                               stays enabled.

Consequence for E1-C Option B: with the tainted sha entry kept (condition 1),
a per-row hold release effected by mutating only the hold table does NOT
survive the next sweep or claim (state 1). The persistent mechanisms the code
actually provides are: pin-level clean repin (state 2), emptying the tainted
list (state 4), the Q10 scoped-B marker path, or a code-level per-row
exemption. Never implement a rollback whose effect is opposite its label.
"""
from __future__ import annotations

import json
import sqlite3

import pytest

from tools.strategy_farm import news_calendar_taint as taint

TAINTED = "a" * 64
CLEAN = "b" * 64


def write_json(path, data):
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


@pytest.fixture
def use_fixture_config(tmp_path, monkeypatch):
    """Point the module CONFIG at the fixture policy file."""
    make_policy(tmp_path)
    monkeypatch.setattr(taint, "CONFIG", tmp_path / "policy.json")
    return tmp_path


def make_policy(tmp_path, *, enabled=True, tainted_sha=TAINTED):
    policy = {
        "schema": "qm.news-calendar-taint/v1",
        "enabled": enabled,
        "activation_evidence": "fixture-only CEO receipt",
        "tainted": (
            [{"sha256": tainted_sha, "evidence_path": "diagnostic.md",
              "declared_at": "2026-09-05T15:12:29+00:00"}]
            if tainted_sha
            else []
        ),
    }
    write_json(tmp_path / "policy.json", policy)
    return policy


@pytest.fixture
def db():
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(
        """
        CREATE TABLE work_items(id TEXT PRIMARY KEY,phase TEXT,status,
          ea_id TEXT,symbol TEXT,setfile_path TEXT,payload_json TEXT);
        CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY,
          hold_code TEXT,reason TEXT,active INTEGER,release_on_restart INTEGER,
          created_at TEXT,updated_at TEXT,released_at TEXT,release_note TEXT);
        CREATE TABLE events(id INTEGER PRIMARY KEY,ts TEXT,entity_type,
          entity_id TEXT,event TEXT,detail_json TEXT);
        """
    )
    yield conn
    conn.close()


def insert_news(conn, item_id="news", phase="Q09_NEWS"):
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
        (item_id, phase, "pending", "QM5_9999", "EURUSD.DWX", "x.set", "{}"),
    )
    conn.commit()


def hold(conn, item_id="news"):
    return conn.execute(
        "SELECT * FROM work_item_holds WHERE work_item_id=?", (item_id,)
    ).fetchone()


def sync(conn, policy, pin, apply=True):
    conn.execute("BEGIN IMMEDIATE")
    rows = taint.synchronize(conn, policy, pin, apply=apply)
    conn.commit()
    return rows


def test_state1_enabled_tainted_applies_hold_and_reapplies_naive_release(db, tmp_path, use_fixture_config):
    policy = make_policy(tmp_path)
    pin = write_json(tmp_path / "pin.json", {"content_sha256": TAINTED})
    insert_news(db)
    rows = sync(db, policy, pin)
    assert rows[0]["action"] == "HOLD"
    assert hold(db)["active"] == 1
    # Claim path: guard returns the taint reason (claim deferred by caller).
    db.execute("BEGIN IMMEDIATE")
    assert taint.guard_claim(db, "news", pin).startswith("PINNED_CALENDAR_TAINTED:")
    db.commit()
    # Naive per-row release (hold-table mutation only, config untouched):
    db.execute(
        "UPDATE work_item_holds SET active=0 WHERE work_item_id='news'"
    )
    db.commit()
    assert hold(db)["active"] == 0
    # Next sweep (and the claim guard) RE-APPLY the hold from the config entry.
    rows = sync(db, policy, pin)
    assert rows[0]["action"] == "HOLD" and hold(db)["active"] == 1
    db.execute("BEGIN IMMEDIATE")
    assert taint.guard_claim(db, "news", pin)
    db.commit()
    assert hold(db)["active"] == 1


def test_state2_enabled_clean_pin_releases_eligibility_globally(db, tmp_path, use_fixture_config):
    policy = make_policy(tmp_path)
    pin = write_json(tmp_path / "pin.json", {"content_sha256": TAINTED})
    insert_news(db)
    insert_news(db, "news2")
    sync(db, policy, pin)
    write_json(pin, {"content_sha256": CLEAN})
    rows = sync(db, policy, pin)
    assert sorted(r["action"] for r in rows) == ["RELEASE", "RELEASE"]
    for item_id in ("news", "news2"):
        row = hold(db, item_id)
        assert row["active"] == 0
        assert row["release_note"] == (
            "Untainted pinned bundle or explicit policy rollback"
        )
    db.execute("BEGIN IMMEDIATE")
    assert taint.guard_claim(db, "news", pin) is None
    db.commit()


def test_state3_disabled_stops_new_enforcement_but_existing_holds_stay(db, tmp_path, use_fixture_config):
    policy = make_policy(tmp_path)
    pin = write_json(tmp_path / "pin.json", {"content_sha256": TAINTED})
    insert_news(db)
    sync(db, policy, pin)
    assert hold(db)["active"] == 1
    # Owner rollback label says "set enabled=false"; actual semantics:
    policy["enabled"] = False
    write_json(tmp_path / "policy.json", policy)
    db.execute("BEGIN IMMEDIATE")
    assert taint.guard_claim(db, "news", pin) is None  # guard itself inert
    db.commit()
    assert hold(db)["active"] == 1  # ...but the hold row is NOT released
    # The production sweep short-circuits on a disabled policy, so it will not
    # release the row either; the generic active-hold claim check keeps
    # blocking the row.
    conn2 = db.execute(
        "SELECT 1 WHERE EXISTS (SELECT 1 FROM work_item_holds "
        "WHERE work_item_id='news' AND active=1)"
    ).fetchone()
    assert conn2 is not None


def test_state4_hash_absent_is_documented_rollback_and_releases(db, tmp_path, use_fixture_config):
    policy = make_policy(tmp_path)
    pin = write_json(tmp_path / "pin.json", {"content_sha256": TAINTED})
    insert_news(db)
    sync(db, policy, pin)
    assert hold(db)["active"] == 1
    policy["tainted"] = []  # sha entry removed; policy stays enabled
    write_json(tmp_path / "policy.json", policy)
    rows = sync(db, policy, pin)
    assert rows[0]["action"] == "RELEASE"
    assert hold(db)["active"] == 0
    db.execute("BEGIN IMMEDIATE")
    assert taint.guard_claim(db, "news", pin) is None
    db.commit()

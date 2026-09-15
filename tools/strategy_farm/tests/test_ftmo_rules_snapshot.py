"""FTMO official-rule snapshot freshness, rebind, and safe fallback (section 63).

Slice f1_ftmo_validation_readiness.
"""
from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

from tools.strategy_farm.ftmo import policy_config
from tools.strategy_farm.ftmo import rules_snapshot as rs


def _snap(days_old, now):
    taken = now - dt.timedelta(days=days_old)
    return {"retrieved_at_utc": taken.strftime("%Y-%m-%dT%H:%M:%SZ"), "source_url": "https://ftmo.com/"}


NOW = dt.datetime(2026, 9, 15, 12, tzinfo=dt.timezone.utc)


def test_fresh_snapshot_ok():
    fb = rs.freshness_blocker(_snap(2, NOW), NOW)
    assert fb["blocker"] is False
    assert fb["severity"] == "OK"


def test_warn_between_go_and_blocker():
    fb = rs.freshness_blocker(_snap(11, NOW), NOW)
    assert fb["blocker"] is False
    assert fb["severity"] == "WARN"


def test_stale_beyond_blocker_age_is_blocker():
    fb = rs.freshness_blocker(_snap(45, NOW), NOW)
    assert fb["blocker"] is True
    assert fb["severity"] == "BLOCKER"
    assert fb["freshness_days"] > policy_config.RULE_SNAPSHOT_BLOCKER_AGE_DAYS


def test_missing_snapshot_is_blocker():
    fb = rs.freshness_blocker(None, NOW)
    assert fb["blocker"] is True
    assert fb["freshness_days"] == "EVIDENCE_MISSING"


def test_shipped_2026_09_15_snapshot_is_present_and_fresh_at_ship():
    snap = rs.load_latest_snapshot()
    assert snap is not None
    # the snapshot this slice shipped is the newest on disk
    assert "2026-09-15" in Path(snap["_snapshot_path"]).name
    # at its own retrieval instant it is fresh
    taken = rs.snapshot_datetime(snap)
    fb = rs.freshness_blocker(snap, taken + dt.timedelta(days=1))
    assert fb["blocker"] is False


def test_fetch_falls_back_safely_when_blocked(tmp_path):
    # a fetcher that always fails simulates the bot-blocked VPS
    def blocked(url):
        return None, "", "BLOCKED:URLError"

    probe = rs.fetch_current_rules(fetcher=blocked, now=NOW)
    assert probe["any_ok"] is False
    for src in probe["sources"].values():
        assert src["fetch_status"].startswith("BLOCKED")


def test_rebind_updates_pointer_not_gate_thresholds(tmp_path):
    # minimal rulepack + snapshot
    rulepack = tmp_path / "rp.json"
    go = [{"criterion_id": "ftmo_rule_snapshot_fresh", "parameters": {"maximum_age_days": 7}}]
    rulepack.write_text(
        json.dumps(
            {
                "as_of": "2020-01-01",
                "official_sources": [{"snapshot_path": "old", "snapshot_sha256": "x", "retrieved_at_utc": "old"}],
                "evaluation_profile": {"go_criteria": go},
            }
        ),
        encoding="utf-8",
    )
    snap = tmp_path / "2026-09-15_ftmo_official_rules_snapshot.json"
    snap.write_text(json.dumps(_snap(0, NOW)), encoding="utf-8")

    binding = rs.rebind_rulepack(rulepack, snap, NOW)
    after = json.loads(rulepack.read_text(encoding="utf-8"))
    # go-criteria threshold untouched (RED boundary)
    assert after["evaluation_profile"]["go_criteria"][0]["parameters"]["maximum_age_days"] == 7
    # pointer + freshness metadata updated
    assert after["official_sources"][0]["snapshot_sha256"] == binding["bound_snapshot_sha256"]
    assert after["rule_snapshot_binding"]["readiness_blocker_age_days"] == policy_config.RULE_SNAPSHOT_BLOCKER_AGE_DAYS

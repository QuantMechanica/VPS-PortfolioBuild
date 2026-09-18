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

    binding = rs.rebind_rulepack(
        rulepack, snap, NOW, freshness_state_path=tmp_path / "freshness.json"
    )
    after = json.loads(rulepack.read_text(encoding="utf-8"))
    # go-criteria threshold untouched (RED boundary)
    assert after["evaluation_profile"]["go_criteria"][0]["parameters"]["maximum_age_days"] == 7
    # pointer + freshness metadata updated
    assert after["official_sources"][0]["snapshot_sha256"] == binding["bound_snapshot_sha256"]
    assert after["rule_snapshot_binding"]["readiness_blocker_age_days"] == policy_config.RULE_SNAPSHOT_BLOCKER_AGE_DAYS


def test_rebind_is_noop_on_pinned_rulepack_when_snapshot_unchanged(tmp_path):
    """A routine freshness check must not drift a hash-pinned rulepack (router
    ticket 41d46b03: `refresh` was rewriting `rebound_at_utc` into the pinned
    FTMO_2S_100K_STANDARD_V2.json on every run, tripping
    `rulepack_file_hash_drift` in tools/strategy_farm/ftmo/trial_setpath.py
    even though the bound snapshot never changed)."""
    snap = tmp_path / "2026-09-15_ftmo_official_rules_snapshot.json"
    snap.write_text(json.dumps(_snap(0, NOW)), encoding="utf-8")
    snap_sha = rs.sha256_file(snap)
    retrieved = json.loads(snap.read_text(encoding="utf-8"))["retrieved_at_utc"]
    # rebind_rulepack relativizes the snapshot pointer against REPO_ROOT when the
    # snapshot lives under it (pytest's tmp_path can land under the repo tree);
    # the fixture must already carry whatever pointer form rebind_rulepack would
    # compute, or the "already bound" comparison spuriously reports a change.
    snap_ref = snap.as_posix()
    repo_root_posix = str(rs.REPO_ROOT.as_posix())
    if repo_root_posix in snap_ref:
        snap_ref = snap_ref.split(repo_root_posix + "/", 1)[-1]

    go = [{"criterion_id": "ftmo_rule_snapshot_fresh", "parameters": {"maximum_age_days": 7}}]
    rulepack = tmp_path / "rp.json"
    rulepack.write_text(
        json.dumps(
            {
                "as_of": retrieved[:10],
                "official_sources": [
                    {
                        "snapshot_path": snap_ref,
                        "snapshot_sha256": snap_sha,
                        "retrieved_at_utc": retrieved,
                    }
                ],
                "evaluation_profile": {"go_criteria": go},
                "rule_snapshot_binding": {
                    "bound_snapshot_path": snap_ref,
                    "bound_snapshot_sha256": snap_sha,
                    "bound_snapshot_retrieved_at_utc": retrieved,
                    "rebound_at_utc": "2026-09-15T14:00:00Z",
                    "freshness_max_age_days": policy_config.RULE_SNAPSHOT_MAX_AGE_DAYS,
                    "readiness_blocker_age_days": policy_config.RULE_SNAPSHOT_BLOCKER_AGE_DAYS,
                    "note": "Freshness tracking only; go-criteria thresholds unchanged (OWNER-only).",
                },
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    before = rulepack.read_bytes()

    freshness_state = tmp_path / "freshness.json"
    binding = rs.rebind_rulepack(
        rulepack,
        snap,
        NOW + dt.timedelta(hours=6),
        freshness_state_path=freshness_state,
    )

    after = rulepack.read_bytes()
    assert after == before, "pinned rulepack must stay byte-identical when the bound snapshot is unchanged"
    # rebound_at_utc is not silently advanced on a no-op check
    assert binding["rebound_at_utc"] == "2026-09-15T14:00:00Z"
    # the freshness check outcome is still observable, just off the pinned file
    state = json.loads(freshness_state.read_text(encoding="utf-8"))
    assert state["rebound_this_check"] is False
    assert state["binding"]["bound_snapshot_sha256"] == snap_sha

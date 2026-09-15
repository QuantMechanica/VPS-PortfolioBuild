"""Kimi governor (kimi_governor.py): NORMAL/CONSERVE/EXHAUSTED derivation from the
ledger, consecutive-failure and subscription-period rules, ownership-tracked flag
write/clear (never touching a foreign-owned flag), allowed_capabilities per state,
and honest usage_source. No live calls."""
from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import kimi_governor as kg  # noqa: E402


NOW = dt.datetime(2026, 9, 20, 12, 0, 0, tzinfo=dt.timezone.utc)


@pytest.fixture()
def gov(tmp_path: Path) -> dict:
    return kg.governor_config({
        "schema": "qm.kimi-adapter.v1",
        "governor": {
            "ledger_path": str(tmp_path / "ledger.jsonl"),
            "flag_path": str(tmp_path / "KIMI_LOW_QUOTA.flag"),
            "state_path": str(tmp_path / "state.json"),
            "log_path": str(tmp_path / "gov.log"),
            "managed_by": "kimi_governor",
            "caps": {"day": 10, "week": 40},
            "conserve_pct": 70,
            "consecutive_fail_threshold": 2,
            "consecutive_fail_statuses": ["rate_limited", "auth_expired"],
            "conserve_allowed_capabilities": ["edge_discovery", "hypothesis_authoring",
                                              "cross_experiment_analysis", "research_critic"],
            "subscription_period": {"start": "2026-09-15", "end": "2026-10-15"},
            "period_conserve_days_before_end": 3,
        },
    })


def _rows(n: int, *, status: str = "ok", when: dt.datetime = NOW, offset_min: int = 0) -> list[dict]:
    out = []
    for i in range(n):
        ts = when - dt.timedelta(minutes=offset_min + i)
        out.append({"ts_utc": ts.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                    "status": status, "usage": None})
    return out


# --- state derivation ------------------------------------------------------------

def test_state_normal_when_within_caps(gov: dict) -> None:
    info = kg.compute_state(_rows(3), gov, now=NOW)
    assert info["state"] == "NORMAL"
    assert info["counts"]["day"] == 3 and info["counts"]["week"] == 3
    assert info["usage_source"] == "local_ledger_only"


def test_state_conserve_at_70pct_of_daily_cap(gov: dict) -> None:
    info = kg.compute_state(_rows(7), gov, now=NOW)  # 7/10 = 70%
    assert info["state"] == "CONSERVE"


def test_state_conserve_on_weekly_pct(gov: dict) -> None:
    # spread across the week, below daily cap but >=70% weekly (28/40 = 70%)
    rows = _rows(5, when=NOW) + _rows(23, when=NOW - dt.timedelta(days=3))
    info = kg.compute_state(rows, gov, now=NOW)
    assert info["counts"]["day"] == 5 and info["counts"]["week"] == 28
    assert info["state"] == "CONSERVE"


def test_state_exhausted_on_daily_cap(gov: dict) -> None:
    info = kg.compute_state(_rows(10), gov, now=NOW)  # 10/10
    assert info["state"] == "EXHAUSTED"


def test_state_exhausted_on_weekly_cap(gov: dict) -> None:
    rows = _rows(6, when=NOW) + _rows(40, when=NOW - dt.timedelta(days=2))
    info = kg.compute_state(rows, gov, now=NOW)
    assert info["state"] == "EXHAUSTED"


def test_state_exhausted_on_two_consecutive_failures(gov: dict) -> None:
    # tail of ledger = 2 rate_limited in a row
    rows = _rows(2, status="ok", when=NOW - dt.timedelta(minutes=30)) \
        + [{"ts_utc": (NOW - dt.timedelta(minutes=2)).isoformat().replace("+00:00", "Z"),
            "status": "rate_limited"},
           {"ts_utc": (NOW - dt.timedelta(minutes=1)).isoformat().replace("+00:00", "Z"),
            "status": "auth_expired"}]
    info = kg.compute_state(rows, gov, now=NOW)
    assert info["state"] == "EXHAUSTED"
    assert info["consecutive_fail_streak"] == 2


def test_single_failure_does_not_exhaust(gov: dict) -> None:
    rows = _rows(2, status="ok", when=NOW - dt.timedelta(minutes=10)) \
        + [{"ts_utc": (NOW - dt.timedelta(minutes=1)).isoformat().replace("+00:00", "Z"),
            "status": "rate_limited"}]
    info = kg.compute_state(rows, gov, now=NOW)
    assert info["state"] == "NORMAL"
    assert info["consecutive_fail_streak"] == 1


def test_state_exhausted_on_cli_missing_last(gov: dict) -> None:
    rows = _rows(1, when=NOW - dt.timedelta(minutes=5)) \
        + [{"ts_utc": NOW.isoformat().replace("+00:00", "Z"), "status": "cli_missing"}]
    info = kg.compute_state(rows, gov, now=NOW)
    assert info["state"] == "EXHAUSTED"


def test_state_conserve_near_period_end(gov: dict) -> None:
    near = dt.datetime(2026, 10, 14, 12, 0, tzinfo=dt.timezone.utc)  # end is 2026-10-15
    info = kg.compute_state(_rows(1, when=near), gov, now=near)
    assert info["state"] == "CONSERVE"
    assert info["subscription_period"]["near_end"] is True


def test_state_exhausted_after_period_end(gov: dict) -> None:
    after = dt.datetime(2026, 10, 16, 12, 0, tzinfo=dt.timezone.utc)
    info = kg.compute_state(_rows(1, when=after), gov, now=after)
    assert info["state"] == "EXHAUSTED"
    assert info["subscription_period"]["ended"] is True


def test_usage_source_flips_when_snapshot_present(gov: dict) -> None:
    rows = _rows(1)
    rows[0]["usage"] = {"tokens": 123}
    info = kg.compute_state(rows, gov, now=NOW)
    assert info["usage_source"] == "usage_snapshot"


# --- allowed_capabilities --------------------------------------------------------

def test_allowed_capabilities_per_state(gov: dict) -> None:
    assert kg.allowed_capabilities("NORMAL", gov) is None  # unrestricted
    conserve = kg.allowed_capabilities("CONSERVE", gov)
    assert set(conserve) == {"edge_discovery", "hypothesis_authoring",
                             "cross_experiment_analysis", "research_critic"}
    assert kg.allowed_capabilities("EXHAUSTED", gov) == []


# --- flag reconciliation ---------------------------------------------------------

def test_flag_written_on_exhausted_with_owner_marker(gov: dict) -> None:
    info = kg.compute_state(_rows(10), gov, now=NOW)
    action = kg.reconcile_flag(info, gov)
    flag = Path(gov["flag_path"])
    assert action["action"] == "SET" and flag.exists()
    body = json.loads(flag.read_text(encoding="utf-8"))
    assert body["schema"] == kg.FLAG_SCHEMA
    assert body["managed_by"] == "kimi_governor"
    assert body["state"] == "EXHAUSTED"


def test_flag_written_on_conserve_carries_state(gov: dict) -> None:
    # F1 (2026-09-15): CONSERVE must be durable at the flag boundary so both planes
    # learn it (previously CONSERVE wrote no flag and silently collapsed to NORMAL).
    info = kg.compute_state(_rows(7), gov, now=NOW)  # 7/10 = 70% -> CONSERVE
    assert info["state"] == "CONSERVE"
    action = kg.reconcile_flag(info, gov)
    flag = Path(gov["flag_path"])
    assert action["action"] == "SET" and flag.exists()
    body = json.loads(flag.read_text(encoding="utf-8"))
    assert body["state"] == "CONSERVE" and body["managed_by"] == "kimi_governor"


def test_flag_updated_on_conserve_to_exhausted_transition(gov: dict) -> None:
    flag = Path(gov["flag_path"])
    kg.reconcile_flag(kg.compute_state(_rows(7), gov, now=NOW), gov)   # CONSERVE
    assert json.loads(flag.read_text(encoding="utf-8"))["state"] == "CONSERVE"
    action = kg.reconcile_flag(kg.compute_state(_rows(10), gov, now=NOW), gov)  # EXHAUSTED
    assert action["action"] == "UPDATE"
    assert json.loads(flag.read_text(encoding="utf-8"))["state"] == "EXHAUSTED"


def test_flag_cleared_when_recovered_if_owned(gov: dict) -> None:
    flag = Path(gov["flag_path"])
    flag.write_text("MANAGED_BY=kimi_governor\nset_at=x\n", encoding="utf-8")
    info = kg.compute_state(_rows(2), gov, now=NOW)  # NORMAL
    action = kg.reconcile_flag(info, gov)
    assert action["action"] == "CLEAR" and not flag.exists()


def test_flag_not_cleared_when_foreign_owned(gov: dict) -> None:
    flag = Path(gov["flag_path"])
    flag.write_text("MANAGED_BY=some_other_owner\nset_at=x\n", encoding="utf-8")
    info = kg.compute_state(_rows(2), gov, now=NOW)  # NORMAL -> would clear if owned
    action = kg.reconcile_flag(info, gov)
    assert action["action"] == "leave-external" and flag.exists()


def test_flag_not_overwritten_when_foreign_owned_on_exhausted(gov: dict) -> None:
    flag = Path(gov["flag_path"])
    flag.write_text("MANAGED_BY=some_other_owner\nreason=manual\n", encoding="utf-8")
    info = kg.compute_state(_rows(10), gov, now=NOW)  # EXHAUSTED
    action = kg.reconcile_flag(info, gov)
    assert action["action"] == "leave-external"
    assert "some_other_owner" in flag.read_text(encoding="utf-8")


def test_normal_writes_no_flag_and_clears_owned(gov: dict) -> None:
    # NORMAL is the only state that leaves no flag; an owned flag is cleared.
    info = kg.compute_state(_rows(2), gov, now=NOW)  # NORMAL
    action = kg.reconcile_flag(info, gov)
    assert action["action"] == "noop"
    assert not Path(gov["flag_path"]).exists()


# --- evaluate end-to-end ---------------------------------------------------------

def test_evaluate_writes_state_file_and_flag(tmp_path: Path, gov: dict) -> None:
    ledger = Path(gov["ledger_path"])
    ledger.write_text("\n".join(json.dumps(r) for r in _rows(10)) + "\n", encoding="utf-8")
    cfg = {"schema": "qm.kimi-adapter.v1", "governor": gov}
    info = kg.evaluate(cfg, now=NOW)
    assert info["state"] == "EXHAUSTED"
    assert Path(gov["state_path"]).exists()
    assert Path(gov["flag_path"]).exists()
    assert info["allowed_capabilities"] == []


# --- real quota telemetry (OWNER-DEC-CBE-20260915 sec30-33) ----------------------

def _quota(*, fetch_status: str = "ok", r5h: float | None = None, r7d: float | None = None,
           monthly: float | None = None, ts: dt.datetime = NOW, plan: str = "Allegro") -> dict:
    def win(r):
        return None if r is None else {"used_ratio": r, "reset_at": ts.isoformat()}
    return {
        "schema": "qm.kimi-quota/v1", "fetch_status": fetch_status, "plan": plan,
        "source": "api.kimi.com/coding/v1/usages",
        "source_timestamp": ts.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "rolling_5h": win(r5h), "rolling_7d": win(r7d), "monthly": win(monthly),
        "breakdown": None, "extra_quota_active": False,
    }


def test_real_ratios_drive_normal(gov: dict) -> None:
    info = kg.compute_state(_rows(2), gov, now=NOW, quota_state=_quota(r5h=0.10, r7d=0.02))
    assert info["state"] == "NORMAL"
    assert info["usage_source"] == "managed_usage_endpoint"
    assert info["real_quota"]["plan"] == "Allegro"


def test_real_ratios_drive_conserve_on_window(gov: dict) -> None:
    # 5h window at 0.85 >= 0.80 conserve threshold -> CONSERVE from REAL telemetry,
    # even though only 2 calls are in the ledger (well below the runaway guard).
    info = kg.compute_state(_rows(2), gov, now=NOW, quota_state=_quota(r5h=0.85, r7d=0.05))
    assert info["state"] == "CONSERVE"
    assert info["usage_source"] == "managed_usage_endpoint"


def test_real_ratios_drive_conserve_on_monthly(gov: dict) -> None:
    info = kg.compute_state(_rows(1), gov, now=NOW, quota_state=_quota(r5h=0.1, monthly=0.90))
    assert info["state"] == "CONSERVE"


def test_real_ratios_drive_exhausted(gov: dict) -> None:
    info = kg.compute_state(_rows(1), gov, now=NOW, quota_state=_quota(r5h=0.99, r7d=0.2))
    assert info["state"] == "EXHAUSTED"
    assert info["usage_source"] == "managed_usage_endpoint"


def test_runaway_guard_still_trips_with_normal_real_ratios(gov: dict) -> None:
    # Real subscription is basically unused, but a runaway loop burned the local guard
    # (10/10 daily) -> EXHAUSTED anyway. Anomaly protection is never disabled (sec33).
    info = kg.compute_state(_rows(10), gov, now=NOW, quota_state=_quota(r5h=0.0, r7d=0.0))
    assert info["state"] == "EXHAUSTED"
    assert any("runaway guard" in r for r in info["reasons"])


def test_stale_real_state_falls_back_to_ledger(gov: dict) -> None:
    stale = _quota(r5h=0.99, ts=NOW - dt.timedelta(hours=2))  # older than max_state_age_s
    info = kg.compute_state(_rows(2), gov, now=NOW, quota_state=stale)
    # The stale 0.99 must NOT drive EXHAUSTED; we fall back to the (quiet) ledger.
    assert info["state"] == "NORMAL"
    assert info["usage_source"] == "local_ledger_fallback"
    assert info["fallback_class"] == "ok"


def test_auth_error_real_state_falls_back(gov: dict) -> None:
    info = kg.compute_state(_rows(2), gov, now=NOW,
                            quota_state=_quota(fetch_status="auth_error"))
    assert info["usage_source"] == "local_ledger_fallback"
    assert info["fallback_class"] == "auth_error"
    assert info["state"] == "NORMAL"  # ledger is quiet -> safe fallback


def test_network_error_fallback_still_honours_ledger_exhaustion(gov: dict) -> None:
    # Fetch failed, but the local ledger shows the runaway guard is hit -> EXHAUSTED.
    info = kg.compute_state(_rows(10), gov, now=NOW,
                            quota_state=_quota(fetch_status="network_error"))
    assert info["usage_source"] == "local_ledger_fallback"
    assert info["state"] == "EXHAUSTED"


def test_legacy_path_unchanged_when_no_quota_state(gov: dict) -> None:
    info = kg.compute_state(_rows(2), gov, now=NOW)  # no quota_state
    assert info["usage_source"] == "local_ledger_only"
    assert info["fallback_class"] is None and info["real_quota"] is None


def test_evaluate_prefers_injected_real_quota(tmp_path: Path, gov: dict) -> None:
    ledger = Path(gov["ledger_path"])
    ledger.write_text("\n".join(json.dumps(r) for r in _rows(2)) + "\n", encoding="utf-8")
    cfg = {"schema": "qm.kimi-adapter.v1", "governor": gov}
    info = kg.evaluate(cfg, now=NOW, quota_state=_quota(r5h=0.99))
    assert info["state"] == "EXHAUSTED"
    assert info["usage_source"] == "managed_usage_endpoint"
    assert Path(gov["flag_path"]).exists()


def test_runaway_guard_default_raised_to_120_600() -> None:
    # Directive sec33: with no explicit caps, the guard defaults are raised well above
    # the old 40/200 so they cannot bind before the real telemetry does.
    gov = kg.governor_config({"schema": "qm.kimi-adapter.v1", "governor": {}})
    assert gov["runaway_guard"] == {"day": 120, "week": 600}
    assert gov["caps"] == {"day": 120, "week": 600}  # legacy alias preserved

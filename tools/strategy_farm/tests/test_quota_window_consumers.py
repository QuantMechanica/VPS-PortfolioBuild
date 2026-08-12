from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import health  # noqa: E402
import quota_pull  # noqa: E402
import render_cockpit  # noqa: E402


def _window(used: int, seconds: int, reset_at: int) -> dict:
    return {
        "used_percent": used,
        "limit_window_seconds": seconds,
        "reset_at": reset_at,
    }


def test_legacy_codex_shape_maps_primary_to_5h_and_secondary_to_week() -> None:
    hourly = _window(31, 18_000, 1_800_000_000)
    weekly = _window(72, quota_pull.WEEK_WINDOW_SECONDS, 1_800_500_000)

    selected_weekly, selected_hourly = quota_pull._pick_rate_windows(
        {"primary_window": hourly, "secondary_window": weekly}
    )

    assert selected_hourly is hourly
    assert selected_weekly is weekly


def test_current_codex_shape_maps_primary_to_week_without_fake_5h() -> None:
    weekly = _window(14, quota_pull.WEEK_WINDOW_SECONDS, 1_800_500_000)

    selected_weekly, selected_hourly = quota_pull._pick_rate_windows(
        {"primary_window": weekly, "secondary_window": None}
    )

    assert selected_weekly is weekly
    assert selected_hourly == {}


def test_pull_codex_emits_current_shape_without_cross_labelling(
    tmp_path: Path, monkeypatch
) -> None:
    auth = tmp_path / "auth.json"
    auth.write_text(
        json.dumps({"tokens": {"access_token": "test", "account_id": "acct"}}),
        encoding="utf-8",
    )
    raw = {
        "plan_type": "team",
        "rate_limit": {
            "primary_window": _window(
                14, quota_pull.WEEK_WINDOW_SECONDS, 1_800_500_000
            ),
            "secondary_window": None,
            "limit_reached": False,
        },
    }
    monkeypatch.setattr(quota_pull, "CODEX_AUTH", auth)
    monkeypatch.setattr(quota_pull, "_http_json", lambda *_args, **_kwargs: raw)

    structured = quota_pull.pull_codex()["structured"]

    assert structured["hour_pct"] is None
    assert structured["hour_reset"] is None
    assert structured["week_pct"] == 14
    assert structured["week_reset"] == "21.01. 02:53 UTC"


def test_cockpit_prefers_structured_week_and_keeps_5h_empty(
    tmp_path: Path, monkeypatch
) -> None:
    snapshot = tmp_path / "quota_snapshot.json"
    now = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
    snapshot.write_text(
        json.dumps(
            {
                "codex": {
                    "received_at": now,
                    "data": {
                        "structured": {
                            "hour_pct": None,
                            "week_pct": 14,
                            "hour_reset": None,
                            "week_reset": "20.07. 12:00 UTC",
                        },
                        "full_text_head": "",
                    },
                }
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr(render_cockpit, "QUOTA_SNAPSHOT", snapshot)

    codex = render_cockpit.quota_snapshot()["codex"]

    assert codex["hour_pct"] is None
    assert codex["hour_reset"] is None
    assert codex["week_pct"] == 14
    assert codex["week_reset"] == "20.07. 12:00 UTC"


def test_health_consumer_checks_freshness_not_window_labels(
    tmp_path: Path, monkeypatch
) -> None:
    now = dt.datetime(2026, 7, 19, 18, 0, tzinfo=dt.timezone.utc)
    snapshot = tmp_path / "quota_snapshot.json"
    snapshot.write_text(
        json.dumps({"codex": {"received_at": now.isoformat()}}),
        encoding="utf-8",
    )
    (tmp_path / "CLAUDE_DISABLED.flag").touch()
    monkeypatch.setattr(health, "ROOT", tmp_path)
    monkeypatch.setattr(health, "QUOTA_SNAPSHOT", snapshot)
    monkeypatch.setattr(health, "_utc_now", lambda: now)

    result = health.chk_quota_snapshot_fresh()

    assert result["status"] == "OK"
    assert result["value"] == 0

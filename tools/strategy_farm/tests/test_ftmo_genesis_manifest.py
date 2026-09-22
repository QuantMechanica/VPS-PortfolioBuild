from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm.ftmo.genesis_manifest import (
    ManifestError,
    build_manifest,
    seal_launch,
    verify_manifest,
)
from tools.strategy_farm.ftmo.sunday_preflight import run_preflight


def _write(path: Path, text: str, *, encoding: str = "utf-8") -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding=encoding)
    return path


def _fixture(tmp_path: Path, *, configured_ks: bool = True) -> dict[str, Path]:
    repo = tmp_path / "repo"
    terminal = tmp_path / "terminal" / "ABCDEF0123456789"
    package = tmp_path / "package"
    label = "QM5_10001_fixture"
    source = _write(repo / f"framework/EAs/{label}/{label}.mq5", "void OnTick() {}\n")
    _write(
        repo / "framework/EAs/QM5_13206_ftmo-account-governor/QM5_13206_ftmo-account-governor.mq5",
        "// maximum_loss enforcement\n",
    )
    _write(repo / "framework/include/QM/QM_FTMOGovernorPolicy.mqh", "int QM_FTMO_PragueDayKey(){return 1;}\n")
    _write(repo / "framework/include/QM/QM_AccountRiskReservation.mqh", "bool QM_AccountRiskRequestLoss(){return true;}\n")
    _write(
        repo / "framework/registry/ea_id_registry.csv",
        "ea_id,slug,strategy_id,status,owner,created_at,retired_at,retired_reason,retired_evidence\n"
        "10001,fixture,s,active,Codex,2026-01-01,,,\n",
    )
    _write(
        repo / "framework/registry/magic_numbers.csv",
        "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n"
        "10001,fixture,2,EURUSD.DWX,100010002,2026-01-01,Codex,active\n",
    )
    common = (
        "[Common]\nLogin=123456789\nServer=FTMO-Demo\n"
        "[Experts]\nEnabled=0\n"
    )
    _write(terminal / "config/common.ini", common, encoding="utf-16")
    ex5 = _write(terminal / f"MQL5/Experts/QM_FTMO/{label}.ex5", "fixture-ex5")
    _write(terminal / "MQL5/Experts/QM_FTMO/QM5_13206_ftmo-account-governor.ex5", "governor")
    ks = "qm_ks_day_anchor_mode=PRAGUE_MIDNIGHT\nqm_ks_book_tag=BOOK_A\n" if configured_ks else ""
    setfile = _write(
        package / "sets/QM5_10001_EURUSD_H1_live_trial.set",
        "ENV=live\nRISK_FIXED=0\nRISK_PERCENT=0.5\n"
        "qm_news_temporal=3\nqm_news_compliance=2\nqm_news_stale_max_hours=336\n"
        "qm_friday_close_enabled=true\nqm_friday_close_hour_broker=21\n" + ks,
    )
    governor_set = _write(
        terminal / "MQL5/Profiles/Presets/QM_FTMO_M13/governor.set",
        "allowed_magics_csv=100010002\nchallenge_id=FIXTURE\n"
        "governor_timer_ms=200\nclose_deviation_points=50\n",
    )
    receipt = _write(package / "RECEIPT_alias_builds.md", "compile: 0 errors / 0 warnings\n")
    rules = _write(repo / "docs/ftmo/rules.md", "FTMO rules fixture\n")
    roster = package / "roster.json"
    roster.write_text(
        json.dumps(
            {
                "schema": "qm.ftmo-book-roster/v1",
                "book_id": "FIXTURE_BOOK",
                "book_risk_percent": 0.5,
                "candidates": [
                    {
                        "ea_id": 10001,
                        "ea_label": label,
                        "dxz_symbol": "EURUSD",
                        "ftmo_symbol": "EURUSD",
                        "timeframe": "H1",
                        "slot": 2,
                        "magic": 100010002,
                        "risk_percent": 0.5,
                        "role": "fixture",
                        "source_path": str(source),
                        "ex5_path": str(ex5),
                        "setfile_path": str(setfile),
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    output = tmp_path / "FTMO_DEMO_GENESIS_MANIFEST_FIXTURE.json"
    return {
        "repo": repo,
        "terminal": terminal,
        "package": package,
        "roster": roster,
        "rules": rules,
        "governor_set": governor_set,
        "receipt": receipt,
        "output": output,
        "ex5": ex5,
    }


def _build(paths: dict[str, Path], *, launched: bool = False) -> dict:
    return build_manifest(
        roster_path=paths["roster"],
        output_json=paths["output"],
        repo=paths["repo"],
        terminal=paths["terminal"],
        package=paths["package"],
        rules_snapshot=paths["rules"],
        book_state=None,
        governor_set=paths["governor_set"],
        generation_id="FIXTURE_GEN",
        launch_timestamp_utc="2026-09-27T12:00:00Z" if launched else None,
        build_receipt=paths["receipt"],
    )


def test_clean_manifest_verifies_every_binding(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    _build(paths)
    result = verify_manifest(paths["output"])
    assert result["status"] == "PASS"
    assert result["drift_count"] == 0
    assert len(result["items"]) >= 12


def test_drifted_installed_ex5_is_reported(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    _build(paths)
    paths["ex5"].write_text("drift", encoding="utf-8")
    result = verify_manifest(paths["output"])
    assert result["status"] == "DRIFT"
    assert any(row["state"] == "DRIFT" and "installed_ex5" in row["item"] for row in result["items"])


def test_missing_kill_switch_configuration_is_critical_red(tmp_path: Path) -> None:
    paths = _fixture(tmp_path, configured_ks=False)
    _build(paths)
    report = run_preflight(paths["output"])
    by_id = {row["check_id"]: row for row in report["checks"]}
    assert by_id["daily_loss_anchor"]["state"] == "RED"
    assert by_id["book_generation_identity"]["state"] == "RED"
    assert report["decision"] == "NO_GO"


def test_launched_manifest_cannot_be_rewritten_or_resealed(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    _build(paths, launched=True)
    with pytest.raises(ManifestError, match="immutable"):
        _build(paths)
    with pytest.raises(ManifestError, match="immutable"):
        seal_launch(paths["output"], "2026-09-27T13:00:00Z")


def test_prelaunch_manifest_can_be_sealed_once(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    _build(paths)
    sealed = seal_launch(paths["output"], "2026-09-27T12:00:00Z")
    assert sealed["status"] == "LAUNCHED_IMMUTABLE"
    assert verify_manifest(paths["output"])["status"] == "PASS"


@pytest.mark.parametrize(
    ("check_id", "critical"),
    [
        ("live_news_feed_binding", True),
        ("terminal_autotrading_flag", True),
        ("weekend_non_tick_rollover", True),
        ("server_request_thresholds", False),
        ("clean_initial_account", True),
        ("sleeve_attribution_dry_run", False),
    ],
)
@pytest.mark.parametrize("state", ["GREEN", "RED"])
def test_critique_addendum_rows_accept_evidence_bound_green_and_red_fixtures(
    tmp_path: Path,
    check_id: str,
    critical: bool,
    state: str,
) -> None:
    paths = _fixture(tmp_path)
    _build(paths)
    evidence = _write(tmp_path / f"{check_id}.json", '{"fixture": true}\n')
    config = tmp_path / f"preflight-{check_id}-{state.lower()}.json"
    config.write_text(
        json.dumps(
            {
                "schema": "qm.ftmo-sunday-preflight-evidence/v1",
                "checks": {
                    check_id: {
                        "state": state,
                        "evidence_path": str(evidence),
                        "reason": f"{check_id} {state} fixture",
                    }
                },
            }
        ),
        encoding="utf-8",
    )

    report = run_preflight(paths["output"], evidence_config=config)
    row = next(row for row in report["checks"] if row["check_id"] == check_id)

    assert row["state"] == state
    assert row["critical"] is critical
    assert row["evidence_path"] == str(evidence)
    assert row["automatic"] is False

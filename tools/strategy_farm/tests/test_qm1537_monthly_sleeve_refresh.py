from __future__ import annotations

import datetime as dt
import importlib.util
from pathlib import Path

import pytest


MODULE = Path(__file__).resolve().parents[1] / "qm1537_monthly_sleeve_refresh.py"
SPEC = importlib.util.spec_from_file_location("qm1537_monthly_sleeve_refresh_fixture", MODULE)
refresh = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(refresh)


def test_month_key_and_schedule_candidate_logic() -> None:
    assert refresh.month_key_for_date(dt.date(2026, 9, 1)) == 202609
    assert refresh.split_month_key(202609) == (2026, 9)
    assert refresh.schedule_window_candidate(dt.date(2026, 9, 1)) is True
    assert refresh.schedule_window_candidate(dt.date(2026, 8, 1)) is False  # Saturday
    assert refresh.schedule_window_candidate(dt.date(2026, 8, 3)) is True
    assert refresh.schedule_window_candidate(dt.date(2026, 9, 4)) is False
    with pytest.raises(refresh.RefreshError, match="invalid month"):
        refresh.split_month_key(202613)


def test_first_native_trading_day_is_bound_to_bar_date() -> None:
    september_first = int(dt.datetime(2026, 9, 1, tzinfo=dt.timezone.utc).timestamp())
    assert refresh.is_first_native_trading_day(dt.date(2026, 9, 1), september_first)
    assert not refresh.is_first_native_trading_day(dt.date(2026, 9, 2), september_first)
    assert not refresh.is_first_native_trading_day(dt.date(2026, 10, 1), september_first)


def test_exact_prefix_check_accepts_append_and_rejects_mutation(tmp_path: Path) -> None:
    prior = tmp_path / "prior.csv"
    candidate = tmp_path / "candidate.csv"
    prior.write_bytes(b"header\nold\n")
    candidate.write_bytes(prior.read_bytes() + b"new\n")
    result = refresh.verify_exact_prefix(prior, candidate)
    assert result["preserved"] is True
    assert result["appended_bytes"] == 4
    candidate.write_bytes(b"header\nchanged\nnew\n")
    with pytest.raises(refresh.RefreshError, match="byte prefix"):
        refresh.verify_exact_prefix(prior, candidate)


def test_receipt_schema_enforces_safety_attestations() -> None:
    observed = dt.datetime(2026, 9, 1, 5, 30, tzinfo=refresh.TIMEZONE)
    receipt = refresh.base_receipt("fixture", "DRY_RUN", 202609, observed)
    receipt["status"] = "PASS"
    refresh.validate_receipt_schema(receipt)
    receipt["safety"]["autotrading_changed"] = True
    with pytest.raises(refresh.RefreshError, match="safety attestation"):
        refresh.validate_receipt_schema(receipt)


def test_preset_render_changes_only_version_and_calendar_pins(tmp_path: Path) -> None:
    source = tmp_path / "prior.set"
    source.write_text(
        "\n".join(
            [
                "; set_version:  sold",
                "; date:         2026-09-01",
                "RISK_FIXED=0",
                "RISK_PERCENT=0.3125",
                "strategy_sleeve_calendar_file=old.csv",
                "strategy_sleeve_calendar_sha256=" + "A" * 64,
                "strategy_sleeve_contract_sha256=" + "B" * 64,
                "strategy_sleeve_input_bundle_sha256=" + "C" * 64,
                "qm_news_stale_max_hours=336",
                "; trial_status: REVIEW_REATTACH_REQUIRED",
                "; unchanged sentinel",
                "",
            ]
        ),
        encoding="utf-8",
        newline="\n",
    )
    rendered = refresh.render_versioned_preset(
        source,
        "s20261001-001",
        "new.csv",
        "D" * 64,
        "B" * 64,
        "E" * 64,
        dt.date(2026, 10, 1),
    ).decode("utf-8")
    assert "strategy_sleeve_calendar_file=new.csv" in rendered
    assert "RISK_FIXED=0\nRISK_PERCENT=0.3125" in rendered
    assert "qm_news_stale_max_hours=336" in rendered
    assert "; unchanged sentinel" in rendered
    assert "\r" not in rendered


def test_preset_render_rejects_weakened_news_ceiling(tmp_path: Path) -> None:
    source = tmp_path / "prior.set"
    source.write_text(
        "; set_version:  sold\n; date:         2026-09-01\n"
        "RISK_PERCENT=0.3125\n"
        "strategy_sleeve_calendar_file=old.csv\n"
        f"strategy_sleeve_calendar_sha256={'A' * 64}\n"
        f"strategy_sleeve_contract_sha256={'B' * 64}\n"
        f"strategy_sleeve_input_bundle_sha256={'C' * 64}\n"
        "qm_news_stale_max_hours=337\n"
        "; trial_status: REVIEW_REATTACH_REQUIRED\n",
        encoding="utf-8",
        newline="\n",
    )
    with pytest.raises(refresh.RefreshError, match="above 336"):
        refresh.render_versioned_preset(
            source,
            "s20261001-001",
            "new.csv",
            "D" * 64,
            "B" * 64,
            "E" * 64,
            dt.date(2026, 10, 1),
        )

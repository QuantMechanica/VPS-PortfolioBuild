from __future__ import annotations

import datetime as dt

from tools.strategy_farm.ftmo import venue_cost_fidelity as venue


def test_matched_p90_delta_is_the_only_eligible_charge() -> None:
    stamps = [int(dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc).timestamp()) + i * 60 for i in range(60)]
    ftmo = {stamp: 2.0 for stamp in stamps}
    dxz = {stamp: 0.5 for stamp in stamps}
    result, table = venue.build(
        ftmo_rows={symbol: ftmo for symbol in venue.TARGETS},
        ftmo_source={"mode": "fixture"},
        dxz_sources={symbol: (dxz, {"mode": "fixture"}) for symbol in venue.TARGETS},
        generated_at=dt.datetime(2026, 9, 22, tzinfo=dt.timezone.utc),
    )

    assert result["status"] == "PASS"
    assert table["USDJPY.DWX"] == 1.5
    assert result["symbols"][0]["comparison"]["matched_minute_count"] == 60


def test_nonoverlap_and_missing_dxz_abstain_without_zero_charge() -> None:
    start = int(dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc).timestamp())
    ftmo = {start + i * 60: 2.0 for i in range(60)}
    dxz = {start - 86400 + i * 60: 0.5 for i in range(60)}
    result, table = venue.build(
        ftmo_rows={symbol: ftmo for symbol in venue.TARGETS},
        ftmo_source={"mode": "fixture"},
        dxz_sources={"GBPUSD": (dxz, {"mode": "fixture"})},
        generated_at=dt.datetime(2026, 9, 22, tzinfo=dt.timezone.utc),
    )

    assert result["status"] == "PARTIAL_ABSTAIN"
    assert table == {}
    gbp = next(row for row in result["symbols"] if row["symbol"] == "GBPUSD")
    jpy = next(row for row in result["symbols"] if row["symbol"] == "USDJPY")
    assert gbp["comparison"]["status"] == "ABSTAIN_NO_MATCHED_DXZ_MINUTES"
    assert gbp["comparison"]["descriptive_independent_period_p90_difference_bps"] == 1.5
    assert jpy["comparison"]["status"] == "ABSTAIN_DXZ_SPREAD_UNMEASURED"
    assert gbp["slippage"]["usd_per_lot_rt"] is None


def test_hourly_summary_always_exposes_rollover_hours() -> None:
    stamp = int(dt.datetime(2026, 1, 1, 22, 0, tzinfo=dt.timezone.utc).timestamp())
    summary = venue._summarize({stamp: 3.25})
    assert set(summary["rollover_21_23z"]) == {"21", "22", "23"}
    assert summary["rollover_21_23z"]["22"]["p90"] == 3.25


def test_live_server_clock_is_normalized_to_utc() -> None:
    observed = int(dt.datetime(2026, 9, 21, 20, 40, tzinfo=dt.timezone.utc).timestamp())
    raw_latest = observed + 3 * 3600 - 60
    normalized, evidence = venue._normalize_server_minutes(
        {symbol: {raw_latest: 1.0} for symbol in venue.TARGETS}, observed
    )
    assert evidence["server_minus_utc_hours"] == 3
    assert max(normalized["USDJPY"]) == observed - 60

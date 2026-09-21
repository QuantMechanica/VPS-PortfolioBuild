from __future__ import annotations

import datetime as dt
import dataclasses
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.ftmo import book_sim


AS_OF = dt.datetime(2026, 9, 21, 12, 0, tzinfo=dt.timezone.utc)


def _epoch(day: int, hour: int, minute: int = 0) -> int:
    return int(dt.datetime(2024, 1, day, hour, minute, tzinfo=dt.timezone.utc).timestamp())


def _row(entry: int, close: int, profit: float, mae: float, *, side: str = "BUY") -> dict:
    return {
        "event": "TRADE_CLOSED",
        "money_basis": "FULL_POSITION_LIFECYCLE_ACTUAL_V1",
        "entry_time": entry,
        "time": close,
        "side": side,
        "profit": profit,
        "net": profit,
        "swap": 2.0,
        "commission": 0.0,
        "mae_acct": mae,
        "volume": 1.0,
        "notional": 100000.0,
    }


def _write_stream(path: Path, rows: list[dict]) -> str:
    path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _registry(path: Path) -> None:
    path.write_text(json.dumps({
        "model": "max(pct_rate_rt*notional_acct, flat_per_lot_rt*volume)",
        "default_class": "forex",
        "classes": {"forex": {"pct_rate_rt": 0.00005, "flat_per_lot_rt": 5.0}},
        "symbol_class": {"EURUSD.DWX": "forex", "GBPUSD.DWX": "forex", "USDJPY.DWX": "forex"},
    }), encoding="utf-8")


def _fixture(tmp_path: Path) -> tuple[Path, Path, Path, list[book_sim.SleeveSpec]]:
    registry = tmp_path / "commission.json"
    _registry(registry)
    rows = {
        1: [
            _row(_epoch(2, 22, 30), _epoch(2, 23, 30), 100.0, -200.0),
            _row(_epoch(3, 9), _epoch(3, 12), -50.0, -100.0),
            _row(_epoch(4, 9), _epoch(4, 12), 80.0, -30.0),
        ],
        2: [
            _row(_epoch(2, 22, 45), _epoch(2, 23, 45), 40.0, -80.0),
            _row(_epoch(3, 10), _epoch(3, 11), -30.0, -70.0),
            _row(_epoch(4, 10), _epoch(4, 11), 20.0, -20.0),
        ],
        3: [
            _row(_epoch(2, 18), _epoch(2, 19), -10.0, -25.0, side="SELL"),
            _row(_epoch(3, 18), _epoch(3, 19), 15.0, -10.0, side="SELL"),
            _row(_epoch(4, 18), _epoch(4, 19), 10.0, -5.0, side="SELL"),
        ],
    }
    specs: list[book_sim.SleeveSpec] = []
    for ea_id, stream_rows in rows.items():
        path = tmp_path / f"{ea_id}_EURUSD_DWX.jsonl"
        sha = _write_stream(path, stream_rows)
        specs.append(book_sim.SleeveSpec(
            id=f"S{ea_id}", ea_id=ea_id,
            symbol="EURUSD.DWX" if ea_id < 3 else "USDJPY.DWX",
            timeframe="H1", stream_path=str(path), stream_sha256=sha,
            risk_percent=0.5, role="test", family="F1" if ea_id < 3 else "F2",
            session="NY" if ea_id < 3 else "ASIA", news_profile="PRE30_POST30",
        ))
    missing_financing = tmp_path / "missing" / "financing_lib.py"
    return registry, missing_financing, tmp_path, specs


def _mark_financed(spec: book_sim.SleeveSpec) -> book_sim.SleeveSpec:
    path = Path(spec.stream_path)
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
    for row in rows:
        row["qm_financing"] = {
            "status": "FIXTURE",
            "financing_usd": float(row.get("swap") or 0.0),
            "units": 1.0,
            "nights": 1,
        }
    sha = _write_stream(path, rows)
    return dataclasses.replace(spec, stream_sha256=sha)


def test_registry_commission_swap_fallback_and_scaling(tmp_path: Path) -> None:
    registry, financing, _, specs = _fixture(tmp_path)
    sleeves, provenance = book_sim.prepare_book(
        [specs[0]], commission_registry_path=registry, financing_lib_path=financing,
    )
    trade = sleeves[0]["trades"][0]

    assert trade["commission_source_usd"] == 5.0
    assert trade["net_source"] == 97.0  # 100 gross + 2 embedded swap - 5 registry cost
    assert trade["net_scaled"] == 48.5
    assert trade["mae_scaled"] == -102.5
    assert "PRIMARY_FINANCING_TABLE_MISSING" in provenance["financing_library_status"]


def test_sha_binding_refuses_tampered_stream(tmp_path: Path) -> None:
    _, _, root, specs = _fixture(tmp_path)
    roster = root / "roster.json"
    roster.write_text(json.dumps({"sleeves": [dict(
        ea_id=specs[0].ea_id, symbol=specs[0].symbol,
        timeframe="H1", risk_percent=0.5,
        stream_path=specs[0].stream_path, stream_sha256=specs[0].stream_sha256,
    )]}), encoding="utf-8")
    Path(specs[0].stream_path).write_text("tampered\n", encoding="utf-8")

    with pytest.raises(ValueError, match="sha256 mismatch"):
        book_sim.load_roster_specs(roster, stream_manifest=None)


def test_prague_midnight_anchor_moves_2330_utc_close_to_next_day(tmp_path: Path) -> None:
    registry, financing, _, specs = _fixture(tmp_path)
    sleeves, _ = book_sim.prepare_book(
        [specs[0]], commission_registry_path=registry, financing_lib_path=financing,
    )
    daily = book_sim._daily_sleeve(sleeves[0])

    assert dt.date(2024, 1, 3) in daily
    assert daily[dt.date(2024, 1, 3)]["net"] == pytest.approx((97.0 - 53.0) * 0.5)


def test_account_daily_loss_uses_prague_day_start_balance() -> None:
    sleeve = {
        "id": "breach", "risk_percent": 1.0,
        "trades": [{
            "entry_time": _epoch(2, 23, 30), "close_time": _epoch(3, 10),
            "net_scaled": -100.0, "mae_scaled": -5100.0,
            "net_source": -100.0, "commission_scaled": 0.0, "swap_scaled": 0.0,
            "spread_stress_scaled": 0.0, "slippage_stress_scaled": 0.0,
            "margin_proxy_scaled": 1000.0,
        }],
    }
    metrics, path = book_sim.account_path_metrics(
        [sleeve], start=dt.date(2024, 1, 3), end=dt.date(2024, 1, 3)
    )

    assert path[0]["balance_start"] == 100000.0
    assert path[0]["equity_low_mae_proxy"] == 94900.0
    assert path[0]["daily_loss_breach"] is True
    assert metrics["HISTORICAL_DAILY_LOSS_BREACH_DAYS"] == 1


def test_full_book_result_is_deterministic_at_fixed_as_of(tmp_path: Path) -> None:
    registry, financing, _, specs = _fixture(tmp_path)
    kwargs = dict(
        cost=book_sim.CostConfig(), commission_registry_path=registry,
        financing_lib_path=financing, n_paths=100, seed=17, block_len=2,
        horizon=20, as_of=AS_OF,
    )
    first, _, _ = book_sim.evaluate_book(specs, **kwargs)
    second, _, _ = book_sim.evaluate_book(specs, **kwargs)

    assert first == second
    assert first["input_manifest_sha256"] == second["input_manifest_sha256"]
    assert first["account_path_summary"]["equity_proxy"] == book_sim.PROXY_LABEL


def test_financed_streams_are_validated_labelled_and_deterministic(
    tmp_path: Path,
) -> None:
    registry, _, root, specs = _fixture(tmp_path)
    financed = [_mark_financed(spec) for spec in specs]
    kwargs = dict(
        cost=book_sim.CostConfig(), commission_registry_path=registry,
        financing_label=book_sim.FINANCED, financed_stream_root=root,
        n_paths=100, seed=17, block_len=2, horizon=20, as_of=AS_OF,
    )

    first, _, _ = book_sim.evaluate_book(financed, **kwargs)
    second, _, _ = book_sim.evaluate_book(financed, **kwargs)

    assert first == second
    assert first["financing"]["label"] == "FINANCED"
    assert first["financing"]["book_evidence_eligible"] is True
    assert first["input_manifest"]["provenance"]["financing_row_contract"].startswith(
        "every TRADE_CLOSED row"
    )


def test_financed_streams_fail_closed_without_row_provenance(tmp_path: Path) -> None:
    registry, _, root, specs = _fixture(tmp_path)

    with pytest.raises(ValueError, match="lacks qm_financing metadata"):
        book_sim.prepare_book(
            [specs[0]], commission_registry_path=registry,
            financing_label=book_sim.FINANCED, financed_stream_root=root,
        )


def test_lcb_resolution_fields_and_unresolved_positive_action() -> None:
    resolution = book_sim._lcb_resolution(
        [0.001, 0.011, -0.006, 0.008, -0.004],
        n_paths=5000, target_delta=0.01,
    )
    assert resolution["replicates"] == 5
    assert "lcb_standard_error" in resolution
    assert "minimum_resolvable_delta_2se" in resolution
    marginal = {
        "candidates": [{
            "id": "candidate", "mode": "add", "status": "OK",
            "proposed_risk_percent": 0.25,
            "proposed": {
                "DELTA_P_FIRST_NET_FTMO_PAYOUT_LCB": 0.01,
                "DELTA_P_DAILY_LOSS_BREACH": -0.001,
                "DELTA_P_MAX_LOSS_BREACH": -0.001,
                "resolution": {
                    "lcb_delta_mean": 0.01,
                    "resolution_status": "UNRESOLVED",
                },
            },
        }]
    }

    row = book_sim._candidate_state_rows(marginal)[0]

    assert row["book_action"] == "SHADOW_BOOK"
    assert row["resolution"]["resolution_status"] == "UNRESOLVED"


def test_cli_requires_explicit_financing_mode() -> None:
    with pytest.raises(SystemExit):
        book_sim.main(["--roster", "unused.json", "--out", "unused-out.json"])


def test_state_writer_preserves_human_mirror_bytes(tmp_path: Path) -> None:
    mirror = tmp_path / "FTMO_BOOK_CURRENT.md"
    mirror.write_text(
        "# Human\n\n- **Strongest missing behaviour:** A low-overlap NY sleeve.\n",
        encoding="utf-8",
    )
    before = hashlib.sha256(mirror.read_bytes()).hexdigest()
    base = {
        "generated_at_utc": AS_OF.isoformat(), "input_manifest_sha256": "a" * 64,
        "sleeves": [{"id": "S1", "ea_id": 1, "symbol": "EURUSD.DWX", "timeframe": "H1",
                     "risk_percent": 0.5, "role": "test", "stream_sha256": "b" * 64,
                     "stream_path": "x"}],
        "book_metrics": {"BOOK_WORST_DAILY_LOSS_MAE_PROXY": -100.0,
                         "BOOK_MAX_DD_ABS_USD": 200.0},
        "first_passage": {"input_manifest_sha256": "c" * 64, "probabilities": {},
                          "time_business_days": {}},
    }
    dependence = {"schema": "qm.ftmo-book-dependence-matrix/v1",
                  "summary": {"top_fail_together_pair": None, "fail_together_clusters": []}}
    marginal = {"candidates": []}

    base["financing"] = {
        "label": "FINANCED", "source": "fixture",
        "financed_stream_root": "fixture-root", "manifest": "fixture.json",
        "manifest_sha256": "d" * 64, "book_evidence_eligible": True,
    }
    existing = {
        "owner_directive": "preserve this prose",
        "demo_cycle": {"classification": "PRE_SUNDAY_LIVE_TRIAL", "state": "RUNNING"},
        "financing": {"evidence": "preserve-this-path"},
    }
    state = book_sim.build_state(
        base, marginal, dependence, book_id="TEST", human_mirror=mirror,
        existing_state=existing,
    )

    assert state["strongest_missing_behavior"] == "A low-overlap NY sleeve."
    assert hashlib.sha256(mirror.read_bytes()).hexdigest() == before
    assert state["owner_directive"] == "preserve this prose"
    assert state["demo_cycle"]["classification"] == "PRE_SUNDAY_LIVE_TRIAL"
    assert state["financing"]["label"] == "FINANCED"
    assert state["financing"]["evidence"] == "preserve-this-path"

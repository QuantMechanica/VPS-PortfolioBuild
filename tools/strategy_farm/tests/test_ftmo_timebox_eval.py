from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_timebox_eval as ftmo


def _day(
    number: int,
    *,
    net: float = 0.0,
    low: float = 0.0,
    eligible: bool = True,
    flat: bool = True,
    trades: int = 1,
) -> ftmo.DailyPoint:
    return ftmo.DailyPoint(
        day=dt.date(2024, 1, 1) + dt.timedelta(days=number),
        net_return=net,
        intraday_low_return=low,
        trade_count=trades,
        eligible_start=eligible,
        flat_at_end=flat,
    )


def _json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")


def _jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def _cost(path: Path, *, missing_swap: bool = False) -> str:
    value: dict[str, object] = {
        "code": "XAU/USD",
        "displayCode": "XAU/USD",
        "active": True,
        "commission": 0.0,
        "commissionType": "percent",
        "swapLong": -75.93,
        "swapShort": -23.55,
    }
    if missing_swap:
        del value["swapShort"]
    _json(path, [value])
    return ftmo.sha256_file(path)


def _daily_rows(
    sleeve_id: str, cost_sha: str, count: int, *, net: float = 0.0025
) -> list[dict[str, object]]:
    return [
        {
            "schema": ftmo.DAILY_STREAM_SCHEMA,
            "sleeve_id": sleeve_id,
            "symbol": "XAUUSD",
            "date": (dt.date(2024, 1, 1) + dt.timedelta(days=index)).isoformat(),
            "net_return": net,
            "intraday_low_return": min(0.0, net),
            "trade_count": 1,
            "eligible_start": True,
            "flat_at_end": True,
            "venue": "FTMO",
            "spread_basis": "FTMO_TERMS",
            "commission_basis": "FTMO_TERMS",
            "swap_basis": "FTMO_TERMS",
            "cost_snapshot_sha256": cost_sha,
        }
        for index in range(count)
    ]


def _spec(
    tmp_path: Path,
    streams: list[dict[str, object]],
    compositions: list[dict[str, object]],
    *,
    missing_swap: bool = False,
) -> dict[str, object]:
    inventory = tmp_path / "inventory.json"
    scores = tmp_path / "scores.json"
    costs = tmp_path / "costs.json"
    _json(inventory, {"inventory": "frozen"})
    _json(scores, {"metric": "FUND_SCORE", "rows": []})
    _cost(costs, missing_swap=missing_swap)
    return {
        "inventory_path": str(inventory),
        "fund_scores_path": str(scores),
        "ftmo_cost_snapshot_path": str(costs),
        "streams": streams,
        "compositions": compositions,
        "bootstrap": {"replicates": 100, "block_calendar_days": 20, "seed": 7},
    }


def _single_comp(sleeve_id: str = "10128:XAUUSD") -> list[dict[str, object]]:
    return [{"id": "singleton", "sleeves": [{"sleeve_id": sleeve_id, "weight": 1.0}]}]


def _config_sha(config: object) -> str:
    return hashlib.sha256(ftmo.canonical_json_bytes(config)).hexdigest()


def test_deterministic_drift_phase_logic_and_chaining() -> None:
    days = [_day(index, net=0.0025) for index in range(140)]
    p1 = ftmo.evaluate_phase(days, 0, 0.10, 60)
    assert p1 == {"outcome": "PASS", "end_index": 38, "days_elapsed": 39}

    first = ftmo.rolling_outcomes(days)[0]
    assert first["p1"]["outcome"] == "PASS"
    assert first["p2"] == {"outcome": "PASS", "end_index": 58, "days_elapsed": 20}
    assert first["joint_pass"] is True


def test_daily_loss_breach_precedes_close() -> None:
    result = ftmo.evaluate_phase([_day(0, low=-0.051)], 0, 0.10, 60)
    assert result["outcome"] == "DAILY_LOSS_BREACH"
    assert result["days_elapsed"] == 1


def test_compounded_path_hits_max_loss_without_daily_breach() -> None:
    days = [
        _day(0, net=-0.04, low=-0.04),
        _day(1, net=-0.04, low=-0.04),
        _day(2, net=0.0, low=-0.03),
    ]
    result = ftmo.evaluate_phase(days, 0, 0.10, 60)
    assert result["outcome"] == "MAX_LOSS_BREACH"
    assert result["days_elapsed"] == 3


def test_finite_horizon_is_timeout_and_target_requires_flat_boundary() -> None:
    zero = [_day(index, net=0.0) for index in range(70)]
    assert ftmo.evaluate_phase(zero, 0, 0.10, 60)["outcome"] == "TIMEOUT"

    drift_open = [_day(index, net=0.003, flat=False) for index in range(60)]
    assert ftmo.evaluate_phase(drift_open, 0, 0.10, 60)["outcome"] == "TIMEOUT"


def test_hac_and_bootstrap_are_reported_for_overlapping_starts() -> None:
    days = [_day(index, net=0.0025) for index in range(140)]
    bootstrap = dict(ftmo.DEFAULT_BOOTSTRAP, replicates=100, block_calendar_days=20, seed=11)
    summary = ftmo.summarize(days, bootstrap)
    assert summary["p1_raw_rate"] is not None
    assert 0.0 < summary["p1_hac"]["effective_n"] <= summary["p1_hac"]["n"]
    assert summary["p1_hac"]["bandwidth"] == 59
    assert summary["p1_bootstrap"]["replicates"] == 100
    assert 0.0 <= summary["p1_bootstrap"]["lower"] <= summary["p1_bootstrap"]["upper"] <= 1.0


def test_config_digest_is_checked_before_any_input_open(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    config_path = tmp_path / "config.json"
    config_path.write_text("{}", encoding="utf-8")
    called = False

    def forbidden_load(*args: object, **kwargs: object) -> object:
        nonlocal called
        called = True
        raise AssertionError("input opened")

    monkeypatch.setattr(ftmo, "load_json", forbidden_load)
    with pytest.raises(ftmo.TimeboxEvaluationError, match="before input access"):
        ftmo.evaluate_config_file(config_path, "0" * 64)
    assert called is False


def test_prepare_refuses_mutable_database_reference_before_pinning() -> None:
    with pytest.raises(ftmo.TimeboxEvaluationError, match="DB/farm-state"):
        ftmo.prepare_config({"db_path": "D:/QM/data/farm_state.db"})


def test_dxz_q08_stream_is_inventory_only_and_gets_no_probability_credit(tmp_path: Path) -> None:
    stream = tmp_path / "q08.jsonl"
    stream.write_text("this need not be parsed\n", encoding="utf-8")
    streams = [
        {
            "sleeve_id": "10128:XAUUSD",
            "symbol": "XAUUSD",
            "ftmo_code": "XAU/USD",
            "stream_schema": ftmo.DXZ_STREAM_SCHEMA,
            "path": str(stream),
        }
    ]
    config = ftmo.prepare_config(_spec(tmp_path, streams, _single_comp()))
    result = ftmo.evaluate_config(config, _config_sha(config))
    assert result["status"] == "NO_ADMISSIBLE_COMPOSITION"
    assert result["sleeve_refusals"] == {"10128:XAUUSD": ftmo.REFUSED_DXZ_SPREAD}
    assert result["decision"]["best_bootstrap_lower_bound_p1"] is None
    assert result["decision"]["evidence_credited_lower_bound_p1"] == 0.0
    assert result["decision"]["label"] == ftmo.NO_CREDIT_LABEL
    assert result["decision"]["binding_dimension"] == "DENSITY"


def test_missing_ftmo_swap_terms_refuse_sleeve_explicitly(tmp_path: Path) -> None:
    stream = tmp_path / "q08.jsonl"
    stream.write_text("{}\n", encoding="utf-8")
    streams = [
        {
            "sleeve_id": "10128:XAUUSD",
            "symbol": "XAUUSD",
            "ftmo_code": "XAU/USD",
            "stream_schema": ftmo.DXZ_STREAM_SCHEMA,
            "path": str(stream),
        }
    ]
    config = ftmo.prepare_config(_spec(tmp_path, streams, _single_comp(), missing_swap=True))
    result = ftmo.evaluate_config(config, _config_sha(config))
    assert result["sleeve_refusals"] == {"10128:XAUUSD": ftmo.REFUSED_MISSING_SWAP}


def test_valid_ftmo_attested_stream_is_evaluated(tmp_path: Path) -> None:
    costs = tmp_path / "costs.json"
    cost_sha = _cost(costs)
    stream = tmp_path / "daily.jsonl"
    _jsonl(stream, _daily_rows("10128:XAUUSD", cost_sha, 140))
    inventory = tmp_path / "inventory.json"
    scores = tmp_path / "scores.json"
    _json(inventory, {})
    _json(scores, {})
    spec = {
        "inventory_path": str(inventory),
        "fund_scores_path": str(scores),
        "ftmo_cost_snapshot_path": str(costs),
        "streams": [
            {
                "sleeve_id": "10128:XAUUSD",
                "symbol": "XAUUSD",
                "ftmo_code": "XAU/USD",
                "stream_schema": ftmo.DAILY_STREAM_SCHEMA,
                "path": str(stream),
            }
        ],
        "compositions": _single_comp(),
        "bootstrap": {"replicates": 100, "block_calendar_days": 20, "seed": 13},
    }
    config = ftmo.prepare_config(spec)
    result = ftmo.evaluate_config(config, _config_sha(config))
    assert result["status"] == "EVALUATED"
    evaluated = result["compositions"][0]
    assert evaluated["status"] == "EVALUATED"
    assert evaluated["statistics"]["p1_raw_rate"] > 0.0
    assert evaluated["statistics"]["p2_given_p1_rate"] > 0.0
    assert evaluated["statistics"]["p1_bootstrap"]["lower"] >= 0.0
    assert result["decision"]["label"] == ftmo.DECISION_LABEL
    assert result["decision"]["book_ready"] is False


def test_cost_attestation_mismatch_is_refused_not_silently_degraded(tmp_path: Path) -> None:
    costs = tmp_path / "costs.json"
    _cost(costs)
    stream = tmp_path / "daily.jsonl"
    _jsonl(stream, _daily_rows("10128:XAUUSD", "0" * 64, 30))
    inventory = tmp_path / "inventory.json"
    scores = tmp_path / "scores.json"
    _json(inventory, {})
    _json(scores, {})
    spec = {
        "inventory_path": str(inventory),
        "fund_scores_path": str(scores),
        "ftmo_cost_snapshot_path": str(costs),
        "streams": [
            {
                "sleeve_id": "10128:XAUUSD",
                "symbol": "XAUUSD",
                "ftmo_code": "XAU/USD",
                "stream_schema": ftmo.DAILY_STREAM_SCHEMA,
                "path": str(stream),
            }
        ],
        "compositions": _single_comp(),
        "bootstrap": {"replicates": 100},
    }
    config = ftmo.prepare_config(spec)
    result = ftmo.evaluate_config(config, _config_sha(config))
    assert result["sleeve_refusals"] == {"10128:XAUUSD": ftmo.REFUSED_COST_ATTESTATION}


def test_dl083_rejects_identical_multi_sleeve_book(tmp_path: Path) -> None:
    costs = tmp_path / "costs.json"
    cost_sha = _cost(costs)
    inventory = tmp_path / "inventory.json"
    scores = tmp_path / "scores.json"
    _json(inventory, {})
    _json(scores, {})
    streams: list[dict[str, object]] = []
    for sleeve_id in ("a", "b"):
        path = tmp_path / f"{sleeve_id}.jsonl"
        rows = _daily_rows(sleeve_id, cost_sha, 40)
        # Non-constant but identical paths have correlation one.
        for index, row in enumerate(rows):
            value = 0.001 if index % 2 == 0 else -0.0005
            row["net_return"] = value
            row["intraday_low_return"] = min(0.0, value)
        _jsonl(path, rows)
        streams.append(
            {
                "sleeve_id": sleeve_id,
                "symbol": "XAUUSD",
                "ftmo_code": "XAU/USD",
                "stream_schema": ftmo.DAILY_STREAM_SCHEMA,
                "path": str(path),
            }
        )
    spec = {
        "inventory_path": str(inventory),
        "fund_scores_path": str(scores),
        "ftmo_cost_snapshot_path": str(costs),
        "streams": streams,
        "compositions": [
            {
                "id": "identical_pair",
                "sleeves": [
                    {"sleeve_id": "a", "weight": 0.5},
                    {"sleeve_id": "b", "weight": 0.5},
                ],
            }
        ],
        "bootstrap": {"replicates": 100},
    }
    config = ftmo.prepare_config(spec)
    result = ftmo.evaluate_config(config, _config_sha(config))
    comp = result["compositions"][0]
    assert comp["status"] == "REFUSED"
    assert comp["correlation"]["effective_correlation"] == pytest.approx(1.0)
    assert comp["refusal_labels"] == [ftmo.REFUSED_CORRELATION]
    assert result["decision"]["binding_dimension"] == "CORRELATION"


def test_dl083_refuses_undefined_pairwise_correlation() -> None:
    streams = {
        "constant": [_day(index, net=0.0) for index in range(20)],
        "variable": [_day(index, net=0.001 if index % 2 else -0.001) for index in range(20)],
    }
    result = ftmo.correlation_diagnostic(streams, ["constant", "variable"])
    assert result["status"] == "REFUSED"
    assert result["label"] == ftmo.REFUSED_UNDEFINED_CORRELATION


def test_dl083_refuses_nonidentical_shared_calendar_before_vector_math() -> None:
    streams = {
        "left": [_day(index, net=0.001 if index % 2 else -0.001) for index in range(20)],
        "right": [_day(index + 1, net=0.001 if index % 2 else -0.001) for index in range(20)],
    }
    result = ftmo.correlation_diagnostic(streams, ["left", "right"])
    assert result["status"] == "REFUSED"
    assert result["label"] == ftmo.REFUSED_CALENDAR

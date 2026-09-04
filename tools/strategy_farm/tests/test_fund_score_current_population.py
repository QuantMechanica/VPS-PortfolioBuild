from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

from tools.strategy_farm.portfolio import fund_score


def _write_stream(path: Path, *, entry_complete: bool) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    start = dt.datetime(2024, 1, 1, 12, tzinfo=dt.timezone.utc)
    lines = []
    for index in range(12):
        close = start + dt.timedelta(days=index * 7)
        row = {
            "event": "TRADE_CLOSED",
            "time": int(close.timestamp()),
            "net": 150.0 if index % 3 else -25.0,
            "mae_acct": -40.0,
        }
        if entry_complete or index:
            row["entry_time"] = int((close - dt.timedelta(hours=4)).timestamp())
        lines.append(json.dumps(row))
    data = ("\n".join(lines) + "\n").encode()
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def test_current_stream_set_is_scored_with_exact_provenance(tmp_path: Path) -> None:
    streams = tmp_path / "bundle" / "QM" / "q08_trades"
    good = streams / "9001_EURUSD_DWX.jsonl"
    bad = streams / "9002_USDJPY_DWX.jsonl"
    good_sha = _write_stream(good, entry_complete=True)
    bad_sha = _write_stream(bad, entry_complete=False)

    rows = fund_score.score_all(tmp_path / "bundle")
    by_sleeve = {row["sleeve"]: row for row in rows}

    scored = by_sleeve["9001:EURUSD"]
    assert scored["status"] == "SCORED"
    assert scored["input_stream_path"] == str(good.resolve())
    assert scored["input_stream_sha256"] == good_sha
    inputs = scored["formula_inputs"]
    assert inputs["denominator"] == max(
        inputs["floor"],
        inputs["daily_loss_multiplier"] * inputs["worst_day_1x_abs"],
        inputs["wdd_p90_1x"],
    )
    assert scored["fund_score"] == inputs["med60_1x"] / inputs["denominator"]

    excluded = by_sleeve["9002:USDJPY"]
    assert excluded["status"] == "UNSCORABLE"
    assert excluded["reason"] == "entry_time_incomplete"
    assert excluded["input_stream_path"] == str(bad.resolve())
    assert excluded["input_stream_sha256"] == bad_sha


def test_refresh_labels_population_and_reconciles_every_stream(tmp_path: Path) -> None:
    streams = tmp_path / "bundle" / "QM" / "q08_trades"
    _write_stream(streams / "9003_XAUUSD_DWX.jsonl", entry_complete=True)
    _write_stream(streams / "9004_XAGUSD_DWX.jsonl", entry_complete=False)
    cache = tmp_path / "scores.json"

    payload = fund_score.refresh_cache(
        cache,
        stream_root=tmp_path / "bundle",
        population_label="synthetic_current",
    )

    assert payload["population"]["label"] == "synthetic_current"
    assert payload["population"]["stream_count"] == 2
    assert len(payload["rows"]) == 2
    assert {row["status"] for row in payload["rows"]} == {"SCORED", "UNSCORABLE"}
    assert json.loads(cache.read_text(encoding="utf-8")) == payload

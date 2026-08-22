from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm.portfolio import economic_strategy_clustering as esc


def _card(ea_id: int, indicator: str) -> str:
    return f"""---
ea_id: QM5_{ea_id}
concepts:
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/{indicator}]]"
---
# Deliberately different title for {ea_id}
### Entry
Enter when the moving averages cross above in trend-following momentum.
### Exit
Exit on the opposite signal with a trailing stop.
"""


def _trade(day: int, net: float, symbol: str) -> dict:
    close = int(dt.datetime(2024, 1, day, 20, tzinfo=dt.UTC).timestamp())
    opened = int(dt.datetime(2024, 1, day, 8, tzinfo=dt.UTC).timestamp())
    return {
        "event": "TRADE_CLOSED", "symbol": symbol, "time": close,
        "entry_time": opened, "net": net, "volume": 1.0, "notional": 10_000.0,
    }


def test_ema_and_sma_variants_have_same_semantic_family() -> None:
    ema = esc.family_descriptor(_card(1001, "ema"))
    sma = esc.family_descriptor(_card(9999, "sma"))
    assert ema == sma
    assert esc.fingerprint(ema) == esc.fingerprint(sma)
    assert ema["indicator_archetypes"] == ["moving_average"]


def test_analysis_collapses_same_family_even_when_names_and_returns_differ(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as conn:
        conn.execute("CREATE TABLE work_items (ea_id TEXT, symbol TEXT, phase TEXT, status TEXT, verdict TEXT)")
        conn.executemany(
            "INSERT INTO work_items VALUES (?, ?, 'Q08', 'done', 'PASS')",
            [("QM5_1001", "EURUSD.DWX"), ("QM5_1002", "GBPUSD.DWX")],
        )
    cards = tmp_path / "cards"
    cards.mkdir()
    (cards / "QM5_1001_completely-unrelated-name.md").write_text(_card(1001, "ema"), encoding="utf-8")
    (cards / "QM5_1002_another-name.md").write_text(_card(1002, "sma"), encoding="utf-8")
    stream_dir = tmp_path / "streams" / "QM" / "q08_trades"
    stream_dir.mkdir(parents=True)
    rows = {
        "1001_EURUSD_DWX.jsonl": [_trade(2, 100.0, "EURUSD.DWX"), _trade(3, -50.0, "EURUSD.DWX")],
        "1002_GBPUSD_DWX.jsonl": [_trade(4, -75.0, "GBPUSD.DWX"), _trade(5, 125.0, "GBPUSD.DWX")],
    }
    for name, trades in rows.items():
        (stream_dir / name).write_text("".join(json.dumps(row) + "\n" for row in trades), encoding="utf-8")

    report = esc.analyze(db_path=db, stream_root=tmp_path / "streams", card_root=cards)

    assert report["coverage"]["usable_nonempty_streams"] == 2
    assert report["independence_summary"]["family_count"] == 1
    assert report["independence_summary"]["economic_independence_cluster_count"] == 1
    assert report["economic_clusters"][0]["member_count"] == 2
    assert report["cluster_links"][0]["same_family"] is True


def test_unclassifiable_card_is_fail_closed_unique_family(tmp_path: Path) -> None:
    text = "---\nea_id: QM5_1001\n---\n# No mechanics\n"
    try:
        esc.family_descriptor(text)
    except esc.ClusteringError as exc:
        assert "no classifiable mechanics" in str(exc)
    else:
        raise AssertionError("unclassifiable card must fail closed")

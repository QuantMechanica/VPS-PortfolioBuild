"""Tests for research_matrix — Logic x Market coverage (DL-064 R-064-1)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

import research_matrix as rm  # noqa: E402


def _registry(tmp_path):
    p = tmp_path / "live_commission.json"
    p.write_text(json.dumps({"symbol_class": {
        "EURUSD.DWX": "forex", "GBPUSD.DWX": "forex",
        "NDX.DWX": "index", "GDAXI.DWX": "index",
        "XAUUSD.DWX": "commodity",
    }}), encoding="utf-8")
    return p


def test_classify_logic():
    assert rm.classify_logic("tv-trend-brk", "ema breakout momentum") == "trend"
    assert rm.classify_logic("rsi-mr", "bollinger mean reversion fade") == "mean_reversion"
    assert rm.classify_logic("fomc-cycle", "seasonal session volatility news") == "seasonality_volatility"
    assert rm.classify_logic("unknown", "nothing matches here") == "trend"  # default


def test_classify_market(tmp_path):
    clusters = rm.load_symbol_clusters(_registry(tmp_path))
    assert rm.classify_market(["EURUSD.DWX"], clusters) == "forex"
    assert rm.classify_market(["NDX.DWX", "GDAXI.DWX"], clusters) == "index"
    assert rm.classify_market(["XAUUSD.DWX"], clusters) == "commodity"
    assert rm.classify_market(["UNKNOWN.X"], clusters) is None


def test_coverage_and_thinnest(tmp_path):
    reg = _registry(tmp_path)
    cards = tmp_path / "cards"
    cards.mkdir()
    # two trend/index cards, one mean_reversion/forex card
    (cards / "QM5_1_tv-trend-brk.md").write_text("breakout momentum on NDX.DWX", encoding="utf-8")
    (cards / "QM5_2_tv-orb.md").write_text("opening range breakout GDAXI.DWX trend", encoding="utf-8")
    (cards / "QM5_3_rsi-mr.md").write_text("rsi mean reversion fade EURUSD.DWX", encoding="utf-8")
    cov = rm.coverage(cards, registry_path=reg)
    by = {(c["logic"], c["market"]): c["count"] for c in cov["cells"]}
    assert by[("trend", "index")] == 2
    assert by[("mean_reversion", "forex")] == 1
    assert cov["total_cards"] == 3
    # an empty cell (e.g. seasonality_volatility/commodity) is among the thinnest (count 0)
    assert cov["min_count"] == 0
    assert any(c["count"] == 0 for c in cov["cells"])


def test_next_research_target_deterministic(tmp_path):
    reg = _registry(tmp_path)
    cards = tmp_path / "cards"
    cards.mkdir()
    (cards / "QM5_1_tv-trend.md").write_text("breakout NDX.DWX", encoding="utf-8")
    t1 = rm.next_research_target(cards, registry_path=reg)
    t2 = rm.next_research_target(cards, registry_path=reg)
    assert t1 == t2  # deterministic
    assert t1["logic"] in rm.LOGIC_TYPES and t1["market"] in rm.MARKET_CLUSTERS

from pathlib import Path
import re


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_12919_amp-value-momentum-xasset.mq5"
SETS_DIR = EA_DIR / "sets"


def source_text() -> str:
    return SOURCE.read_text(encoding="utf-8")


def set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_long_lookback_history_is_retried_and_fail_closed() -> None:
    text = source_text()
    assert "Strategy_RefreshHistoryDepth" in text
    assert "CopyClose(symbol, PERIOD_D1, 0, required_bars, warmup)" in text
    assert "g_history_retry_day_keys[symbol_slot] == retry_day_key" in text
    assert "Strategy_HistoryReadyCount(missing_symbols)" in text
    assert '"SETUP_DATA_MISSING"' in text
    assert text.index("QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1") < text.index(
        "Strategy_HistoryReadyCount(missing_symbols)"
    )


def test_approved_signal_and_risk_contract_are_unchanged() -> None:
    text = source_text()
    assert "strategy_skip_recent_days         = 21" in text
    assert "strategy_momentum_lookback_days   = 252" in text
    assert "strategy_value_lookback_days      = 1260" in text
    assert "strategy_momentum_weight          = 0.50" in text
    assert "strategy_value_weight             = 0.50" in text
    assert "strategy_top_n                    = 3" in text
    assert "strategy_min_eligible_symbols     = 4" in text

    stale = re.search(r"qm_news_stale_max_hours\s*=\s*(\d+)", text)
    assert stale is not None
    assert int(stale.group(1)) <= 336

    setfiles = sorted(SETS_DIR.glob("*_backtest.set"))
    assert len(setfiles) == 8
    for setfile in setfiles:
        values = set_values(setfile)
        assert float(values["RISK_FIXED"]) > 0
        assert float(values["RISK_PERCENT"]) == 0

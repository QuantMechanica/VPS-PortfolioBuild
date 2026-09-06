from __future__ import annotations

import re
from pathlib import Path

from tools.strategy_farm import farmctl


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_DIR = REPO_ROOT / "framework" / "EAs" / "QM5_11015_the5ers-weekly-ny"
SETFILE = EA_DIR / "sets" / "QM5_11015_the5ers-weekly-ny_EURUSD.DWX_H1_backtest.set"
MQ5 = EA_DIR / "QM5_11015_the5ers-weekly-ny.mq5"

EXPECTED_STRATEGY_DEFAULTS = {
    "strategy_ny_start_hour": "16",
    "strategy_ny_end_hour": "22",
    "strategy_sma_period": "20",
    "strategy_atr_period": "14",
    "strategy_session_move_atr": "0.5",
    "strategy_breakout_buf_atr": "0.0",
    "strategy_sl_atr_mult": "1.5",
    "strategy_sl_atr_floor": "1.0",
    "strategy_tp_rr": "2.0",
    "strategy_time_stop_bars": "36",
    "strategy_friday_exit_hour": "18",
}


def test_repaired_baseline_has_all_nonempty_strategy_defaults() -> None:
    ok, detail = farmctl._q02_strategy_params_contract(str(SETFILE))
    assert ok is True, detail
    assert detail["strategy_parameter_count"] == len(EXPECTED_STRATEGY_DEFAULTS)

    assignments = farmctl._setfile_semantic_parameters(SETFILE)
    observed = {
        key: value for key, value in assignments.items() if key.startswith("strategy_")
    }
    assert observed == EXPECTED_STRATEGY_DEFAULTS


def test_repaired_defaults_match_compiled_ea_input_defaults() -> None:
    source = MQ5.read_text(encoding="utf-8-sig")
    for name, value in EXPECTED_STRATEGY_DEFAULTS.items():
        assert re.search(
            rf"(?m)^input\s+\w+\s+{re.escape(name)}\s*=\s*{re.escape(value)}\s*;",
            source,
        ), name

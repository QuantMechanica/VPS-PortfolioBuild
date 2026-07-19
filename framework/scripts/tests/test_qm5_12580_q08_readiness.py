import json
from pathlib import Path

from framework.scripts import q08_5_neighborhood_runner


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_12580_fx-usd-exhaustion-reversal"
BASELINE_SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_12580_fx-usd-exhaustion-reversal_AUDUSD.DWX_D1_backtest.set"
)


def test_qm5_12580_q08_baseline_is_a_fixed_risk_basket_with_perturbable_params() -> None:
    """Lock the repaired Q08 input contract for the nearest FX basket sleeve."""
    manifest = json.loads(
        (EA_DIR / "basket_manifest.json").read_text(encoding="utf-8-sig")
    )
    setfile_text = BASELINE_SETFILE.read_text(encoding="utf-8-sig")
    identity = q08_5_neighborhood_runner.inspect_baseline_setfile(
        BASELINE_SETFILE,
        "AUDUSD.DWX",
    )
    params = q08_5_neighborhood_runner.load_params_from_setfile(
        BASELINE_SETFILE
    )["params"]

    assert manifest["timeframe"] == "D1"
    assert set(manifest["symbols"]) == {
        "EURUSD.DWX",
        "GBPUSD.DWX",
        "AUDUSD.DWX",
        "NZDUSD.DWX",
        "USDJPY.DWX",
        "USDCHF.DWX",
        "USDCAD.DWX",
    }
    assert "RISK_FIXED=1000" in setfile_text
    assert "RISK_PERCENT=0" in setfile_text
    assert identity["strategy_param_count"] == 8
    assert set(params) == {
        "strategy_basket_return_bars",
        "strategy_basket_z_lookback",
        "strategy_basket_z_threshold",
        "strategy_sma_period",
        "strategy_atr_period",
        "strategy_extension_atr_mult",
        "strategy_stop_atr_mult",
        "strategy_hold_bars",
    }

import json
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def test_qm5_12580_legacy_manifest_gets_multisymbol_q08_runtime_budget() -> None:
    parent = {
        "ea_id": "QM5_12580",
        "symbol": "AUDUSD.DWX",
        "payload_json": json.dumps(
            {
                "host_symbol": "AUDUSD.DWX",
                "host_timeframe": "D1",
                "timeout_min": 120,
            }
        ),
    }

    payload = farmctl._promotion_payload_with_basket_context(
        parent,
        {
            "promoted_from_phase": "Q07",
            "promotion_source": "test",
        },
    )
    farmctl._apply_phase_timeout_min(payload, "Q08")

    assert Path(payload["basket_manifest"]).resolve() == (
        REPO
        / "framework"
        / "EAs"
        / "QM5_12580_fx-usd-exhaustion-reversal"
        / "basket_manifest.json"
    ).resolve()
    assert payload["basket_symbol_count"] == 7
    assert set(payload["basket_symbols"]) == {
        "EURUSD.DWX",
        "GBPUSD.DWX",
        "AUDUSD.DWX",
        "NZDUSD.DWX",
        "USDJPY.DWX",
        "USDCHF.DWX",
        "USDCAD.DWX",
    }
    assert payload["host_symbol"] == "AUDUSD.DWX"
    assert payload["host_timeframe"] == "D1"
    assert "portfolio_scope" not in payload
    assert payload["timeout_min"] == farmctl._q08_active_timeout_min(payload)
    assert payload["timeout_min"] == 418

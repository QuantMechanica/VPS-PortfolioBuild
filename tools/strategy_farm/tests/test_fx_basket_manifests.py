import json
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]


def _mq5_allowed_symbols(ea_dir: Path) -> set[str]:
    mq5_path = ea_dir / f"{ea_dir.name}.mq5"
    text = mq5_path.read_text(encoding="utf-8", errors="ignore")
    allowed: set[str] = set()
    for body in re.findall(r"string\s+allowed\s*\[[^\]]*\]\s*=\s*\{([^}]*)\}", text):
        allowed.update(re.findall(r'"([A-Z]{6}\.DWX)"', body))
    return allowed


def test_qm5_12781_manifest_uses_jpy_tester_account_for_jpy_cross_basket() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12781_edgelab-usdjpy-audjpy-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "JPY"
    assert manifest["tester_deposit"] == 15000000
    assert declared == {"USDJPY.DWX", "AUDJPY.DWX"}
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12783_manifest_uses_aud_tester_account_for_aud_base_basket() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12783_edgelab-audusd-audjpy-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "AUD"
    assert manifest["tester_deposit"] == 150000
    assert declared == {"AUDUSD.DWX", "AUDJPY.DWX"}
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12772_manifest_declares_usdjpy_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12772_edgelab-gbpjpy-audjpy-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"GBPJPY.DWX", "AUDJPY.DWX", "USDJPY.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12758_manifest_declares_audusd_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12758_edgelab-gbpusd-euraud-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"GBPUSD.DWX", "EURAUD.DWX", "AUDUSD.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12749_manifest_declares_audjpy_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12749_edgelab-nzdusd-audjpy-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"NZDUSD.DWX", "AUDJPY.DWX", "AUDUSD.DWX", "USDJPY.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12751_manifest_declares_euraud_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12751_edgelab-eurusd-euraud-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"EURUSD.DWX", "EURAUD.DWX", "AUDUSD.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12728_manifest_declares_gbpjpy_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12728_edgelab-nzdusd-gbpjpy-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"NZDUSD.DWX", "GBPJPY.DWX", "GBPUSD.DWX", "USDJPY.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12712_manifest_declares_eur_cross_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12712_edgelab-eurgbp-euraud-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"EURGBP.DWX", "EURAUD.DWX", "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12778_manifest_declares_euraud_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12778_edgelab-audusd-eurjpy-cointegration"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "EUR"
    assert {"AUDUSD.DWX", "EURJPY.DWX", "EURUSD.DWX", "EURAUD.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_13024_manifest_declares_audcad_gbpaud_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_13024_audcad-gbpaud-coint"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"AUDCAD.DWX", "GBPAUD.DWX", "USDCAD.DWX", "AUDUSD.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_13058_manifest_declares_audcad_gbpnzd_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_13058_audcad-gbpnzd-coint"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"AUDCAD.DWX", "GBPNZD.DWX", "USDCAD.DWX", "NZDUSD.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_12507_manifest_declares_all_warmed_pair_symbols() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_12507_pair-coint-z"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"EURUSD.DWX", "GBPUSD.DWX", "NDX.DWX", "WS30.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_1257_manifest_declares_audusd_usdjpy_logical_pair() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_1257_lemishko-fx-cointpair"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["logical_symbol"] == "QM5_1257_AUDUSD_USDJPY_COINTEGRATION_H1"
    assert manifest["host_timeframe"] == "H1"
    assert manifest["tester_currency"] == "USD"
    assert declared == {"AUDUSD.DWX", "USDJPY.DWX"}
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_9184_manifest_has_logical_audusd_nzdusd_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_9184_jstm-pair-cointegration-fx"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    host_tf = manifest["host_timeframe"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_{host_tf}_backtest.set"

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert logical == "QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1"
    assert manifest["tester_currency"] == "USD"
    assert declared == {"AUDUSD.DWX", "NZDUSD.DWX"}
    assert logical_setfile.exists()
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_13119_zscore_uses_strictly_prior_calibration_window() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_13119_usdjpy-euraud"
    source = (ea_dir / "QM5_13119_usdjpy-euraud.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )

    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert "g_spread_z = (spreads[0] - g_spread_mean) / g_spread_sd;" in source


def test_qm5_13119_routes_host_through_trade_manager_and_declares_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_13119_usdjpy-euraud"
    source = (ea_dir / "QM5_13119_usdjpy-euraud.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert "return (_Symbol == g_leg_usdjpy);" in source
    assert "QM_TM_OpenPosition(host_req, ticket)" in source
    assert {"USDJPY.DWX", "EURAUD.DWX", "AUDUSD.DWX", "EURUSD.DWX"} <= declared
    assert _mq5_allowed_symbols(ea_dir) <= declared


def test_qm5_13117_zscore_uses_strictly_prior_calibration_window() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_13117_eurgbp-audjpy"
    source = (ea_dir / "QM5_13117_eurgbp-audjpy.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )

    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert "g_spread_z = (spreads[0] - g_spread_mean) / g_spread_sd;" in source


def test_qm5_12978_zscore_uses_strictly_prior_calibration_window() -> None:
    ea_dir = (
        REPO
        / "framework"
        / "EAs"
        / "QM5_12978_edgelab-gbpusd-usdcad-cointegration"
    )
    source = (
        ea_dir / "QM5_12978_edgelab-gbpusd-usdcad-cointegration.mq5"
    ).read_text(encoding="utf-8", errors="ignore")

    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert "g_spread_z = (spreads[0] - g_spread_mean) / g_spread_sd;" in source

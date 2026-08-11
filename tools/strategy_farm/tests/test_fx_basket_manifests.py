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


def test_qm5_1257_manifest_declares_gbpusd_usdjpy_logical_pair() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_1257_lemishko-fx-cointpair"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))

    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["logical_symbol"] == "QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1"
    assert manifest["host_timeframe"] == "H1"
    assert manifest["tester_currency"] == "USD"
    assert declared == {"GBPUSD.DWX", "USDJPY.DWX"}
    assert _mq5_allowed_symbols(ea_dir) <= declared

    retired = json.loads(
        (ea_dir / "docs" / "basket_manifest_slot12_q02_snapshot.json").read_text(
            encoding="utf-8-sig"
        )
    )
    assert retired["logical_symbol"] == "QM5_1257_AUDUSD_USDJPY_COINTEGRATION_H1"
    assert {retired["host_symbol"], *retired["basket_symbols"]} == {
        "AUDUSD.DWX",
        "USDJPY.DWX",
    }


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


def test_qm5_10309_is_one_logical_eurusd_gbpusd_two_leg_package() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_10309_cointeg-hft-pairs"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    source = (ea_dir / "QM5_10309_cointeg-hft-pairs.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )

    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_M15_backtest.set"
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z0-9]+\.DWX)"', source))

    assert logical == "QM5_10309_EURUSD_GBPUSD_COINTEG_FX"
    assert manifest["host_symbol"] == "GBPUSD.DWX"
    assert manifest["host_timeframe"] == "M15"
    assert manifest["tester_currency"] == "USD"
    assert declared == {"EURUSD.DWX", "GBPUSD.DWX"}
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "QM_TM_OpenPosition(host_req, ticket)" in source
    assert "QM_BasketOpenPosition(qm_ea_id" in source
    assert "QM_KillSwitchRegisterMagic((long)foreign_magic)" in source
    assert "ClosePackage(QM_EXIT_STRATEGY);" in source


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


def test_qm5_13060_declares_and_warms_usd_account_conversion_history() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_13060_xti-eurcad-rspr"
    source = (ea_dir / "QM5_13060_xti-eurcad-rspr.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}

    assert manifest["tester_currency"] == "USD"
    assert {"XTIUSD.DWX", "EURCAD.DWX", "USDCAD.DWX", "EURUSD.DWX"} <= declared
    assert 'string basket_symbols[4]' in source
    assert "QM_BasketWarmupHistory(basket_symbols" in source
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


def test_qm5_20183_manifest_and_risk_fixed_logical_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20183_gbpusd-chf-coint"
    source = (ea_dir / "QM5_20183_gbpusd-chf-coint.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "GBPUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert declared == {"GBPUSD.DWX", "USDCHF.DWX"}
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  GBPUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2


def test_qm5_20191_manifest_and_risk_fixed_logical_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20191_eurusd-chf-coint"
    source = (ea_dir / "QM5_20191_eurusd-chf-coint.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20191_EURUSD_USDCHF_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "EURUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert declared == {"EURUSD.DWX", "USDCHF.DWX"}
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  EURUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.585986704" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2


def test_qm5_20193_manifest_and_risk_fixed_logical_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20193_eurusd-cad-coint"
    source = (ea_dir / "QM5_20193_eurusd-cad-coint.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20193_EURUSD_USDCAD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "EURUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert declared == {"EURUSD.DWX", "USDCAD.DWX"}
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  EURUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.839757300" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2


def test_qm5_20195_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20195_nzd-eurgbp-coint"
    source = (ea_dir / "QM5_20195_nzd-eurgbp-coint.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20195_NZDUSD_EURGBP_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "NZDUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert declared == {"NZDUSD.DWX", "EURGBP.DWX", "GBPUSD.DWX", "EURUSD.DWX"}
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  NZDUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.101296029" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[4] = {"NZDUSD.DWX", "EURGBP.DWX", "GBPUSD.DWX", "EURUSD.DWX"};'
        in source
    )
    assert "if(nzdusd_lots <= 0.0 || eurgbp_lots <= 0.0)" in source


def test_qm5_20196_manifest_and_risk_fixed_logical_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20196_eurusd-jpy-coint"
    source = (ea_dir / "QM5_20196_eurusd-jpy-coint.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "EURUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["EURUSD.DWX", "USDJPY.DWX"]
    assert declared == {"EURUSD.DWX", "USDJPY.DWX"}
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  EURUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.505485905" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert 'string allowed[2] = {"EURUSD.DWX", "USDJPY.DWX"};' in source
    assert "if(eurusd_lots <= 0.0 || usdjpy_lots <= 0.0)" in source


def test_qm5_20197_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20197_eurjpy-eurgbp"
    source = (ea_dir / "QM5_20197_eurjpy-eurgbp.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20197_EURJPY_EURGBP_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "EURJPY.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["EURJPY.DWX", "EURGBP.DWX"]
    assert declared == {
        "EURJPY.DWX",
        "EURGBP.DWX",
        "USDJPY.DWX",
        "GBPUSD.DWX",
        "EURUSD.DWX",
    }
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  EURJPY.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.679904414" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[5] = {"EURJPY.DWX", "EURGBP.DWX", "USDJPY.DWX", '
        '"GBPUSD.DWX", "EURUSD.DWX"};'
        in source
    )
    assert "if(eurjpy_lots <= 0.0 || eurgbp_lots <= 0.0)" in source


def test_qm5_20199_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20199_eurjpy-euraud"
    source = (ea_dir / "QM5_20199_eurjpy-euraud.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20199_EURJPY_EURAUD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "EURJPY.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["EURJPY.DWX", "EURAUD.DWX"]
    assert declared == {
        "EURJPY.DWX",
        "EURAUD.DWX",
        "USDJPY.DWX",
        "AUDUSD.DWX",
        "EURUSD.DWX",
    }
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  EURJPY.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-1.073345776" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[5] = {"EURJPY.DWX", "EURAUD.DWX", "USDJPY.DWX", '
        '"AUDUSD.DWX", "EURUSD.DWX"};'
        in source
    )
    assert "if(eurjpy_lots <= 0.0 || euraud_lots <= 0.0)" in source


def test_qm5_20200_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20200_audjpy-euraud"
    source = (ea_dir / "QM5_20200_audjpy-euraud.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20200_AUDJPY_EURAUD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "AUDJPY.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["AUDJPY.DWX", "EURAUD.DWX"]
    assert declared == {
        "AUDJPY.DWX",
        "EURAUD.DWX",
        "USDJPY.DWX",
        "AUDUSD.DWX",
        "EURUSD.DWX",
    }
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  AUDJPY.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-2.073289367" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[5] = {"AUDJPY.DWX", "EURAUD.DWX", "USDJPY.DWX", '
        '"AUDUSD.DWX", "EURUSD.DWX"};'
        in source
    )
    assert "if(audjpy_lots <= 0.0 || euraud_lots <= 0.0)" in source


def test_qm5_20201_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20201_gbpjpy-eurgbp"
    source = (ea_dir / "QM5_20201_gbpjpy-eurgbp.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20201_GBPJPY_EURGBP_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "GBPJPY.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["GBPJPY.DWX", "EURGBP.DWX"]
    assert declared == {
        "GBPJPY.DWX",
        "EURGBP.DWX",
        "USDJPY.DWX",
        "GBPUSD.DWX",
        "EURUSD.DWX",
    }
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  GBPJPY.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-1.681438352" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[5] = {"GBPJPY.DWX", "EURGBP.DWX", "USDJPY.DWX", '
        '"GBPUSD.DWX", "EURUSD.DWX"};'
        in source
    )
    assert "if(gbpjpy_lots <= 0.0 || eurgbp_lots <= 0.0)" in source


def test_qm5_20203_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20203_eurusd-audjpy"
    source = (ea_dir / "QM5_20203_eurusd-audjpy.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "EURUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["EURUSD.DWX", "AUDJPY.DWX"]
    assert declared == {
        "EURUSD.DWX",
        "AUDJPY.DWX",
        "AUDUSD.DWX",
        "USDJPY.DWX",
    }
    assert source_symbols <= declared
    assert logical_setfile.exists()
    assert "; host_symbol:  EURUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.160071209" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[4] = {"EURUSD.DWX", "AUDJPY.DWX", '
        '"AUDUSD.DWX", "USDJPY.DWX"};'
        in source
    )
    assert "if(eurusd_lots <= 0.0 || audjpy_lots <= 0.0)" in source


def test_qm5_20207_manifest_and_fixed_risk_logical_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20207_usdcad-audusd"
    source = (ea_dir / "QM5_20207_usdcad-audusd.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20207_USDCAD_AUDUSD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "USDCAD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["USDCAD.DWX", "AUDUSD.DWX"]
    assert declared == {"USDCAD.DWX", "AUDUSD.DWX"}
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  USDCAD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.460267756" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert 'string allowed[2] = {"USDCAD.DWX", "AUDUSD.DWX"};' in source
    assert "if(usdcad_lots <= 0.0 || audusd_lots <= 0.0)" in source


def test_qm5_20208_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20208_nzdusd-euraud"
    source = (ea_dir / "QM5_20208_nzdusd-euraud.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20208_NZDUSD_EURAUD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "NZDUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["NZDUSD.DWX", "EURAUD.DWX"]
    assert declared == {
        "NZDUSD.DWX",
        "EURAUD.DWX",
        "AUDUSD.DWX",
        "EURUSD.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  NZDUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.286008035" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[4] = {"NZDUSD.DWX", "EURAUD.DWX", '
        '"AUDUSD.DWX", "EURUSD.DWX"};'
        in source
    )
    assert "if(nzdusd_lots <= 0.0 || euraud_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20210_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20210_gbpusd-audjpy"
    source = (ea_dir / "QM5_20210_gbpusd-audjpy.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20210_GBPUSD_AUDJPY_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "GBPUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["GBPUSD.DWX", "AUDJPY.DWX"]
    assert declared == {
        "GBPUSD.DWX",
        "AUDJPY.DWX",
        "AUDUSD.DWX",
        "USDJPY.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  GBPUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.038239845" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[4] = {"GBPUSD.DWX", "AUDJPY.DWX", '
        '"AUDUSD.DWX", "USDJPY.DWX"};'
        in source
    )
    assert "if(gbpusd_lots <= 0.0 || audjpy_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20211_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20211_gbpjpy-euraud"
    source = (ea_dir / "QM5_20211_gbpjpy-euraud.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20211_GBPJPY_EURAUD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "GBPJPY.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["GBPJPY.DWX", "EURAUD.DWX"]
    assert declared == {
        "GBPJPY.DWX",
        "EURAUD.DWX",
        "USDJPY.DWX",
        "GBPUSD.DWX",
        "EURUSD.DWX",
        "AUDUSD.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  GBPJPY.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-1.386054145" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[6] = {"GBPJPY.DWX", "EURAUD.DWX", "USDJPY.DWX", '
        '"GBPUSD.DWX", "EURUSD.DWX", "AUDUSD.DWX"};'
        in source
    )
    assert "if(gbpjpy_lots <= 0.0 || euraud_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20212_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20212_gbpusd-eurjpy"
    source = (ea_dir / "QM5_20212_gbpusd-eurjpy.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20212_GBPUSD_EURJPY_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "GBPUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["GBPUSD.DWX", "EURJPY.DWX"]
    assert declared == {
        "GBPUSD.DWX",
        "EURJPY.DWX",
        "EURUSD.DWX",
        "USDJPY.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  GBPUSD.DWX" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.080732288" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[4] = {"GBPUSD.DWX", "EURJPY.DWX", '
        '"EURUSD.DWX", "USDJPY.DWX"};'
        in source
    )
    assert "if(gbpusd_lots <= 0.0 || eurjpy_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20216_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20216_audusd-euraud"
    source = (ea_dir / "QM5_20216_audusd-euraud.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20216_AUDUSD_EURAUD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "AUDUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["AUDUSD.DWX", "EURAUD.DWX"]
    assert declared == {
        "AUDUSD.DWX",
        "EURAUD.DWX",
        "EURUSD.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  AUDUSD.DWX" in set_text
    assert "qm_ea_id=20216" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "strategy_beta=-0.655175398" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[3] = {"AUDUSD.DWX", "EURAUD.DWX", "EURUSD.DWX"};'
        in source
    )
    assert "if(audusd_lots <= 0.0 || euraud_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20219_manifest_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20219_usdjpy-nzdusd"
    source = (ea_dir / "QM5_20219_usdjpy-nzdusd.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20219_USDJPY_NZDUSD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "USDJPY.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["USDJPY.DWX", "NZDUSD.DWX"]
    assert declared == {"USDJPY.DWX", "NZDUSD.DWX"}
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  USDJPY.DWX" in set_text
    assert "qm_ea_id=20219" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "PORTFOLIO_WEIGHT=1" in set_text
    assert "strategy_beta=-0.782302979" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert 'string allowed[2] = {"USDJPY.DWX", "NZDUSD.DWX"};' in source
    assert "if(usdjpy_lots <= 0.0 || nzdusd_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20220_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20220_usdcad-audjpy"
    source = (ea_dir / "QM5_20220_usdcad-audjpy.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20220_USDCAD_AUDJPY_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "USDCAD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["USDCAD.DWX", "AUDJPY.DWX"]
    assert declared == {
        "USDCAD.DWX",
        "AUDJPY.DWX",
        "AUDUSD.DWX",
        "USDJPY.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  USDCAD.DWX" in set_text
    assert "qm_ea_id=20220" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "PORTFOLIO_WEIGHT=1" in set_text
    assert "strategy_beta=-0.186232670" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[4] = {"USDCAD.DWX", "AUDJPY.DWX", '
        '"AUDUSD.DWX", "USDJPY.DWX"};'
        in source
    )
    assert "if(usdcad_lots <= 0.0 || audjpy_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20223_manifest_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20223_gbpusd-eurgbp"
    source = (ea_dir / "QM5_20223_gbpusd-eurgbp.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20223_GBPUSD_EURGBP_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "GBPUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["GBPUSD.DWX", "EURGBP.DWX"]
    assert declared == {"GBPUSD.DWX", "EURGBP.DWX"}
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  GBPUSD.DWX" in set_text
    assert "qm_ea_id=20223" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "PORTFOLIO_WEIGHT=1" in set_text
    assert "strategy_beta=-0.399228065" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert 'string allowed[2] = {"GBPUSD.DWX", "EURGBP.DWX"};' in source
    assert "if(gbpusd_lots <= 0.0 || eurgbp_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20246_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20246_usdjpy-eurgbp"
    source = (ea_dir / "QM5_20246_usdjpy-eurgbp.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "USDJPY.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["USDJPY.DWX", "EURGBP.DWX"]
    assert declared == {
        "USDJPY.DWX",
        "EURGBP.DWX",
        "GBPUSD.DWX",
        "EURUSD.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  USDJPY.DWX" in set_text
    assert "qm_ea_id=20246" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "PORTFOLIO_WEIGHT=1" in set_text
    assert "strategy_beta=-1.281773609960" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[4] = {"USDJPY.DWX", "EURGBP.DWX", '
        '"GBPUSD.DWX", "EURUSD.DWX"};'
        in source
    )
    assert "if(usdjpy_lots <= 0.0 || eurgbp_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20250_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20250_usdchf-audjpy"
    source = (ea_dir / "QM5_20250_usdchf-audjpy.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20250_USDCHF_AUDJPY_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "USDCHF.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["USDCHF.DWX", "AUDJPY.DWX"]
    assert declared == {
        "USDCHF.DWX",
        "AUDJPY.DWX",
        "AUDUSD.DWX",
        "USDJPY.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  USDCHF.DWX" in set_text
    assert "qm_ea_id=20250" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "PORTFOLIO_WEIGHT=1" in set_text
    assert "strategy_beta=-0.027722525061" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[4] = {"USDCHF.DWX", "AUDJPY.DWX", '
        '"AUDUSD.DWX", "USDJPY.DWX"};'
        in source
    )
    assert "if(usdchf_lots <= 0.0 || audjpy_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20252_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20252_usdchf-euraud"
    source = (ea_dir / "QM5_20252_usdchf-euraud.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20252_USDCHF_EURAUD_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "USDCHF.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["USDCHF.DWX", "EURAUD.DWX"]
    assert declared == {
        "USDCHF.DWX",
        "EURAUD.DWX",
        "AUDUSD.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  USDCHF.DWX" in set_text
    assert "qm_ea_id=20252" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "PORTFOLIO_WEIGHT=1" in set_text
    assert "strategy_beta=-0.013891609131" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[3] = {"USDCHF.DWX", "EURAUD.DWX", '
        '"AUDUSD.DWX"};'
        in source
    )
    assert "if(usdchf_lots <= 0.0 || euraud_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_20255_manifest_conversion_history_and_fixed_risk_setfile() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_20255_usdchf-eurjpy"
    source = (ea_dir / "QM5_20255_usdchf-eurjpy.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    declared = {manifest["host_symbol"], *manifest["basket_symbols"]}
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1"
    assert manifest["host_symbol"] == "USDCHF.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert manifest["tester_deposit"] == 100000
    assert manifest["traded_symbols"] == ["USDCHF.DWX", "EURJPY.DWX"]
    assert declared == {
        "USDCHF.DWX",
        "EURJPY.DWX",
        "USDJPY.DWX",
    }
    assert source_symbols == declared
    assert logical_setfile.exists()
    assert "; host_symbol:  USDCHF.DWX" in set_text
    assert "qm_ea_id=20255" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "PORTFOLIO_WEIGHT=1" in set_text
    assert "strategy_beta=-0.075286902527" in set_text
    assert "const int history_count = lookback + 1;" in source
    assert source.count("PERIOD_D1, 1, history_count") == 4
    assert source.count("for(int i = 1; i < history_count; ++i)") == 2
    assert (
        'string allowed[3] = {"USDCHF.DWX", "EURJPY.DWX", '
        '"USDJPY.DWX"};'
        in source
    )
    assert "if(usdchf_lots <= 0.0 || eurjpy_lots <= 0.0)" in source
    assert "g_companion_entry_ready &&" in source
    assert "if(!companion_opened)" in source


def test_qm5_1224_is_one_atomic_fx7_cross_sectional_package() -> None:
    ea_dir = REPO / "framework" / "EAs" / "QM5_1224_white-okunev-fx-xmom"
    manifest = json.loads((ea_dir / "basket_manifest.json").read_text(encoding="utf-8-sig"))
    source = (ea_dir / f"{ea_dir.name}.mq5").read_text(
        encoding="utf-8", errors="ignore"
    )

    expected_symbols = {
        "EURUSD.DWX",
        "GBPUSD.DWX",
        "AUDUSD.DWX",
        "NZDUSD.DWX",
        "USDCAD.DWX",
        "USDCHF.DWX",
        "USDJPY.DWX",
    }
    logical = manifest["logical_symbol"]
    logical_setfile = ea_dir / "sets" / f"{ea_dir.name}_{logical}_D1_backtest.set"
    set_text = logical_setfile.read_text(encoding="utf-8-sig")
    source_symbols = set(re.findall(r'"([A-Z]{6}\.DWX)"', source))

    assert logical == "QM5_1224_FX7_XMOM_D1"
    assert manifest["host_symbol"] == "EURUSD.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert manifest["tester_currency"] == "USD"
    assert set(manifest["basket_symbols"]) == expected_symbols
    assert source_symbols == expected_symbols
    assert logical_setfile.exists()
    assert "; host_symbol:  EURUSD.DWX" in set_text
    assert "RISK_FIXED=500" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "qm_friday_close_enabled=0" in set_text

    assert "QM_BasketOpenPosition(qm_ea_id" in source
    assert "QM_KillSwitchRegisterMagic((long)magic)" in source
    assert "QM_SymbolGuardInit(g_symbols)" in source
    assert "Strategy_PackageCompositionValid()" in source
    assert "QM_FRIDAY_CLOSE_DISABLED" in source
    assert "QM_CalendarPeriodKey(cadence, _Symbol, 0)" in source
    assert "QM_CalendarPeriodKey(cadence, _Symbol, 1)" in source
    assert "QM_IsNewCalendarPeriod" not in source
    assert not re.search(r"\bi(?:Time|Close|Open|High|Low|Volume|Bars)\s*\(", source)

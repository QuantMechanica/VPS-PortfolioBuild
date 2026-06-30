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

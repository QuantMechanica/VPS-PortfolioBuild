"""Static and optional artifact-only MetaEditor acceptance for QM_ChartPanel."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


REPO = Path("C:/QM/repo")
HEADER = REPO / "framework/include/QM/QM_ChartPanel.mqh"
SCHEME = REPO / "framework/include/QM/QM_ChartScheme.mqh"
PROBE = REPO / "framework/tests/mql5/QM_ChartPanel_compile_probe.mq5"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


INCLUDE_ROOT = REPO / "framework/include/QM"
DEPENDENCIES = (
    "QM_ChartPanel.mqh", "QM_ChartScheme.mqh", "QM_DesignTokens.mqh",
    "QM_ConsoleModel.mqh", "QM_ConsoleData.mqh", "QM_StrategyConsole.mqh",
)
TOKEN_JSON = REPO / "docs/design/qm_implementation_package_v1.0/website/quantmechanica-design-tokens.json"


def token_color_mapping() -> list[dict]:
    tokens = json.loads(TOKEN_JSON.read_text(encoding="utf-8"))["color"]
    text = (INCLUDE_ROOT / "QM_DesignTokens.mqh").read_text(encoding="utf-8")
    rows = []
    for key, expected in tokens.items():
        constant = "QM_COLOR_" + re.sub(r"(?<!^)(?=[A-Z])", "_", key).upper()
        match = re.search(rf"#define\s+{constant}\s+C'([0-9,]+)'", text)
        actual = "#" + "".join(f"{int(v):02X}" for v in match.group(1).split(",")) if match else None
        rows.append({"json_token": f"color.{key}", "constant": constant,
                     "value": expected, "actual": actual, "matches": actual == expected})
    return rows


def static_acceptance() -> dict:
    sources = {name: (INCLUDE_ROOT / name).read_text(encoding="utf-8") for name in DEPENDENCIES}
    renderer = sources["QM_StrategyConsole.mqh"]
    model = sources["QM_ConsoleModel.mqh"]
    data = sources["QM_ConsoleData.mqh"]
    header = sources["QM_ChartPanel.mqh"]
    scheme = sources["QM_ChartScheme.mqh"]
    probe = PROBE.read_text(encoding="utf-8")
    combined = "".join(sources.values()) + probe
    checks = {
        "ascii_only": combined.isascii(),
        "no_trade_calls": not re.search(r"\b(?:OrderSend|OrderSendAsync|CTrade|PositionClose|PositionModify)\s*\(", combined),
        "pure_snapshot_renderer": not re.search(
            r"\b(?:HistorySelect|HistoryDealGet\w*|PositionGet\w*|OrderGet\w*|OrderCalcProfit|AccountInfo\w*|QM_News\w*|QM_FTMO\w*|Strategy_\w*)\s*\(", renderer),
        "structured_states": "const QM_ConsoleSnapshot &snapshot" in renderer and
            "QM_ConsoleGateState" in model and "StringToUpper" not in renderer,
        "no_ontick": not re.search(r"\bvoid\s+OnTick\s*\(", combined),
        "tester_optimization_inert": all("MQL_TESTER" in sources[name] and "MQL_OPTIMIZATION" in sources[name]
            for name in ("QM_ChartPanel.mqh", "QM_StrategyConsole.mqh", "QM_ConsoleData.mqh", "QM_ChartScheme.mqh")),
        "timer_fixture": all(token in probe for token in ("EventSetTimer(5)", "OnTimer()", "EventKillTimer()")),
        "required_hierarchy": all(token in renderer for token in (
            '"Quant"', '"Mechanica"', '"STRATEGY CONSOLE"', '"FILTER GATE"', '"RISK"',
            '"LIVE"', '"Today  "', '"Week  "', '"PERFORMANCE | THIS EA"', '"(c) QuantMechanica"')),
        "no_obsolete_product_copy": not any(token in renderer for token in (
            "LOGIN", "LICENSE", "Support:", "Heartbeat", "debug")),
        "three_modes": all(token in renderer + model for token in (
            "QM_CONSOLE_FULL", "QM_CONSOLE_COMPACT", "QM_CONSOLE_MINIMAL", "QM_ConsoleNextMode")),
        "view_event_timer_only": "CHARTEVENT_OBJECT_CLICK" in renderer and
            "Render(" not in renderer.split("void OnChartEvent", 1)[1].split("void Render", 1)[0],
        "object_namespace": '"QM_SIG_"' in header,
        "update_in_place": "ObjectFind" in renderer and "RemoveUnused" in renderer and "m_used" in renderer,
        "single_redraw_per_cycle": renderer.split("void Render", 1)[1].split("void Shutdown", 1)[0].count("ChartRedraw(") == 1,
        "dynamic_live": "if(ArraySize(lines)==0) return y;" in renderer and '"NONE"' not in renderer,
        "de_de_en_us_formatters": all(token in data for token in (
            '"100.000,00"', '"100,000.00"', '"0,31 %"', '"0.31 %"', "QM_PanelFormatterSelfTest")),
        "self_test_probe": "QM_ConsoleSnapshotSelfTest()" in probe and "QM_PanelFormatterSelfTest()" in probe,
        "history_hard_minimum": "now_ms-m_last_scan_ms>=QM_PANEL_REFRESH_SECONDS*1000" in data and
            "m_dirty ||" not in data and "#define QM_PANEL_REFRESH_SECONDS 30" in data,
        "broker_aware_risk": "OrderCalcProfit(" in data and "UNPRICED" in data,
        "all_color_tokens_match": all(row["matches"] for row in token_color_mapping()),
        "scheme_snapshot_restore": all(scheme.count(prop) >= 3 for prop in (
            "CHART_COLOR_BACKGROUND", "CHART_COLOR_CANDLE_BULL", "CHART_COLOR_CANDLE_BEAR",
            "CHART_COLOR_BID", "CHART_SHOW_GRID", "CHART_SHOW_VOLUMES", "CHART_SHOW_LAST_LINE")),
    }
    return {"status": "PASS" if all(checks.values()) else "FAIL", "checks": checks,
            "files": {name: sha256(INCLUDE_ROOT / name) for name in DEPENDENCIES},
            "token_mapping": token_color_mapping(), "probe_sha256": sha256(PROBE)}


def native_compile(metaeditor: Path, artifact_root: Path) -> dict:
    root = artifact_root.resolve()
    required_prefix = Path("D:/QM/ftmo").resolve()
    if required_prefix not in root.parents or not root.name.startswith("compile_probe_"):
        raise ValueError("artifact root must be D:/QM/ftmo/compile_probe_*")
    if root.exists():
        raise FileExistsError(f"fresh artifact root required: {root}")

    source = root / "MQL5/Experts/QM_ChartPanel_compile_probe.mq5"
    include = root / "MQL5/Include/QM/QM_ChartPanel.mqh"
    scheme = root / "MQL5/Include/QM/QM_ChartScheme.mqh"
    source.parent.mkdir(parents=True)
    include.parent.mkdir(parents=True)
    shutil.copy2(PROBE, source)
    for name in DEPENDENCIES:
        shutil.copy2(INCLUDE_ROOT / name, include.parent / name)

    command = [
        str(metaeditor.resolve()),
        "/portable",
        f"/compile:{source}",
        f"/include:{root / 'MQL5'}",
        "/log",
    ]
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    completed = subprocess.run(
        command,
        cwd=metaeditor.resolve().parent,
        startupinfo=startup,
        creationflags=subprocess.CREATE_NO_WINDOW,
        timeout=120,
        capture_output=True,
        text=True,
    )
    log = source.with_suffix(".log")
    binary = source.with_suffix(".ex5")
    log_text = log.read_text(encoding="utf-16", errors="replace") if log.exists() else ""
    summary = re.search(r"Result:\s+(\d+) errors?,\s+(\d+) warnings?", log_text)
    passed = bool(summary and summary.group(1) == "0" and summary.group(2) == "0" and binary.is_file())
    result = {
        "status": "PASS" if passed else "FAIL",
        "artifact_only": True,
        "terminal_started": False,
        "metaeditor": str(metaeditor.resolve()),
        "returncode": completed.returncode,
        "source": str(source),
        "source_sha256": sha256(source),
        "compile_log": str(log),
        "ex5": str(binary) if binary.exists() else None,
        "ex5_sha256": sha256(binary) if binary.exists() else None,
        "summary": summary.group(0) if summary else None,
    }
    (root / "acceptance.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metaeditor", type=Path)
    parser.add_argument("--artifact-root", type=Path)
    args = parser.parse_args()
    static = static_acceptance()
    report = {"schema": "qm.chart-panel-acceptance/v1", "static": static, "native": None}
    if args.metaeditor or args.artifact_root:
        if not args.metaeditor or not args.artifact_root:
            parser.error("--metaeditor and --artifact-root are required together")
        report["native"] = native_compile(args.metaeditor, args.artifact_root)
    print(json.dumps(report, indent=2))
    return 0 if static["status"] == "PASS" and (
        report["native"] is None or report["native"]["status"] == "PASS"
    ) else 1


if __name__ == "__main__":
    raise SystemExit(main())

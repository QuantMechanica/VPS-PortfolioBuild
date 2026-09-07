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


def static_acceptance() -> dict:
    header = HEADER.read_text(encoding="utf-8")
    scheme = SCHEME.read_text(encoding="utf-8")
    probe = PROBE.read_text(encoding="utf-8")
    combined = header + scheme + probe
    checks = {
        "ascii_only": all(ord(char) < 128 for char in combined),
        "no_trade_calls": not re.search(
            r"\b(?:OrderSend|OrderSendAsync|CTrade|PositionClose|PositionModify)\b", header
        ),
        "no_ontick": not re.search(r"\bvoid\s+OnTick\s*\(", header),
        "tester_inert": "MQL_TESTER" in header and "MQL_VISUAL_MODE" not in header,
        "timer_fixture": all(
            token in probe for token in ("EventSetTimer(5)", "OnTimer()", "EventKillTimer()")
        ),
        "required_fields": all(
            token in header
            for token in (
                "TRADING ", "MAGIC ", "NEWS ", "FRI ", "GOV ", "KS ",
                "RISK ", "ROOM DAILY ", "EXPOSURE SL ", "POS ", "ORD ",
                "NEXT BAR ", "LAST SIGNAL ", "LAST TRADE ", "HEALTH HB ",
                "CAL ", "LICENSE ", "BUILD ", "_Symbol", "_Period",
            )
        ),
        "object_namespace": '"QM_SIG_"' in header,
        "light_brand_tokens": all(
            token in scheme
            for token in ("C'255,255,255'", "C'41,84,212'", "C'5,150,105'", "C'239,68,68'")
        ),
        "scheme_snapshot_restore": all(
            token in scheme
            for token in (
                "QM_ChartScheme_Apply", "QM_ChartScheme_Restore",
                "CHART_COLOR_BACKGROUND", "CHART_COLOR_FOREGROUND",
                "CHART_COLOR_GRID", "CHART_COLOR_CHART_UP",
                "CHART_COLOR_CHART_DOWN", "CHART_COLOR_CANDLE_BULL",
                "CHART_COLOR_CANDLE_BEAR", "CHART_COLOR_BID",
                "CHART_COLOR_ASK", "CHART_COLOR_VOLUME", "CHART_MODE",
                "CHART_SCALE", "CHART_SHOW_GRID",
            )
        ),
        "max_22_rows": "line < 18" in header,
        "market_safe_support": "Support: MQL5 comments/messages" in header,
    }
    return {
        "status": "PASS" if all(checks.values()) else "FAIL",
        "checks": checks,
        "header": str(HEADER),
        "header_sha256": sha256(HEADER),
        "scheme": str(SCHEME),
        "scheme_sha256": sha256(SCHEME),
        "probe": str(PROBE),
        "probe_sha256": sha256(PROBE),
    }


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
    shutil.copy2(HEADER, include)
    shutil.copy2(SCHEME, scheme)

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

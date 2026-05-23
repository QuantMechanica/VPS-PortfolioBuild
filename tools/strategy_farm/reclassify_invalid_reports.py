"""Reclassify invalid MT5 reports that were mislabeled MIN_TRADES_NOT_MET.

Default mode is dry-run. Use --apply to update work_items.verdict and
payload_json verdict_reason for rows whose evidence summary points at blank
M0/Bars=0 tester reports.
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
from pathlib import Path
from typing import Any


ROOT = Path(r"D:\QM\strategy_farm")
DB = ROOT / "state" / "farm_state.sqlite"


def _html_value(html: str, label: str) -> str:
    m = re.search(
        rf"(?is)<td[^>]*>\s*{re.escape(label)}:\s*</td>\s*<td[^>]*>\s*<b>(?P<v>.*?)</b>",
        html,
    )
    if not m:
        return ""
    return re.sub(r"<[^>]+>", "", m.group("v")).strip()


def _num(value: str) -> float:
    m = re.search(r"[-+]?[0-9][0-9\s,\.]*", value or "")
    if not m:
        return 0.0
    token = re.sub(r"\s+", "", m.group(0))
    if "." in token and "," in token:
        token = token.replace(",", "")
    elif "," in token and "." not in token:
        token = token.replace(",", ".")
    try:
        return float(token)
    except ValueError:
        return 0.0


def _read_text(path: Path) -> str:
    data = path.read_bytes()
    for enc in ("utf-8", "utf-16", "utf-16-le", "cp1252"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="ignore")


def classify_report(report_path: Path, tester_log_path: Path | None = None) -> dict[str, Any]:
    html = _read_text(report_path)
    log = ""
    if tester_log_path and tester_log_path.exists():
        log = _read_text(tester_log_path)
    expert = _html_value(html, "Expert")
    symbol = _html_value(html, "Symbol")
    period = _html_value(html, "Period")
    bars = int(_num(_html_value(html, "Bars")))
    reasons: list[str] = []
    if not expert.strip():
        reasons.append("EMPTY_EXPERT")
    if not symbol.strip():
        reasons.append("EMPTY_SYMBOL")
    if re.search(r"\bM0\b", period, re.I) or "1970.01.01 - 1970.01.01" in period:
        reasons.append("M0_1970_PERIOD")
    if bars <= 0:
        reasons.append("BARS_ZERO")
    if re.search(r"no history data,\s*stop testing", log, re.I):
        reasons.append("NO_HISTORY_LOG")
    if ("M0_1970_PERIOD" in reasons or "BARS_ZERO" in reasons) and re.search(r"\bhistory\b", log, re.I):
        reasons.append("HISTORY_CONTEXT_INVALID")
    if "generating based on real ticks" not in log.lower() and "automatical testing finished" in log.lower():
        reasons.append("NO_REAL_TICKS_MARKER_FAST_FINISH")
    verdict = None
    if "NO_HISTORY_LOG" in reasons or "HISTORY_CONTEXT_INVALID" in reasons:
        verdict = "NO_HISTORY"
    elif "NO_REAL_TICKS_MARKER_FAST_FINISH" in reasons:
        verdict = "NO_REAL_TICKS"
    elif reasons:
        verdict = "INVALID_REPORT"
    return {"invalid": bool(verdict), "verdict": verdict, "reasons": reasons}


def classify_summary(summary_path: Path) -> dict[str, Any]:
    summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    verdicts = []
    for run in summary.get("runs") or []:
        report = Path(run.get("report_canonical_path") or run.get("report_source_path") or "")
        log_path = Path(run.get("tester_log_path")) if run.get("tester_log_path") else None
        if report.exists():
            verdicts.append(classify_report(report, log_path))
    for preferred in ("NO_HISTORY", "NO_REAL_TICKS", "INVALID_REPORT"):
        if any(v.get("verdict") == preferred for v in verdicts):
            return {"invalid": True, "verdict": preferred, "runs": verdicts}
    return {"invalid": False, "verdict": None, "runs": verdicts}


def scan(root: Path = ROOT, apply: bool = False) -> list[dict[str, Any]]:
    con = sqlite3.connect(str(root / "state" / "farm_state.sqlite"))
    con.row_factory = sqlite3.Row
    rows = con.execute(
        """
        SELECT id, ea_id, phase, verdict, evidence_path, payload_json
        FROM work_items
        WHERE verdict='FAIL' AND payload_json LIKE '%MIN_TRADES_NOT_MET%'
        ORDER BY updated_at
        """
    ).fetchall()
    out = []
    for row in rows:
        evidence = Path(row["evidence_path"] or "")
        if not evidence.exists():
            continue
        cls = classify_summary(evidence)
        if not cls.get("invalid"):
            continue
        item = {
            "id": row["id"],
            "ea_id": row["ea_id"],
            "phase": row["phase"],
            "evidence_path": str(evidence),
            "new_verdict": cls["verdict"],
        }
        out.append(item)
        if apply:
            payload = json.loads(row["payload_json"] or "{}")
            payload["verdict_reason"] = cls["verdict"]
            payload["invalid_report_reclassified"] = True
            payload["invalid_report_reasons"] = cls
            con.execute(
                "UPDATE work_items SET verdict=?, payload_json=?, updated_at=datetime('now') WHERE id=?",
                (cls["verdict"], json.dumps(payload, sort_keys=True), row["id"]),
            )
    if apply and out:
        con.commit()
    con.close()
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Dry-run or apply invalid-report reclassification.")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--classify-report", type=Path)
    parser.add_argument("--tester-log", type=Path)
    args = parser.parse_args()
    if args.classify_report:
        print(json.dumps(classify_report(args.classify_report, args.tester_log), indent=2, sort_keys=True))
        return 0
    rows = scan(args.root, apply=args.apply)
    print(json.dumps({"apply": args.apply, "count": len(rows), "rows": rows}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

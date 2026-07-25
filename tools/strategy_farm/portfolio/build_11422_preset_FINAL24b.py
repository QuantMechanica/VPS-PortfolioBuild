"""Extend the FINAL24b staging: BUILD the new 11422/USDCAD live preset (no deployed
source exists) and merge it with the committed stage_tlive_presets_risk.py incumbent
report into ONE unified staging report with per-file diff proof.

Recipe (per operator instruction): take 11422's backtest_set as base
(= the setfile the 07-24 Q10 ran, resolved from the Q10 tester.ini
 -> ..._USDCAD.DWX_D1_q10_confirmation.set), patch the ENV header to live, RISK_FIXED=0,
RISK_PERCENT=<final book weight>, PORTFOLIO_WEIGHT=1.0, and confirm qm_magic_slot_offset
matches the registry slot (USDCAD -> slot 4). Every other line is copied verbatim so the
diff proof shows exactly the patched lines and nothing else.

Read-only against T_Live (only reads the deployed 10440 preset to record its SHA for the
drop record). Writes ONLY into --out-dir. No terminal, no DB.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import sys
from pathlib import Path

MANIFEST = Path(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json")
BASE_SET = Path(r"C:/QM/repo/framework/EAs/QM5_11422_williams-18ma-outside-bar-entry-d1/"
                r"sets/QM5_11422_williams-18ma-outside-bar-entry-d1_USDCAD.DWX_D1_q10_confirmation.set")
NEW_NAME = "25_USDCAD_D1_QM5_11422_williams-18ma-outside-bar-entry-d1.set"
DROPPED_PRESET = Path(r"C:/QM/mt5/T_Live/MT5_Base/MQL5/Presets/15_NDX_H1_QM5_10440_mql5-ohlc-mtf.set")
REGISTRY_SLOT = 4  # magic_numbers.csv: 11422,...,4,USDCAD.DWX,114220004


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--incumbent-report", type=Path, required=True,
                    help="JSON written by stage_tlive_presets_risk.py for the 23 incumbents")
    ap.add_argument("--json", type=Path, required=True, help="unified staging report output path")
    ap.add_argument("--apply", action="store_true", help="write the built preset (default: dry-run)")
    args = ap.parse_args(argv)

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    sleeve = next(s for s in manifest["sleeves"] if s["ea_id"] == 11422 and s["symbol"] == "USDCAD.DWX")
    weight = float(sleeve["risk_percent"])
    weight_str = f"{weight:.6f}".rstrip("0").rstrip(".")

    raw = BASE_SET.read_bytes()
    try:
        text = raw.decode("utf-8")
        enc = "utf-8"
    except UnicodeDecodeError:
        text = raw.decode("utf-8-sig")
        enc = "utf-8-sig"
    lines = text.splitlines(keepends=True)

    problems: list[str] = []

    def patch_unique(pred, new_value_fn, label):
        idx = [i for i, l in enumerate(lines) if pred(l)]
        if len(idx) != 1:
            problems.append(f"{label}: expected exactly 1 match, found {len(idx)}")
            return None
        i = idx[0]
        old = lines[i]
        eol = "\r\n" if old.endswith("\r\n") else ("\n" if old.endswith("\n") else "")
        lines[i] = new_value_fn(old.rstrip("\r\n")) + eol
        return (old.rstrip("\r\n"), lines[i].rstrip("\r\n"))

    changes = []
    # 1. header environment -> live (preserve "; environment:  " prefix + spacing)
    changes.append(patch_unique(
        lambda l: l.startswith("; environment:"),
        lambda s: re.sub(r"(;\s*environment:\s*).*", r"\1live", s), "header environment"))
    # 2. header risk_mode -> PERCENT
    changes.append(patch_unique(
        lambda l: l.startswith("; risk_mode:"),
        lambda s: re.sub(r"(;\s*risk_mode:\s*).*", r"\1PERCENT", s), "header risk_mode"))
    # 3. RISK_FIXED -> 0
    changes.append(patch_unique(
        lambda l: l.startswith("RISK_FIXED="),
        lambda s: "RISK_FIXED=0", "RISK_FIXED"))
    # 4. RISK_PERCENT -> final weight
    changes.append(patch_unique(
        lambda l: l.startswith("RISK_PERCENT="),
        lambda s: f"RISK_PERCENT={weight_str}", "RISK_PERCENT"))
    # 5. PORTFOLIO_WEIGHT -> 1.0
    changes.append(patch_unique(
        lambda l: l.startswith("PORTFOLIO_WEIGHT="),
        lambda s: "PORTFOLIO_WEIGHT=1.0", "PORTFOLIO_WEIGHT"))

    # confirm magic slot offset matches registry
    slot_lines = [l.rstrip("\r\n") for l in lines if l.startswith("qm_magic_slot_offset=")]
    if len(slot_lines) != 1 or slot_lines[0] != f"qm_magic_slot_offset={REGISTRY_SLOT}":
        problems.append(f"qm_magic_slot_offset mismatch: found {slot_lines!r}, registry slot={REGISTRY_SLOT}")
    magic_ok = (len(slot_lines) == 1 and slot_lines[0] == f"qm_magic_slot_offset={REGISTRY_SLOT}")

    # confirm TF token in filename matches the setfile timeframe header
    tf_hdr = next((l.split(":", 1)[1].strip() for l in lines if l.lstrip("; ").startswith("timeframe")), None)
    if tf_hdr != "D1":
        problems.append(f"timeframe header {tf_hdr!r} != D1 (preset name token)")

    staged_text = "".join(lines)
    staged = staged_text.encode("utf-8")  # write no-BOM utf-8 to match deployed presets

    diff = list(difflib.unified_diff(
        text.splitlines(), staged_text.splitlines(),
        fromfile=f"base/{BASE_SET.name}", tofile=f"staged/{NEW_NAME}", lineterm="", n=0))
    content_changes = [d for d in diff if d.startswith(("+", "-")) and not d.startswith(("+++", "---"))]
    # expected changed lines: 5 patched (each -/+ pair = 10)
    expected_changed = 10
    if len([c for c in content_changes]) != expected_changed:
        problems.append(f"diff has {len(content_changes)} changed lines, expected {expected_changed}")

    if args.apply and not problems:
        args.out_dir.mkdir(parents=True, exist_ok=True)
        (args.out_dir / NEW_NAME).write_bytes(staged)

    build_entry = {
        "preset": NEW_NAME, "ea_id": 11422, "symbol": "USDCAD",
        "action": "BUILD_NEW", "base_set": str(BASE_SET).replace("/", "\\"),
        "base_set_resolution": "07-24 Q10 tester.ini ExpertParameters=..._USDCAD.DWX_D1_q10_confirmation.set",
        "encoding_read": enc, "encoding_written": "utf-8",
        "new_risk": weight_str, "portfolio_weight": "1.0", "risk_fixed": "0",
        "qm_magic_slot_offset": REGISTRY_SLOT, "magic_number": 11422 * 10000 + REGISTRY_SLOT,
        "magic_slot_matches_registry": magic_ok,
        "tf_token": "D1", "tf_header": tf_hdr,
        "header_patches": ["; environment: * -> live", "; risk_mode: * -> PERCENT"],
        "body_patches": ["RISK_FIXED=1000 -> 0", f"RISK_PERCENT=0 -> {weight_str}", "PORTFOLIO_WEIGHT=1 -> 1.0"],
        "sha256_base": sha256(raw), "sha256_staged": sha256(staged),
        "changed_lines": content_changes,
        "note": ("Built from the Q10-confirmation base (identical strategy params to the _backtest.set, "
                 "plus qm_news_temporal/qm_news_compliance=DXZ and qm_stress_reject_probability=0.0000 carried "
                 "verbatim). Base set carries NO qm_filter_* library block (the incumbent deployed presets do); "
                 "flagged for OWNER — this is base-set content, not something the recipe strips or adds."),
    }

    # 10440 drop record
    drop_sha = sha256(DROPPED_PRESET.read_bytes()) if DROPPED_PRESET.exists() else None
    drop_entry = {
        "preset": DROPPED_PRESET.name, "ea_id": 10440, "symbol": "NDX",
        "action": "DROP", "staged": False,
        "reason": ("fresh warm Q10 on the NEW binary is a hard FAIL (pf 1.07, dd 31.0%, 490 trades, over the 25% "
                   "DD ceiling); removed from the FINAL24b book. Its deployed preset is intentionally NOT staged."),
        "sha256_deployed": drop_sha,
    }

    inc = json.loads(args.incumbent_report.read_text(encoding="utf-8"))
    unified = {
        "schema": "staging_report_FINAL24b.v1",
        "mode": inc.get("mode"),
        "manifest": str(MANIFEST).replace("/", "\\"),
        "out_dir": str(args.out_dir).replace("/", "\\"),
        "deployed_presets_dir": r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets",
        "deployed_presets_read_only": True,
        "n_deployed_presets": 24,
        "n_incumbents_patched": len(inc.get("staged", [])),
        "n_dropped": 1,
        "n_built_new": 1 if (args.apply and not problems) else 0,
        "n_staged_files_total": len(inc.get("staged", [])) + (1 if (args.apply and not problems) else 0),
        "expected_vs_actual_note": (
            "Operator brief said '22 patched incumbent presets'; ACTUAL is 23. The deployed T_Live "
            "Presets dir holds 24 presets (01-24) matching the base-24 composition; dropping #15 "
            "(10440/NDX) leaves 23 incumbents that match the FINAL24b manifest, all patched. 23, not 22."),
        "incumbents_patched": inc.get("staged", []),
        "dropped": [drop_entry],
        "built_new": [build_entry],
        "committed_tool_problems": inc.get("problems", []),
        "build_problems": problems,
    }
    args.json.write_text(json.dumps(unified, indent=1), encoding="utf-8")

    print(f"build 11422 preset [{'APPLY' if args.apply else 'DRY-RUN'}]  problems={len(problems)}")
    print(f"  base   {BASE_SET.name}")
    print(f"  staged {NEW_NAME}  RISK_PERCENT={weight_str}  slot_ok={magic_ok}  tf={tf_hdr}")
    for c in content_changes:
        print(f"    {c}")
    for p in problems:
        print(f"  PROBLEM: {p}")
    print(f"  unified report -> {args.json}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(build())

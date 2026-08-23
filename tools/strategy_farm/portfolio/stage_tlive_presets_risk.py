"""Stage T_Live presets at a new TOTAL_RISK by patching RISK_PERCENT in place.

Why patch instead of regenerate: the 2026-07-19 deployment presets were produced by a
session-local script that was never committed, so a full regeneration cannot be proven
equivalent. A single-key patch can: every staged file is byte-identical to its deployed
source except the `RISK_PERCENT=` line (and, where explicitly listed, a stale header
comment), and the tool emits that proof per file. The audit trail is the point.

Read-only against T_Live. Staged output goes to --out-dir; copying staged presets into
`C:/QM/mt5/T_Live` is the OWNER-gated deployment step and is NOT done here.

Usage:
    python stage_tlive_presets_risk.py --manifest <12.0 manifest> --out-dir <staging>
    (add --apply to write the staging dir; default is dry-run)
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import sys
from pathlib import Path

try:
    from tools.strategy_farm import risk_freeze
except ModuleNotFoundError:  # direct script execution
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.strategy_farm import risk_freeze

DEFAULT_PRESETS = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets")
DEFAULT_MANIFEST = Path(
    r"D:\QM\reports\portfolio\portfolio_manifest_sunday_24sleeve_TOTALRISK12_20260726.json"
)
PRESET_RE = re.compile(r"^(?P<nn>\d{2})_(?P<sym>[A-Z0-9]+)_(?P<tf>[A-Z0-9]+)_QM5_(?P<ea>\d+)_")

# Deployed presets are ANSI/ASCII text (not UTF-16); verified against the 07-19 set.
ENC = "utf-8"

# Stale header comments to normalise while we are touching the file anyway. Keyed by
# preset ea_id. These are COMMENTS (the EA reads only `key=value` inputs), but the
# 2026-07-25 deployment-readiness audit flagged them as contradicting the manifest's
# ENV=live expectation, and a header that lies is how audits go wrong.
HEADER_FIXES: dict[int, list[tuple[str, str]]] = {
    10919: [
        ("; environment:  backtest", "; environment:  live"),
        ("; risk_mode:    FIXED", "; risk_mode:    PERCENT"),
    ],
    12989: [
        ("; risk_mode:    PERCENT_DRAFT_INVOL_SUMRISK_CAPPED_S3-D2D-15-SWAP",
         "; risk_mode:    PERCENT"),
    ],
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--presets", type=Path, default=DEFAULT_PRESETS)
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--apply", action="store_true", help="write staged files (default: dry-run)")
    ap.add_argument("--json", type=Path, help="write the verification report here")
    args = ap.parse_args(argv)

    if args.apply:
        risk_freeze.assert_live_book_mutation_allowed(
            "stage T_Live preset risk changes",
        )

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    # Full-precision risk per (ea_id, bare symbol) — the preset filename carries the bare
    # broker-style symbol (no .DWX), the manifest carries the .DWX form.
    risk: dict[tuple[int, str], float] = {
        (int(s["ea_id"]), s["symbol"].replace(".DWX", "")): float(s["risk_percent"])
        for s in manifest["sleeves"]
    }

    report: list[dict] = []
    problems: list[str] = []
    seen: set[tuple[int, str]] = set()

    for preset in sorted(args.presets.glob("*.set")):
        m = PRESET_RE.match(preset.name)
        if not m:
            problems.append(f"unparseable preset name: {preset.name}")
            continue
        ea, sym = int(m.group("ea")), m.group("sym")
        key = (ea, sym)
        if key not in risk:
            problems.append(f"{preset.name}: no manifest sleeve for QM5_{ea}/{sym}")
            continue
        seen.add(key)

        raw = preset.read_bytes()
        text = raw.decode(ENC, errors="strict")
        lines = text.splitlines(keepends=True)

        target = f"{risk[key]:.6f}".rstrip("0").rstrip(".")
        risk_lines = [i for i, l in enumerate(lines) if l.startswith("RISK_PERCENT=")]
        if len(risk_lines) != 1:
            problems.append(f"{preset.name}: expected exactly 1 RISK_PERCENT line, found {len(risk_lines)}")
            continue
        i = risk_lines[0]
        old_line = lines[i]
        eol = "\r\n" if old_line.endswith("\r\n") else "\n"
        lines[i] = f"RISK_PERCENT={target}{eol}"

        changed_headers = []
        for old, new in HEADER_FIXES.get(ea, []):
            for j, l in enumerate(lines):
                if l.rstrip("\r\n") == old:
                    lines[j] = new + ("\r\n" if l.endswith("\r\n") else "\n")
                    changed_headers.append(f"{old!r} -> {new!r}")

        staged = "".join(lines).encode(ENC)
        diff = list(difflib.unified_diff(
            text.splitlines(), staged.decode(ENC).splitlines(),
            fromfile=f"deployed/{preset.name}", tofile=f"staged/{preset.name}", lineterm="", n=0,
        ))
        # Proof bound: every diff hunk must be the RISK_PERCENT line or a listed header fix.
        content_changes = [d for d in diff if d.startswith(("+", "-")) and not d.startswith(("+++", "---"))]
        allowed = len(changed_headers) * 2 + 2
        if len(content_changes) != allowed:
            problems.append(f"{preset.name}: diff has {len(content_changes)} changed lines, expected {allowed}")
            continue

        entry = {
            "preset": preset.name, "ea_id": ea, "symbol": sym,
            "old_risk": old_line.strip().split("=", 1)[1], "new_risk": target,
            "header_fixes": changed_headers,
            "sha256_deployed": sha256(raw), "sha256_staged": sha256(staged),
            "changed_lines": content_changes,
        }
        report.append(entry)
        if args.apply:
            args.out_dir.mkdir(parents=True, exist_ok=True)
            (args.out_dir / preset.name).write_bytes(staged)

    missing = sorted(set(risk) - seen)
    for k in missing:
        problems.append(f"manifest sleeve QM5_{k[0]}/{k[1]} has no deployed preset")

    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"stage_tlive_presets_risk [{mode}]  presets={len(report)}  problems={len(problems)}")
    for e in report:
        hf = f"  +{len(e['header_fixes'])} header fix(es)" if e["header_fixes"] else ""
        print(f"  {e['preset'][:58]:60s} {e['old_risk']:>9s} -> {e['new_risk']:<9s}{hf}")
    for p in problems:
        print(f"  PROBLEM: {p}")
    if args.json:
        args.json.write_text(json.dumps({"mode": mode, "staged": report, "problems": problems},
                                        indent=1), encoding="utf-8")
        print(f"  -> {args.json}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

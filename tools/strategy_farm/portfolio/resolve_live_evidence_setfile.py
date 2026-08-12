"""Resolve, for each live sleeve, the backtest setfile that actually describes the
configuration deployed on T_Live — and flag any sleeve where none does.

Why this exists
---------------
`gen_dxz_final_manifest.py` fills a sleeve's `backtest_set` with
`glob(f"{ea_dir}/sets/*{symbol}*backtest.set")[0]` — the alphabetically first match.
That is not the file the evidence came from. Audited 2026-07-24 against the deployed
T_Live presets: for 11 of 24 sleeves the manifest names a setfile whose strategy
parameters differ from what is actually trading.

For QM5_10513/XAUUSD the manifest named a 2026-05-28 param-less stub (EA defaults
9/26/52/14) while the deployed preset runs 6/18/68/18 — which IS a fully evidenced
configuration, `..._D1_backtest_grid_008.set`. So the defect is traceability, not
(necessarily) an untested live config. This tool tells the two apart per sleeve.

Matching rules
--------------
A setfile matches the deployed preset when, for every strategy_* input the EA declares,
the EFFECTIVE value agrees. Effective value = the value stated in the file, or the EA's
compiled-in `input` default when the file omits it. That is what MT5 actually runs, so
comparing stated-values-only would produce false mismatches for every preset that simply
leaves a parameter at its default.

Read-only. Never writes into C:/QM/mt5/T_Live.

Usage:
    python resolve_live_evidence_setfile.py
    python resolve_live_evidence_setfile.py --manifest <path> --json <out.json>
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[3]
EAS_DIR = REPO_ROOT / "framework" / "EAs"
DEFAULT_PRESETS = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets")
DEFAULT_MANIFEST = Path(
    r"D:\QM\reports\portfolio\portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json"
)

_INPUT_RE = re.compile(r"^\s*input\s+\S+\s+(strategy_\w+)\s*=\s*([^;]+);", re.M)

# Setfiles persist ENUM_TIMEFRAMES numerically (PERIOD_H4 -> 16388) while the .mq5
# declares the symbolic name. Without this mapping every timeframe input reads as a
# mismatch and otherwise-identical setfiles are reported as unevidenced.
_ENUM_TIMEFRAMES = {
    "period_current": "0", "period_m1": "1", "period_m2": "2", "period_m3": "3",
    "period_m4": "4", "period_m5": "5", "period_m6": "6", "period_m10": "10",
    "period_m12": "12", "period_m15": "15", "period_m20": "20", "period_m30": "30",
    "period_h1": "16385", "period_h2": "16386", "period_h3": "16387",
    "period_h4": "16388", "period_h6": "16390", "period_h8": "16392",
    "period_h12": "16396", "period_d1": "16408", "period_w1": "32769",
    "period_mn1": "49153",
}


def ea_defaults(mq5: Path) -> dict[str, str]:
    """Compiled-in defaults for every strategy_* input the EA declares."""
    if not mq5.exists():
        return {}
    text = mq5.read_text(encoding="utf-8", errors="replace")
    return {m.group(1): m.group(2).strip() for m in _INPUT_RE.finditer(text)}


def setfile_params(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("strategy_") and "=" in line:
            key, _, val = line.partition("=")
            out[key.strip()] = val.strip()
    return out


def _norm(value: str) -> str:
    """Compare 2.0 == 2, true == TRUE, 1.50 == 1.5 — MT5 parses these identically."""
    v = value.strip().strip('"').lower()
    if v in _ENUM_TIMEFRAMES:
        return _ENUM_TIMEFRAMES[v]
    if v in ("true", "false"):
        return v
    try:
        return f"{float(v):.10g}"
    except ValueError:
        return v


def effective(params: dict[str, str], defaults: dict[str, str]) -> dict[str, str]:
    return {k: _norm(params.get(k, defaults[k])) for k in defaults}


def find_preset(presets_dir: Path, ea_id: int, symbol: str) -> Path | None:
    bare = symbol.replace(".DWX", "")
    for p in sorted(presets_dir.glob("*.set")):
        parts = p.name.split("_")
        if f"QM5_{ea_id}_" in p.name and len(parts) > 1 and parts[1] == bare:
            return p
    return None


def resolve_sleeve(ea_label: str, ea_id: int, symbol: str, presets_dir: Path,
                   manifest_set: str | None) -> dict[str, Any]:
    ea_dir = EAS_DIR / ea_label
    mq5 = ea_dir / f"{ea_label}.mq5"
    defaults = ea_defaults(mq5)
    preset = find_preset(presets_dir, ea_id, symbol)
    rec: dict[str, Any] = {
        "ea_label": ea_label, "ea_id": ea_id, "symbol": symbol,
        "deployed_preset": preset.name if preset else None,
        "manifest_backtest_set": Path(manifest_set).name if manifest_set else None,
        "n_strategy_inputs": len(defaults),
    }
    if preset is None:
        rec["verdict"] = "NO_DEPLOYED_PRESET"
        return rec
    if not defaults:
        rec["verdict"] = "NO_STRATEGY_INPUTS"
        return rec

    target = effective(setfile_params(preset), defaults)
    matches: list[str] = []
    for cand in sorted((ea_dir / "sets").glob("*.set")):
        name = cand.name.lower()
        if "_live" in name or "stress" in name:
            continue
        if symbol.replace(".DWX", "").lower() not in name:
            continue
        if effective(setfile_params(cand), defaults) == target:
            matches.append(cand.name)

    rec["matching_setfiles"] = matches
    manifest_name = rec["manifest_backtest_set"]
    if not matches:
        rec["verdict"] = "NO_EVIDENCE_SETFILE_FOR_DEPLOYED_CONFIG"
        rec["deployed_effective"] = target
    elif manifest_name in matches:
        rec["verdict"] = "OK_MANIFEST_MATCHES_DEPLOYED"
    else:
        rec["verdict"] = "MANIFEST_NAMES_WRONG_SETFILE"
        rec["should_be"] = matches[0]
    return rec


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    ap.add_argument("--presets", default=str(DEFAULT_PRESETS))
    ap.add_argument("--json", default=None, help="write full result JSON here")
    args = ap.parse_args(argv)

    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8-sig"))
    presets_dir = Path(args.presets)
    results = [
        resolve_sleeve(s["ea_label"], int(s["ea_id"]), s["symbol"],
                       presets_dir, s.get("backtest_set"))
        for s in sorted(manifest["sleeves"], key=lambda x: -x["risk_percent"])
    ]

    order = ["NO_EVIDENCE_SETFILE_FOR_DEPLOYED_CONFIG", "NO_DEPLOYED_PRESET",
             "MANIFEST_NAMES_WRONG_SETFILE", "NO_STRATEGY_INPUTS",
             "OK_MANIFEST_MATCHES_DEPLOYED"]
    for verdict in order:
        rows = [r for r in results if r["verdict"] == verdict]
        if not rows:
            continue
        print(f"\n=== {verdict}  ({len(rows)}) ===")
        for r in rows:
            print(f"  {r['ea_label'][:38]:38s} {r['symbol']:12s} "
                  f"inputs={r['n_strategy_inputs']:2d}")
            print(f"      manifest : {r['manifest_backtest_set']}")
            if r.get("should_be"):
                print(f"      should be: {r['should_be']}")
                if len(r.get("matching_setfiles", [])) > 1:
                    print(f"      ({len(r['matching_setfiles'])} setfiles match the deployed config)")
            if verdict == "NO_EVIDENCE_SETFILE_FOR_DEPLOYED_CONFIG":
                print(f"      deployed effective config: {r.get('deployed_effective')}")

    counts = {v: sum(1 for r in results if r["verdict"] == v) for v in order}
    print("\n" + "=" * 70)
    print(f"{len(results)} sleeves: " + " | ".join(f"{v}={n}" for v, n in counts.items() if n))
    if args.json:
        Path(args.json).write_text(json.dumps(results, indent=1), encoding="utf-8")
        print(f"-> {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

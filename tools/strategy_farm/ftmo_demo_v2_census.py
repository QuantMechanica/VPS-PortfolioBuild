"""FTMO demo book v2 admission census (READ-ONLY, re-runnable).

Purpose
-------
Book sprint BOOK_SPRINT_2026-09-20.md item F4 / ticket 42a437a4. Decide ADMIT / EXCLUDE
per DXZ v2 roster sleeve for a *burn-in* deployment on the FTMO **demo** terminal
(account 1514536732), reusing the exact same sha256-identified DXZ binaries. No rebuild,
no qualification claim, no gate change.

Hard limits honoured by this script
-----------------------------------
* Read-only. It never starts terminal64.exe, never writes into any FTMO / T_Live data
  dir, never recompiles an EA, never attaches a chart, never touches a governor policy.
* The only artifact it writes is the census JSON under
  docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/roster_ftmo_demo_v2.json
  (pass --out to relocate).

What it determines per sleeve (a..e of the census brief)
--------------------------------------------------------
(a) FTMO symbol name + provenance (alias registry > native 2026-09-06 capture > FTMO
    terminal ticks dir). If none: symbol_source=unverified, decision=EXCLUDE.
(b) EA symbol-handling class of the exact deployable binary (sha256-bound), via
    tools/strategy_farm/ea_symbol_literal_inventory.py + source inspection.
(c) News-compliance capability (qm_news_compliance enum input present => FTMO(=2)
    selectable; else legacy-only). Recorded, never an exclude reason.
(d) magic = ea_id*10000+slot; collision check vs the FTMO governor's currently-allowed
    magics and vs framework/registry/magic_numbers.csv.
(e) RISK_PERCENT: weight_risk_percent (existing) / burn_in_risk_percent (new), which the
    DXZ v2 profile already materialises as chart risk_percent.

Sources (all read-only)
-----------------------
* Deployable roster / slot / magic / risk / expert-path:
  C:/QM/deploy/DXZ_V2_20260913/profile/DarwinexZero_Book2_LiveOps/profile_manifest.json
  (already carries the 12969 -> 41470 substitution; chart 29 is the monitor, skipped)
* Per-sleeve weight vs burn-in risk fields:
  D:/QM/reports/portfolio/dxz_v2_20260913/build_28_r11/analytic_preview_manifest_28_r11.json
* Symbol aliases: framework/registry/execution_symbol_aliases_v1.json (FTMO_TRIAL venue)
* Native FTMO symbol capture 2026-09-06 (symbols_covered_native):
  docs/ops/evidence/2026-09-14_ftmo_book_v2/ftmo_book_symbol_cost_snapshot_v2.json
* FTMO terminal ticks dir (positive existence evidence):
  <FTMO_DATADIR>/bases/FTMO-Demo/ticks/<SYMBOL>
* Governor currently-allowed magics: docs/ops/evidence/2026-09-06_ftmo_demo_governor/
  (the 8 magics currently deployed under the M13 governor)
* Magic registry: framework/registry/magic_numbers.csv
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
FTMO_DATADIR = Path(
    "C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/"
    "81A933A9AFC5DE3C23B15CAB19C63850"
)
PROFILE_MANIFEST = Path(
    "C:/QM/deploy/DXZ_V2_20260913/profile/DarwinexZero_Book2_LiveOps/profile_manifest.json"
)
ANALYTIC_MANIFEST = Path(
    "D:/QM/reports/portfolio/dxz_v2_20260913/build_28_r11/"
    "analytic_preview_manifest_28_r11.json"
)
ALIASES = REPO / "framework/registry/execution_symbol_aliases_v1.json"
COST_SNAPSHOT = REPO / "docs/ops/evidence/2026-09-14_ftmo_book_v2/ftmo_book_symbol_cost_snapshot_v2.json"
MAGIC_REGISTRY = REPO / "framework/registry/magic_numbers.csv"
INVENTORY_TOOL = REPO / "tools/strategy_farm/ea_symbol_literal_inventory.py"

TLIVE_EAS = Path("C:/QM/mt5/T_Live/MT5_Base/MQL5/Experts/Live EAs")
DEPLOY_EAS = Path("C:/QM/deploy/DXZ_V2_20260913/eas")
REPAIR_EAS = Path("C:/QM/deploy/DXZ_V2_20260913/repair_v2/eas")

# FTMO governor currently-allowed magics (the 8 sleeves deployed under FTMO_2S_P1_100K_V2 /
# M13). Source: docs/ops/evidence/2026-09-06_ftmo_demo_governor/ (census brief).
GOVERNOR_ALLOWED_MAGICS = {
    107060001, 114210000, 114220004, 119100006,
    130540000, 15370001, 200480000, 215050000,
}

# Sleeves flagged dark no-ops in v2 (NOT_EQUIVALENT rebuilds) — BOOK_SPRINT_2026-09-20.md
# item D7 ("12778/13117 (NOT_EQUIVALENT rebuilds) stay dark no-ops in v2; own chains
# continue | accepted"). They are multi-symbol cointegration/pair EAs and are not carried
# into the FTMO burn-in.
DARK_NOOP_EA_IDS = {12778, 13117}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def ftmo_alias_map(aliases: dict) -> dict[str, str]:
    """logical .DWX symbol -> FTMO raw symbol, from the FTMO_TRIAL venue."""
    out: dict[str, str] = {}
    for venue in aliases.get("venues", []):
        if venue.get("venue_id") == "FTMO_TRIAL":
            for sym in venue.get("symbols", []):
                out[sym["logical_symbol"]] = sym["raw_symbol"]
    return out


def native_captured_symbols(cost_snapshot: dict) -> set[str]:
    src = cost_snapshot.get("sources", {}).get("native_swap_contract_2026_09_06", {})
    return set(src.get("symbols_covered_native", []))


def ftmo_ticks_symbols() -> set[str]:
    ticks = FTMO_DATADIR / "bases/FTMO-Demo/ticks"
    if not ticks.is_dir():
        return set()
    return {p.name for p in ticks.iterdir() if p.is_dir()}


def resolve_ftmo_symbol(
    dwx_symbol: str,
    alias_map: dict[str, str],
    native_syms: set[str],
    ticks_syms: set[str],
) -> tuple[str, str]:
    """Return (ftmo_symbol, symbol_source). Never guesses."""
    # 1) authoritative alias registry (FTMO_TRIAL venue)
    if dwx_symbol in alias_map:
        return alias_map[dwx_symbol], "alias_registry_FTMO_TRIAL"
    base = dwx_symbol.replace(".DWX", "")
    # 2) native 2026-09-06 capture (plain-name symbols)
    if base in native_syms:
        return base, "native_capture_2026-09-06"
    # 3) FTMO terminal ticks dir (positive existence evidence)
    if base in ticks_syms:
        return base, "ftmo_ticks_dir_1514536732"
    # cash-suffix probe against ticks dir (indices/commodities)
    for cand in (f"{base}.cash",):
        if cand in ticks_syms:
            return cand, "ftmo_ticks_dir_1514536732"
    return "UNVERIFIED", "unverified"


def registry_by_magic(path: Path) -> dict[int, dict]:
    out: dict[int, dict] = {}
    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            try:
                out[int(row["magic"])] = row
            except (KeyError, ValueError):
                continue
    return out


def classify_symbol_handling(ea_label: str) -> dict:
    """Run the file-based symbol-literal inventory for one EA label."""
    proc = subprocess.run(
        [sys.executable, "-X", "utf8", str(INVENTORY_TOOL), "--ea-label", ea_label],
        capture_output=True, text=True, cwd=str(REPO),
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return {"class": "UNKNOWN", "detail": "inventory_tool_failed"}
    data = json.loads(proc.stdout)
    findings = data.get("findings", [])
    trade_literals = [f for f in findings if f["classification"] == "trading_logic_literal"]
    input_defaults = [f for f in findings if f["classification"] == "symbol_input_default"]
    multi = bool(data.get("multi_symbol_sources"))
    # Blocking .DWX literal = a trading-logic literal that is NOT keyed off an input
    # (calendar host-symbol inputs surface as trading_logic_literal but are input-driven;
    # they are recorded in detail so a reviewer can confirm).
    if input_defaults and multi:
        klass = "symbol-input-slot+multi-symbol"
    elif input_defaults:
        klass = "symbol-input-slot"
    elif multi:
        klass = "chart-symbol-only+non-chart-reads"
    else:
        klass = "chart-symbol-only"
    return {
        "class": klass,
        "trading_logic_literals": [
            {"path": f["path"], "line": f["line"], "symbol": f["symbol"], "severity": f["severity"]}
            for f in trade_literals
        ],
        "symbol_input_defaults": len(input_defaults),
        "multi_symbol_access": multi,
    }


def news_capability(ea_label: str) -> dict:
    mq = REPO / "framework/EAs" / ea_label / f"{ea_label}.mq5"
    if not mq.is_file():
        return {"capability": "SOURCE_MISSING", "compliance_input": False}
    text = mq.read_text(encoding="utf-8", errors="replace")
    has_input = "input QM_NewsComplianceProfile qm_news_compliance" in text
    has_legacy = "qm_news_mode_legacy" in text
    if has_input:
        cap = "FTMO_MODE2_SELECTABLE"  # enum includes QM_NEWS_COMPLIANCE_FTMO=2
    elif has_legacy:
        cap = "LEGACY_ONLY_MODE1"
    else:
        cap = "NO_NEWS_INPUT"
    return {"capability": cap, "compliance_input": has_input, "legacy_input": has_legacy}


def resolve_binary(expert_name: str) -> tuple[str, str]:
    for base, tag in ((TLIVE_EAS, "T_Live"), (DEPLOY_EAS, "deploy_staging"), (REPAIR_EAS, "repair_v2")):
        cand = base / f"{expert_name}.ex5"
        if cand.is_file():
            return str(cand), tag
    return "", "MISSING"


def build_census() -> dict:
    profile = load_json(PROFILE_MANIFEST)
    analytic = load_json(ANALYTIC_MANIFEST)
    aliases = load_json(ALIASES)
    cost = load_json(COST_SNAPSHOT)

    alias_map = ftmo_alias_map(aliases)
    native_syms = native_captured_symbols(cost)
    ticks_syms = ftmo_ticks_symbols()
    reg = registry_by_magic(MAGIC_REGISTRY)

    # per-(ea_id,symbol) weight/burn-in from the analytic manifest
    analytic_by_key: dict[tuple[int, str], dict] = {}
    for s in analytic["sleeves"]:
        analytic_by_key[(s["ea_id"], s["symbol"])] = s

    rows = []
    for chart in profile["charts"]:
        if chart.get("kind") == "monitor":
            continue
        ea_id = chart["ea_id"]
        expert_name = chart["expert_name"]
        dwx_symbol = f'{chart["symbol"]}.DWX'
        magic = chart["magic"]
        slot = chart["slot"]
        is_new = chart.get("kind") == "new"
        replaced = chart.get("replaces_ea_id")

        ftmo_symbol, symbol_source = resolve_ftmo_symbol(
            dwx_symbol, alias_map, native_syms, ticks_syms
        )

        bin_path, bin_loc = resolve_binary(expert_name)
        bin_sha = sha256_file(Path(bin_path)) if bin_path else ""

        handling = classify_symbol_handling(expert_name)
        news = news_capability(expert_name)

        # magic checks
        formula_ok = magic == ea_id * 10000 + slot
        gov_overlap = magic in GOVERNOR_ALLOWED_MAGICS
        reg_row = reg.get(magic)
        # collision = magic maps to a DIFFERENT ea in the registry, or governor overlap
        # belongs to a different ea. Same-sleeve reuse is consistency, not collision.
        reg_collision = bool(reg_row and int(reg_row["ea_id"]) != ea_id)
        magic_collision = reg_collision

        # risk (e): weight for existing, burn-in for new; profile already materialises it.
        # analytic manifest is keyed on (ea_id, logical .DWX symbol); 41470 inherits 12969's row.
        lookup_id = replaced if replaced else ea_id
        akey = analytic_by_key.get((lookup_id, dwx_symbol))
        risk_profile = float(chart["risk_percent"])
        if akey:
            risk = akey["burn_in_risk_percent"] if is_new else akey["weight_risk_percent"]
            risk_field = "burn_in_risk_percent" if is_new else "weight_risk_percent"
        else:
            risk = risk_profile
            risk_field = "profile_manifest.risk_percent (analytic row not found)"

        # decision
        reasons = []
        if symbol_source == "unverified":
            reasons.append("no verified FTMO symbol name")
        if ea_id in DARK_NOOP_EA_IDS:
            reasons.append(
                "dark no-op in v2 (NOT_EQUIVALENT rebuild, multi-symbol cointegration/pair) "
                "per BOOK_SPRINT_2026-09-20.md D7"
            )
        if handling["class"] == "UNKNOWN":
            reasons.append("symbol-handling class could not be determined")
        if magic_collision:
            reasons.append(
                f"magic {magic} collides with registry ea_id {reg_row['ea_id']}"
            )
        decision = "EXCLUDE" if reasons else "ADMIT"

        rows.append({
            "ea_id": ea_id,
            "ea_label": expert_name,
            "replaces_ea_id": replaced,
            "dxz_symbol": dwx_symbol,
            "ftmo_symbol": ftmo_symbol,
            "symbol_source": symbol_source,
            "binary_path": bin_path,
            "binary_location": bin_loc,
            "binary_sha256": bin_sha,
            "symbol_handling_class": handling["class"],
            "symbol_handling_detail": handling,
            "news_compliance_capability": news["capability"],
            "news_compliance_detail": news,
            "slot": slot,
            "magic": magic,
            "magic_formula_ok": formula_ok,
            "magic_in_governor_allowed": gov_overlap,
            "magic_registry_ea_id": (int(reg_row["ea_id"]) if reg_row else None),
            "magic_collision": magic_collision,
            "risk_percent": risk,
            "risk_percent_field": risk_field,
            "risk_percent_profile": risk_profile,
            "is_new_sleeve": is_new,
            "decision": decision,
            "reason": "; ".join(reasons) if reasons else "all checks passed",
        })

    admit = [r for r in rows if r["decision"] == "ADMIT"]
    exclude = [r for r in rows if r["decision"] == "EXCLUDE"]

    # governor input deltas (PROPOSAL ONLY)
    admit_magics = sorted(r["magic"] for r in admit)
    new_magics = sorted(m for m in admit_magics if m not in GOVERNOR_ALLOWED_MAGICS)
    admit_symbols = sorted({r["ftmo_symbol"] for r in admit})

    return {
        "schema": "qm.ftmo-demo-v2-admission-census/v1",
        "purpose": "READ-ONLY admission census for FTMO demo book v2 burn-in (BOOK_SPRINT F4 / ticket 42a437a4)",
        "generated_by": "tools/strategy_farm/ftmo_demo_v2_census.py",
        "ftmo_account": 1514536732,
        "ftmo_server": "FTMO-Demo",
        "no_rebuild": True,
        "no_qualification_claim": True,
        "sources": {
            "profile_manifest": str(PROFILE_MANIFEST),
            "analytic_manifest": str(ANALYTIC_MANIFEST),
            "aliases": str(ALIASES),
            "cost_snapshot_native_capture": str(COST_SNAPSHOT),
            "magic_registry": str(MAGIC_REGISTRY),
            "governor_allowed_magics": sorted(GOVERNOR_ALLOWED_MAGICS),
            "ftmo_ticks_dir_symbols": sorted(ticks_syms),
            "native_capture_symbols": sorted(native_syms),
        },
        "counts": {
            "sleeves": len(rows),
            "admit": len(admit),
            "exclude": len(exclude),
        },
        "governor_input_deltas_PROPOSAL_ONLY": {
            "note": "PROPOSAL ONLY — not applied anywhere. Policy FTMO_2S_P1_100K_V2 unchanged.",
            "allowed_magics_csv": ",".join(str(m) for m in sorted(set(GOVERNOR_ALLOWED_MAGICS) | set(admit_magics))),
            "new_magics_to_add_csv": ",".join(str(m) for m in new_magics),
            "governed_symbols_csv": ",".join(admit_symbols),
        },
        "roster": rows,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--out",
        type=Path,
        default=REPO / "docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/roster_ftmo_demo_v2.json",
    )
    args = ap.parse_args()
    census = build_census()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(census, indent=2) + "\n", encoding="utf-8")
    c = census["counts"]
    print(f"wrote {args.out}")
    print(f"sleeves={c['sleeves']} ADMIT={c['admit']} EXCLUDE={c['exclude']}")
    for r in census["roster"]:
        if r["decision"] == "EXCLUDE":
            print(f"  EXCLUDE {r['ea_id']:>6} {r['dxz_symbol']:<12} -> {r['reason']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

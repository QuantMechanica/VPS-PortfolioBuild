"""FTMO demo book v2 admission census (book sprint F4).

Decides ADMIT / EXCLUDE per DXZ v2 roster sleeve for a burn-in deployment on the
FTMO DEMO terminal (account 1514536732, server FTMO-Demo).

The census is strictly read-only:
  * it never starts terminal64.exe,
  * it never writes into the FTMO or T_Live data dirs,
  * it never recompiles an EA (a rebuilt .ex5 is a new identity),
  * it proposes governor input deltas but changes no governor policy.

Re-run with:
    python -X utf8 tools/strategy_farm/ftmo_demo_v2_census.py \
        --out-dir C:/QM/repo/docs/ops/evidence/2026-09-15_ftmo_demo_v2_census

Outputs roster_ftmo_demo_v2.json (schema documented in the README) and README.md.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

REPO = Path("C:/QM/repo")

ROSTER = Path(
    "D:/QM/reports/portfolio/dxz_v2_20260913/build_28_r11/"
    "analytic_preview_manifest_28_r11.json"
)
PROFILE_MANIFEST = Path(
    "C:/QM/deploy/DXZ_V2_20260913/profile/DarwinexZero_Book2_LiveOps/profile_manifest.json"
)
ALIASES = REPO / "framework/registry/execution_symbol_aliases_v1.json"

FTMO_DATA_DIR = Path(
    "C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/"
    "81A933A9AFC5DE3C23B15CAB19C63850"
)
FTMO_ATTACH_MAP = FTMO_DATA_DIR / "ftmo_demo_attach_map.json"
FTMO_CHART_DIR = FTMO_DATA_DIR / "MQL5/Profiles/Charts/Default"
FTMO_TICKS_DIR = FTMO_DATA_DIR / "bases/FTMO-Demo/ticks"
FTMO_HISTORY_DIR = FTMO_DATA_DIR / "bases/FTMO-Demo/history"

NATIVE_SNAPSHOT = REPO / "docs/ops/evidence/2026-09-06_ftmo_demo_install/terminal_snapshot.json"

BINARY_SEARCH_PATH = [
    ("T_Live", Path("C:/QM/mt5/T_Live/MT5_Base/MQL5/Experts/Live EAs")),
    ("deploy/eas", Path("C:/QM/deploy/DXZ_V2_20260913/eas")),
    ("repair_v2/eas", Path("C:/QM/deploy/DXZ_V2_20260913/repair_v2/eas")),
]

# The 8 magics the FTMO governor QM5_13206 (policy FTMO_2S_P1_100K_V2) allows today.
# Source: chart01.chr input allowed_magics_csv in FTMO_CHART_DIR.
GOVERNOR_ALLOWED_MAGICS_TODAY = [
    107060001,
    114210000,
    114220004,
    119100006,
    130540000,
    15370001,
    200480000,
    215050000,
]

# Symbol-slot inputs that must be overridden with a broker-native name before the
# EA can trade on a non-.DWX venue. Bound by source inspection (file:line recorded
# in the README). Empty list => the EA trades the chart symbol only.
SYMBOL_SLOT_INPUTS = {
    12778: [
        "strategy_leg_a_symbol",
        "strategy_leg_b_symbol",
        "strategy_conv_symbol_1",
        "strategy_conv_symbol_2",
    ],
    13117: [
        "strategy_leg_a_symbol",
        "strategy_leg_b_symbol",
        "strategy_conv_symbol_1",
        "strategy_conv_symbol_2",
    ],
    # 41470 compares via QM_MagicSymbolCanonical() on BOTH sides, so the .DWX
    # default still matches a bare chart symbol; it needs no override to trade.
    41470: [],
    # 1537 keys its sealed monthly-sleeve CSV by the logical .DWX name and
    # compares with ==, so strategy_calendar_symbol MUST stay the .DWX name.
    1537: [],
}

# Auxiliary (non-chart) symbols each symbol-slot EA additionally needs, expressed
# as logical .DWX names taken from the input defaults.
AUX_LOGICAL_SYMBOLS = {
    12778: ["AUDUSD.DWX", "EURJPY.DWX", "EURUSD.DWX", "EURAUD.DWX"],
    13117: ["EURGBP.DWX", "AUDJPY.DWX", "GBPUSD.DWX", "USDJPY.DWX"],
}

# EAs whose preset must pin an input to the logical .DWX name (not the broker name).
PRESET_MUST_PIN = {
    1537: {"strategy_calendar_symbol": "XAGUSD.DWX"},
}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path: Path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def chart_text(path: Path) -> str:
    """MT5 .chr files are UTF-16LE."""
    return path.read_bytes().decode("utf-16-le", errors="ignore")


def ftmo_terminal_inventory() -> dict:
    """Read-only evidence about which raw symbol names this terminal knows.

    symbols-<login>.dat is compressed and carries no plaintext names, so the
    inventory is assembled from directory names and the chart profile instead.
    """
    ticks = sorted(p.name for p in FTMO_TICKS_DIR.iterdir()) if FTMO_TICKS_DIR.is_dir() else []
    history = (
        sorted(p.name for p in FTMO_HISTORY_DIR.iterdir()) if FTMO_HISTORY_DIR.is_dir() else []
    )
    charts: list[str] = []
    if FTMO_CHART_DIR.is_dir():
        for chart in sorted(FTMO_CHART_DIR.glob("chart*.chr")):
            match = re.search(r"^symbol=(.+)$", chart_text(chart), re.MULTILINE)
            if match:
                charts.append(match.group(1).strip())
    attach: list[str] = []
    if FTMO_ATTACH_MAP.is_file():
        attach = [row[1] for row in read_json(FTMO_ATTACH_MAP) if len(row) > 1]
    native: list[str] = []
    if NATIVE_SNAPSHOT.is_file():
        native = [s["name"] for s in read_json(NATIVE_SNAPSHOT).get("symbols", [])]
    return {
        "ticks_dir": ticks,
        "history_dir": history,
        "chart_profile": sorted(set(charts)),
        "attach_map": sorted(set(attach)),
        "native_snapshot": sorted(set(native)),
    }


def attach_map_bindings() -> dict[int, str]:
    """magic -> FTMO raw symbol, from the terminal's own attach map.

    The attach map carries (slot, symbol, timeframe, expert, preset, magic). Because
    magic == ea_id*10000+slot is also what the DXZ roster assigns, a magic match
    binds a logical sleeve to the FTMO raw symbol that sleeve actually ran on.
    """
    if not FTMO_ATTACH_MAP.is_file():
        return {}
    out: dict[int, str] = {}
    for row in read_json(FTMO_ATTACH_MAP):
        if len(row) >= 6:
            out[int(row[5])] = str(row[1])
    return out


def build_symbol_map(inventory: dict, attach_by_magic: dict[int, str], roster) -> dict:
    """logical .DWX symbol -> {ftmo_symbol, symbol_source, evidence[]}."""
    alias_doc = read_json(ALIASES)
    alias_ftmo = {}
    for venue in alias_doc["venues"]:
        if venue["venue_id"] == "FTMO_TRIAL":
            alias_account = venue["account_id"]
            for row in venue["symbols"]:
                alias_ftmo[row["logical_symbol"]] = row["raw_symbol"]

    # Logical->raw pairs proven by the terminal's own attach map via magic identity.
    by_magic: dict[str, set[str]] = {}
    for sleeve in roster:
        raw = attach_by_magic.get(int(sleeve["magic"]))
        if raw:
            by_magic.setdefault(sleeve["symbol"], set()).add(raw)

    known_raw = set(inventory["ticks_dir"]) | set(inventory["history_dir"]) | set(
        inventory["chart_profile"]
    ) | set(inventory["attach_map"]) | set(inventory["native_snapshot"])

    logical_symbols = sorted({s["symbol"] for s in roster})
    for extra in AUX_LOGICAL_SYMBOLS.values():
        logical_symbols.extend(extra)
    logical_symbols = sorted(set(logical_symbols))

    out = {}
    for logical in logical_symbols:
        evidence = []
        raw = None
        source = None

        magic_bound = sorted(by_magic.get(logical, ()))
        if len(magic_bound) == 1:
            raw = magic_bound[0]
            source = "terminal attach map (magic-bound)"
            evidence.append(
                f"{FTMO_ATTACH_MAP.as_posix()} :: magic identity ea_id*10000+slot -> {raw}"
            )
        elif logical in alias_ftmo:
            raw = alias_ftmo[logical]
            source = f"alias table (FTMO_TRIAL acct {alias_account})"
            evidence.append(f"{ALIASES.as_posix()} :: FTMO_TRIAL {logical} -> {raw}")

        if raw is None:
            # Last resort: the bare base name, but only if the terminal has shown it.
            bare = logical.replace(".DWX", "")
            if bare in known_raw:
                raw = bare
                source = "terminal inventory (bare base name observed)"

        if raw is None:
            out[logical] = {
                "ftmo_symbol": "UNVERIFIED",
                "symbol_source": "unverified",
                "evidence": ["no alias row, no attach-map magic binding, not observed in terminal"],
                "observed_in_terminal": False,
            }
            continue

        if logical in alias_ftmo and alias_ftmo[logical] == raw and "alias" not in (source or ""):
            evidence.append(f"{ALIASES.as_posix()} :: corroborates {logical} -> {raw}")
        for label, key in (
            ("ticks dir", "ticks_dir"),
            ("history dir", "history_dir"),
            ("chart profile", "chart_profile"),
            ("native snapshot 2026-09-06", "native_snapshot"),
        ):
            if raw in inventory[key]:
                evidence.append(f"observed in {label}: {raw}")

        out[logical] = {
            "ftmo_symbol": raw,
            "symbol_source": source,
            "evidence": evidence,
            "observed_in_terminal": raw in known_raw,
        }
    return out


def symbol_handling_classes(ea_ids: set[int]) -> dict[int, dict]:
    """Classify each EA's symbol handling from the sanctioned source scanner."""
    out_path = Path(os.environ.get("TEMP", "C:/Windows/TEMP")) / "qm_sym_inventory_census.json"
    subprocess.run(
        [
            sys.executable,
            "-X",
            "utf8",
            str(REPO / "tools/strategy_farm/ea_symbol_literal_inventory.py"),
            "--repo-root",
            str(REPO),
            "--output",
            str(out_path),
        ],
        check=True,
        capture_output=True,
    )
    doc = read_json(out_path)
    by_id = {p["ea_id"]: p for p in doc["priority_candidates"]}

    literals_by_id: dict[int, list] = {}
    for finding in doc["findings"]:
        match = re.search(r"/QM5_(\d+)_", finding["path"])
        if not match or "_obsolete" in finding["path"]:
            continue
        literals_by_id.setdefault(int(match.group(1)), []).append(finding)

    out = {}
    for ea_id in sorted(ea_ids):
        scanned = by_id.get(ea_id)
        lits = literals_by_id.get(ea_id, [])
        slots = SYMBOL_SLOT_INPUTS.get(ea_id)
        trading_literals = [f for f in lits if f["classification"] == "trading_logic_literal"]

        if slots:
            cls = "symbol-input-slot"
            note = (
                "symbol slots are inputs (OWNER 2026-09-06 rule); the .DWX defaults are "
                "used verbatim for SymbolSelect/CopyClose, so an FTMO preset MUST override "
                f"all of: {', '.join(slots)}"
            )
        elif ea_id in PRESET_MUST_PIN:
            cls = "chart-symbol-only (preset-pinned logical symbol)"
            note = (
                "trades the chart symbol, but an internal sealed-CSV lookup is keyed by the "
                "logical .DWX name and compared with ==, so the preset MUST pin "
                + ", ".join(f"{k}={v}" for k, v in PRESET_MUST_PIN[ea_id].items())
            )
        elif slots == []:
            cls = "symbol-input-slot (canonical-compare, no override needed)"
            note = (
                "host symbol is an input but both sides go through QM_MagicSymbolCanonical(), "
                "so the .DWX default already matches a bare broker chart symbol"
            )
        elif trading_literals:
            cls = ".DWX-literal"
            note = "hardcoded symbol literal in trading logic"
        else:
            cls = "chart-symbol-only"
            note = "no symbol literals and no non-chart market-data access"

        out[ea_id] = {
            "symbol_handling_class": cls,
            "note": note,
            "scanner_classification": (scanned or {}).get("classification", "NOT_SCANNED"),
            "non_chart_market_data_calls": (scanned or {}).get("non_chart_market_data_calls"),
            "symbol_literal_findings": [
                {
                    "classification": f["classification"],
                    "severity": f["severity"],
                    "symbol": f["symbol"],
                    "at": f"{f['path']}:{f['line']}",
                }
                for f in lits
                if f["classification"] in ("trading_logic_literal", "symbol_input_default")
            ],
            "required_preset_overrides": slots or [],
            "required_preset_pins": PRESET_MUST_PIN.get(ea_id, {}),
        }
    return out


def news_compliance_capability(ea_id: int) -> dict:
    """mode 2 (qm_news_compliance) vs legacy mode 1 (qm_news_mode) - record only."""
    dirs = sorted(REPO.glob(f"framework/EAs/QM5_{ea_id}_*"))
    if not dirs:
        return {"capability": "UNKNOWN", "evidence": "no source dir"}
    source = dirs[0] / f"{dirs[0].name}.mq5"
    if not source.is_file():
        return {"capability": "UNKNOWN", "evidence": f"missing {source.as_posix()}"}
    text = source.read_text(encoding="utf-8", errors="ignore")
    if "qm_news_compliance" in text:
        return {
            "capability": "MODE_2_CAPABLE",
            "evidence": f"{source.as_posix()} declares qm_news_compliance",
        }
    if "qm_news_mode" in text:
        return {
            "capability": "MODE_1_LEGACY_ONLY",
            "evidence": f"{source.as_posix()} uses legacy qm_news_mode only",
        }
    return {"capability": "NO_NEWS_GATE_FOUND", "evidence": source.as_posix()}


def locate_binary(expert_name: str) -> dict:
    for tag, base in BINARY_SEARCH_PATH:
        candidate = base / f"{expert_name}.ex5"
        if candidate.is_file():
            return {
                "binary_path": candidate.as_posix(),
                "binary_source": tag,
                "binary_sha256": sha256_file(candidate),
            }
    return {"binary_path": None, "binary_source": "MISSING", "binary_sha256": None}


def build_census() -> dict:
    roster_doc = read_json(ROSTER)
    roster = roster_doc["sleeves"]
    profile = read_json(PROFILE_MANIFEST)
    charts = {
        (c["ea_id"], c["symbol"]): c
        for c in profile["charts"]
        if c.get("kind") != "monitor" and c.get("ea_id")
    }
    # 12969 is replaced by 41470; bind the roster sleeve to the replacement chart.
    replacements = {
        c["replaces_ea_id"]: c for c in profile["charts"] if c.get("replaces_ea_id")
    }

    inventory = ftmo_terminal_inventory()
    attach_by_magic = attach_map_bindings()
    symbol_map = build_symbol_map(inventory, attach_by_magic, roster)

    ea_ids = {int(s["ea_id"]) for s in roster} | set(replacements)
    ea_ids |= {int(c["ea_id"]) for c in replacements.values()}
    classes = symbol_handling_classes(ea_ids)

    rows = []
    for sleeve in roster:
        ea_id = int(sleeve["ea_id"])
        logical = sleeve["symbol"]
        bare = logical.replace(".DWX", "")

        chart = charts.get((ea_id, bare))
        effective_ea_id = ea_id
        replaced_by = None
        if ea_id in replacements:
            chart = replacements[ea_id]
            effective_ea_id = int(chart["ea_id"])
            replaced_by = effective_ea_id

        expert_name = chart["expert_name"] if chart else None
        binary = locate_binary(expert_name) if expert_name else {
            "binary_path": None,
            "binary_source": "MISSING",
            "binary_sha256": None,
        }

        cls = classes.get(effective_ea_id, {})
        news = news_compliance_capability(effective_ea_id)
        sym = symbol_map.get(logical, {})

        slot = int(chart["slot"]) if chart and chart.get("slot") is not None else None
        magic = int(chart["magic"]) if chart and chart.get("magic") is not None else int(
            sleeve["magic"]
        )
        magic_formula_ok = (
            slot is not None and magic == effective_ea_id * 10000 + slot
        )

        risk_percent = (
            sleeve["burn_in_risk_percent"]
            if sleeve.get("is_new_sleeve")
            else sleeve["weight_risk_percent"]
        )

        # --- admission decision -------------------------------------------------
        reasons = []
        decision = "ADMIT"

        if binary["binary_path"] is None:
            decision = "EXCLUDE"
            reasons.append(f"no deployable .ex5 found for {expert_name}")

        if sym.get("ftmo_symbol", "UNVERIFIED") == "UNVERIFIED":
            decision = "EXCLUDE"
            reasons.append(
                f"chart symbol {logical} has no verified FTMO name "
                f"({sym.get('evidence', ['no evidence'])[0]})"
            )

        if cls.get("symbol_handling_class") == ".DWX-literal":
            decision = "EXCLUDE"
            reasons.append("symbol handling class is .DWX-literal")

        # Symbol-slot EAs need every auxiliary symbol verified AND a preset override.
        for aux in AUX_LOGICAL_SYMBOLS.get(effective_ea_id, []):
            aux_binding = symbol_map.get(aux, {})
            if aux_binding.get("ftmo_symbol", "UNVERIFIED") == "UNVERIFIED":
                decision = "EXCLUDE"
                reasons.append(
                    f"auxiliary symbol {aux} (input slot) has no verified FTMO name"
                )
        if cls.get("required_preset_overrides"):
            preset = chart.get("preset") if chart else None
            has_override = False
            if preset and Path(preset).is_file():
                text = Path(preset).read_text(encoding="utf-8", errors="ignore")
                has_override = any(
                    re.search(rf"^{re.escape(name)}=", text, re.MULTILINE)
                    for name in cls["required_preset_overrides"]
                )
            if not has_override:
                if decision != "EXCLUDE":
                    decision = "EXCLUDE"
                reasons.append(
                    "DXZ v2 preset carries no symbol-slot override, so the EA would run "
                    "dark (SymbolSelect/CopyClose on .DWX names absent on FTMO): "
                    + (preset or "no preset")
                )

        if not magic_formula_ok:
            reasons.append(
                f"magic {magic} != ea_id*10000+slot ({effective_ea_id}*10000+{slot})"
            )

        if decision == "ADMIT" and not reasons:
            reasons.append("symbol verified, binary sha-bound, magic consistent")

        rows.append(
            {
                "ea_id": ea_id,
                "effective_ea_id": effective_ea_id,
                "replaced_by_ea_id": replaced_by,
                "ea_label": sleeve["ea_label"],
                "effective_ea_label": expert_name or sleeve["ea_label"],
                "dxz_symbol": logical,
                "ftmo_symbol": sym.get("ftmo_symbol", "UNVERIFIED"),
                "symbol_source": sym.get("symbol_source", "unverified"),
                "symbol_evidence": sym.get("evidence", []),
                "binary_path": binary["binary_path"],
                "binary_source": binary["binary_source"],
                "binary_sha256": binary["binary_sha256"],
                "symbol_handling_class": cls.get("symbol_handling_class", "UNKNOWN"),
                "symbol_handling_note": cls.get("note"),
                "symbol_literal_findings": cls.get("symbol_literal_findings", []),
                "required_preset_overrides": cls.get("required_preset_overrides", []),
                "required_preset_pins": cls.get("required_preset_pins", {}),
                "news_compliance_capability": news["capability"],
                "news_compliance_evidence": news["evidence"],
                "slot": slot,
                "magic": magic,
                "magic_formula_ok": magic_formula_ok,
                "risk_percent": round(float(risk_percent), 6),
                "risk_basis": "burn_in_risk_percent" if sleeve.get("is_new_sleeve") else "weight_risk_percent",
                "already_live_dxz": bool(sleeve.get("already_live")),
                "decision": decision,
                "reason": "; ".join(reasons),
            }
        )

    # --- magic collision analysis ---------------------------------------------
    seen: dict[int, list[str]] = {}
    for row in rows:
        seen.setdefault(row["magic"], []).append(f"{row['effective_ea_label']}@{row['dxz_symbol']}")
    for row in rows:
        holders = seen[row["magic"]]
        in_governor = row["magic"] in GOVERNOR_ALLOWED_MAGICS_TODAY
        row["magic_collision"] = len(holders) > 1
        row["magic_collision_detail"] = (
            f"shared with {holders}" if len(holders) > 1 else "unique within roster"
        )
        row["already_allowed_by_governor"] = in_governor

    admitted = [r for r in rows if r["decision"] == "ADMIT"]

    # --- governor input deltas (PROPOSAL ONLY) --------------------------------
    proposed_magics = sorted({r["magic"] for r in admitted})
    proposed_symbols = sorted({r["ftmo_symbol"] for r in admitted})
    retained = sorted(set(GOVERNOR_ALLOWED_MAGICS_TODAY) - set(proposed_magics))

    return {
        "schema": "qm.ftmo-demo-v2-admission-census/v1",
        "generated_by": "tools/strategy_farm/ftmo_demo_v2_census.py",
        "ticket": "42a437a4-9674-47ce-9ca9-80eba8a2bc91 (book sprint F4)",
        "target_account": {
            "login": 1514536732,
            "server": "FTMO-Demo",
            "data_dir": FTMO_DATA_DIR.as_posix(),
            "governor": "QM5_13206 policy FTMO_2S_P1_100K_V2 (UNCHANGED by this census)",
        },
        "inputs": {
            "roster": ROSTER.as_posix(),
            "roster_sha256": sha256_file(ROSTER),
            "profile_manifest": PROFILE_MANIFEST.as_posix(),
            "profile_manifest_sha256": sha256_file(PROFILE_MANIFEST),
            "aliases": ALIASES.as_posix(),
            "aliases_sha256": sha256_file(ALIASES),
            "attach_map": FTMO_ATTACH_MAP.as_posix(),
            "attach_map_sha256": sha256_file(FTMO_ATTACH_MAP) if FTMO_ATTACH_MAP.is_file() else None,
        },
        "ftmo_terminal_inventory": inventory,
        "symbol_map": symbol_map,
        "counts": {
            "sleeves": len(rows),
            "admit": len(admitted),
            "exclude": len(rows) - len(admitted),
        },
        "governor_input_delta_PROPOSAL": {
            "status": "PROPOSAL ONLY - not applied, governor policy untouched",
            "allowed_magics_csv_today": ",".join(str(m) for m in GOVERNOR_ALLOWED_MAGICS_TODAY),
            "allowed_magics_csv_proposed": ",".join(str(m) for m in proposed_magics),
            "governed_symbols_csv_proposed": ",".join(proposed_symbols),
            "magics_retained_from_today_not_in_roster": retained,
            "note": (
                "The proposed allowed_magics_csv covers ADMITted roster sleeves only. "
                "Magics listed in magics_retained_from_today_not_in_roster belong to the "
                "current 8-sleeve demo book and must be unioned in if those sleeves stay."
            ),
        },
        "roster": rows,
    }


def render_readme(census: dict) -> str:
    rows = census["roster"]
    admit = [r for r in rows if r["decision"] == "ADMIT"]
    exclude = [r for r in rows if r["decision"] == "EXCLUDE"]
    lines = []
    add = lines.append

    add("# FTMO demo book v2 - admission census (book sprint F4)")
    add("")
    add(f"Ticket: `{census['ticket']}`")
    add("")
    add(
        f"Target: FTMO DEMO account **{census['target_account']['login']}** "
        f"({census['target_account']['server']}), governor "
        f"{census['target_account']['governor']}."
    )
    add("")
    add(
        f"**{census['counts']['admit']} ADMIT / {census['counts']['exclude']} EXCLUDE** "
        f"of {census['counts']['sleeves']} DXZ v2 roster sleeves."
    )
    add("")
    add("Read-only census: no terminal started, no FTMO/T_Live data-dir write, no recompile,")
    add("no governor policy change. Governor input deltas below are a **proposal**.")
    add("")

    add("## Schema (roster_ftmo_demo_v2.json)")
    add("")
    add("`roster[]` - one row per roster sleeve:")
    add("")
    for field, desc in [
        ("ea_id / effective_ea_id / replaced_by_ea_id", "roster id; id actually deployed (12969 -> 41470)"),
        ("dxz_symbol / ftmo_symbol", "logical .DWX name; FTMO raw name or `UNVERIFIED`"),
        ("symbol_source / symbol_evidence", "how the FTMO name was bound, with evidence paths"),
        ("binary_path / binary_source / binary_sha256", "the exact .ex5 that would be deployed"),
        ("symbol_handling_class", "chart-symbol-only / symbol-input-slot / .DWX-literal"),
        ("required_preset_overrides / required_preset_pins", "preset work needed before deploy"),
        ("news_compliance_capability", "MODE_2_CAPABLE or MODE_1_LEGACY_ONLY (recorded, not excluding)"),
        ("slot / magic / magic_formula_ok / magic_collision", "magic = ea_id*10000+slot and collision state"),
        ("risk_percent / risk_basis", "DXZ v2 per-sleeve weight"),
        ("decision / reason", "ADMIT or EXCLUDE with evidence-bound reason"),
    ]:
        add(f"- `{field}` - {desc}")
    add("")

    add("## ADMIT")
    add("")
    add("| ea | FTMO symbol | class | magic | risk % | news | binary sha256 (12) |")
    add("|---|---|---|---|---|---|---|")
    for r in sorted(admit, key=lambda x: x["ea_id"]):
        sha = (r["binary_sha256"] or "")[:12]
        add(
            f"| {r['effective_ea_id']} {r['effective_ea_label']} | {r['ftmo_symbol']} | "
            f"{r['symbol_handling_class']} | {r['magic']} | {r['risk_percent']} | "
            f"{r['news_compliance_capability']} | `{sha}` |"
        )
    add("")

    add("## EXCLUDE")
    add("")
    add("| ea | dxz symbol | reason |")
    add("|---|---|---|")
    for r in sorted(exclude, key=lambda x: x["ea_id"]):
        add(f"| {r['effective_ea_id']} {r['effective_ea_label']} | {r['dxz_symbol']} | {r['reason']} |")
    add("")

    add("## Symbol bindings")
    add("")
    add("| logical | FTMO raw | source |")
    add("|---|---|---|")
    for logical, info in sorted(census["symbol_map"].items()):
        add(f"| {logical} | {info['ftmo_symbol']} | {info['symbol_source']} |")
    add("")

    add("## Magic collision check")
    add("")
    collisions = [r for r in rows if r["magic_collision"]]
    if collisions:
        for r in collisions:
            add(f"- **COLLISION** magic {r['magic']}: {r['magic_collision_detail']}")
    else:
        add("- No magic is shared by two roster sleeves (all 28 unique).")
    delta = census["governor_input_delta_PROPOSAL"]
    retained = set(delta["magics_retained_from_today_not_in_roster"])
    overlap = retained & {r["magic"] for r in rows}
    add(
        f"- Roster magics vs the {len(retained)} current demo-book magics that are not in the "
        f"roster: {'COLLISION ' + str(sorted(overlap)) if overlap else 'no overlap'}."
    )
    add(
        "- All ADMIT rows satisfy `magic == ea_id*10000 + slot`: "
        + ("yes" if all(r["magic_formula_ok"] for r in admit) else "NO - see roster[].magic_formula_ok")
    )
    add("")

    add("## Evidence caveats / residual risk")
    add("")
    add(
        "1. **Alias-table rows are bound to a different account.** "
        "`execution_symbol_aliases_v1.json` declares "
        "`matching: EXACT_CASE_SENSITIVE_VENUE_ACCOUNT_SERVER_RAW_SYMBOL` and its `FTMO_TRIAL` "
        "venue is account **1513845506**, not the target **1514536732**. Same server "
        "(FTMO-Demo), so the raw names are expected to be identical, but the registry does not "
        "formally cover this account. Affected: USDJPY, WS30->US30.cash, XTIUSD->USOIL.cash."
    )
    add(
        "2. **`US30.cash` was never observed in the target terminal.** It appears in no tick dir, "
        "history dir, chart profile, attach map or native snapshot - only in the alias table "
        "(see 1). EA 9641 is ADMITted on that binding alone; confirm the name in Market Watch "
        "before deploying it."
    )
    add(
        "3. **Symbol-handling class is derived from source, not from the binary.** The deployed "
        "`.ex5` files are compressed and expose no readable string constants, so no literal can "
        "be read back out of the binary. Classification comes from the sanctioned source scanner "
        "at the current `C:/QM/repo` HEAD; it assumes each `.ex5` was built from the source now "
        "in the tree. Binaries are sha256-bound in `roster[].binary_sha256` so the assumption is "
        "auditable, but it is an assumption."
    )
    add(
        "4. **EA 1537 only works if the preset pins the logical name.** "
        "`QM1537_HostSymbol()` returns `_Symbol` when `strategy_calendar_symbol` is empty, and "
        "the sealed monthly-sleeve CSV is keyed by `XAGUSD.DWX` and compared with `==` "
        "(`QM5_1537_MonthlySleeveCalendar.mqh:289` and `:312`). With a bare `XAGUSD` chart and an "
        "empty input, every calendar row is skipped and the bundle-SHA guard never fires. The "
        "current FTMO chart08 and the DXZ v2 preset both set `strategy_calendar_symbol=XAGUSD.DWX`, "
        "so this is satisfied today - it must not be dropped."
    )
    add(
        "5. **EA 1567 predates the news-compliance contract.** It exposes only the legacy "
        "`qm_news_mode` (`QM_NEWS_PAUSE`) and has no `qm_news_compliance` input, so it cannot be "
        "driven to FTMO news mode 2. Recorded, not excluded (demo burn-in), per the ticket."
    )
    add(
        "6. **Ticket premise correction: 12778 and 13117 are not `.DWX`-literal EAs.** Both carry "
        "proper per-slot symbol *inputs* under the OWNER 2026-09-06 rule "
        "(`QM5_13117_eurgbp-audjpy.mq5:50-53`, "
        "`QM5_12778_edgelab-audusd-eurjpy-cointegration.mq5:90-93`); the `.DWX` strings are input "
        "*defaults*, and the source comment states presets are expected to override them with "
        "bare broker names. They are dark on FTMO only because the DXZ v2 presets set no symbol "
        "overrides at all (verified: those `.set` files contain `RISK_*` and nothing else). They "
        "become admissible once EURGBP / EURJPY / EURAUD have verified FTMO names **and** the "
        "preset overrides every slot - the exclusion is a preset+symbol gap, not a code defect."
    )
    add("")

    add("## Governor input delta (PROPOSAL - not applied)")
    add("")
    add(f"- today  `allowed_magics_csv={delta['allowed_magics_csv_today']}`")
    add(f"- proposed `allowed_magics_csv={delta['allowed_magics_csv_proposed']}`")
    add(f"- proposed `governed_symbols_csv={delta['governed_symbols_csv_proposed']}`")
    add(f"- retained-from-today (current demo book, not in roster): {delta['magics_retained_from_today_not_in_roster']}")
    add("")
    add(f"> {delta['note']}")
    add("")

    add("## Inputs (sha256-bound)")
    add("")
    for key, value in census["inputs"].items():
        add(f"- `{key}`: {value}")
    add("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out-dir",
        default="C:/QM/repo/docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/slot3_reconciliation",
    )
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    census = build_census()
    (out_dir / "roster_ftmo_demo_v2.json").write_text(
        json.dumps(census, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    (out_dir / "README.md").write_text(render_readme(census), encoding="utf-8")

    print(
        f"ADMIT={census['counts']['admit']} EXCLUDE={census['counts']['exclude']} "
        f"-> {out_dir.as_posix()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

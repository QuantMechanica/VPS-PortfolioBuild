"""FTMO demo book v2 admission census (READ-ONLY, re-runnable) — slot-1 v2 rework.

WHY THIS FILE LIVES HERE AND NOT IN tools/strategy_farm/
--------------------------------------------------------
Two headless Claude orchestration sessions (slots 1 and 3 of the same
`run_agent_orchestration_task.py --agent claude --max-sessions 3` fan-out) were
both handed ticket 42a437a4 by the generic session prompt and both reworked
`tools/strategy_farm/ftmo_demo_v2_census.py` at the same time. The sibling
session's version landed on the shared tool path at 2026-09-15 11:59 local and
its JSON landed on the shared artifact name at 12:00.

Rather than overwrite the sibling (the mirror image of the same defect), this
slot-1 version is preserved intact under the evidence dir and writes ONLY into
`slot1_census_v2/`, so neither session's artifact can clobber the other's.
See `COLLISION.md` next to this file. Nothing here is committed.

Purpose
-------
Book sprint BOOK_SPRINT_2026-09-20.md item F4 / ticket 42a437a4. Decide
ADMIT / ADMIT_CONDITIONAL / EXCLUDE per DXZ v2 roster sleeve for a *burn-in*
deployment on the FTMO **demo** terminal (account 1514536732), reusing the exact
same sha256-identified DXZ binaries. No rebuild, no qualification claim, no gate
change.

Binding due date: **Wed 2026-09-16 18:00Z** (ticket 42a437a4 title). The sprint
file F4 line says Fri 2026-09-18; the ticket date is the binding one and the
sprint file is the looser downstream schedule (the v1 README said 09-17, which
was wrong and is corrected here). [F8]

Hard limits honoured by this script
-----------------------------------
* Read-only. It never starts terminal64.exe, never writes into any FTMO /
  T_Live data dir, never recompiles an EA, never attaches a chart, never
  touches a governor policy. Reads of the FTMO data dir are opens for read only.
* The only artifacts it writes are the census JSON and the FTMO symbol-source
  probe JSON under this directory.

v2 rework (critique receipt critique_42a437a4_20260915T085204Z, F1..F11)
------------------------------------------------------------------------
F1/F7  Per-row binary-vintage predicate against the two documented FTMO
       compatibility fixes (4fb47bd3b5 magic-resolver base-name tolerance,
       dcaeca68f5 QM5_1537 strategy_calendar_symbol input). A binary whose
       mtime predates the fix cannot contain it -> ADMIT_CONDITIONAL
       (blocked_on_resolver_rebuild). No prose exemption.
F2     A governor magic already held on the RUNNING demo (AutoTrading ON) by a
       binary with a DIFFERENT sha256 counts as magic_collision=true unless the
       deploy plan detaches that chart first. The detach is emitted as an
       explicit deploy precondition, never assumed.
F3     The brief's rule ".DWX literal = EXCLUDE" is implemented here: every
       trading_logic_literal with severity FAIL excludes; severity WARN excludes
       unless the (ea_label, path) is on LITERAL_INPUT_EXEMPTIONS *and* the
       bound binary postdates the commit that added the governing input.
F4     allowed_magics_csv and governed_symbols_csv are derived from the SAME
       row set, so magic coverage and symbol coverage cannot drift apart.
F5     The FTMO_TRIAL alias venue is bound to account 1513845506, not to the
       census target 1514536732, and the registry's own matching rule is
       EXACT_CASE_SENSITIVE_VENUE_ACCOUNT_SERVER_RAW_SYMBOL with
       cross_venue_pooling_for_qualification=false. Alias hits are therefore
       recorded as cross-account and must be corroborated on THIS account
       (ticks/history dir or terminal log) before they count as verified.
F6     The FTMO symbol inventory is probed for real: bases/FTMO-Demo/symbols/
       (symbols.raw does not exist on this build; symbols-<login>.dat is not
       plaintext — the printable-token scan is written to the probe JSON), the
       ticks and history dirs, and all terminal + Experts logs.
F10    The 8 currently-governed magics are PARSED from the governor manifest
       table instead of hardcoded behind a pointer that does not contain them.
F11    symbol_handling_class is a source-file scan heuristic over the tip .mq5,
       not a property read out of the bound .ex5. Recorded as such per row.

What it determines per sleeve (a..e of the census brief)
--------------------------------------------------------
(a) FTMO symbol name + provenance and per-account corroboration.
(b) EA symbol-handling class + blocking .DWX literal decision.
(c) News-compliance capability. Recorded, never an exclude reason (demo burn-in).
(d) magic = ea_id*10000+slot; collision vs the governor's live magics and the
    registry; plus the resolver preconditions that decide whether the magic can
    resolve at all on a broker-named chart.
(e) RISK_PERCENT re-derived for EVERY row and reconciled against the profile.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
FTMO_DATADIR = Path(
    "C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/"
    "81A933A9AFC5DE3C23B15CAB19C63850"
)
FTMO_ACCOUNT = 1514536732
FTMO_SERVER = "FTMO-Demo"

PROFILE_MANIFEST = Path(
    "C:/QM/deploy/DXZ_V2_20260913/profile/DarwinexZero_Book2_LiveOps/profile_manifest.json"
)
ANALYTIC_MANIFEST = Path(
    "D:/QM/reports/portfolio/dxz_v2_20260913/build_28_r11/"
    "analytic_preview_manifest_28_r11.json"
)
ALIASES = REPO / "framework/registry/execution_symbol_aliases_v1.json"
COST_SNAPSHOT = (
    REPO / "docs/ops/evidence/2026-09-14_ftmo_book_v2/ftmo_book_symbol_cost_snapshot_v2.json"
)
MAGIC_REGISTRY = REPO / "framework/registry/magic_numbers.csv"
INVENTORY_TOOL = REPO / "tools/strategy_farm/ea_symbol_literal_inventory.py"
# F10: the 8 governed magics and the deployed-hash reconciliation live in THIS
# file (the 2026-09-06_ftmo_demo_governor/ directory holds only the compile probe).
GOVERNOR_MANIFEST = REPO / "docs/ops/evidence/2026-09-06_ftmo_demo_governor_manifest.md"

TLIVE_EAS = Path("C:/QM/mt5/T_Live/MT5_Base/MQL5/Experts/Live EAs")
DEPLOY_EAS = Path("C:/QM/deploy/DXZ_V2_20260913/eas")
REPAIR_EAS = Path("C:/QM/deploy/DXZ_V2_20260913/repair_v2/eas")

# --- F1/F7: the two documented FTMO-compatibility fixes -----------------------
# A binary compiled before a fix cannot contain it. Commit timestamps are the
# authoring times reported by `git log --date=iso`, normalised to UTC.
FIX_MAGIC_RESOLVER = {
    "commit": "4fb47bd3b5d744aeb544225414b4002c01e77a0c",
    "utc": "2026-09-06T19:56:06+00:00",
    "what": "QM_MagicResolver.mqh suffix-tolerant base-name compare "
            "(registry EURUSD.DWX vs broker EURUSD)",
    "observed_failure_without_it": "EA_MAGIC_RESOLUTION_FAILED -> FRAMEWORK_INIT_FAILED "
                                   "(FTMO demo Experts log 20260906.log, 3 sleeves)",
}
FIX_1537_CALENDAR_INPUT = {
    "commit": "dcaeca68f58324c1d083c99c031aa1992469c5dc",
    "utc": "2026-09-06T20:03:01+00:00",
    "what": "QM5_1537 strategy_calendar_symbol input (calendar host-symbol name)",
    "observed_failure_without_it": "SLEEVE_CALENDAR_INIT_FAILED on FTMO demo 2026-09-06",
}

# F3: the ONLY exemptions from the ".DWX literal = EXCLUDE" rule, as code, each
# tied to the input that neutralises the literal and to the commit that added it.
# A row only earns the exemption when its bound binary postdates that commit.
LITERAL_INPUT_EXEMPTIONS = {
    (
        "QM5_1537_aa-vol-sma10",
        "framework/EAs/QM5_1537_aa-vol-sma10/QM5_1537_MonthlySleeveCalendar.mqh",
    ): {
        "governing_input": "strategy_calendar_symbol",
        "input_added_by": FIX_1537_CALENDAR_INPUT["commit"],
        "input_added_utc": FIX_1537_CALENDAR_INPUT["utc"],
        "why": "calendar host-symbol default; the input overrides it with the "
               "registry name, so the literal is not a trading-logic symbol pin",
    },
}

# Sleeves flagged dark no-ops in v2 (NOT_EQUIVALENT rebuilds) —
# BOOK_SPRINT_2026-09-20.md item D7.
DARK_NOOP_EA_IDS = {12778, 13117}


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def mtime_utc(path: Path) -> str:
    return dt.datetime.fromtimestamp(path.stat().st_mtime, dt.UTC).isoformat(timespec="seconds")


def magic_symbol_canonical(symbol: str) -> str:
    """Python port of QM_MagicSymbolCanonical (QM_MagicResolver.mqh:134).

    Keep in lockstep with the .mqh: base name before the first '.', plus the one
    explicit broker alias USOIL -> XTIUSD. Anything else fails closed, which is
    why index sleeves (GDAXI.DWX vs GER40.cash) cannot resolve even after a
    rebuild — they need a registry re-symbol, not a recompile.
    """
    dot = symbol.find(".")
    base = symbol[:dot] if dot > 0 else symbol
    return "XTIUSD" if base == "USOIL" else base


def read_utf16_log(path: Path) -> str:
    return path.read_bytes().decode("utf-16-le", errors="ignore")


# ---------------------------------------------------------------------------
# F10: parse the governed magics + deployed shas out of the governor manifest
# ---------------------------------------------------------------------------
def governor_state(manifest: Path) -> dict:
    """Parse the governed sleeve roster and the deployed-hash addendum.

    Returns {magic: {ea_id, sealed_sha256, deployed_sha256, chart}} plus the
    RUNNING / AutoTrading claim so the caller never has to hardcode the 8 magics.
    """
    text = manifest.read_text(encoding="utf-8")
    sealed: dict[int, dict] = {}
    # | QM5_10706 | GBPUSD H1 | 107060001 | `sha` | `preset` | `halt` |
    row = re.compile(
        r"^\|\s*QM5_(\d+)\s*\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|\s*`([0-9a-f]{64})`", re.M
    )
    for m in row.finditer(text):
        sealed[int(m.group(3))] = {
            "ea_id": int(m.group(1)),
            "native_chart": m.group(2).strip(),
            "sealed_sha256": m.group(4),
        }
    # addendum: | `chart02` / QM5_10706 | `deployedsha` | ...
    dep = re.compile(
        r"^\|\s*`(chart\d+)`\s*/\s*QM5_(\d+)\s*\|\s*`([0-9a-f]{64})`", re.M
    )
    deployed_by_ea: dict[int, dict] = {}
    for m in dep.finditer(text):
        deployed_by_ea[int(m.group(2))] = {
            "chart": m.group(1),
            "deployed_sha256": m.group(3),
        }
    for magic, info in sealed.items():
        d = deployed_by_ea.get(info["ea_id"])
        info["deployed_sha256"] = d["deployed_sha256"] if d else info["sealed_sha256"]
        info["deployed_chart"] = d["chart"] if d else None
        info["deployed_differs_from_sealed"] = info["deployed_sha256"] != info["sealed_sha256"]
    running = "RUNNING (AutoTrading ON by OWNER)" in text
    return {
        "source": str(manifest),
        "running_autotrading_on": running,
        "magics": sealed,
    }


# ---------------------------------------------------------------------------
# F6: probe the FTMO terminal's own symbol inventory, for real
# ---------------------------------------------------------------------------
PROBE_NAMES = (
    "US500", "SP500", "NGAS", "XNGUSD", "EURGBP", "US30", "GER40", "US100",
    "USOIL", "XAUUSD", "XAGUSD",
)


def ftmo_symbol_probe() -> dict:
    """Read-only inventory probe of the FTMO demo terminal.

    Three independent sources, each recorded with its result — including the
    negative ones, so a later reader can tell "not found" from "not looked for".
    """
    base = FTMO_DATADIR / "bases" / FTMO_SERVER
    ticks_dir = base / "ticks"
    hist_dir = base / "history"
    sym_dir = base / "symbols"

    ticks = sorted(p.name for p in ticks_dir.iterdir() if p.is_dir()) if ticks_dir.is_dir() else []
    hist = sorted(p.name for p in hist_dir.iterdir() if p.is_dir()) if hist_dir.is_dir() else []

    # symbols.raw (the name the brief expected) vs what this MT5 build writes.
    symbols_raw = sym_dir / "symbols.raw"
    sym_files = sorted(p.name for p in sym_dir.iterdir()) if sym_dir.is_dir() else []
    account_db = sym_dir / f"symbols-{FTMO_ACCOUNT}.dat"
    db_probe: dict = {
        "path": str(account_db),
        "exists": account_db.is_file(),
        "plaintext_symbol_names": False,
    }
    if account_db.is_file():
        blob = account_db.read_bytes()
        tokens = {m.decode("ascii") for m in re.findall(rb"[A-Za-z0-9._#\-]{3,24}", blob)}
        hits = sorted(t for t in tokens if any(t.startswith(n) for n in PROBE_NAMES))
        db_probe.update({
            "bytes": len(blob),
            "printable_tokens": len(tokens),
            "probe_name_hits": hits,
            "plaintext_symbol_names": bool(hits),
            "note": "no probe name occurs as a printable token -> the file is not "
                    "plaintext on this build; absence here is NOT evidence that a "
                    "symbol is missing from the broker's list",
        })

    # terminal journal + Experts logs
    log_files = sorted((FTMO_DATADIR / "logs").glob("*.log")) + sorted(
        (FTMO_DATADIR / "MQL5" / "Logs").glob("*.log")
    )
    pat = re.compile("(" + "|".join(PROBE_NAMES) + r")[A-Za-z0-9._]*")
    log_hits: dict[str, int] = {}
    for f in log_files:
        for m in pat.finditer(read_utf16_log(f)):
            log_hits[m.group(0)] = log_hits.get(m.group(0), 0) + 1

    return {
        "account": FTMO_ACCOUNT,
        "server": FTMO_SERVER,
        "ticks_dir": {"path": str(ticks_dir), "symbols": ticks},
        "history_dir": {"path": str(hist_dir), "symbols": hist},
        "symbols_dir": {
            "path": str(sym_dir),
            "files": sym_files,
            "symbols_raw_exists": symbols_raw.is_file(),
            "account_symbol_db": db_probe,
        },
        "logs": {
            "files_scanned": len(log_files),
            "encoding": "utf-16-le",
            "probe_name_occurrences": dict(sorted(log_hits.items())),
        },
    }


def ftmo_alias_rows(aliases: dict) -> tuple[dict[str, str], dict]:
    """logical .DWX symbol -> FTMO raw symbol, plus the venue binding (F5)."""
    out: dict[str, str] = {}
    venue_meta: dict = {}
    for venue in aliases.get("venues", []):
        if venue.get("venue_id") == "FTMO_TRIAL":
            venue_meta = {
                "venue_id": venue.get("venue_id"),
                "account_id": venue.get("account_id"),
                "server": venue.get("server"),
            }
            for sym in venue.get("symbols", []):
                out[sym["logical_symbol"]] = sym["raw_symbol"]
    venue_meta["matching"] = aliases.get("matching")
    venue_meta["cross_venue_pooling_for_qualification"] = aliases.get(
        "cross_venue_pooling_for_qualification"
    )
    venue_meta["binds_census_target_account"] = venue_meta.get("account_id") == FTMO_ACCOUNT
    return out, venue_meta


def native_captured_symbols(cost_snapshot: dict) -> set[str]:
    src = cost_snapshot.get("sources", {}).get("native_swap_contract_2026_09_06", {})
    return set(src.get("symbols_covered_native", []))


def resolve_ftmo_symbol(
    dwx_symbol: str,
    alias_map: dict[str, str],
    native_syms: set[str],
    probe: dict,
) -> dict:
    """Return the FTMO raw symbol, its source, and per-account corroboration (F5/F6).

    An alias hit alone is cross-account (venue 1513845506). It only counts as
    verified once the same raw name is corroborated ON account 1514536732 by the
    ticks dir, the history dir, or a terminal log line.
    """
    ticks = set(probe["ticks_dir"]["symbols"])
    hist = set(probe["history_dir"]["symbols"])
    logs = set(probe["logs"]["probe_name_occurrences"])
    base = dwx_symbol.replace(".DWX", "")

    candidate = ""
    source = "unverified"
    if dwx_symbol in alias_map:
        candidate, source = alias_map[dwx_symbol], "alias_registry_FTMO_TRIAL_cross_account"
    elif base in native_syms:
        candidate, source = base, "native_capture_2026-09-06"
    elif base in ticks:
        candidate, source = base, f"ftmo_ticks_dir_{FTMO_ACCOUNT}"
    elif f"{base}.cash" in ticks:
        candidate, source = f"{base}.cash", f"ftmo_ticks_dir_{FTMO_ACCOUNT}"

    if not candidate:
        return {
            "ftmo_symbol": "UNVERIFIED",
            "symbol_source": "unverified",
            "on_account_corroboration": [],
            "symbol_verified_on_target_account": False,
        }

    corro = []
    if candidate in ticks:
        corro.append("ticks_dir")
    if candidate in hist:
        corro.append("history_dir")
    if candidate in logs:
        corro.append("terminal_log")
    return {
        "ftmo_symbol": candidate,
        "symbol_source": source,
        "on_account_corroboration": corro,
        "symbol_verified_on_target_account": bool(corro),
    }


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
    """Source-scan heuristic over the tip .mq5 (F11 — NOT a property of the .ex5)."""
    proc = subprocess.run(
        [sys.executable, "-X", "utf8", str(INVENTORY_TOOL), "--ea-label", ea_label],
        capture_output=True, text=True, cwd=str(REPO),
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return {"class": "UNKNOWN", "detail": "inventory_tool_failed",
                "trading_logic_literals": [], "symbol_input_defaults": 0,
                "multi_symbol_access": False}
    data = json.loads(proc.stdout)
    findings = data.get("findings", [])
    trade_literals = [f for f in findings if f["classification"] == "trading_logic_literal"]
    input_defaults = [f for f in findings if f["classification"] == "symbol_input_default"]
    multi = bool(data.get("multi_symbol_sources"))
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
        "classifier": "tools/strategy_farm/ea_symbol_literal_inventory.py over the tip "
                      ".mq5/.mqh sources; a heuristic about SOURCE, not about the bound .ex5",
        "trading_logic_literals": [
            {"path": f["path"], "line": f["line"], "symbol": f["symbol"],
             "severity": f["severity"]}
            for f in trade_literals
        ],
        "symbol_input_defaults": len(input_defaults),
        "multi_symbol_access": multi,
    }


def literal_decision(ea_label: str, handling: dict, binary_mtime: str | None) -> dict:
    """F3: implement '.DWX literal = EXCLUDE' with an explicit, code-level allowlist."""
    blocking: list[dict] = []
    exempted: list[dict] = []
    for lit in handling.get("trading_logic_literals", []):
        key = (ea_label, lit["path"])
        exemption = LITERAL_INPUT_EXEMPTIONS.get(key)
        if lit["severity"] == "FAIL" or exemption is None:
            blocking.append({**lit, "why": "trading-logic .DWX literal with no governing input"})
            continue
        # WARN + an allowlisted governing input: the binary must postdate the
        # commit that added that input, otherwise the exemption is fiction.
        if binary_mtime is None or binary_mtime < exemption["input_added_utc"]:
            blocking.append({
                **lit,
                "why": f"governing input {exemption['governing_input']} was added by "
                       f"{exemption['input_added_by']} at {exemption['input_added_utc']}; "
                       f"the bound binary (mtime {binary_mtime}) predates it, so the "
                       f"literal is NOT neutralised in this artifact",
            })
        else:
            exempted.append({**lit, "exemption": exemption})
    return {"blocking_literals": blocking, "exempted_literals": exempted}


def news_capability(ea_label: str) -> dict:
    mq = REPO / "framework/EAs" / ea_label / f"{ea_label}.mq5"
    if not mq.is_file():
        return {"capability": "SOURCE_MISSING", "compliance_input": False}
    text = mq.read_text(encoding="utf-8", errors="replace")
    has_input = "input QM_NewsComplianceProfile qm_news_compliance" in text
    has_legacy = "qm_news_mode_legacy" in text
    if has_input:
        cap = "FTMO_MODE2_SELECTABLE"
    elif has_legacy:
        cap = "LEGACY_ONLY_MODE1"
    else:
        cap = "NO_NEWS_INPUT"
    return {
        "capability": cap,
        "compliance_input": has_input,
        "legacy_input": has_legacy,
        "derived_from": "tip .mq5 source, not the bound .ex5",
    }


def resolve_binary(expert_name: str) -> tuple[str, str]:
    for base, tag in (
        (TLIVE_EAS, "T_Live"), (DEPLOY_EAS, "deploy_staging"), (REPAIR_EAS, "repair_v2")
    ):
        cand = base / f"{expert_name}.ex5"
        if cand.is_file():
            return str(cand), tag
    return "", "MISSING"


# ---------------------------------------------------------------------------
# census
# ---------------------------------------------------------------------------
def build_census(probe: dict) -> dict:
    profile = load_json(PROFILE_MANIFEST)
    analytic = load_json(ANALYTIC_MANIFEST)
    aliases = load_json(ALIASES)
    cost = load_json(COST_SNAPSHOT)

    alias_map, alias_venue = ftmo_alias_rows(aliases)
    native_syms = native_captured_symbols(cost)
    reg = registry_by_magic(MAGIC_REGISTRY)
    gov = governor_state(GOVERNOR_MANIFEST)

    analytic_by_key = {(s["ea_id"], s["symbol"]): s for s in analytic["sleeves"]}

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

        sym = resolve_ftmo_symbol(dwx_symbol, alias_map, native_syms, probe)

        bin_path, bin_loc = resolve_binary(expert_name)
        bin_sha = sha256_file(Path(bin_path)) if bin_path else ""
        bin_mtime = mtime_utc(Path(bin_path)) if bin_path else None

        handling = classify_symbol_handling(expert_name)
        literals = literal_decision(expert_name, handling, bin_mtime)
        news = news_capability(expert_name)

        # --- (d) magic + the resolver preconditions -------------------------
        formula_ok = magic == ea_id * 10000 + slot
        reg_row = reg.get(magic)
        registry_symbol = (reg_row or {}).get("symbol", "")
        reg_collision = bool(reg_row and int(reg_row["ea_id"]) != ea_id)

        # F1/F7 vintage: does the bound binary contain the resolver fix at all?
        resolver_fix_present = bool(bin_mtime and bin_mtime >= FIX_MAGIC_RESOLVER["utc"])
        # Structural: even WITH the fix, the canonical bases must agree.
        reg_canon = magic_symbol_canonical(registry_symbol) if registry_symbol else ""
        ftmo_canon = (
            magic_symbol_canonical(sym["ftmo_symbol"])
            if sym["ftmo_symbol"] != "UNVERIFIED" else ""
        )
        canonical_match = bool(reg_canon and ftmo_canon and reg_canon == ftmo_canon)
        # Registry snapshot: the resolver table is compiled INTO the .ex5, so a
        # magic reserved after the build date cannot be in that binary's table.
        reserved_at = (reg_row or {}).get("reserved_at", "")
        reserved_norm = (reserved_at or "")[:10]
        registry_snapshot_covers_magic = bool(
            bin_mtime and reserved_norm and reserved_norm <= bin_mtime[:10]
        )

        # F2: is this magic live on the demo right now, held by another binary?
        gov_row = gov["magics"].get(magic)
        gov_overlap = gov_row is not None
        gov_running_sha = gov_row["deployed_sha256"] if gov_row else None
        magic_held_by_other_binary = bool(
            gov_overlap and gov_running_sha and bin_sha and gov_running_sha != bin_sha
        )
        magic_collision = bool(reg_collision or magic_held_by_other_binary)

        # --- (e) risk, re-derived for EVERY row -----------------------------
        lookup_id = replaced if replaced else ea_id
        akey = analytic_by_key.get((lookup_id, dwx_symbol))
        risk_profile = float(chart["risk_percent"])
        if akey:
            risk = float(akey["burn_in_risk_percent"] if is_new else akey["weight_risk_percent"])
            risk_field = "burn_in_risk_percent" if is_new else "weight_risk_percent"
        else:
            risk = risk_profile
            risk_field = "profile_manifest.risk_percent (analytic row not found)"
        risk_matches_profile = abs(risk - risk_profile) < 5e-5

        # --- decision -------------------------------------------------------
        exclude_reasons: list[str] = []
        conditions: list[str] = []

        if sym["symbol_source"] == "unverified":
            exclude_reasons.append(
                "no FTMO symbol name from any read source (alias registry, native capture, "
                "ticks/history dir, terminal logs)"
            )
        elif not sym["symbol_verified_on_target_account"]:
            exclude_reasons.append(
                f"FTMO name '{sym['ftmo_symbol']}' comes only from the "
                f"{alias_venue.get('venue_id')} alias venue bound to account "
                f"{alias_venue.get('account_id')}, not the census target {FTMO_ACCOUNT}; "
                f"no ticks dir, history dir or log line corroborates it on this account "
                f"(registry matching={alias_venue.get('matching')}, "
                f"cross_venue_pooling={alias_venue.get('cross_venue_pooling_for_qualification')})"
            )

        if ea_id in DARK_NOOP_EA_IDS:
            exclude_reasons.append(
                "dark no-op in v2 (NOT_EQUIVALENT rebuild, multi-symbol cointegration/pair) "
                "per BOOK_SPRINT_2026-09-20.md D7"
            )
        if handling["class"] == "UNKNOWN":
            exclude_reasons.append("symbol-handling class could not be determined")
        for lit in literals["blocking_literals"]:
            exclude_reasons.append(
                f"blocking .DWX trading-logic literal {lit['symbol']} at {lit['path']}:"
                f"{lit['line']} (severity {lit['severity']}) - {lit['why']}"
            )
        if reg_collision:
            exclude_reasons.append(
                f"magic {magic} is registered to ea_id {reg_row['ea_id']}, not {ea_id}"
            )
        if registry_symbol and sym["ftmo_symbol"] != "UNVERIFIED" and not canonical_match:
            exclude_reasons.append(
                f"magic resolver fails closed on this account even after a rebuild: registry "
                f"symbol {registry_symbol} canonicalises to '{reg_canon}', FTMO chart symbol "
                f"{sym['ftmo_symbol']} to '{ftmo_canon}' (QM_MagicSymbolCanonical, "
                f"QM_MagicResolver.mqh:134) - needs a registry re-symbol, not a recompile"
            )

        # Conditions are always computed, even for EXCLUDE rows: an excluded row
        # that ALSO carries a stale binary must not hide that fact behind the
        # first exclude reason (F1 wanted 1537's pre-fix binary named explicitly).
        if not resolver_fix_present:
            conditions.append(
                f"blocked_on_resolver_rebuild: bound binary mtime {bin_mtime} predates "
                f"{FIX_MAGIC_RESOLVER['commit'][:10]} ({FIX_MAGIC_RESOLVER['utc']}), so it "
                f"cannot contain the base-name tolerance; registry says {registry_symbol}, "
                f"the FTMO chart would be {sym['ftmo_symbol']}. Observed without it: "
                f"{FIX_MAGIC_RESOLVER['observed_failure_without_it']}"
            )
        if not registry_snapshot_covers_magic:
            conditions.append(
                f"registry_snapshot_stale: magic {magic} was reserved {reserved_at}, the "
                f"bound binary was built {bin_mtime}; the resolver table is compiled into "
                f"the .ex5, so this magic may not be in that binary's table "
                f"(EA_MAGIC_NOT_REGISTERED)"
            )
        if magic_held_by_other_binary:
            conditions.append(
                f"detach_required: magic {magic} is live on the RUNNING demo "
                f"(AutoTrading ON) under chart {gov_row['deployed_chart']} with sha "
                f"{gov_running_sha[:12]}..., the roster binds {bin_sha[:12]}... - two "
                f"identities on one magic. The deploy plan must detach that chart first."
            )

        if exclude_reasons:
            decision = "EXCLUDE"
        elif conditions:
            decision = "ADMIT_CONDITIONAL"
        else:
            decision = "ADMIT"

        rows.append({
            "ea_id": ea_id,
            "ea_label": expert_name,
            "replaces_ea_id": replaced,
            "dxz_symbol": dwx_symbol,
            "ftmo_symbol": sym["ftmo_symbol"],
            "symbol_source": sym["symbol_source"],
            "symbol_on_account_corroboration": sym["on_account_corroboration"],
            "symbol_verified_on_target_account": sym["symbol_verified_on_target_account"],
            "binary_path": bin_path,
            "binary_location": bin_loc,
            "binary_sha256": bin_sha,
            "binary_mtime_utc": bin_mtime,
            "resolver_fix_present": resolver_fix_present,
            "registry_symbol": registry_symbol,
            "registry_symbol_canonical": reg_canon,
            "ftmo_symbol_canonical": ftmo_canon,
            "canonical_match": canonical_match,
            "registry_magic_reserved_at": reserved_at,
            "registry_snapshot_covers_magic": registry_snapshot_covers_magic,
            "symbol_handling_class": handling["class"],
            "symbol_handling_detail": handling,
            "literal_decision": literals,
            "news_compliance_capability": news["capability"],
            "news_compliance_detail": news,
            "slot": slot,
            "magic": magic,
            "magic_formula_ok": formula_ok,
            "magic_in_governor_allowed": gov_overlap,
            "governor_running_sha256": gov_running_sha,
            "magic_held_by_other_binary": magic_held_by_other_binary,
            "magic_registry_ea_id": (int(reg_row["ea_id"]) if reg_row else None),
            "magic_collision": magic_collision,
            "risk_percent": risk,
            "risk_percent_field": risk_field,
            "risk_percent_profile": risk_profile,
            "risk_percent_matches_profile": risk_matches_profile,
            "is_new_sleeve": is_new,
            "decision": decision,
            "admit_now": decision == "ADMIT",
            "conditions": conditions,
            "reason": "; ".join(exclude_reasons or conditions) or "all checks passed",
        })

    admit = [r for r in rows if r["decision"] == "ADMIT"]
    cond = [r for r in rows if r["decision"] == "ADMIT_CONDITIONAL"]
    exclude = [r for r in rows if r["decision"] == "EXCLUDE"]

    # F4: BOTH governor CSVs derive from the same row set. `deployable` is what
    # the governor would have to allow for the burn-in to run at all.
    deployable = admit + cond
    gov_magics = set(gov["magics"])
    union_magics = sorted(gov_magics | {r["magic"] for r in deployable})
    union_symbols = sorted(
        {info["native_chart"].split()[0] for info in gov["magics"].values()}
        | {r["ftmo_symbol"] for r in deployable if r["ftmo_symbol"] != "UNVERIFIED"}
    )
    new_magics = sorted(m for m in union_magics if m not in gov_magics)

    return {
        "schema": "qm.ftmo-demo-v2-admission-census/v2-slot1",
        "purpose": "READ-ONLY admission census for FTMO demo book v2 burn-in "
                   "(BOOK_SPRINT F4 / ticket 42a437a4)",
        "generated_by": "docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/slot1_census_v2/"
                        "ftmo_demo_v2_census_slot1.py",
        "rework_of": "critique receipt critique_42a437a4_20260915T085204Z (F1..F11)",
        "session_collision_note": "Slot-1 of a 3-session claude orchestration fan-out. A "
                                  "sibling session reworked the same ticket concurrently and "
                                  "owns tools/strategy_farm/ftmo_demo_v2_census.py + "
                                  "../roster_ftmo_demo_v2.json. See ../slot1_census_v2/"
                                  "COLLISION.md. Neither side is committed.",
        "due_utc_binding": "2026-09-16T18:00:00Z",
        "due_date_sources": {
            "ticket_42a437a4_title": "Wed 2026-09-16 18:00Z (BINDING)",
            "docs/ops/BOOK_SPRINT_2026-09-20.md F4": "Fri 2026-09-18 (downstream schedule)",
            "v1_README": "Wed 2026-09-17 18:00Z (incorrect, superseded)",
        },
        "ftmo_account": FTMO_ACCOUNT,
        "ftmo_server": FTMO_SERVER,
        "no_rebuild": True,
        "no_qualification_claim": True,
        "sources": {
            "profile_manifest": str(PROFILE_MANIFEST),
            "analytic_manifest": str(ANALYTIC_MANIFEST),
            "aliases": str(ALIASES),
            "alias_venue_binding": alias_venue,
            "cost_snapshot_native_capture": str(COST_SNAPSHOT),
            "magic_registry": str(MAGIC_REGISTRY),
            "governor_manifest": str(GOVERNOR_MANIFEST),
            "ftmo_symbol_probe": "ftmo_symbol_probe_slot1.json (written by this script)",
            "fixes": {
                "magic_resolver": FIX_MAGIC_RESOLVER,
                "qm5_1537_calendar_input": FIX_1537_CALENDAR_INPUT,
            },
        },
        "governor_state": {
            "running_autotrading_on": gov["running_autotrading_on"],
            "magics": {str(k): v for k, v in sorted(gov["magics"].items())},
        },
        "counts": {
            "sleeves": len(rows),
            "admit": len(admit),
            "admit_conditional": len(cond),
            "exclude": len(exclude),
        },
        "governor_input_deltas_PROPOSAL_ONLY": {
            "note": "PROPOSAL ONLY - not applied anywhere. Policy FTMO_2S_P1_100K_V2 "
                    "unchanged. Both CSVs derive from the SAME row set "
                    "(governor's 8 live magics UNION the deployable roster rows), so "
                    "magic coverage and symbol coverage cannot drift apart (F4).",
            "derived_from": "governor_live_magics UNION (ADMIT + ADMIT_CONDITIONAL)",
            "allowed_magics_csv": ",".join(str(m) for m in union_magics),
            "new_magics_to_add_csv": ",".join(str(m) for m in new_magics),
            "governed_symbols_csv": ",".join(union_symbols),
        },
        "deploy_preconditions": sorted({
            c.split(":")[0] for r in rows for c in r["conditions"]
        }),
        "roster": rows,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="FTMO demo book v2 admission census (read-only)")
    ap.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parent,
        help="defaults to this script's own directory so it never clobbers the "
             "sibling session's shared artifacts",
    )
    args = ap.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    probe = ftmo_symbol_probe()
    (args.out_dir / "ftmo_symbol_probe_slot1.json").write_text(
        json.dumps(probe, indent=2) + "\n", encoding="utf-8"
    )
    census = build_census(probe)
    (args.out_dir / "roster_ftmo_demo_v2_slot1.json").write_text(
        json.dumps(census, indent=2) + "\n", encoding="utf-8"
    )

    c = census["counts"]
    print(f"wrote {args.out_dir / 'roster_ftmo_demo_v2_slot1.json'}")
    print(f"wrote {args.out_dir / 'ftmo_symbol_probe_slot1.json'}")
    print(
        f"sleeves={c['sleeves']} ADMIT={c['admit']} "
        f"ADMIT_CONDITIONAL={c['admit_conditional']} EXCLUDE={c['exclude']}"
    )
    for r in census["roster"]:
        if r["decision"] != "ADMIT":
            print(f"  {r['decision']:<18} {r['ea_id']:>6} {r['dxz_symbol']:<12} "
                  f"-> {r['reason'][:150]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

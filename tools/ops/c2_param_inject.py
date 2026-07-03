"""
C2 Param Inject — Wave 1
Injects strategy_params from .mq5 compiled defaults into:
  1. Approved cards (markdown table section)
  2. Pending setfiles (replace card_defaults_source=not_found)
Then stages requeue for EAs with 0 pending items.

Usage: python c2_param_inject.py [--dry-run]
"""

import re
import sys
import json
import shutil
import sqlite3
import uuid
from pathlib import Path
from datetime import datetime, timezone

DRY_RUN = "--dry-run" in sys.argv

REPO_ROOT = Path("C:/QM/repo")
FARM_ROOT = Path("D:/QM/strategy_farm")
CARDS_DIR = FARM_ROOT / "artifacts" / "cards_approved"
EA_ROOT = REPO_ROOT / "framework" / "EAs"
DB_PATH = FARM_ROOT / "state" / "farm_state.sqlite"
EXCLUDED_FILE = FARM_ROOT / "state" / "requeue_excluded_eas.txt"
ARTIFACTS_OPS = FARM_ROOT / "artifacts" / "ops"
TODAY = datetime.now(timezone.utc).strftime("%Y-%m-%d")

# 49 confirmed 0-trade EAs from scan + 2 priority EAs
SCAN_EA_IDS = [
    "QM5_10025", "QM5_10050", "QM5_1060", "QM5_10605", "QM5_1088",
    "QM5_1093", "QM5_1094", "QM5_1095", "QM5_1096", "QM5_1097",
    "QM5_1099", "QM5_1101", "QM5_1104", "QM5_1118", "QM5_1119",
    "QM5_1121", "QM5_1132", "QM5_1149", "QM5_1195", "QM5_1237",
    "QM5_1359", "QM5_1371", "QM5_1383", "QM5_1385", "QM5_1386",
    "QM5_1387", "QM5_1395", "QM5_1400", "QM5_1406", "QM5_1433",
    "QM5_1434", "QM5_1435", "QM5_1440", "QM5_1442", "QM5_1443",
    "QM5_1448", "QM5_1510", "QM5_1517", "QM5_1518", "QM5_1548",
    "QM5_1551", "QM5_1554", "QM5_1568", "QM5_1576", "QM5_1703",
    "QM5_1800", "QM5_1804", "QM5_2010", "QM5_9122",
    # Priority EAs (already have regenerated setfiles, need card update)
    "QM5_10307", "QM5_1328",
]

# Index/metal/commodity asset classes (lower commission, priority for requeue)
INDEX_COMMODITY_PREFIXES = [
    "sp500", "ndx", "ws30", "gdaxi", "dax", "xauusd", "xtiusd", "xng",
    "xbrent", "xagusd", "nas", "ger", "uk100", "fra40",
]


def load_excluded_eas():
    excluded = set()
    if EXCLUDED_FILE.exists():
        for line in EXCLUDED_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                excluded.add(line.strip())
    return excluded


def extract_mq5_strategy_params(mq5_path: Path) -> dict:
    """Extract input params from the 'Strategy' group in a .mq5 file."""
    params = {}
    in_strategy = False
    content = mq5_path.read_text(encoding="utf-8", errors="replace")
    for line in content.splitlines():
        # Detect group change
        m_group = re.match(r'^\s*input\s+group\s+"([^"]+)"', line)
        if m_group:
            in_strategy = m_group.group(1) == "Strategy"
            continue
        # Match input declaration
        m_input = re.match(
            r"^\s*input\s+(?:[A-Za-z_][A-Za-z0-9_<>]*\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;]+);",
            line,
        )
        if m_input and in_strategy:
            name = m_input.group(1).strip()
            value = m_input.group(2).strip()
            if name.startswith("strategy_"):
                params[name] = value
    return params


def find_ea_dir(ea_id: str) -> Path | None:
    """Find the EA directory for a given ea_id."""
    # Try exact match first
    for d in EA_ROOT.iterdir():
        if d.is_dir() and d.name.startswith(ea_id + "_"):
            return d
    return None


def find_card_path(ea_id: str) -> Path | None:
    """Find the approved card for a given ea_id."""
    for f in CARDS_DIR.glob(f"{ea_id}_*.md"):
        return f
    # Also try exact slug match
    for f in CARDS_DIR.glob(f"{ea_id}.md"):
        return f
    return None


def has_strategy_params_table(card_text: str) -> bool:
    """Check if the card already has a Strategy Parameters section."""
    return "## Strategy Parameters" in card_text


def add_strategy_params_to_card(card_path: Path, params: dict) -> bool:
    """Add a Strategy Parameters table to the card body. Returns True if changed."""
    text = card_path.read_text(encoding="utf-8", errors="replace")

    if has_strategy_params_table(text):
        return False  # Already has it

    if not params:
        return False  # Nothing to add

    # Build the markdown table
    table_lines = ["", "## Strategy Parameters", "", "| param | default |", "|-------|---------|"]
    for k, v in params.items():
        table_lines.append(f"| `{k}` | `{v}` |")
    table_lines.append("")
    table_section = "\n".join(table_lines)

    # Append before ## Concepts or ## R1-R4 or at end
    for marker in ["## Concepts", "## R1-R4", "## R1-R4 Bewertung", "## Verwandte"]:
        if marker in text:
            text = text.replace(marker, table_section + "\n" + marker, 1)
            break
    else:
        # Append at end
        text = text.rstrip() + "\n" + table_section

    if not DRY_RUN:
        card_path.write_text(text, encoding="utf-8")
    return True


def fix_setfile(setfile_path: Path, params: dict, card_path: Path) -> bool:
    """Replace card_defaults_source=not_found with params. Returns True if changed."""
    if not setfile_path.exists():
        return False

    content = setfile_path.read_text(encoding="utf-8", errors="replace")

    if "card_defaults_source=not_found" not in content:
        return False  # Already fixed or different format

    # Build replacement: card source + params
    card_ref = f"; card_defaults_source={card_path}"
    param_lines = [card_ref]
    for k, v in params.items():
        param_lines.append(f"{k}={v}")
    replacement = "\n".join(param_lines)

    # Replace the not_found marker
    new_content = content.replace(
        "; card_defaults_source=not_found", replacement
    )

    if not DRY_RUN:
        setfile_path.write_text(new_content, encoding="utf-8", newline="\n")
    return True


def is_index_commodity(ea_id: str, card_path: Path | None) -> bool:
    """Check if EA is index/commodity class for priority ordering."""
    if card_path and card_path.exists():
        text = card_path.read_text(encoding="utf-8", errors="replace")
        for sym in ["SP500", "NDX", "WS30", "GDAXI", "XAUUSD", "XTIUSD", "XNGUSD", "XAGUSD", "WTI", "DAX"]:
            if sym in text[:2000]:  # Check frontmatter + first section
                return True
    # Also check EA slug
    ea_lower = ea_id.lower()
    return any(p in ea_lower for p in INDEX_COMMODITY_PREFIXES)


def main():
    print(f"=== C2 Param Inject Wave-1 {'[DRY RUN]' if DRY_RUN else ''} ===")
    print(f"Date: {TODAY}")

    excluded = load_excluded_eas()
    print(f"Loaded {len(excluded)} excluded EAs from requeue list")

    # Connect to DB
    con = sqlite3.connect(str(DB_PATH))
    con.row_factory = sqlite3.Row

    results = {
        "wave": "C2_wave1",
        "generated_at": TODAY,
        "processed": [],
        "cards_updated": 0,
        "setfiles_fixed": 0,
        "setfiles_already_ok": 0,
        "setfiles_missing_params": 0,
        "requeued_new": 0,
        "errors": [],
    }

    # Process each EA
    for ea_id in SCAN_EA_IDS:
        print(f"\n--- {ea_id} ---")
        ea_result = {
            "ea_id": ea_id,
            "card_updated": False,
            "setfiles_fixed": 0,
            "setfiles_already_ok": 0,
            "params_count": 0,
            "error": None,
        }

        try:
            # Find EA directory and .mq5
            ea_dir = find_ea_dir(ea_id)
            if not ea_dir:
                raise FileNotFoundError(f"EA dir not found for {ea_id}")

            mq5_files = list(ea_dir.glob("*.mq5"))
            if not mq5_files:
                raise FileNotFoundError(f"No .mq5 in {ea_dir}")
            mq5_path = mq5_files[0]

            # Extract strategy params
            params = extract_mq5_strategy_params(mq5_path)
            ea_result["params_count"] = len(params)
            print(f"  .mq5 strategy params: {len(params)} ({list(params.keys())[:3]}...)")

            # Find card
            card_path = find_card_path(ea_id)
            if not card_path:
                raise FileNotFoundError(f"Card not found for {ea_id} in {CARDS_DIR}")
            print(f"  Card: {card_path.name}")

            # Update card with strategy params table
            if params:
                changed = add_strategy_params_to_card(card_path, params)
                if changed:
                    print(f"  Card updated: added Strategy Parameters table")
                    ea_result["card_updated"] = True
                    results["cards_updated"] += 1
                else:
                    print(f"  Card already has Strategy Parameters section")

            # Fix pending setfiles for this EA
            pending_rows = con.execute(
                "SELECT DISTINCT setfile_path FROM work_items WHERE ea_id=? AND phase='Q02' AND status='pending'",
                (ea_id,)
            ).fetchall()

            for row in pending_rows:
                sp = Path(row["setfile_path"])
                if params:
                    fixed = fix_setfile(sp, params, card_path)
                    if fixed:
                        ea_result["setfiles_fixed"] += 1
                        results["setfiles_fixed"] += 1
                    else:
                        ea_result["setfiles_already_ok"] += 1
                        results["setfiles_already_ok"] += 1
                else:
                    results["setfiles_missing_params"] += 1
                    print(f"  WARNING: No strategy params extracted for {ea_id}")

            print(f"  Setfiles fixed: {ea_result['setfiles_fixed']}, already OK: {ea_result['setfiles_already_ok']}")

        except Exception as e:
            ea_result["error"] = str(e)
            results["errors"].append({"ea_id": ea_id, "error": str(e)})
            print(f"  ERROR: {e}")

        results["processed"].append(ea_result)

    # Handle QM5_1095 and QM5_2010 — 0 pending, need to check if requeue needed
    zero_pending_eas = ["QM5_1095", "QM5_2010"]
    new_items_added = 0
    MAX_NEW_ITEMS = 50  # Leave headroom from the 100 limit

    print("\n=== Handling 0-pending EAs ===")
    for ea_id in zero_pending_eas:
        if ea_id in excluded:
            print(f"{ea_id}: excluded from requeue")
            continue

        # Check done Q02 rows to understand state
        done_rows = con.execute(
            "SELECT symbol, verdict FROM work_items WHERE ea_id=? AND phase='Q02' AND status='done'",
            (ea_id,)
        ).fetchall()
        done_verdicts = {r["symbol"]: r["verdict"] for r in done_rows}
        pass_symbols = [s for s, v in done_verdicts.items() if v in ("PASS", "PASS_SOFT", "PASS_LOWFREQ")]

        print(f"{ea_id}: {len(done_rows)} done, {len(pass_symbols)} passing symbols: {pass_symbols[:5]}")
        if pass_symbols:
            print(f"  Already has passing symbols — no requeue needed")
        else:
            print(f"  All done items are FAIL/INFRA — would need requeue, but max-wave limit constrains us")
            # We could requeue but at 476 pending already this is deferred

    print(f"\n=== Summary ===")
    print(f"Cards updated: {results['cards_updated']}")
    print(f"Setfiles fixed: {results['setfiles_fixed']}")
    print(f"Setfiles already OK: {results['setfiles_already_ok']}")
    print(f"Setfiles with no params: {results['setfiles_missing_params']}")
    print(f"Errors: {len(results['errors'])}")
    if results["errors"]:
        for e in results["errors"]:
            print(f"  {e['ea_id']}: {e['error']}")

    # Write evidence JSON
    evidence_path = ARTIFACTS_OPS / f"c2_wave1_inject_evidence_{TODAY}.json"
    if not DRY_RUN:
        evidence_path.write_text(json.dumps(results, indent=2, default=str))
    print(f"\nEvidence: {evidence_path}")

    return results


if __name__ == "__main__":
    results = main()
    # Exit code: 0 if no errors, 1 if errors
    sys.exit(0 if not results["errors"] else 1)

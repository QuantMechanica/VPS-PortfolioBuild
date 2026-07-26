"""Assemble a joint-simulator manifest from qualified sleeves.

WHY THIS EXISTS
---------------
`ftmo_bar_joint_book_sim.py` needs a manifest naming, per sleeve, the Q08 summary,
the Q08 trade stream and its hash, the M15 bar series and its hash, the sizing and
the venue cost block. The 2026-07-22 manifest was assembled by hand, which is why
the simulator has only ever been run over that one frozen four-sleeve book — and
why the obvious question, whether the correlation structure of a *different* set
would survive FTMO's loss caps, was never asked.

This builds one from a list of (ea_id, symbol) pairs so the question can be asked
of any candidate book.

FAIL-CLOSED BY DESIGN
---------------------
A sleeve is emitted only when every input is present and verifiable: a Q08 summary
on disk, a trade stream with a computable SHA256, an M15 bar file, and a cost entry
for the symbol. Anything missing is reported as a rejection with the reason — never
silently defaulted, because a fabricated cost or an absent bar series would produce
a confident and wrong drawdown number, which is worse than no number at all.

The manifest is research output. `deployment_allowed` and `money_gate_authorized`
stay false; deployment is an OWNER decision made elsewhere.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
STREAM_DIR = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades"
)
BAR_DIR = Path(r"D:\QM\mt5\T_Export\MQL5\Files")
COST_PATH = Path(r"C:\QM\repo\framework\registry\venue_cost_model.json")
POLICY_PATH = Path(r"C:\QM\repo\framework\include\QM\QM_FTMOGovernorPolicy.mqh")
POLICY_ID = "FTMO_2S_P1_100K_V2"


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def find_stream(ea_id: str, symbol: str) -> Path | None:
    bare = ea_id.replace("QM5_", "")
    stem = symbol.replace(".", "_")
    exact = STREAM_DIR / f"{bare}_{stem}.jsonl"
    if exact.exists():
        return exact
    for candidate in STREAM_DIR.glob(f"{bare}_*.jsonl"):
        if symbol.split(".")[0] in candidate.stem:
            return candidate
    return None


def count_lines(path: Path) -> int:
    with path.open("rb") as handle:
        return sum(1 for line in handle if line.strip())


def load_costs() -> dict[str, Any]:
    if not COST_PATH.exists():
        return {}
    doc = json.loads(COST_PATH.read_text(encoding="utf-8-sig"))
    by_symbol: dict[str, Any] = {}
    def walk(node: Any) -> None:
        if isinstance(node, dict):
            sym = node.get("symbol") or node.get("dwx_symbol")
            if isinstance(sym, str) and ("commission" in json.dumps(node)[:4000]
                                         or "swap" in json.dumps(node)[:4000]):
                by_symbol.setdefault(sym.upper(), node)
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)
    walk(doc)
    return by_symbol


def q08_summary(conn: sqlite3.Connection, ea_id: str, symbol: str) -> Path | None:
    row = conn.execute(
        "SELECT evidence_path FROM work_items WHERE ea_id=? AND phase='Q08' "
        "AND symbol LIKE ? AND status='done' ORDER BY updated_at DESC LIMIT 1",
        (ea_id, f"{symbol.split('.')[0]}%"),
    ).fetchone()
    if row is None or not row["evidence_path"]:
        return None
    path = Path(row["evidence_path"])
    return path if path.exists() else None


def build(pairs: list[tuple[str, str]], risk_fixed: float) -> dict[str, Any]:
    conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    costs = load_costs()

    sleeves: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []

    for ea_id, symbol in pairs:
        problems: list[str] = []

        summary = q08_summary(conn, ea_id, symbol)
        if summary is None:
            problems.append("q08_summary_missing")

        stream = find_stream(ea_id, symbol)
        if stream is None:
            problems.append("q08_trade_stream_missing")

        bar = BAR_DIR / f"{symbol}_M15.csv"
        if not bar.exists():
            problems.append(f"m15_bars_missing:{bar.name}")

        cost = costs.get(symbol.upper()) or costs.get(symbol.split(".")[0].upper())
        if cost is None:
            problems.append("venue_cost_entry_missing")

        if problems:
            rejected.append({"ea_id": ea_id, "symbol": symbol, "reasons": problems})
            continue

        sleeves.append({
            "ea_id": int(ea_id.replace("QM5_", "")),
            "symbol": symbol,
            "summary_path": str(summary),
            "stream_path": str(stream),
            "stream_sha256": sha256_of(stream),
            "stream_trades": count_lines(stream),
            "bar_path": str(bar),
            "bar_sha256": sha256_of(bar),
            "base_risk_fixed": risk_fixed,
            "qualification": "CHALLENGE_READY",
            "cost": cost,
        })

    return {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "status": "RESEARCH_ONLY_NO_GO",
        "deployment_allowed": False,
        "money_gate_authorized": False,
        "policy_change_authorized": False,
        "timestamp_basis": "darwinex_broker_wall",
        "source_policy_id": POLICY_ID,
        "source_policy_path": str(POLICY_PATH),
        "source_cost_path": str(COST_PATH),
        "generated_by": "build_joint_sim_manifest.py",
        "sleeves": sleeves,
        "rejected": rejected,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sleeve", action="append", required=True,
                        help="EA_ID:SYMBOL, repeatable (e.g. QM5_10128:XAUUSD.DWX)")
    parser.add_argument("--risk-fixed", type=float, default=1000.0)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    pairs = []
    for spec in args.sleeve:
        ea_id, _, symbol = spec.partition(":")
        pairs.append((ea_id.strip(), symbol.strip()))

    manifest = build(pairs, args.risk_fixed)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(f"sleeves emitted : {len(manifest['sleeves'])}")
    for sleeve in manifest["sleeves"]:
        print(f"  {sleeve['ea_id']:6} {sleeve['symbol']:12} "
              f"trades={sleeve['stream_trades']:5}")
    if manifest["rejected"]:
        print(f"rejected        : {len(manifest['rejected'])}")
        for row in manifest["rejected"]:
            print(f"  {row['ea_id']:11} {row['symbol']:12} {', '.join(row['reasons'])}")
    print(f"wrote {args.out}")
    return 0 if manifest["sleeves"] else 2


if __name__ == "__main__":
    raise SystemExit(main())

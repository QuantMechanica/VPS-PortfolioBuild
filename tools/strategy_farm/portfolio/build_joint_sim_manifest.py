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


def durable_stream(aggregate: Path) -> tuple[Path | None, int]:
    """The Q08 aggregate names the durable stream copy and its trade count.

    Do NOT glob Common\\Files for it: that copy is whatever the last run left
    behind — for QM5_10128 it holds 155 trades while the durable copy the
    aggregate points at holds 433. Feeding the short one to the simulator would
    silently model a third of the book.
    """
    try:
        doc = json.loads(aggregate.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None, 0
    stream = doc.get("portfolio_stream") or {}
    path = stream.get("path")
    if not path:
        return None, 0
    p = Path(path)
    return (p if p.exists() else None), int(stream.get("n") or 0)


def usable_summary(ea_id: str, symbol: str, expected_trades: int) -> Path | None:
    """The run_smoke summary the reconciler can use, matched BY TRADE COUNT.

    `ftmo_stream_reconciliation` needs a summary carrying a `runs` array with an
    OK run and >0 trades — the Q08 aggregate is not such a file. Rather than
    guessing which work item produced the stream, take the one whose usable run
    reports exactly as many trades as the durable stream contains. That is an
    exact, self-verifying match instead of a path convention that can drift.
    """
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    ids = [r["id"] for r in con.execute(
        "SELECT id FROM work_items WHERE ea_id=? AND symbol LIKE ? AND status='done' "
        "ORDER BY updated_at DESC LIMIT 60", (ea_id, f"{symbol.split('.')[0]}%"))]
    best: tuple[float, Path] | None = None
    for wid in ids:
        directory = Path(r"D:\QM\reports\work_items") / wid
        if not directory.is_dir():
            continue
        for candidate in directory.rglob("summary.json"):
            try:
                doc = json.loads(candidate.read_text(encoding="utf-8-sig"))
            except (OSError, json.JSONDecodeError):
                continue
            ok = [r for r in (doc.get("runs") or [])
                  if str(r.get("status") or "").upper() == "OK"
                  and float(r.get("total_trades") or 0) > 0]
            if not ok:
                continue
            if int(float(ok[-1].get("total_trades") or 0)) != expected_trades:
                continue
            mtime = candidate.stat().st_mtime
            if best is None or mtime > best[0]:
                best = (mtime, candidate)
    return best[1] if best else None


def count_lines(path: Path) -> int:
    with path.open("rb") as handle:
        return sum(1 for line in handle if line.strip())


REFERENCE_MANIFESTS = (
    Path(r"D:\QM\reports\portfolio\ftmo_book_engine_20260722\manifest.json"),
)


def load_costs() -> dict[str, Any]:
    """Per-symbol cost blocks, taken from manifests that have actually been simulated.

    `venue_cost_model.json` is a provenance document — it names the ground-truth
    sources (the broker's injected tester commission table, the FTMO spec) but is
    not a machine-readable per-symbol table, and it carries no swap points, which
    the simulator requires. The cost block it needs (ftmo_symbol_code, commission
    per side, swap long/short points, contract size, digits, triple weekday) is a
    composed structure.

    Rather than recompose it from scratch — and risk inventing a swap rate, which
    Hard Rules forbid — reuse the blocks from manifests that were built and run
    against the real cost sources. A symbol with no validated block is rejected,
    not defaulted.
    """
    by_symbol: dict[str, Any] = {}
    for reference in REFERENCE_MANIFESTS:
        if not reference.exists():
            continue
        try:
            doc = json.loads(reference.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            continue
        for sleeve in doc.get("sleeves") or []:
            symbol = str(sleeve.get("symbol") or "").upper()
            cost = sleeve.get("cost")
            if symbol and isinstance(cost, dict) and "swap_long_points" in cost:
                by_symbol.setdefault(symbol, dict(cost))
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

        aggregate = q08_summary(conn, ea_id, symbol)
        if aggregate is None:
            problems.append("q08_aggregate_missing")

        stream, stream_n = (None, 0)
        summary = None
        if aggregate is not None:
            stream, stream_n = durable_stream(aggregate)
            if stream is None:
                problems.append("q08_durable_stream_missing")
            else:
                summary = usable_summary(ea_id, symbol, stream_n)
                if summary is None:
                    problems.append(
                        f"no_run_smoke_summary_with_{stream_n}_trades")

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
            "stream_trades": stream_n or count_lines(stream),
            "bar_path": str(bar),
            "bar_sha256": sha256_of(bar),
            "base_risk_fixed": risk_fixed,
            "qualification": "CHALLENGE_READY",
            "cost": cost,
        })

    # Equal-weight scenarios at full and half sizing. Flat weights are the honest
    # starting point for a book nobody has optimised yet: any other weighting is a
    # claim about relative edge that the evidence does not yet support, and the
    # half-size run shows how much of the drawdown is sizing rather than structure.
    keys = [f"{s['ea_id']}:{s['symbol']}" for s in sleeves]
    scenarios = [
        {"name": "flat_100", "weights": {k: 1.0 for k in keys}},
        {"name": "flat_050", "weights": {k: 0.5 for k in keys}},
    ] if keys else []

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
        "scenarios": scenarios,
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

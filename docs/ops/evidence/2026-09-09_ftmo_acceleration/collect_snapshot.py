"""Reproduce the FTMO acceleration intake; read-only DB, create-only output."""
from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO))
from tools.strategy_farm import gate_manifest, path_to_25
from tools.strategy_farm.portfolio import ftmo_q09_admission as admission


def main() -> None:
    destination = Path(sys.argv[1])
    if destination.exists():
        raise SystemExit("Refusing to replace an existing snapshot")
    database = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
    cost_path = REPO / "docs/ops/evidence/2026-09-05_ftmo_current_pool_cost_snapshot.json"
    costs = json.loads(cost_path.read_text(encoding="utf-8-sig"))
    projections = {r["sleeve_id"]: r for r in costs["projection"]["sleeves"]}
    manifest = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    terminal = manifest.terminal_requalification_gate
    terminal_ordinal = next(g.ordinal for g in manifest.gates if g.id == terminal)
    gates = tuple(g.id for g in manifest.gates if 2 <= g.ordinal <= terminal_ordinal)
    with sqlite3.connect(f"file:{database.as_posix()}?mode=ro", uri=True, timeout=15) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA query_only=ON")
        conn.execute("BEGIN")
        rows = path_to_25._qualified_pool(path_to_25._pair_summaries_fast(conn, gates), terminal)
        results = []
        active_phases = admission.NEWS_READ_PHASES
        for row in sorted(rows, key=lambda r: (r["ea_id"], r["symbol"])):
            try:
                admission.NEWS_READ_PHASES = ("Q09_NEWS",)
                before = admission.evaluate_ftmo_q09_admission(conn, **row)
            finally:
                admission.NEWS_READ_PHASES = active_phases
            after = admission.evaluate_ftmo_q09_admission(conn, **row)
            key = row["ea_id"].removeprefix("QM5_") + ":" + row["symbol"].removesuffix(".DWX")
            results.append({
                **row, "legacy_reader_result": before, "active_reader_result": after,
                "historical_cost_projection_before_spread": projections.get(key),
                "projection_scope": "EXPLORATORY_2026_09_05_NOT_CURRENT_BINARY_OR_NET_EDGE_CERTIFICATION",
            })
        news_counts = [dict(r) for r in conn.execute(
            "SELECT w.phase,t.contract_version,t.matrix_scope,t.target_compliance,t.verdict,COUNT(*) n "
            "FROM q09_news_tests t JOIN work_items w ON w.id=t.work_item_id GROUP BY 1,2,3,4,5"
        )]
        q14 = [dict(r) for r in conn.execute(
            "SELECT verdict,COUNT(*) n FROM work_items WHERE phase='Q14' GROUP BY verdict"
        )]
        conn.rollback()
    bound = [
        Path(__file__), cost_path,
        REPO / "tools/strategy_farm/portfolio/ftmo_q09_admission.py",
        REPO / "tools/strategy_farm/path_to_25.py",
        REPO / "tools/strategy_farm/config/gate_manifest.v4.json",
        REPO / "tools/strategy_farm/config/gate_manifest.v4.draft.json",
        REPO / "docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md",
    ]
    report = {
        "schema": "qm.ftmo-acceleration-intake/v1",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "db_read_mode": "mode=ro; query_only=ON; single read transaction",
        "qualified_pairs": len(rows),
        "count_definition": "path_to_25._pair_summaries_fast + _qualified_pool, contiguous Q14",
        "active_reader_phases": list(active_phases),
        "legacy_admitted": sum(r["legacy_reader_result"]["admitted"] for r in results),
        "active_reader_admitted": sum(r["active_reader_result"]["admitted"] for r in results),
        "legacy_reasons": dict(Counter(r["legacy_reader_result"]["reason_code"] for r in results)),
        "active_reasons": dict(Counter(r["active_reader_result"]["reason_code"] for r in results)),
        "pairs": results, "news_storage_counts": news_counts, "raw_q14_verdict_counts": q14,
        "bindings": [{"path": str(p), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in bound],
        "limits": [
            "FTMO news admission is only one prerequisite; admission does not authorize trading.",
            "No holdout was opened; prior published projections are exploratory and exclude spread delta.",
            "Provider terms and binary identity require fresh binding before use in an economic test.",
            "This snapshot cannot change a pipeline verdict, the 25-pair rule, R5, or purchase authority.",
        ],
    }
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(json.dumps({k: report[k] for k in (
        "measured_at_utc", "qualified_pairs", "legacy_admitted", "active_reader_admitted", "active_reasons"
    )}))


if __name__ == "__main__":
    main()

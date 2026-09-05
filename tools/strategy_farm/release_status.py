#!/usr/bin/env python3
"""Read-only release-status projection; no gate, verdict, or admission mutation.

Contract: docs/ops/evidence/CONTIGUITY_CONTRACT_V1.md. JSON goes to stdout.
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import sys
from functools import lru_cache
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import assemble_stream_bundle as bundle
from tools.strategy_farm import book_build_guard as guard
from tools.strategy_farm import rebaseline_census as rc


def obj(raw):
    try:
        value = json.loads(raw or "{}")
        return value if isinstance(value, dict) else {}
    except (ValueError, TypeError):
        return {}


def read_json(path):
    try:
        return obj(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, TypeError):
        return {}


def sha(path):
    try:
        return bundle.sha256_file(Path(path)) if path else None
    except OSError:
        return None


@lru_cache(maxsize=1024)
def resolved(phase, version):
    return (rc.canonical_gate(phase, version), rc.phase_qid(phase, version).upper().endswith("_PORTFOLIO"))


def gate(row):
    return resolved(row.get("phase"), row.get("gate_contract_version"))[0]


def passing(row, *, diagnostic_without_soft=False):
    g = gate(row)
    informational = resolved(row.get("phase"), row.get("gate_contract_version"))[1]
    if diagnostic_without_soft and g == "Q08" and row.get("verdict") == "FAIL_SOFT":
        return False
    return row.get("status", "").lower() == "done" and not informational and rc.vclass(row.get("verdict"), g) == "PASS"


def project_records(rows, *, diagnostic_without_soft=False):
    """Fast set projection of the same historical pair semantics as the census."""
    valid = {}
    for row in rows:
        key = (str(row["ea_id"]), str(row["symbol"]))
        valid.setdefault(key, set())
        if passing(row, diagnostic_without_soft=diagnostic_without_soft) and gate(row):
            valid[key].add(gate(row))
    return {key: {"valid_gates": [g for g in rc.GATE_CHAIN if g in gates],
                  "missing_link": next((g for g in rc.GATE_CHAIN if g not in gates), None)}
            for key, gates in valid.items()}


def identity(row):
    p = obj(row.get("payload_json"))
    return {k: row.get(k) or p.get("expected_" + k) or p.get(k)
            for k in ("ex5_sha256", "setfile_sha256", "mq5_sha256")}


def pair_detail(con, key, rows, summary, fund_rows):
    terminal = rc.GATE_CHAIN[-1]
    terminals = [r for r in rows if gate(r) == terminal and passing(r)]
    terminals.sort(key=lambda r: (r.get("updated_at") or "", r["id"]), reverse=True)
    selected = terminals[0] if terminals else {}
    ident = identity(selected)
    ident["terminal_work_item_id"] = selected.get("id")
    ident["terminal_verdict"] = selected.get("verdict")
    ident["terminal_evidence_sha256_observed"] = sha(selected.get("evidence_path"))
    flags = []
    valid = project_records(rows)[key]
    witnesses = []
    for g in rc.GATE_CHAIN:
        options = [r for r in rows if gate(r) == g and passing(r)]
        options.sort(key=lambda r: (r.get("updated_at") or "", r["id"]), reverse=True)
        same = [r for r in options if identity(r)["ex5_sha256"] == ident["ex5_sha256"] and ident["ex5_sha256"]]
        witness = (same or options or [{}])[0]
        wi = identity(witness)
        witnesses.append({"gate": g, "work_item_id": witness.get("id"), "verdict": witness.get("verdict"),
                          "identity": wi, "same_terminal_binary": bool(same),
                          "evidence_path": witness.get("evidence_path"),
                          "evidence_sha256_observed": sha(witness.get("evidence_path"))})
    # Historical census is existential, not an exact-identity lineage proof.
    flags.append("EXACT_CHAIN_LINEAGE_NOT_ATTESTED")
    if any(not w["same_terminal_binary"] for w in witnesses):
        flags.append("CHAIN_BINARY_IDENTITY_MISSING_OR_MIXED")
    if any(not w["evidence_sha256_observed"] for w in witnesses):
        flags.append("CHAIN_EVIDENCE_BYTES_UNAVAILABLE")
    bound = bundle.find_bound_q08(con, *key, ident["ex5_sha256"]) if ident["ex5_sha256"] else None
    stream = {"status": "UNAVAILABLE"}
    data = {"status": "UNKNOWN", "window_start": None, "window_end": None, "archive_manifest_sha256": None}
    if bound:
        located, checked = bundle.locate_sealed_bytes(bound["seal_content_sha256"],
            bundle.stream_filename(int(key[0].removeprefix("QM5_")), key[1]),
            bound["recorded_path"], bound["source_artifact_path"], bundle.DEFAULT_SEARCH_ROOTS)
        stream = {**bound, "status": "BOUND" if located else "MISSING_BYTES", "located_path": str(located) if located else None,
                  "checked_existing_paths": checked}
        q = next(r for r in rows if r["id"] == bound["q08_work_item_id"])
        p = obj(q.get("payload_json")); a = p.get("artifact_identity") or {}
        archive = p.get("custom_history_archive_admission") or {}
        data = {"status": "DECLARED_NOT_REHASHED", "window_start": q.get("data_window_start") or a.get("data_window_start"),
                "window_end": q.get("data_window_end") or a.get("data_window_end"),
                "archive_manifest_sha256": archive.get("manifest_sha256"),
                "artifact_identity": a, "archive_admission": archive}
        if (q.get("updated_at") or "") > (selected.get("updated_at") or ""):
            flags.append("Q08_STREAM_RESEALED_AFTER_TERMINAL_CLOSURE")
    if stream["status"] != "BOUND": flags.append("CURRENT_SEALED_STREAM_UNAVAILABLE")
    flags.append("DATA_ARCHIVE_BYTES_NOT_REVALIDATED")
    sleeve = f'{int(key[0].removeprefix("QM5_"))}:{key[1].removesuffix(".DWX")}'
    score = next((r for r in fund_rows if r.get("sleeve") == sleeve), {})
    score_bound = bool(score.get("input_stream_sha256") and score.get("input_stream_sha256") == stream.get("seal_content_sha256") and stream["status"] == "BOUND")
    if not score_bound: flags.append("ECONOMIC_SCORE_MISSING_OR_STALE")
    if any(w["gate"] == "Q08" and w["verdict"] == "FAIL_SOFT" for w in witnesses): flags.append("Q08_FAIL_SOFT_OWNER_PASS_CLASS")
    economic = {"status": "CURRENT_SCREENING_ONLY" if score_bound else "UNAVAILABLE_OR_STALE",
                "fund_score": score.get("fund_score"), "score_record": score,
                "source_matches_bound_stream": score_bound, "release_economics": "NOT_ESTABLISHED"}
    return {"ea_id": key[0], "symbol": key[1], "identity": ident, "data_version": data,
            "historical_contiguity": {**valid, "reference_highest": summary["highest_contiguous_valid_gate"], "witnesses": witnesses},
            "sealed_stream": stream, "economic_result": economic,
            "uncertainty_flags": flags, "execution_readiness": "NOT_AUTHORIZED_BY_THIS_PROJECTION",
            "blocker": {"missing_historical_gate": valid["missing_link"],
                        "unavailable_witness_gates": [w["gate"] for w in witnesses if not w["evidence_sha256_observed"]],
                        "unmatched_binary_gates": [w["gate"] for w in witnesses if not w["same_terminal_binary"]],
                        "stream_status": stream["status"], "score_status": economic["status"],
                        "separate_release_requirements": ["book_guard", "exact_chain_attestation", "venue_economic_acceptance", "native_operational_proof"]},
            "owner": "Pipeline-Operator: evidence; Codex: review; OWNER: authorization",
            "next_step": "Review recorded identities and missing evidence; use the existing book guard and venue acceptance process."}


def build_report(db_path, fund_scores, order_dir):
    con = rc.open_ro(str(db_path))
    try:
        con.execute("PRAGMA query_only=ON")
        con.execute("BEGIN")  # One SQLite read snapshot across all census views.
        records = rc.build_pairs(con, limit=None)
        summaries = {key: rc.summarise_pair(value) for key, value in records.items()}
        terminal = rc.GATE_CHAIN[-1]
        qualified = {key for key, value in summaries.items() if value["highest_contiguous_valid_gate"] == terminal}
        thin = [dict(r) for r in con.execute("SELECT id,ea_id,symbol,phase,status,verdict,gate_contract_version FROM work_items WHERE ea_id IS NOT NULL AND ea_id<>'' AND symbol IS NOT NULL AND symbol<>''")]
        fast = project_records(thin)
        fast_qualified = {key for key, value in fast.items() if value["missing_link"] is None}
        diagnostic = project_records(thin, diagnostic_without_soft=True)
        diagnostic_qualified = {key for key, value in diagnostic.items() if value["missing_link"] is None}
        terminal_rows = [r for r in thin if gate(r) == terminal and passing(r)]
        cohort = qualified | {(str(r["ea_id"]), str(r["symbol"])) for r in terminal_rows}
        funds = read_json(fund_scores)
        details = []
        for key in sorted(cohort):
            rows = [dict(r) for r in con.execute("SELECT * FROM work_items WHERE ea_id=? AND symbol=?", key)]
            details.append(pair_detail(con, key, rows, summaries[key], funds.get("rows", [])))
        qualified_rows = [{"ea_id": k[0], "symbol": k[1]} for k in sorted(qualified)]
        book = guard.check_book_build_allowed("ftmo", db_path, order_dir, qualified_rows=qualified_rows)
        return {"schema": "qm.release-status/v1", "contract": "qm.contiguity/v1", "read_only": True,
                "observed_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                "gate_contract_version": rc.ACTIVE_GATE_CONTRACT_VERSION, "gate_chain": rc.GATE_CHAIN,
                "db_path": str(db_path), "fund_scores_path": str(fund_scores), "fund_scores_sha256": sha(fund_scores),
                "counts": {"terminal_pass_rows": len(terminal_rows), "terminal_distinct_pairs": len({(r['ea_id'], r['symbol']) for r in terminal_rows}),
                           "reference_qualified_pairs": len(qualified), "fast_qualified_pairs": len(fast_qualified),
                           "diagnostic_without_q08_soft_pairs": len(diagnostic_qualified),
                           "builder_qualified_pairs": book.qualified_pairs,
                           "bundle_bound_pairs": sum(r["sealed_stream"]["status"] == "BOUND" for r in details)},
                "reconciliation": {"reference_equals_fast": qualified == fast_qualified,
                                   "symmetric_difference": sorted(qualified ^ fast_qualified),
                                   "soft_rule_added_pairs": sorted(qualified - diagnostic_qualified),
                                   "duplicate_terminal_rows": len(terminal_rows) - len({(r['ea_id'], r['symbol']) for r in terminal_rows}),
                                   "fast_component": "release_status.project_records (new parity projection; no separate legacy fast-census entrypoint located)"},
                "book_guard": dataclasses.asdict(book), "pairs": details,
                "limits": ["Historical contiguity is not a bound release chain.", "Disk files can change outside the SQLite read snapshot; hashes record the observed bytes.",
                           "Screening scores do not establish FTMO release economics.", "This report grants no build, gate, purchase, or deployment authority."]}
    finally:
        con.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=guard.DEFAULT_DB_PATH)
    parser.add_argument("--fund-scores", type=Path, default=Path("D:/QM/strategy_farm/artifacts/portfolio/fund_scores.json"))
    parser.add_argument("--order-dir", type=Path, default=guard.DEFAULT_ORDER_DIR)
    args = parser.parse_args()
    result = build_report(args.db, args.fund_scores, args.order_dir)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["reconciliation"]["reference_equals_fast"] else 2


if __name__ == "__main__":
    raise SystemExit(main())

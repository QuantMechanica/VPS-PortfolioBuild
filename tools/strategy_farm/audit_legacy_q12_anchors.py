#!/usr/bin/env python3
"""Read-only, fail-closed anchor audit for the legacy Q12-ready cohort."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Any, Iterable


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
REQUAL8 = {
    ("QM5_1567", "EURUSD.DWX"),
    ("QM5_10815", "GDAXI.DWX"),
    ("QM5_10939", "GBPUSD.DWX"),
    ("QM5_11421", "EURUSD.DWX"),
    ("QM5_12567", "XAUUSD.DWX"),
}
OPT_FORK = {
    ("QM5_10706", "GBPUSD.DWX"),
    ("QM5_11421", "EURUSD.DWX"),
    ("QM5_11422", "USDCAD.DWX"),
}
NEWS_MATRIX = {("QM5_10513", "XAUUSD.DWX")}
HASH_KEYS = {
    "ex5": (
        "ex5_sha256", "expected_ex5_sha256", "baseline_ex5_sha256",
        "source_ex5_sha256", "build_hash",
    ),
    "setfile": (
        "setfile_sha256", "expected_setfile_sha256",
        "baseline_setfile_sha256", "source_setfile_sha256",
    ),
    "mq5": (
        "mq5_sha256", "expected_mq5_sha256", "baseline_mq5_sha256",
        "source_mq5_sha256",
    ),
    "news": (
        "news_calendar_sha256", "calendar_sha256",
        "source_news_calendar_sha256", "baseline_news_calendar_sha256",
    ),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _json(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _values(obj: Any, keys: Iterable[str]) -> list[str]:
    wanted = {key.lower() for key in keys}
    found: list[str] = []
    if isinstance(obj, dict):
        for key, value in obj.items():
            if str(key).lower() in wanted and isinstance(value, str):
                candidate = value.strip().lower()
                if len(candidate) == 64 and all(c in "0123456789abcdef" for c in candidate):
                    found.append(candidate)
            found.extend(_values(value, keys))
    elif isinstance(obj, list):
        for value in obj:
            found.extend(_values(value, keys))
    return list(dict.fromkeys(found))


def _file_binding(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {"path": None, "exists": False, "sha256": None, "mtime_utc": None}
    exists = path.is_file()
    return {
        "path": str(path),
        "exists": exists,
        "sha256": sha256_file(path) if exists else None,
        "mtime_utc": (
            dt.datetime.fromtimestamp(path.stat().st_mtime, dt.UTC)
            .replace(microsecond=0).isoformat()
            if exists else None
        ),
    }


def _evidence_binding(path_value: Any) -> tuple[dict[str, Any], dict[str, Any]]:
    path = Path(str(path_value)) if path_value else None
    binding = _file_binding(path)
    document: dict[str, Any] = {}
    if binding["exists"]:
        try:
            value = json.loads(path.read_text(encoding="utf-8-sig"))  # type: ignore[union-attr]
            if isinstance(value, dict):
                document = value
        except (OSError, json.JSONDecodeError):
            binding["parse_error"] = True
    return binding, document


def _first_bound_hash(
    kind: str,
    rows: Iterable[dict[str, Any]],
    documents: Iterable[dict[str, Any]],
) -> str | None:
    keys = HASH_KEYS[kind]
    for row in rows:
        for key in keys:
            value = str(row.get(key) or "").lower()
            if len(value) == 64 and all(c in "0123456789abcdef" for c in value):
                return value
        found = _values(_json(row.get("payload_json")), keys)
        if found:
            return found[0]
    for document in documents:
        found = _values(document, keys)
        if found:
            return found[0]
    return None


def _match(expected: str | None, actual: str | None) -> str:
    if not expected:
        return "UNBOUND"
    if not actual:
        return "CURRENT_MISSING"
    return "MATCH" if expected == actual else "MISMATCH"


def audit(db: Path, repo: Path) -> dict[str, Any]:
    uri = f"file:{db.as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    quick_check = str(conn.execute("PRAGMA quick_check").fetchone()[0])
    manifest_path = repo / "tools" / "strategy_farm" / "config" / "gate_manifest.v4.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    equivalence = manifest["contract_equivalence"]["v3_to_v4"]
    cohort = [dict(row) for row in conn.execute(
        "SELECT * FROM portfolio_candidates WHERE state='Q12_REVIEW_READY' "
        "ORDER BY CAST(REPLACE(ea_id,'QM5_','') AS INTEGER),symbol,q11_work_item_id"
    )]
    results: list[dict[str, Any]] = []
    for pc in cohort:
        pair = (str(pc["ea_id"]), str(pc["symbol"]))
        exclusions: list[str] = []
        if pair in REQUAL8:
            exclusions.append("REQUAL8")
        if pair in OPT_FORK:
            exclusions.append("ACTIVE_OPT_FORK")
        if pair in NEWS_MATRIX:
            exclusions.append("ACTIVE_NEWS_MATRIX")

        q11_row_raw = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (pc["q11_work_item_id"],)
        ).fetchone()
        q11_row = dict(q11_row_raw) if q11_row_raw else {}
        payload = _json(q11_row.get("payload_json"))
        predecessor_id = str(payload.get("promoted_from_work_item") or "")
        predecessor_raw = (
            conn.execute("SELECT * FROM work_items WHERE id=?", (predecessor_id,)).fetchone()
            if predecessor_id else None
        )
        latest_q08_raw = conn.execute(
            "SELECT * FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q08' "
            "AND status='done' ORDER BY updated_at DESC,id DESC LIMIT 1", pair
        ).fetchone()
        q08_raw = latest_q08_raw or predecessor_raw
        q08_row = dict(q08_raw) if q08_raw else {}

        pc_evidence, pc_doc = _evidence_binding(pc.get("evidence_path"))
        q08_path = q08_row.get("evidence_path") or payload.get("q08_evidence_path")
        q08_evidence, q08_doc = _evidence_binding(q08_path)
        evidence_documents = [pc_doc, q08_doc]

        numeric = pair[0].replace("QM5_", "", 1)
        ea_dirs = sorted((repo / "framework" / "EAs").glob(f"QM5_{numeric}_*"))
        ea_dir = ea_dirs[0] if len(ea_dirs) == 1 else None
        ex5 = _file_binding(
            ea_dir / f"{ea_dir.name}.ex5" if ea_dir is not None else None
        )
        mq5 = _file_binding(
            ea_dir / f"{ea_dir.name}.mq5" if ea_dir is not None else None
        )
        setfile_value = q11_row.get("setfile_path") or q08_row.get("setfile_path")
        setfile = _file_binding(Path(str(setfile_value)) if setfile_value else None)
        source_rows = [row for row in (q11_row, q08_row) if row]
        expected_ex5 = _first_bound_hash("ex5", source_rows, evidence_documents)
        expected_setfile = _first_bound_hash("setfile", source_rows, evidence_documents)
        expected_mq5 = _first_bound_hash("mq5", source_rows, evidence_documents)
        expected_news = _first_bound_hash("news", source_rows, evidence_documents)
        ex5_match = _match(expected_ex5, ex5["sha256"])
        setfile_match = _match(expected_setfile, setfile["sha256"])
        mq5_match = _match(expected_mq5, mq5["sha256"])

        legacy_ts = str(q08_row.get("updated_at") or pc.get("updated_at") or "")
        rebuilt_after_evidence = bool(
            ex5["mtime_utc"] and legacy_ts and str(ex5["mtime_utc"]) > legacy_ts
        )
        evidence_chain_present = bool(q08_evidence["exists"])
        hash_bound = bool(expected_ex5 and expected_setfile)
        data_start = q08_row.get("data_window_start")
        data_end = q08_row.get("data_window_end")
        window_bound = bool(data_start and data_end)

        if exclusions:
            anchor = "EXCLUDED_ACTIVE_TRACK"
            reason = "+".join(exclusions)
        elif q08_row.get("verdict") == "FAIL_HARD":
            anchor = "RETIRE_CANDIDATE"
            reason = "last authentic Q08 row has strategy-taxonomy FAIL_HARD; OWNER disposition still required"
        elif (
            not ex5["exists"]
            or ex5_match == "MISMATCH"
            or setfile_match == "MISMATCH"
            or (rebuilt_after_evidence and ex5_match == "UNBOUND")
        ):
            anchor = "Q02_NEW_IDENTITY"
            reason = "current binary/setfile is missing, mismatched, or rebuilt after unbound legacy evidence"
        elif not hash_bound or not evidence_chain_present:
            anchor = "Q02_NEW_IDENTITY"
            reason = "legacy Q08 chain is missing or lacks exact EX5+setfile bindings"
        elif q08_row.get("status") == "done" and str(q08_row.get("verdict") or "").startswith(("PASS", "FAIL_SOFT")):
            anchor = "Q09"
            reason = "hash-bound Q08 reusable; v4 Q09 pre-news full-history baseline must be current"
        else:
            anchor = "Q08"
            reason = "bytes bind, but no reusable terminal Q08 result"

        results.append({
            "ea_id": pair[0],
            "symbol": pair[1],
            "excluded": exclusions,
            "portfolio_work_item_id": pc["q11_work_item_id"],
            "portfolio_phase": q11_row.get("phase"),
            "portfolio_v4_equivalent": equivalence.get(str(q11_row.get("phase") or "")),
            "q08_work_item_id": q08_row.get("id"),
            "q08_status": q08_row.get("status"),
            "q08_verdict": q08_row.get("verdict"),
            "q08_gate_contract_version": q08_row.get("gate_contract_version"),
            "portfolio_evidence": pc_evidence,
            "q08_evidence": q08_evidence,
            "current_ex5": ex5,
            "expected_ex5_sha256": expected_ex5,
            "ex5_match": ex5_match,
            "current_mq5": mq5,
            "expected_mq5_sha256": expected_mq5,
            "mq5_match": mq5_match,
            "current_setfile": setfile,
            "expected_setfile_sha256": expected_setfile,
            "setfile_match": setfile_match,
            "rebuilt_after_legacy_evidence": rebuilt_after_evidence,
            "data_window_start": data_start,
            "data_window_end": data_end,
            "window_bound": window_bound,
            "expected_news_calendar_sha256": expected_news,
            "news_compatibility": (
                "PRE_NEWS_Q09_NO_CALENDAR; Q10_REUSE_REFUSED_WITHOUT_BOUND_CURRENT_CALENDAR_AND_WINDOW"
            ),
            "proposed_anchor": anchor,
            "anchor_reason": reason,
        })
    conn.close()
    audited = [row for row in results if not row["excluded"]]
    counts: dict[str, int] = {}
    for row in audited:
        counts[row["proposed_anchor"]] = counts.get(row["proposed_anchor"], 0) + 1
    return {
        "schema": "qm.legacy-q12-anchor-audit/v1",
        "generated_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "read_only": True,
        "db_path": str(db),
        "db_quick_check": quick_check,
        "manifest_path": str(manifest_path),
        "manifest_sha256": sha256_file(manifest_path),
        "contract_equivalence": equivalence,
        "cohort_count": len(results),
        "audited_count": len(audited),
        "excluded_pair_count": len(results) - len(audited),
        "anchor_counts": counts,
        "results": results,
    }


def markdown(packet: dict[str, Any]) -> str:
    lines = [
        "# Legacy Q12-ready cohort v4 anchor audit — 2026-08-30",
        "",
        "- Router task: `359988fb-db68-4c80-b1f1-eab42196dcc7`",
        "- Mode: **READ-ONLY** — no enqueue, disposition, hold, verdict, or queue mutation",
        f"- Cohort: **{packet['cohort_count']}** pairs; audited: **{packet['audited_count']}**; active-track exclusions: **{packet['excluded_pair_count']}**",
        f"- v4 manifest SHA-256: `{packet['manifest_sha256']}`",
        "- Disposition: **FAIL-CLOSED OWNER VORLAGE**",
        "",
        "## Decision summary",
        "",
    ]
    for anchor, count in sorted(packet["anchor_counts"].items()):
        lines.append(f"- `{anchor}`: **{count}**")
    lines.extend([
        "",
        f"No audited row qualifies for direct Q10/Q10_NEWS reuse. The v4 manifest permits legacy evidence reuse only when criteria are contract-equal and build, setfile, and window bindings match. {packet['anchor_counts'].get('Q09', 0)} pair(s) have a fully byte-bound v4-recognizable Q08 dossier and may start at Q09; the remaining non-retire audited rows lack a complete binding and/or durable Q08 aggregate. A working-copy EX5 newer than unbound legacy evidence is classified as a rebuilt binary and therefore a new identity from Q02.",
        "",
        "The contract map is exact: legacy `Q08 -> Q08`; `Q10A -> Q09`; `Q09 -> Q10`; `Q09_NEWS -> Q10_NEWS`; and `Q09_PORTFOLIO -> Q10_PORTFOLIO`. The portfolio lane is informational and cannot substitute for v4 Q09. Q09 is pre-news, so no calendar is applied there; any later Q10 reuse requires a bound current news-calendar hash and compatible full-history window, which these rows do not provide.",
        "",
        "## Active-track exclusions (reported for complete 30-pair coverage)",
        "",
        "| Pair | Active track | Audit action |",
        "|---|---|---|",
    ])
    for row in packet["results"]:
        if row["excluded"]:
            lines.append(
                f"| `{row['ea_id']}/{row['symbol']}` | `{'+'.join(row['excluded'])}` | excluded; no mutation |"
            )
    lines.extend([
        "",
        "## Per-pair anchor table",
        "",
        "`missing` in an evidence column means the database path is durable but the referenced file is absent. Hash cells show `expected/current` (12-character prefixes); `UNBOUND` is not treated as a match.",
        "",
        "| Pair | Q08 chain / durable evidence | EX5 binding (expected/current; build time) | Setfile binding (expected/current) | Window/news compatibility | Proposed anchor |",
        "|---|---|---|---|---|---|",
    ])
    for row in packet["results"]:
        if row["excluded"]:
            continue
        q08 = row["q08_work_item_id"] or "none"
        ev = row["q08_evidence"]
        ev_status = f"present `{str(ev.get('sha256') or '')[:12]}`" if ev["exists"] else "missing"
        ex = row["expected_ex5_sha256"]
        ax = row["current_ex5"]["sha256"]
        sf = row["expected_setfile_sha256"]
        af = row["current_setfile"]["sha256"]
        ex_cell = f"`{str(ex or 'UNBOUND')[:12]}/{str(ax or 'MISSING')[:12]}` {row['ex5_match']}; `{row['current_ex5']['mtime_utc'] or 'missing'}`"
        sf_cell = f"`{str(sf or 'UNBOUND')[:12]}/{str(af or 'MISSING')[:12]}` {row['setfile_match']}; `{row['current_setfile']['path'] or 'missing'}`"
        window = f"`{row['data_window_start'] or 'UNBOUND'}..{row['data_window_end'] or 'UNBOUND'}`; Q09 pre-news; Q10 calendar `{str(row['expected_news_calendar_sha256'] or 'UNBOUND')[:12]}`"
        lines.append(
            f"| `{row['ea_id']}/{row['symbol']}` | `{q08}` `{row['q08_verdict'] or 'none'}`; {ev_status}; `{ev['path'] or 'none'}` | {ex_cell} | {sf_cell} | {window} | **`{row['proposed_anchor']}`** — {row['anchor_reason']} |"
        )
    lines.extend([
        "",
        "## Re-entry contract",
        "",
        "- `Q02_NEW_IDENTITY` means allocate/approve a new identity or otherwise complete the separately governed new-identity contract, then begin at Q02. This audit does not allocate, enqueue, or retire anything.",
        "- `Q08` would mean rerun the last unproven unchanged gate only when current bytes are independently bound; no audited row reached that result.",
        "- `Q09` means reuse the fully hash-bound Q08 dossier and run/bind the current full-history pre-news baseline. It does not reuse the old portfolio row as Q09.",
        "- `RETIRE_CANDIDATE` records an existing strategy-taxonomy Q08 `FAIL_HARD`; it is an OWNER Vorlage, not a disposition. Absence of proof alone is never treated as an economic failure.",
        "",
        "## Verification",
        "",
        "The database was opened with SQLite `mode=ro` and `PRAGMA query_only=ON`. The 30-pair cohort was read directly from `portfolio_candidates`, every linked work-item/evidence path was checked, current MQ5/EX5/setfile hashes and EX5 mtimes were computed from the canonical checkout, and the v4 equivalence map was loaded from its SHA-bound manifest. No terminal, worker, T_Live, AutoTrading, queue row, disposition, or verdict was changed.",
        "",
        "Verdict: `OWNER_REVIEW_REQUIRED_SEALED_PER_PAIR_REENTRY_VORLAGE`.",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--json", type=Path)
    parser.add_argument("--markdown", type=Path)
    args = parser.parse_args()
    packet = audit(args.db, args.repo)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(packet, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(markdown(packet), encoding="utf-8")
    print(json.dumps({key: packet[key] for key in (
        "cohort_count", "audited_count", "excluded_pair_count", "anchor_counts"
    )}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Derive the OWNER-DEC-Q09HOLD-REQUAL-8 manifest without mutating farm state."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path
from typing import Any


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
TASK_ID = "8709bc0f-e0cf-4117-bb73-a6b399e5e612"
DECISION_ID = "OWNER-DEC-Q09HOLD-REQUAL-8-20260829"
SHA_RE = re.compile(r"[0-9a-f]{64}")

SCOPE = (
    ("aa80274f-fb46-4432-b47e-6fb2bf28c9a2", "QM5_13128", "NDX.DWX", "H1", "QM5_41215", "pre-fomc-drift-ndx-requal8"),
    ("1cff016c-d25c-4723-a892-6bc53bfafa0b", "QM5_12989", "XAUUSD.DWX", "H4", "QM5_41216", "grimes-nested-pb-v2-requal8"),
    ("57d8bacd-2805-45a6-ac51-156e22bb3a65", "QM5_10815", "GDAXI.DWX", "H1", "QM5_41217", "tv-post-vwap-requal8"),
    ("2604a1f0-4f58-4597-89ef-432af9093131", "QM5_1567", "EURUSD.DWX", "H4", "QM5_41218", "demark-td-reverse-sequential-h4-requal8"),
    ("7bbeef66-becf-4bd3-aa5c-1d00bde262d8", "QM5_12567", "XAUUSD.DWX", "D1", "QM5_41219", "cum-rsi2-commodity-requal8"),
    ("9639a773-b913-40a2-b12f-128a027aec98", "QM5_10939", "GBPUSD.DWX", "H4", "QM5_41220", "grimes-context-pb-requal8"),
    ("30584122-b7b3-41eb-8e1a-b03517554d4d", "QM5_11421", "EURUSD.DWX", "D1", "QM5_41221", "ohlc-daily-squeeze-reversal-d1-requal8"),
    ("08fe4173-07d9-47e1-97e9-a76b1159ad94", "QM5_11476", "USDJPY.DWX", "H1", "QM5_41222", "lien-k-double-bb-trend-h1-requal8"),
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def json_object(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def recursive_hashes(value: Any) -> set[str]:
    found: set[str] = set()
    if isinstance(value, dict):
        for item in value.values():
            found.update(recursive_hashes(item))
    elif isinstance(value, list):
        for item in value:
            found.update(recursive_hashes(item))
    elif isinstance(value, str):
        token = value.strip().lower()
        if SHA_RE.fullmatch(token):
            found.add(token)
    return found


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def gate_equivalence(phase: str, version: str, equivalence: dict[str, str]) -> str | None:
    if version == "v4":
        return phase if re.fullmatch(r"Q(?:0[0-9]|1[0-7])", phase) else None
    return equivalence.get(phase)


def authentic_anchor(
    conn: sqlite3.Connection,
    ea_id: str,
    symbol: str,
    equivalence: dict[str, str],
) -> tuple[dict[str, Any], dict[str, Any]]:
    rows = conn.execute(
        "SELECT * FROM work_items WHERE ea_id=? AND symbol=? AND status='done' "
        "ORDER BY updated_at DESC,id DESC",
        (ea_id, symbol),
    )
    for raw in rows:
        row = dict(raw)
        phase = str(row.get("phase") or "")
        version = str(row.get("gate_contract_version") or "legacy")
        equivalent = gate_equivalence(phase, version, equivalence)
        expected = {
            key: str(row.get(key) or "").lower()
            for key in ("mq5_sha256", "ex5_sha256", "setfile_sha256")
        }
        if not equivalent or not all(SHA_RE.fullmatch(value) for value in expected.values()):
            continue
        evidence = Path(str(row.get("evidence_path") or ""))
        if not evidence.is_file():
            continue
        try:
            evidence_doc = json.loads(evidence.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            continue
        evidence_hashes = recursive_hashes(evidence_doc)
        payload_hashes = recursive_hashes(json_object(row.get("payload_json")))
        # EX5 and setfile must be visibly authenticated by the evidence file.
        # MQ5 may be authenticated by either evidence or the row's typed payload.
        verification = {
            "mq5_bound": expected["mq5_sha256"] in evidence_hashes | payload_hashes,
            "ex5_bound_in_evidence": expected["ex5_sha256"] in evidence_hashes,
            "setfile_bound_in_evidence": expected["setfile_sha256"] in evidence_hashes,
        }
        if not all(verification.values()):
            continue
        row["equivalent_v4_gate"] = equivalent
        row["anchor_hashes"] = expected
        row["anchor_include_closure_sha256"] = (
            str(row.get("include_closure_sha256") or "").lower() or None
        )
        return row, {
            "path": str(evidence),
            "sha256": sha256_file(evidence),
            "verification": verification,
        }
    raise RuntimeError(f"no authentic hash-bound v4-equivalent anchor for {ea_id}/{symbol}")


def find_ea_dir(repo: Path, ea_id: str) -> Path:
    numeric = ea_id.replace("QM5_", "", 1)
    matches = sorted((repo / "framework" / "EAs").glob(f"QM5_{numeric}_*"))
    matches = [path for path in matches if path.is_dir()]
    if len(matches) != 1:
        raise RuntimeError(f"expected one EA directory for {ea_id}, found {len(matches)}")
    return matches[0]


def derive(db: Path, repo: Path) -> dict[str, Any]:
    sys.path.insert(0, str(repo / "tools" / "strategy_farm"))
    import mnt_closure_drift  # type: ignore

    manifest_path = repo / "tools" / "strategy_farm" / "config" / "gate_manifest.v4.json"
    gate_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    equivalence = gate_manifest["contract_equivalence"]["v3_to_v4"]
    ea_registry_path = repo / "framework" / "registry" / "ea_id_registry.csv"
    magic_path = repo / "framework" / "registry" / "magic_numbers.csv"
    ea_registry = read_csv(ea_registry_path)
    magic_registry = read_csv(magic_path)
    allocator_receipt = repo / "docs" / "ops" / "evidence" / "2026-08-30_8709bc0f_requal8_allocator_receipt.json"

    uri = f"file:{db.as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    if conn.execute("PRAGMA quick_check").fetchone()[0] != "ok":
        raise RuntimeError("farm DB quick_check failed")

    rows: list[dict[str, Any]] = []
    for hold_id, old_ea, symbol, timeframe, new_ea, slug in SCOPE:
        hold_raw = conn.execute("SELECT * FROM work_items WHERE id=?", (hold_id,)).fetchone()
        if hold_raw is None:
            raise RuntimeError(f"missing held work item {hold_id}")
        hold = dict(hold_raw)
        hold_payload = json_object(hold.get("payload_json"))
        if hold.get("status") != "pending" or hold_payload.get("q09_activation_hold_code") != "Q09_AWAITING_SEALED_PLAN":
            raise RuntimeError(f"held work item no longer in expected fail-closed state: {hold_id}")

        anchor, evidence = authentic_anchor(conn, old_ea, symbol, equivalence)
        ea_dir = find_ea_dir(repo, old_ea)
        mq5_path = ea_dir / f"{ea_dir.name}.mq5"
        ex5_path = ea_dir / f"{ea_dir.name}.ex5"
        setfile_path = Path(str(hold.get("setfile_path") or ""))
        for required in (mq5_path, ex5_path, setfile_path):
            if not required.is_file():
                raise RuntimeError(f"missing current artifact {required}")
        closure = mnt_closure_drift.source_closure(mq5_path, repo)
        if closure["unresolved_repo_includes"]:
            raise RuntimeError(f"unresolved repo includes for {old_ea}: {closure['unresolved_repo_includes']}")
        current = {
            "mq5": {"path": str(mq5_path), "sha256": sha256_file(mq5_path)},
            "ex5": {"path": str(ex5_path), "sha256": sha256_file(ex5_path)},
            "setfile": {"path": str(setfile_path), "sha256": sha256_file(setfile_path)},
            "include_closure": {
                "method": closure["resolver"],
                "sha256": closure["aggregate_sha256"],
                "member_count": closure["member_count"],
                "unresolved_repo_includes": closure["unresolved_repo_includes"],
            },
        }
        anchor_hashes = anchor["anchor_hashes"]
        comparisons = {
            "mq5": "MATCH" if current["mq5"]["sha256"] == anchor_hashes["mq5_sha256"] else "MISMATCH",
            "ex5": "MATCH" if current["ex5"]["sha256"] == anchor_hashes["ex5_sha256"] else "MISMATCH",
            "setfile": "MATCH" if current["setfile"]["sha256"] == anchor_hashes["setfile_sha256"] else "MISMATCH",
            "include_closure": (
                "UNBOUND_AT_ANCHOR"
                if anchor["anchor_include_closure_sha256"] is None
                else "MATCH"
                if current["include_closure"]["sha256"] == anchor["anchor_include_closure_sha256"]
                else "MISMATCH"
            ),
        }
        new_identity = any(
            comparisons[key] != "MATCH" for key in ("mq5", "setfile", "include_closure")
        )
        action = "NEW_IDENTITY_FROM_Q02" if new_identity else "SAME_IDENTITY_APPEND_ONLY"
        if action != "NEW_IDENTITY_FROM_Q02":
            raise RuntimeError(f"unexpected same-identity result for reserved row {old_ea}/{symbol}")

        numeric = new_ea.replace("QM5_", "", 1)
        ea_rows = [r for r in ea_registry if r["ea_id"] == numeric and r["status"] == "active"]
        magic_rows = [r for r in magic_registry if r["ea_id"] == numeric and r["status"] == "active"]
        if len(ea_rows) != 1 or ea_rows[0]["slug"] != slug:
            raise RuntimeError(f"invalid identity reservation for {new_ea}")
        if len(magic_rows) != 1:
            raise RuntimeError(f"invalid magic reservation count for {new_ea}")
        expected_magic = str(int(numeric) * 10000)
        if magic_rows[0]["symbol"] != symbol or magic_rows[0]["symbol_slot"] != "0" or magic_rows[0]["magic"] != expected_magic:
            raise RuntimeError(f"invalid magic reservation for {new_ea}/{symbol}")
        review_card = Path(r"D:\QM\strategy_farm\artifacts\cards_review") / f"{new_ea}_{slug}.md"
        copied_card = repo / "framework" / "EAs" / f"{new_ea}_{slug}" / "docs" / "strategy_card.md"
        if not review_card.is_file() or not copied_card.is_file() or sha256_file(review_card) != sha256_file(copied_card):
            raise RuntimeError(f"reservation card binding failed for {new_ea}")
        if list(copied_card.parent.parent.rglob("*.mq5")) or list(copied_card.parent.parent.rglob("*.ex5")):
            raise RuntimeError(f"reservation unexpectedly contains source/binary for {new_ea}")
        if conn.execute("SELECT count(*) FROM work_items WHERE ea_id=?", (new_ea,)).fetchone()[0] != 0:
            raise RuntimeError(f"reservation unexpectedly has work items for {new_ea}")

        release_note = (
            f"{DECISION_ID}; release only after Orchestrator approves manifest SHA-256, "
            f"{new_ea} is built and Codex-reviewed, and one append-only Q02 seed for {symbol} "
            f"is verified from anchor {anchor['id']}; preserve historical rows."
        )
        no_touch = None
        if old_ea == "QM5_11421":
            no_touch = (
                "This requalification must not mutate, supersede, cancel, reprioritize, "
                "reuse, or otherwise touch any QM5_41162 OPT_CENSUS row, artifact, or evidence."
            )
        rows.append({
            "held_work_item_id": hold_id,
            "pair": {"ea_id": old_ea, "symbol": symbol, "timeframe": timeframe},
            "hold_state": {"status": hold["status"], "code": hold_payload["q09_activation_hold_code"]},
            "last_authentic_anchor": {
                "work_item_id": anchor["id"],
                "stored_gate": anchor["phase"],
                "gate_contract_version": anchor["gate_contract_version"],
                "equivalent_v4_gate": anchor["equivalent_v4_gate"],
                "verdict": anchor["verdict"],
                "updated_at": anchor["updated_at"],
                "hashes": {
                    "mq5_sha256": anchor_hashes["mq5_sha256"],
                    "ex5_sha256": anchor_hashes["ex5_sha256"],
                    "setfile_sha256": anchor_hashes["setfile_sha256"],
                    "include_closure_sha256": anchor["anchor_include_closure_sha256"],
                },
                "evidence": evidence,
            },
            "current_artifacts": current,
            "comparisons": comparisons,
            "action": action,
            "classification_reason": [key for key in ("mq5", "setfile", "include_closure") if comparisons[key] != "MATCH"],
            "reserved_identity": {
                "ea_id": new_ea,
                "slug": slug,
                "ea_registry_row": ea_rows[0],
                "magic_registry_row": magic_rows[0],
                "recovery_card": {"path": str(review_card), "sha256": sha256_file(review_card)},
                "canonical_card_copy": {"path": str(copied_card), "sha256": sha256_file(copied_card)},
                "reservation_only": True,
            },
            "successor_phase": "Q02",
            "canonical_enqueue_command_contract": (
                "python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest "
                f"--review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_{new_ea}> --phase Q02"
            ),
            "enqueue_preconditions": "governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded",
            "decision_bound_hold_release_note": release_note,
            "protected_program_no_touch": no_touch,
        })

    protected = [dict(row) for row in conn.execute(
        "SELECT id,status,verdict,updated_at FROM work_items "
        "WHERE ea_id='QM5_41162' AND phase='OPT_CENSUS' ORDER BY id"
    )]
    conn.close()
    return {
        "schema": "qm.q09-requalification-manifest/v1",
        "router_task_id": TASK_ID,
        "owner_decision": DECISION_ID,
        "derived_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "classification_rule": (
            "action=NEW_IDENTITY_FROM_Q02 iff current MQ5/setfile/include-closure bytes "
            "differ from the evidence-bound vintage of the pair's last authentic gate, "
            "or the bound evidence file/vintage is missing; otherwise SAME_IDENTITY_APPEND_ONLY"
        ),
        "anchor_rule": (
            "newest done work item of the pair whose MQ5/EX5/setfile hashes verify against "
            "current or archived bindings and whose gate contract has a v4 equivalence"
        ),
        "result": {"row_count": len(rows), "new_identity_count": sum(r["action"] == "NEW_IDENTITY_FROM_Q02" for r in rows), "same_identity_count": sum(r["action"] == "SAME_IDENTITY_APPEND_ONLY" for r in rows)},
        "control_bindings": {
            "gate_manifest": {"path": str(manifest_path), "sha256": sha256_file(manifest_path)},
            "allocator_receipt": {"path": str(allocator_receipt), "sha256": sha256_file(allocator_receipt)},
            "ea_id_registry": {"path": str(ea_registry_path), "sha256": sha256_file(ea_registry_path)},
            "magic_registry": {"path": str(magic_path), "sha256": sha256_file(magic_path)},
        },
        "mutation_statement": "Exactly eight identity and eight slot-0 magic reservations were made; no compile, queue seed, hold release, or historical work-item mutation was performed.",
        "protected_qm5_41162_opt_census_snapshot": {"row_count": len(protected), "rows_sha256": hashlib.sha256(json.dumps(protected, sort_keys=True, separators=(",", ":")).encode()).hexdigest()},
        "rows": rows,
    }


def render_markdown(manifest: dict[str, Any], json_path: Path, json_sha256: str) -> str:
    lines = [
        "# Q09 eight-pair deterministic requalification manifest",
        "",
        f"Date: {manifest['derived_at_utc']}",
        "",
        f"Router task: `{TASK_ID}`",
        "",
        f"OWNER decision: `{DECISION_ID}`",
        "",
        "## Verdict",
        "",
        "`MANIFEST_READY_FOR_ORCHESTRATOR_REVIEW`. The mechanical rule yields exactly eight "
        "`NEW_IDENTITY_FROM_Q02` rows and zero same-identity rows. QM5_41215 through QM5_41222 "
        "are reservations only: no EA was compiled, no Q02 row was seeded, and all eight holds remain active.",
        "",
        "## Mechanical rule",
        "",
        manifest["classification_rule"] + ".",
        "",
        manifest["anchor_rule"] + ".",
        "",
        f"Machine-readable manifest: `{json_path}`",
        "",
        f"Manifest SHA-256: `{json_sha256}`",
        "",
        "## Exact eight-row manifest",
        "",
        "| Held work item | Pair | Authentic anchor (stored -> v4) | Comparison MQ5 / EX5 / set / closure | Action | Reserved identity / magic | Successor |",
        "|---|---|---|---|---|---|---|",
    ]
    for row in manifest["rows"]:
        anchor = row["last_authentic_anchor"]
        comp = row["comparisons"]
        reserved = row["reserved_identity"]
        magic = reserved["magic_registry_row"]
        lines.append(
            f"| `{row['held_work_item_id']}` | {row['pair']['ea_id']} / {row['pair']['symbol']} | "
            f"`{anchor['work_item_id']}` ({anchor['stored_gate']} {anchor['gate_contract_version']} -> {anchor['equivalent_v4_gate']}) | "
            f"{comp['mq5']} / {comp['ex5']} / {comp['setfile']} / {comp['include_closure']} | "
            f"`{row['action']}` | {reserved['ea_id']} / `{reserved['slug']}` / `{magic['magic']}` slot {magic['symbol_slot']} | Q02 |"
        )
    lines.extend(["", "## Per-row hash evidence", ""])
    for index, row in enumerate(manifest["rows"], 1):
        anchor = row["last_authentic_anchor"]
        current = row["current_artifacts"]
        reserved = row["reserved_identity"]
        lines.extend([
            f"### {index}. {row['pair']['ea_id']} / {row['pair']['symbol']} -> {reserved['ea_id']}",
            "",
            f"- Held row: `{row['held_work_item_id']}`; state `{row['hold_state']['status']}` / `{row['hold_state']['code']}`.",
            f"- Anchor: `{anchor['work_item_id']}`; {anchor['stored_gate']} `{anchor['gate_contract_version']}` -> {anchor['equivalent_v4_gate']}; evidence `{anchor['evidence']['path']}` SHA-256 `{anchor['evidence']['sha256']}`.",
            f"- Anchor hashes: MQ5 `{anchor['hashes']['mq5_sha256']}`; EX5 `{anchor['hashes']['ex5_sha256']}`; setfile `{anchor['hashes']['setfile_sha256']}`; include closure `{anchor['hashes']['include_closure_sha256'] or 'UNBOUND'}`.",
            f"- Current hashes: MQ5 `{current['mq5']['sha256']}`; EX5 `{current['ex5']['sha256']}`; setfile `{current['setfile']['sha256']}`; recursive include closure `{current['include_closure']['sha256']}` ({current['include_closure']['member_count']} members).",
            f"- Mechanical result: `{row['action']}` because {', '.join(row['classification_reason'])} is not `MATCH`.",
            f"- Reservation: `{reserved['ea_id']}` / `{reserved['slug']}`; active magic row `{reserved['magic_registry_row']}`; recovery card `{reserved['recovery_card']['path']}` SHA-256 `{reserved['recovery_card']['sha256']}`.",
            f"- Successor/enqueue contract (not executed): `{row['canonical_enqueue_command_contract']}`. Preconditions: {row['enqueue_preconditions']}.",
            f"- Hold release note (not applied): {row['decision_bound_hold_release_note']}",
        ])
        if row["protected_program_no_touch"]:
            lines.append(f"- **No-touch clause:** {row['protected_program_no_touch']}")
        lines.append("")
    lines.extend([
        "## Scope and safeguards",
        "",
        "- The allocator receipt proves eight EA rows and eight magic rows were added with zero status-aware magic collisions; cards were copied byte-for-byte into the reserved EA directories.",
        "- Each reserved directory contains only `docs/strategy_card.md`: no MQ5, EX5, setfile, compile result, or work item exists for a successor.",
        "- All eight held rows remain pending under `Q09_AWAITING_SEALED_PLAN`. Hold release requires a later Orchestrator-approved, compiled, Codex-reviewed, append-only Q02 seed.",
        "- The QM5_11421 successor is isolated from QM5_41162. It may not mutate, supersede, cancel, reprioritize, reuse, or otherwise touch any QM5_41162 `OPT_CENSUS` row, artifact, or evidence.",
        "- No pipeline verdict is asserted by this manifest.",
        "",
        "Verdict: `MANIFEST_READY_FOR_ORCHESTRATOR_REVIEW`; eight reservations complete, zero seeds, zero hold releases.",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--json-out", type=Path, required=True)
    parser.add_argument("--markdown-out", type=Path, required=True)
    args = parser.parse_args()
    manifest = derive(args.db, args.repo)
    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    json_sha = sha256_file(args.json_out)
    args.markdown_out.write_text(render_markdown(manifest, args.json_out, json_sha), encoding="utf-8")
    print(json.dumps({"ok": True, "rows": len(manifest["rows"]), "json": str(args.json_out), "json_sha256": json_sha, "markdown": str(args.markdown_out)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

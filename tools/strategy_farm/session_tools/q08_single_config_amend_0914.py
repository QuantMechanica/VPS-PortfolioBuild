"""Governed card amendment: append the ``qm-dsr-single-configuration`` declaration (class A of
OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914; OWNER 2026-09-14 "ABC & D freigegeben zur Umsetzung").

For every class-A Q08 row the EA has an APPROVED card, was never censused (no sealed DL-089 search
ledger) and carries exactly one configuration: the card defaults overlaid by the row's set file.  The
declaration therefore states the truth the DSR n=1 contract asks for (complete, no optimisation search,
research_trial_count 0) and locks ``spec_sha256`` (SPEC.md) plus ``locked_parameters`` (source defaults +
set file, exactly as dsr_single_configuration.effective_parameters computes them).

Per row the tool resolves label/card/spec/mq5/ex5/set file the way dsr_cohort.assemble_single_configuration
does, builds the block, and validates OFFLINE with the contract's own functions
(dsr_single_configuration.declaration + validate against the current build identity) before touching any
card.  Apply appends ONE amendment section (append-only; a card that already carries a block is refused)
to the D: card (the assembler's source of truth) and mirrors the identical bytes to the C: copy when it
exists; every change is journaled with before/after hashes.  Default = dry-run.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import sqlite3
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO))
os.chdir(REPO)
import dsr_cohort  # noqa: E402
import dsr_single_configuration as single  # noqa: E402

DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
CARDS_D = Path("D:/QM/strategy_farm/artifacts/cards_approved")
CARDS_C = REPO / "artifacts" / "cards_approved"
EVID = REPO / "docs" / "ops" / "evidence" / "2026-09-14_q08_context_repair"
JOURNAL = EVID / "card_amend_journal.jsonl"
DECISION_ID = "OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914"
RECEIPT_ID = "3415f6c0"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resolve(row: sqlite3.Row, replacement: dict[str, str]) -> dict:
    payload = json.loads(row["payload_json"] or "{}")
    setfile = Path(replacement.get(row["ea_id"]) or row["setfile_path"])
    ea_dir = setfile.parent.parent
    label = ea_dir.name
    timeframe = None
    try:
        timeframe = dsr_cohort._timeframe(dict(row), payload)
    except Exception:
        import re
        m = re.search(r"_(M1|M5|M15|M30|H1|H4|D1|W1)_", setfile.name)
        timeframe = m.group(1) if m else None
    return {
        "row": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"], "timeframe": timeframe, "label": label,
        "card_d": CARDS_D / (label + ".md"), "card_c": CARDS_C / (label + ".md"),
        "spec": ea_dir / "SPEC.md", "mq5": ea_dir / (label + ".mq5"), "ex5": ea_dir / (label + ".ex5"), "setfile": setfile,
    }


def build_block(info: dict) -> dict:
    locked = single.effective_parameters(info["mq5"].read_bytes(), info["setfile"].read_bytes())
    return {
        "complete": True,
        "ea_id": info["ea_id"],
        "locked_parameters": dict(sorted(locked.items())),
        "no_optimization_search": True,
        "research_trial_count": 0,
        "schema": single.DECLARATION,
        "spec_sha256": sha(info["spec"]),
        "symbol": info["symbol"],
        "timeframe": info["timeframe"],
    }


def amendment_text(block: dict, info: dict) -> str:
    return (
        "\n\n## Approved Amendment (2026-09-14) — DSR Single Configuration\n\n"
        f"- Authority: `{DECISION_ID}`, OWNER receipt `{RECEIPT_ID}…` (YES: \"ABC & D freigegeben zur Umsetzung\").\n"
        "- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.\n"
        f"- This declaration locks the exact {info['symbol']}/{info['timeframe']} configuration used by Q08 (set file `{info['setfile'].name}`). It changes no strategy mechanics, threshold, or stored verdict.\n\n"
        "```qm-dsr-single-configuration\n" + json.dumps(block, indent=2, sort_keys=True) + "\n```\n"
    )


def offline_validate(info: dict, new_card: bytes) -> tuple[bool, str]:
    try:
        single.declaration(new_card)
    except ValueError as exc:
        return False, f"declaration:{exc}"
    provenance = {"card": {"path": "MEMORY", "sha256": hashlib.sha256(new_card).hexdigest()}}
    # validate() reads bindings from disk; emulate with the future card bytes by validating the parts it checks
    try:
        decl = single.declaration(new_card)
        candidate = {"ea_id": info["ea_id"], "symbol": info["symbol"], "timeframe": info["timeframe"]}
        if {k: decl.get(k) for k in ("ea_id", "symbol", "timeframe")} != candidate:
            return False, "candidate mismatch"
        if decl.get("spec_sha256") != sha(info["spec"]):
            return False, "spec sha mismatch"
        if decl["locked_parameters"] != single.effective_parameters(info["mq5"].read_bytes(), info["setfile"].read_bytes()):
            return False, "locked parameter drift"
    except Exception as exc:
        return False, f"validate:{exc}"
    return True, "ok"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows", required=True, help="comma-separated work item id prefixes (class A rows)")
    ap.add_argument("--replacement-set", action="append", default=[], help="EA_ID=<path to the versioned set file> (regenerated baselines)")
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    replacement = dict(x.split("=", 1) for x in args.replacement_set)
    conn = sqlite3.connect(DB_RO, uri=True, timeout=60)
    conn.row_factory = sqlite3.Row
    seen_ea: set[str] = set()
    ok_n = skip_n = fail_n = 0
    for prefix in [x.strip() for x in args.rows.split(",") if x.strip()]:
        row = conn.execute("SELECT * FROM work_items WHERE id LIKE ?", (prefix + "%",)).fetchone()
        if row is None:
            print("MISSING", prefix); fail_n += 1; continue
        info = resolve(row, replacement)
        tag = f"{prefix} {info['label']} {info['symbol']} {info['timeframe']}"
        if info["ea_id"] in seen_ea:
            print("SKIP  ", tag, "(EA already handled; one declaration per card)"); skip_n += 1; continue
        seen_ea.add(info["ea_id"])
        missing = [k for k in ("spec", "mq5", "ex5", "setfile") if not info[k].is_file()]
        card_path = info["card_d"]
        if not card_path.is_file():
            print("FAIL  ", tag, "card missing on D:", card_path.name); fail_n += 1; continue
        if missing or not info["timeframe"]:
            print("FAIL  ", tag, "missing", missing, "timeframe", info["timeframe"]); fail_n += 1; continue
        card_bytes = card_path.read_bytes()
        if b"qm-dsr-single-configuration" in card_bytes:
            print("SKIP  ", tag, "card already declares a single configuration"); skip_n += 1; continue
        block = build_block(info)
        new_card = card_bytes.rstrip(b"\r\n") + amendment_text(block, info).encode("utf-8")
        valid, why = offline_validate(info, new_card)
        if not valid:
            print("FAIL  ", tag, why); fail_n += 1; continue
        mirror = info["card_c"] if info["card_c"].is_file() else None
        print(("APPLY " if args.apply else "DRY   "), tag, f"params={len(block['locked_parameters'])} set={info['setfile'].name} mirrorC={bool(mirror)}")
        if not args.apply:
            ok_n += 1; continue
        before = hashlib.sha256(card_bytes).hexdigest()
        card_path.write_bytes(new_card)
        after = sha(card_path)
        if mirror is not None:
            mirror.write_bytes(new_card)
        EVID.mkdir(parents=True, exist_ok=True)
        with JOURNAL.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps({"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "row": row["id"], "ea_id": info["ea_id"], "symbol": info["symbol"],
                                 "timeframe": info["timeframe"], "card_d": str(card_path), "card_c": str(mirror) if mirror else None,
                                 "card_sha_before": before, "card_sha_after": after, "spec_sha256": block["spec_sha256"],
                                 "setfile": str(info["setfile"]), "setfile_sha256": sha(info["setfile"]), "locked_parameter_count": len(block["locked_parameters"]),
                                 "decision_id": DECISION_ID, "receipt_id_prefix": RECEIPT_ID}) + "\n")
        ok_n += 1
    print(f"ok {ok_n} skipped {skip_n} failed {fail_n} mode {'apply' if args.apply else 'dry-run'}")
    return 0 if fail_n == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

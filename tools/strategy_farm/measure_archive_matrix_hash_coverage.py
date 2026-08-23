"""One-off measurement for STRATEGY_ARCHIVE_MATRIX_SPEC_2026-08-23 F4/step 1.

Read-only. For the latest row per (ea_id, symbol, base-Qxx-phase) triple in
work_items_clean, checks whether the row records the ex5 hash it ran against
(``expected_ex5_sha256`` / ``expected_current_ex5_sha256`` in payload_json),
and if so whether that hash still matches the EA's current on-disk .ex5. This
decides F4: (b) stale-pass-hollow marker needs coverage; if coverage is poor,
the matrix falls back to (a) latest-verdict-wins with a visible warning.

Usage: python tools/strategy_farm/measure_archive_matrix_hash_coverage.py
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from work_item_clean_view import open_clean_view_connection  # noqa: E402

DB_PATH = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
EA_ROOT = REPO_ROOT / "framework" / "EAs"


def phase_base(phase: str) -> str:
    if not phase:
        return ""
    s = str(phase)
    if s.startswith("Q") and len(s) >= 3 and s[1:3].isdigit():
        return s[:3]
    if s == "P2":
        return "Q02"
    return ""


def current_ex5_sha256_by_ea() -> dict[str, str]:
    out: dict[str, str] = {}
    for ea_dir in EA_ROOT.iterdir():
        if not ea_dir.is_dir():
            continue
        ea_id = ea_dir.name.split("_", 2)
        if len(ea_id) < 2 or not ea_id[0].startswith("QM5"):
            continue
        canonical = "_".join(ea_id[:2])
        ex5s = sorted(ea_dir.glob("*.ex5"))
        if not ex5s:
            continue
        # canonical build is the ex5 matching the ea_dir name (not a symbol variant)
        target = ea_dir / f"{ea_dir.name}.ex5"
        f = target if target.exists() else ex5s[0]
        out[canonical] = hashlib.sha256(f.read_bytes()).hexdigest()
    return out


def main() -> int:
    conn = open_clean_view_connection(DB_PATH)
    try:
        cur = conn.execute(
            "SELECT ea_id, phase, symbol, status, verdict, updated_at, payload_json "
            "FROM work_items_clean WHERE ea_id IS NOT NULL AND symbol IS NOT NULL AND symbol != ''"
        )
        latest: dict[tuple[str, str, str], dict] = {}
        for ea_id, phase, symbol, status, verdict, updated_at, payload_json in cur:
            base = phase_base(phase)
            if base not in {f"Q{n:02d}" for n in range(2, 14)}:
                continue
            key = (ea_id, symbol, base)
            upd = updated_at or ""
            row = latest.get(key)
            if row is None or upd > row["upd"]:
                latest[key] = {
                    "upd": upd, "status": status, "verdict": verdict,
                    "payload_json": payload_json,
                }
    finally:
        conn.close()

    total = len(latest)
    with_hash = 0
    matched = 0
    stale = 0
    unresolved_ea = 0
    current_hash = current_ex5_sha256_by_ea()

    rows_out = []
    for (ea_id, symbol, base), row in latest.items():
        pj = row["payload_json"]
        expected = None
        if pj:
            try:
                parsed = json.loads(pj)
            except Exception:
                parsed = {}
            expected = parsed.get("expected_current_ex5_sha256") or parsed.get("expected_ex5_sha256")
        if not expected:
            continue
        with_hash += 1
        cur_hash = current_hash.get(ea_id)
        if cur_hash is None:
            unresolved_ea += 1
            continue
        if cur_hash == expected:
            matched += 1
        else:
            stale += 1
            rows_out.append((ea_id, symbol, base, row["verdict"], row["upd"], expected[:16], cur_hash[:16]))

    print(f"schema=qm.archive_matrix_hash_coverage.v1")
    print(f"cells_total_Q02_Q13={total}")
    print(f"cells_with_expected_hash={with_hash}")
    print(f"coverage_pct={round(100.0 * with_hash / total, 2) if total else 0.0}")
    print(f"ea_current_hash_unresolved={unresolved_ea}")
    print(f"matched_current_build={matched}")
    print(f"stale_pass_vs_rebuilt_ex5={stale}")
    print(f"eas_with_current_hash_indexed={len(current_hash)}")

    out_path = REPO_ROOT / "docs" / "ops" / "evidence" / "archive_matrix_stale_cells_2026-08-23.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        fh.write("ea_id,symbol,gate,verdict,updated_at,expected_hash_prefix,current_hash_prefix\n")
        for r in sorted(rows_out):
            fh.write(",".join(str(x) for x in r) + "\n")
    print(f"stale_rows_csv={out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

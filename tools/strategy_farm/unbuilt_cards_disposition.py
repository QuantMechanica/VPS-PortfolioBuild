"""MNT-013: bucket the approved-but-unbuilt card backlog so the WARN count means something.

`chk_unbuilt_cards_count` (health.py) reports a single number: approved cards
with no .ex5 and no pending/active build task, restricted to cards that already
pass the R-gate frontmatter check. That number conflates two very different
situations: cards that are genuinely ready and simply waiting for a Codex/build
slot, versus cards whose R3 data-availability claim (asserted at approval time)
no longer holds against the live Custom-history isolation manifest.

This script re-runs the identical enumeration as chk_unbuilt_cards_count, then
for each card that passes the R-gate re-checks `custom_history_archive_admission`
against the *current* archive manifest (the actual runtime authority, which can
drift after a card was approved) and the card's R1 source-lineage quality. It
writes a disposition snapshot so repeated runs make the backlog's drain rate
visible over time.

Buckets:
  READY         — passes R-gate + current archive admission; nothing blocking
                  except build-lane throughput.
  DATA_BLOCKED  — the current Custom-history archive manifest cannot satisfy
                  the card's declared symbol(s); its R3 PASS is stale.
  NEEDS_SOURCE  — buildable (R-gates all pass) but R1 source lineage is weak
                  (UNKNOWN/FAIL/missing track record) — informational per
                  DL-082, not a build blocker, but worth surfacing.

Read-only: does not create build tasks, does not touch cards, work_items, or
the pipeline. Writes one timestamped JSON snapshot to
D:/QM/reports/state/unbuilt_cards_disposition/.

Usage:
    python tools/strategy_farm/unbuilt_cards_disposition.py
"""

from __future__ import annotations

import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import health  # noqa: E402

OUT_DIR = Path(r"D:\QM\reports\state\unbuilt_cards_disposition")
DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")


def _enumerate_unbuilt(con: sqlite3.Connection) -> list[tuple[str, str, Path, dict]]:
    """Same enumeration as health.chk_unbuilt_cards_count: R-gate-ready approved
    cards with no .ex5 and no auto-build task. Returns (ea_id, slug, card_path, fm)."""
    cards_dir = health.ROOT / "artifacts" / "cards_approved"
    out = []
    if not cards_dir.is_dir():
        return out
    for card_md in sorted(cards_dir.glob("QM5_*.md")):
        m = health.re.match(r"(QM5_\d{4,5})_(.+)\.md$", card_md.name)
        if not m:
            continue
        ea_id, slug = m.group(1), m.group(2)
        label = f"{ea_id}_{slug}"
        ex5 = health.FRAMEWORK_EAS_DIR / label / f"{label}.ex5"
        if ex5.exists() or health._has_auto_build_task_file(ea_id) or health._has_auto_build_task(con, ea_id):
            continue
        fm = health._card_frontmatter(card_md)
        # Mirror chk_unbuilt_cards_count exactly (frontmatter-only R-gate check,
        # no card_path) so this script's total matches the health WARN count.
        # The stricter body-vs-frontmatter consistency check is a separate,
        # already-distinct health signal and is not this ticket's scope.
        if not farmctl._card_r_gate_ready(fm):
            continue
        out.append((ea_id, slug, card_md, fm))
    return out


def _classify(ea_id: str, card_path: Path, fm: dict) -> tuple[str, str]:
    """Return (bucket, reason)."""
    numeric_id = ea_id.replace("QM5_", "")
    try:
        admission = farmctl.custom_history_archive_admission(
            farmctl.DEFAULT_ROOT, ea_id=numeric_id, card_path=card_path
        )
    except Exception as exc:  # defensive: a classifier bug must not look like DATA_BLOCKED
        return "CLASSIFY_ERROR", f"admission_check_raised:{exc!r}"
    if not admission.get("ok", True):
        return "DATA_BLOCKED", str(admission.get("reason") or "archive_admission_not_ok")

    r1 = str(fm.get("r1_track_record") or "").strip().upper()
    source_id = str(fm.get("source_id") or "").strip()
    if not source_id:
        return "NEEDS_SOURCE", "source_id_missing"
    if r1 in ("", "UNKNOWN", "FAIL", "TIER_C"):
        return "NEEDS_SOURCE", f"r1_track_record={r1 or 'blank'}"
    return "READY", "r_gates_pass_and_archive_admission_ok"


def main() -> int:
    con = sqlite3.connect(str(DB_PATH))
    try:
        cards = _enumerate_unbuilt(con)
    finally:
        con.close()

    rows = []
    buckets: dict[str, int] = {"READY": 0, "DATA_BLOCKED": 0, "NEEDS_SOURCE": 0, "CLASSIFY_ERROR": 0}
    for ea_id, slug, card_path, fm in cards:
        bucket, reason = _classify(ea_id, card_path, fm)
        buckets[bucket] = buckets.get(bucket, 0) + 1
        rows.append(
            {
                "ea_id": ea_id,
                "slug": slug,
                "card_path": str(card_path),
                "bucket": bucket,
                "reason": reason,
            }
        )

    snapshot = {
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "total_unbuilt": len(rows),
        "buckets": buckets,
        "rows": rows,
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_path = OUT_DIR / f"snapshot_{ts}.json"
    out_path.write_text(json.dumps(snapshot, indent=2), encoding="utf-8")

    print(f"total_unbuilt={len(rows)} buckets={buckets}")
    print(f"-> {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

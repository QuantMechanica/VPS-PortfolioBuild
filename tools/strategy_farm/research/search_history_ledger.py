"""Search-history ledger — pre-committed trial accounting against data snooping.

Append-only JSONL, ``schema: qm.research-search-history/v1`` (design doc sec 6.3,
sec 9). One line per DISCOVER search/experiment, written *before* it runs, so the
winner-only report pattern is structurally impossible — attempts are counted, not
just successes.

Row fields (directive sec 18):
  research_id | campaign_id, hypothesis_family, dataset_id (manifest sha256),
  period, instruments, feature_families, parameter_space_size, holdout_id,
  holdout_touched (bool), outcome, ts (UTC ISO-8601).

EVIDENCE ROLE (design doc sec 6.4, R-C) — critical invariant:
  ``declared_trial_count_for(family)`` is the number of *bites of the apple* the
  research layer took for a hypothesis family. It is the EVIDENCE for the value a
  QM-RESEARCH Strategy Card must DECLARE in its ``research_trial_count`` field.
  **This ledger never writes into any Q08 DSR cohort, effective_trial_count, or
  any gate formula.** Folding a research count into the sealed DSR deflation is a
  separate ROT gate-contract decision, explicitly out of scope here.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

SEARCH_HISTORY_SCHEMA = "qm.research-search-history/v1"

# One of research_id / campaign_id must be present; the rest are required.
_REQUIRED_FIELDS = (
    "hypothesis_family",
    "dataset_id",
    "period",
    "instruments",
    "feature_families",
    "parameter_space_size",
    "holdout_id",
    "holdout_touched",
    "outcome",
)


def _utc_now_iso() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def _normalize(record: dict[str, Any]) -> dict[str, Any]:
    """Validate + normalize one search record, filling schema/ts if absent."""

    if not isinstance(record, dict):
        raise TypeError("search-history record must be a dict")
    row = dict(record)
    row.setdefault("schema", SEARCH_HISTORY_SCHEMA)
    row.setdefault("ts", _utc_now_iso())

    if not str(row.get("research_id") or "").strip() and not str(
        row.get("campaign_id") or ""
    ).strip():
        raise ValueError("search-history record needs research_id or campaign_id")

    missing = [f for f in _REQUIRED_FIELDS if f not in row]
    if missing:
        raise ValueError(f"search-history record missing fields: {sorted(missing)}")

    row["hypothesis_family"] = str(row["hypothesis_family"]).strip()
    if not row["hypothesis_family"]:
        raise ValueError("hypothesis_family must be non-empty")
    row["holdout_touched"] = bool(row["holdout_touched"])
    try:
        row["parameter_space_size"] = int(row["parameter_space_size"])
    except (TypeError, ValueError) as exc:
        raise ValueError("parameter_space_size must be an integer") from exc
    return row


def append_search(ledger_path: Path | str, record: dict[str, Any]) -> dict[str, Any]:
    """Append one validated search record to the append-only ledger."""

    row = _normalize(record)
    path = Path(ledger_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    line = (json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND | getattr(os, "O_BINARY", 0)
    fd = os.open(path, flags, 0o600)
    try:
        view = memoryview(line)
        while view:
            written = os.write(fd, view)
            if written <= 0:
                raise OSError("search-history append made no progress")
            view = view[written:]
    finally:
        os.close(fd)
    return row


def read_records(ledger_path: Path | str) -> list[dict[str, Any]]:
    """Read all valid JSONL rows (skipping blank lines); missing file -> []."""

    path = Path(ledger_path)
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def trials_per_family(ledger_path: Path | str) -> dict[str, int]:
    """Return {hypothesis_family: number of searches logged}."""

    counter: Counter[str] = Counter()
    for row in read_records(ledger_path):
        family = str(row.get("hypothesis_family") or "").strip()
        if family:
            counter[family] += 1
    return dict(counter)


def declared_trial_count_for(ledger_path: Path | str, family: str) -> int:
    """Evidence value for a card's ``research_trial_count`` for ``family``.

    This is the count a QM-RESEARCH card must declare AT LEAST. It is surfaced to
    Fable's preregistration decision, the ATTACK critic, and research reporting —
    NEVER written into the sealed Q08 DSR cohort (design doc sec 6.4, R-C).
    """

    target = str(family or "").strip()
    return sum(
        1
        for row in read_records(ledger_path)
        if str(row.get("hypothesis_family") or "").strip() == target
    )


def holdout_reuse_count(ledger_path: Path | str) -> dict[str, int]:
    """Return {holdout_id: number of records that TOUCHED that holdout}.

    A holdout_id with a count > 1 has been re-mined and the candidate that reused
    it must be down-weighted (design doc sec 9.4).
    """

    counter: Counter[str] = Counter()
    for row in read_records(ledger_path):
        if not bool(row.get("holdout_touched")):
            continue
        holdout = str(row.get("holdout_id") or "").strip()
        if holdout:
            counter[holdout] += 1
    return dict(counter)


def summarize(ledger_path: Path | str) -> dict[str, Any]:
    """Compact research-reporting summary over the whole ledger."""

    records = read_records(ledger_path)
    families = trials_per_family(ledger_path)
    reuse = holdout_reuse_count(ledger_path)
    return {
        "schema": SEARCH_HISTORY_SCHEMA,
        "total_searches": len(records),
        "trials_per_family": dict(sorted(families.items())),
        "holdout_reuse_count": dict(sorted(reuse.items())),
        "reused_holdouts": sorted(h for h, c in reuse.items() if c > 1),
        "note": (
            "trials_per_family is EVIDENCE for each card's declared "
            "research_trial_count; it is never written into any Q08 DSR cohort."
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    parser.add_argument("--family", type=str, default=None)
    args = parser.parse_args(argv)
    if args.family:
        print(json.dumps({
            "family": args.family,
            "declared_trial_count": declared_trial_count_for(args.ledger, args.family),
        }, indent=2, sort_keys=True))
    else:
        print(json.dumps(summarize(args.ledger), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

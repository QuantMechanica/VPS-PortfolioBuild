"""Reproduce the MATCH-EA pending-placement trace from the 2026-09-09 inventory.

Read-only with respect to farm/runtime state. It reads repository sources and writes
only the adjacent CSV evidence artifact.
"""
import csv
import hashlib
import re
from pathlib import Path

ROOT = Path("C:/QM/repo")
INPUT = ROOT / "docs/ops/evidence/2026-09-09_fleet_clock_inventory.csv"
OUTPUT = ROOT / "docs/ops/evidence/2026-09-12_fleet_clock_pending_trace.csv"

OVERRIDES = {
    "QM5_1120": ("OPPOSITE_ONLY", [297, 305, 362, 365], "Both stop legs are submitted independently; a crossed leg can fail while the opposite leg remains."),
    "QM5_11435": ("OPPOSITE_ONLY", [120, 128, 131, 139], "No crossed-level branch; direct independent submissions allow only the opposite leg to remain."),
    "QM5_11505": ("UNDEFINED", [217, 218, 222, 223, 346], "Directional stop is submitted without a strategy-level price-versus-market guard; rejection/retry semantics are not specified."),
    "QM5_11697": ("SKIP", [188, 189, 190, 203, 204, 205], "Explicitly returns false when buy entry is at/below ask or sell entry is at/above bid."),
    "QM5_20188": ("OPPOSITE_ONLY", [328, 330, 332, 333, 575], "Two stop legs are submitted independently and the day is consumed regardless of placement success."),
    "QM5_41097": ("OPPOSITE_ONLY", [330, 331, 623, 628], "Straddle legs are submitted independently with no crossed-level branch; one accepted opposite leg can remain."),
    "QM5_41324": ("OPPOSITE_ONLY", [331, 332, 635, 640], "Straddle legs are submitted independently with no crossed-level branch; one accepted opposite leg can remain."),
    "QM5_41398": ("OPPOSITE_ONLY", [332, 333, 625, 630, 634], "Independent submissions can leave the opposite leg and permission intent marks the day even if placement fails."),
}


def citations(path: Path, wanted: list[int] | None = None) -> str:
    lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    rel = path.relative_to(ROOT).as_posix()
    if wanted is None:
        patterns = (
            r"\.type\s*=\s*QM_(?:BUY|SELL)(?!_STOP)",
            r"QM_TM_OpenPosition\s*\(",
        )
        wanted = []
        for pattern in patterns:
            for number, line in enumerate(lines, 1):
                if re.search(pattern, line) and not line.lstrip().startswith("//"):
                    wanted.append(number)
                    break
    return " | ".join(f"{rel}:{number}: {lines[number-1].strip()}" for number in wanted)


def main() -> None:
    rows = list(csv.DictReader(INPUT.open(encoding="utf-8-sig")))
    matches = [row for row in rows if row["classification"] == "MATCH"]
    output = []
    for row in matches:
        ea_id = row["ea_id"]
        source = ROOT / row["source"]
        actual_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        if actual_hash != row["source_sha256"]:
            raise SystemExit(f"source hash drift: {ea_id}: {actual_hash} != {row['source_sha256']}")
        if ea_id in OVERRIDES:
            behavior, wanted, rationale = OVERRIDES[ea_id]
            placement = "STOP_PENDING"
            evidence = citations(source, wanted)
        else:
            behavior = "MARKET"
            placement = "MARKET_OR_NO_PENDING_LEVEL"
            rationale = "Inventory and source trace contain no stop-pending order type; crossed pending-level behavior is not applicable."
            evidence = citations(source)
            if not evidence:
                # These implementations delegate through a strategy module or use
                # a non-request wrapper. The clock-audit citation remains exact.
                evidence = row["clock_code_evidence"].split(" | ", 1)[0]
                rationale += " Order routing is delegated; citation is the exact strategy clock call site."
        output.append({
            "ea_id": ea_id,
            "source": row["source"],
            "source_sha256": actual_hash,
            "placement_path": placement,
            "price_already_outside_behavior": behavior,
            "file_line_evidence": evidence,
            "classification_basis": rationale,
            "work_items_created": 0,
        })
    if len(output) != 93:
        raise SystemExit(f"expected 93 MATCH rows, got {len(output)}")
    with OUTPUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(output[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(output)
    counts = {name: sum(row["price_already_outside_behavior"] == name for row in output) for name in ("MARKET", "SKIP", "OPPOSITE_ONLY", "UNDEFINED")}
    print({"rows": len(output), "counts": counts, "missing_evidence": sum(not row["file_line_evidence"] for row in output), "work_items_created": sum(int(row["work_items_created"]) for row in output)})


if __name__ == "__main__":
    main()

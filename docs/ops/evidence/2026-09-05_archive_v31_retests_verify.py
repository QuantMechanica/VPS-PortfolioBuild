"""Read-only comparison of the review snapshots; no publication or farm writes."""
import json
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO))
from tools.strategy_farm import website_archive_v31 as producer


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def counts(archive):
    contradictory, overlapping, duplicates, observations = 0, 0, 0, 0
    for item in archive["items"]:
        bad, overlap = False, False
        for phase in item["gate_journey"]:
            for gate in phase["gates"]:
                rows = gate["backtests"]
                keys = [(b["symbol_public"], b["timeframe"]) for b in rows]
                passed = {k for k, b in zip(keys, rows) if b["verdict"] == "PASS"}
                failed = {k for k, b in zip(keys, rows) if b["verdict"] == "FAIL"}
                bad |= bool(passed & failed)
                overlap |= bool(set(gate["passed_symbols"]) & set(gate["failed_symbols"]))
                duplicates += len(keys) - len(set(keys))
                observations += sum(len(b.get("retests", [])) for b in rows)
        contradictory += bad
        overlapping += overlap
    unknown = [x for x in archive["items"] if any(m["timeframe"] == "UNKNOWN" for m in x["markets"])]
    return {"families": archive["total"], "contradictory_cell_families": contradictory,
            "overlapping_chip_families": overlapping, "duplicate_cells": duplicates,
            "retest_observations": observations, "unknown_timeframe_families": len(unknown),
            "unknown_timeframe_markets": sum(m["timeframe"] == "UNKNOWN" for x in unknown for m in x["markets"]),
            "families_without_markets": sum(not x["markets"] for x in archive["items"])}


before = load(REPO / "docs/ops/evidence/2026-09-05_archive_v31_dryrun_v2/strategy-archive-v31.json")
after = load(REPO / "docs/ops/evidence/2026-09-05_archive_v31_dryrun_v3/strategy-archive-v31.json")
producer.validate(after)
schema = load(REPO / "public-data/strategy-archive.schema.v31.json")
gate_schema = schema["properties"]["items"]["items"]["properties"]["gate_journey"]["items"]["properties"]["gates"]["items"]["properties"]
backtest_schema = gate_schema["backtests"]["items"]
retest_schema = backtest_schema["properties"]["retests"]["items"]
assert set(backtest_schema["required"]) == set(backtest_schema["properties"]) == {"symbol_public", "timeframe", "verdict", "retests"}
assert set(retest_schema["required"]) == set(retest_schema["properties"]) == {"recorded_at", "verdict"}
assert backtest_schema["additionalProperties"] is retest_schema["additionalProperties"] is False
result = {"before": counts(before), "after": counts(after), "runtime_whitelist": "PASS", "schema_field_contract": "PASS"}
assert result["after"]["contradictory_cell_families"] == 0
assert result["after"]["overlapping_chip_families"] == 0
assert result["after"]["duplicate_cells"] == 0
print(json.dumps(result, indent=2))

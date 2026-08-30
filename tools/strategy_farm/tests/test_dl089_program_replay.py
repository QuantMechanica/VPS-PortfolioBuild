from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path


FIXTURE = Path(__file__).parent / "fixtures" / "dl089_program_replay_fixture.json"


def _canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _replay(programs: list[dict], slots: int) -> tuple[list[str], dict[str, dict]]:
    pending = deque((p["program_id"], deque(p["cells"])) for p in programs)
    owners: list[tuple[str, deque]] = []
    trace: list[str] = []
    terminal: dict[str, list[str]] = {p["program_id"]: [] for p in programs}
    receipts: dict[str, list[dict]] = {p["program_id"]: [] for p in programs}
    selected: dict[str, list[str]] = {p["program_id"]: [] for p in programs}
    evidence: dict[str, list[dict]] = {p["program_id"]: [] for p in programs}

    while pending or owners:
        while pending and len(owners) < slots:
            owners.append(pending.popleft())
        next_owners: list[tuple[str, deque]] = []
        for program_id, cells in owners:
            cell = cells.popleft()
            trace.append(f"{program_id}:{cell['cell_key']}")
            terminal[program_id].append(cell["disposition"])
            receipt = cell.get("pruning_receipt")
            if receipt:
                receipts[program_id].append(
                    {key: value for key, value in receipt.items() if key != "observed_at"}
                )
            if cell.get("selected"):
                selected[program_id].append(cell["cell_key"])
            evidence[program_id].append(cell["evidence"])
            if cells:
                next_owners.append((program_id, cells))
        owners = next_owners

    result = {
        program_id: {
            "terminal_dispositions": terminal[program_id],
            "pruning_receipts_timestamp_exempt": receipts[program_id],
            "selected_cells": selected[program_id],
            "evidence_sha256": hashlib.sha256(_canonical(evidence[program_id])).hexdigest(),
        }
        for program_id in terminal
    }
    return trace, result


def test_serial_and_k_program_replay_are_byte_equivalent_per_program() -> None:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    serial_trace, serial = _replay(fixture["programs"], slots=1)
    parallel_trace, parallel = _replay(fixture["programs"], slots=4)
    assert serial_trace != parallel_trace
    assert _canonical(serial) == _canonical(parallel)


def test_replay_preserves_within_program_order_and_single_cell_per_round() -> None:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    trace, _ = _replay(fixture["programs"], slots=4)
    for program in fixture["programs"]:
        observed = [entry.split(":", 1)[1] for entry in trace if entry.startswith(program["program_id"] + ":")]
        assert observed == [cell["cell_key"] for cell in program["cells"]]

from __future__ import annotations

import json
from pathlib import Path

import pytest

from framework.scripts import emit_q16_lineage as emitter
from framework.scripts import q16_head_to_head as q16


def _write(path: Path, value: object | str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, str):
        path.write_text(value, encoding="utf-8")
    else:
        path.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")
    return path


SET_BODY = "RISK_FIXED=1000\nRISK_PERCENT=0\n"


def _challenger_inputs(tmp_path: Path, *, q07_declared=154, q07_observed=154, q08_declared=154, q08_observed=154):
    binary = _write(tmp_path / "challenger.ex5", "challenger-binary")
    setfile = _write(tmp_path / "challenger.set", SET_BODY)
    stream = _write(tmp_path / "challenger.jsonl", "{}\n")
    q10 = _write(tmp_path / "q10.json", {"phase": "Q10", "verdict": "PASS"})
    ledger = _write(tmp_path / "trial_ledger.json", {
        "schema": q16.TRIAL_LEDGER_SCHEMA, "card_id": "opt-census-1", "status": "CLOSED",
        "declared_trial_count": 154,
        "trials": [{"trial_id": f"T{i:03d}"} for i in range(154)],
    })
    card = _write(tmp_path / "opt_card.json", {
        "schema": "qm.opt-card/v1", "card_id": "opt-census-1",
        "parent": {"ea_id": 21500, "symbol": "USDJPY.DWX"},
        "lever": "PREDICATE_ABLATION",
        "trial_ledger_path": str(ledger),
    })
    q07 = _write(tmp_path / "q07.json", {
        "phase": "Q07", "trial_ledger": {"declared_trial_count": q07_declared, "observed_trial_count": q07_observed}
    })
    q08 = _write(tmp_path / "q08.json", {
        "phase": "Q08", "trial_ledger": {"declared_trial_count": q08_declared, "observed_trial_count": q08_observed}
    })
    return {
        "role": "CHALLENGER",
        "ea_id": 21501,
        "symbol": "USDJPY.DWX",
        "binary_path": binary,
        "setfile_path": setfile,
        "stream_path": stream,
        "stream_risk_fixed": 1000.0,
        "stream_risk_percent": 0.0,
        "stream_trade_count": 40,
        "q10_evidence_path": q10,
        "card_path": card,
        "ledger_path": ledger,
        "q07_evidence_path": q07,
        "q08_evidence_path": q08,
        "selection_trial_count": 1,
    }


def _run(kwargs: dict, tmp_path: Path, *, apply: bool = True, out_name: str = "lineage.json") -> dict:
    return emitter.run_emit_q16_lineage(out_path=tmp_path / out_name, apply=apply, **kwargs)


def test_challenger_lineage_accepted_by_q16_loader_and_ledger_validator(tmp_path):
    kwargs = _challenger_inputs(tmp_path)
    result = _run(kwargs, tmp_path)
    out_path = Path(result["out_path"])
    lineage = json.loads(out_path.read_text(encoding="utf-8"))

    assert lineage["schema"] == q16.LINEAGE_SCHEMA
    assert lineage["role"] == "CHALLENGER"
    loaded = q16.load_lineage(out_path, "CHALLENGER")

    card_raw = json.loads(Path(kwargs["card_path"]).read_text(encoding="utf-8"))
    refs = q16.validate_trial_ledger(card_raw, Path(kwargs["ledger_path"]), loaded)
    assert refs["declared_trial_count"] == 154
    assert refs["phase_references"]["Q07"]["observed"] == 154


def test_parent_lineage_accepted_by_q16_loader(tmp_path):
    binary = _write(tmp_path / "parent.ex5", "parent-binary")
    setfile = _write(tmp_path / "parent.set", SET_BODY)
    stream = _write(tmp_path / "parent.jsonl", "{}\n")
    q10 = _write(tmp_path / "q10_parent.json", {"phase": "Q10", "verdict": "PASS"})
    kwargs = {
        "role": "PARENT", "ea_id": 10939, "symbol": "GBPUSD.DWX",
        "binary_path": binary, "setfile_path": setfile, "stream_path": stream,
        "stream_risk_fixed": 1000.0, "stream_risk_percent": 0.0, "stream_trade_count": 5,
        "q10_evidence_path": q10,
        "card_path": None, "ledger_path": None, "q07_evidence_path": None, "q08_evidence_path": None,
        "selection_trial_count": None,
    }
    result = _run(kwargs, tmp_path)
    out_path = Path(result["out_path"])
    loaded = q16.load_lineage(out_path, "PARENT")
    assert loaded["key"] == (10939, "GBPUSD.DWX")
    lineage = json.loads(out_path.read_text(encoding="utf-8"))
    assert "q07" not in lineage and "q08" not in lineage


def test_selection_trial_count_distinct_from_declared(tmp_path):
    kwargs = _challenger_inputs(tmp_path)
    kwargs["selection_trial_count"] = 1
    result = _run(kwargs, tmp_path)
    lineage = json.loads(Path(result["out_path"]).read_text(encoding="utf-8"))
    assert lineage["q07"]["selection_trial_count"] == 1
    assert lineage["q07"]["trial_ledger_declared_count"] == 154
    assert lineage["q07"]["selection_trial_count"] != lineage["q07"]["trial_ledger_declared_count"]
    assert lineage["q08"]["selection_trial_count"] == 1


def test_evidence_declared_mismatch_against_ledger_rejected(tmp_path):
    kwargs = _challenger_inputs(tmp_path, q07_declared=153)
    with pytest.raises(emitter.EmitQ16LineageError, match="differs from the trial ledger"):
        _run(kwargs, tmp_path)


def test_counts_come_from_evidence_not_a_cli_argument(tmp_path):
    # There is no CLI knob for the counts at all -- only --q07-evidence / --q08-evidence.
    # Prove the emitted numbers track the evidence file content exactly.
    kwargs = _challenger_inputs(tmp_path, q07_observed=140, q08_observed=150)
    result = _run(kwargs, tmp_path)
    lineage = json.loads(Path(result["out_path"]).read_text(encoding="utf-8"))
    assert lineage["q07"]["observed_trial_count"] == 140
    assert lineage["q08"]["observed_trial_count"] == 150


def test_missing_selection_trial_count_rejected_for_challenger(tmp_path):
    kwargs = _challenger_inputs(tmp_path)
    kwargs["selection_trial_count"] = None
    with pytest.raises(emitter.EmitQ16LineageError, match="selection-trial-count"):
        _run(kwargs, tmp_path)


def test_two_runs_are_byte_identical(tmp_path):
    kwargs = _challenger_inputs(tmp_path)
    first = _run(kwargs, tmp_path, out_name="run1.json")
    second = _run(kwargs, tmp_path, out_name="run2.json")
    assert first["body_sha256"] == second["body_sha256"]
    assert Path(first["out_path"]).read_bytes() == Path(second["out_path"]).read_bytes()


def test_dry_run_does_not_write(tmp_path):
    kwargs = _challenger_inputs(tmp_path)
    out_path = tmp_path / "lineage.json"
    result = _run(kwargs, tmp_path, apply=False)
    assert result["applied"] is False
    assert not out_path.exists()
    assert "lineage" in result


def test_non_risk_fixed_setfile_rejected(tmp_path):
    kwargs = _challenger_inputs(tmp_path)
    bad_set = Path(kwargs["setfile_path"])
    bad_set.write_text("RISK_FIXED=0\nRISK_PERCENT=1\n", encoding="utf-8")
    with pytest.raises(emitter.EmitQ16LineageError):
        _run(kwargs, tmp_path)

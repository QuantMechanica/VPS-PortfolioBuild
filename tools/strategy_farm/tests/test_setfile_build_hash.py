from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

from tools.strategy_farm import compile_work_items
from tools.strategy_farm.setfile_build_hash import (
    PENDING_BUILD_HASH_LINE,
    SETFILE_BUILD_HASH_TRANSITION_SCHEMA,
    authenticate_setfile_build_hash_transition,
)


def _generator_bytes(*, risk_fixed: str = "1000", risk_percent: str = "0") -> bytes:
    lines = [
        ";==========================================================",
        "; QM5 Set File",
        "; ea_id:        90001",
        "; ea_slug:      lifecycle-fixture",
        "; ea_version:   v5.0",
        "; set_version:  v1",
        "; symbol:       EURUSD.DWX",
        "; timeframe:    H1",
        "; environment:  backtest",
        "; magic_slot:   0",
        "; risk_mode:    FIXED",
        "; portfolio_weight: 1",
        PENDING_BUILD_HASH_LINE,
        "; author:       Development",
        "; date:         2026-09-22",
        ";==========================================================",
        "qm_ea_id=90001",
        "qm_magic_slot_offset=0",
        f"RISK_FIXED={risk_fixed}",
        f"RISK_PERCENT={risk_percent}",
        "PORTFOLIO_WEIGHT=1",
        "strategy_period=14",
    ]
    return ("\n".join(lines) + "\n").encode("utf-8")


def _build_check_bytes(generated: bytes) -> bytes:
    lines = generated.decode("utf-8").splitlines()
    normalized_pending = ("\r\n".join(lines) + "\r\n").encode("utf-8")
    stamp = hashlib.sha256(normalized_pending).hexdigest()
    index = lines.index(PENDING_BUILD_HASH_LINE)
    lines[index] = f"; build_hash:   {stamp}"
    return ("\r\n".join(lines) + "\r\n").encode("utf-8")


def _authenticated_ex5_restamp_bytes(generated: bytes, ex5_sha256: str) -> bytes:
    lines = generated.decode("utf-8").splitlines()
    index = lines.index(PENDING_BUILD_HASH_LINE)
    lines[index] = f"; build_hash:   {ex5_sha256}"
    return ("\n".join(lines) + "\n").encode("utf-8")


def test_authenticates_exact_full_compile_lifecycle() -> None:
    generated = _generator_bytes()
    final = _build_check_bytes(generated)

    result = authenticate_setfile_build_hash_transition(
        hashlib.sha256(generated).hexdigest(), final
    )

    assert result["ok"] is True, result
    assert result["schema"] == SETFILE_BUILD_HASH_TRANSITION_SCHEMA
    assert result["generated_setfile_sha256"] == hashlib.sha256(generated).hexdigest()
    assert result["final_setfile_sha256"] == hashlib.sha256(final).hexdigest()
    assert result["build_hash"] == result["normalized_pending_sha256"]
    assert result["risk_fixed"] == "1000"
    assert result["risk_percent"] == "0"
    assert result["input_assignments_unchanged"] is True


def test_rejects_changed_input_even_when_attacker_restamps_it() -> None:
    original = _generator_bytes()
    changed_and_self_consistently_stamped = _build_check_bytes(
        _generator_bytes(risk_fixed="999")
    )

    result = authenticate_setfile_build_hash_transition(
        hashlib.sha256(original).hexdigest(), changed_and_self_consistently_stamped
    )

    assert result["ok"] is False
    assert result["reason"] == "generated_setfile_bytes_not_exact_preimage"


def test_authenticates_exact_compile_ok_ex5_restamp() -> None:
    generated = _generator_bytes()
    ex5_sha = hashlib.sha256(b"authenticated COMPILE_OK binary").hexdigest()
    final = _authenticated_ex5_restamp_bytes(generated, ex5_sha)

    result = authenticate_setfile_build_hash_transition(
        hashlib.sha256(generated).hexdigest(),
        final,
        expected_ex5_sha256=ex5_sha,
    )

    assert result["ok"] is True, result
    assert result["transition_mode"] == "authenticated_ex5_hash_restamp"
    assert result["build_hash"] == ex5_sha
    assert result["stamp_source_artifact"] == {
        "kind": "COMPILE_OK.ex5",
        "sha256": ex5_sha,
    }
    assert result["reconstructed_build_check_final_setfile_sha256"] == (
        hashlib.sha256(_build_check_bytes(generated)).hexdigest()
    )


def test_rejects_ex5_restamp_not_bound_to_expected_binary() -> None:
    generated = _generator_bytes()
    stamped_ex5 = hashlib.sha256(b"different binary").hexdigest()
    expected_ex5 = hashlib.sha256(b"sealed binary").hexdigest()

    result = authenticate_setfile_build_hash_transition(
        hashlib.sha256(generated).hexdigest(),
        _authenticated_ex5_restamp_bytes(generated, stamped_ex5),
        expected_ex5_sha256=expected_ex5,
    )

    assert result["ok"] is False
    assert result["reason"] == "final_setfile_transition_not_recognized"


def test_rejects_forged_build_hash_stamp() -> None:
    generated = _generator_bytes()
    final = _build_check_bytes(generated).replace(
        b"; build_hash:   ", b"; build_hash:   " + (b"0" * 64) + b"; old=" , 1
    )

    result = authenticate_setfile_build_hash_transition(
        hashlib.sha256(generated).hexdigest(), final
    )

    assert result["ok"] is False
    assert result["reason"] in {
        "final_build_hash_line_not_canonical",
        "build_hash_stamp_mismatch",
    }


def test_rejects_non_fixed_backtest_risk_contract() -> None:
    generated = _generator_bytes(risk_percent="1")
    final = _build_check_bytes(generated)

    result = authenticate_setfile_build_hash_transition(
        hashlib.sha256(generated).hexdigest(), final
    )

    assert result["ok"] is False
    assert result["reason"] == "backtest_risk_binding_invalid"


def test_compile_evidence_finalizer_preserves_pre_stamp_and_seals_final(
    tmp_path: Path,
) -> None:
    generated = _generator_bytes()
    final = _build_check_bytes(generated)
    setfile = tmp_path / "fixture.set"
    setfile.write_bytes(final)
    generation = {
        "symbol": "EURUSD.DWX",
        "setfile_path": str(setfile),
        "setfile_sha256": hashlib.sha256(generated).hexdigest(),
        "setfile_exists": True,
        "exit_code": 0,
    }

    compile_work_items._finalize_generated_setfile_evidence([generation])

    assert generation["generated_setfile_sha256"] == hashlib.sha256(generated).hexdigest()
    assert generation["setfile_sha256"] == hashlib.sha256(final).hexdigest()
    assert generation["setfile_sha256_after_build_check"] == hashlib.sha256(final).hexdigest()
    assert generation["build_hash_transition"]["ok"] is True


def test_compile_evidence_finalizer_fails_closed_on_unrecognized_change(
    tmp_path: Path,
) -> None:
    generated = _generator_bytes()
    setfile = tmp_path / "fixture.set"
    setfile.write_bytes(_build_check_bytes(_generator_bytes(risk_fixed="999")))
    generation = {
        "symbol": "EURUSD.DWX",
        "setfile_path": str(setfile),
        "setfile_sha256": hashlib.sha256(generated).hexdigest(),
        "setfile_exists": True,
        "exit_code": 0,
    }

    with pytest.raises(RuntimeError, match="SETFILE_BUILD_HASH_TRANSITION_INVALID"):
        compile_work_items._finalize_generated_setfile_evidence([generation])

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import build_book_ftmo, ftmo_p1_mc, ftmo_timebox_eval
from tools.strategy_farm.portfolio.ftmo_probability_contract import (
    DEFAULT_CONTRACT_PATH,
    FtmoProbabilityContractError,
    load_probability_contract,
)


REPO = Path(__file__).resolve().parents[3]


def test_contract_loads_and_rulepack_percent_strings_are_validated() -> None:
    contract = load_probability_contract()
    gates = contract.probability["gates"]
    assert contract.payload["schema"] == "qm.ftmo-probability-correlation-contract/v1"
    assert gates["p1_pass"]["point_min"] == 0.80
    assert gates["p1_pass"]["lower_95_min"] == 0.80
    assert gates["breach"]["upper_95_max"] == 0.10
    assert gates["two_phase"]["p2_conditional_min"] == 0.85
    assert gates["two_phase"]["joint_min"] == 0.65
    assert gates["breach"]["enforcement_status"] == "INERT_UNTIL_C6_ENGINE_OWNER_APPROVED"
    assert gates["two_phase"]["enforcement_status"] == "INERT_UNTIL_C6_ENGINE_OWNER_APPROVED"
    assert contract.probability["dsr_correction"]["fleet_default_trial_count_N"] == 369


def test_contract_loader_rejects_schema_and_parity_drift(tmp_path: Path) -> None:
    payload = json.loads(DEFAULT_CONTRACT_PATH.read_text(encoding="utf-8"))
    payload["probability"]["gates"]["breach"]["upper_95_max"] = 10.0
    changed = tmp_path / "changed.json"
    changed.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(FtmoProbabilityContractError, match="breach upper parity mismatch"):
        load_probability_contract(changed)

    duplicate = tmp_path / "duplicate.json"
    duplicate.write_text('{"schema":"a","schema":"b"}', encoding="utf-8")
    with pytest.raises(FtmoProbabilityContractError, match="duplicate JSON key"):
        load_probability_contract(duplicate)


def test_contract_digest_is_lf_normalized_and_raw_digest_is_retained(
    tmp_path: Path,
) -> None:
    lf_raw = DEFAULT_CONTRACT_PATH.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    crlf_raw = lf_raw.replace(b"\n", b"\r\n")
    lf_path = tmp_path / "contract-lf.json"
    crlf_path = tmp_path / "contract-crlf.json"
    lf_path.write_bytes(lf_raw)
    crlf_path.write_bytes(crlf_raw)

    lf_contract = load_probability_contract(lf_path)
    crlf_contract = load_probability_contract(crlf_path)
    expected_portable = hashlib.sha256(lf_raw).hexdigest()
    assert lf_contract.sha256 == crlf_contract.sha256 == expected_portable
    assert lf_contract.raw_sha256 == expected_portable
    assert crlf_contract.raw_sha256 == hashlib.sha256(crlf_raw).hexdigest()
    assert crlf_contract.raw_sha256 != crlf_contract.sha256


def test_binding_thresholds_are_identical_across_engines() -> None:
    contract = load_probability_contract()
    probability = contract.probability
    correlation = contract.correlation
    assert build_book_ftmo.P1_LOWER_BOUND_FLOOR == ftmo_timebox_eval.DEFAULT_RULES["design_bar_p1"] == probability["gates"]["p1_pass"]["lower_95_min"]
    assert build_book_ftmo.WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION == correlation["caps_absolute_layered"]["hard_book_admission"]["value"]
    assert ftmo_timebox_eval.DEFAULT_CORRELATION["maximum_budget_exclusive"] == correlation["caps_absolute_layered"]["q09_marginal_timebox_reject"]["value"]
    assert ftmo_timebox_eval.DEFAULT_CORRELATION["strong_budget_exclusive"] == correlation["caps_absolute_layered"]["timebox_strong_warning"]["value"]
    assert ftmo_timebox_eval.DEFAULT_RULES["phase1_horizon_calendar_days"] == probability["horizon"]["phase1_calendar_days"]
    assert ftmo_timebox_eval.DEFAULT_RULES["phase2_horizon_calendar_days"] == probability["horizon"]["phase2_calendar_days"]
    assert ftmo_timebox_eval.DEFAULT_BOOTSTRAP["replicates"] == probability["bootstrap"]["replicates"]
    assert ftmo_p1_mc.DEFAULT_HORIZON_TRADING_DAYS == probability["horizon"]["diagnostic_conventions"]["mc_trading_days"]


def test_dsr_369_and_census_154_remain_distinct_source_constants() -> None:
    dsr = (REPO / "framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py").read_text(encoding="utf-8-sig")
    census = (REPO / "tools/strategy_farm/opt_census.py").read_text(encoding="utf-8-sig")
    assert "N_CANDIDATE_STRATEGIES = 369" in dsr
    assert "DECLARED_TRIAL_COUNT = 154" in census
    assert "N_CANDIDATE_STRATEGIES = 154" not in dsr


def test_diagnostic_engines_carry_nonbinding_horizon_labels() -> None:
    mc = (REPO / "tools/strategy_farm/portfolio/ftmo_p1_mc.py").read_text(encoding="utf-8-sig")
    firstpassage = (REPO / "tools/strategy_farm/portfolio/challenge_firstpassage.py").read_text(encoding="utf-8-sig")
    for source in (mc, firstpassage):
        assert 'DIAGNOSTIC_ROLE = "DIAGNOSTIC_ONLY"' in source
        assert "HORIZON_BIAS_NOTE" in source

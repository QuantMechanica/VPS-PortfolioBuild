from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
COMMON = REPO / "framework" / "include" / "QM" / "QM_Common.mqh"
RUN_SMOKE = REPO / "framework" / "scripts" / "run_smoke.ps1"


def test_structured_logger_is_armed_before_fail_closed_init_checks() -> None:
    source = COMMON.read_text(encoding="utf-8")

    logger_init = source.index(
        "QM_LoggerInit(ea_id, slug, _Symbol, (ENUM_TIMEFRAMES)_Period, 0);"
    )
    runtime_refusal = source.index('\\"runtime_state_not_armed\\"')
    risk_validation = source.index("QM_FrameworkValidateRiskInputs(", logger_init)
    magic_resolution = source.index("QM_MagicChecked(", logger_init)

    assert logger_init < runtime_refusal < risk_validation < magic_resolution


def test_pre_magic_init_refusals_emit_structured_reasons() -> None:
    source = COMMON.read_text(encoding="utf-8")

    for reason in (
        "runtime_state_not_armed",
        "ea_id_non_positive",
        "portfolio_weight_out_of_range",
        "risk_inputs_invalid",
        "magic_resolution_failed",
    ):
        assert f'\\"reason\\":\\"{reason}\\"' in source

    assert "QM_LoggerSetMagic(g_qm_fw_magic);" in source


def test_tester_journal_classification_is_bound_to_exact_run_identity() -> None:
    source = RUN_SMOKE.read_text(encoding="utf-8")

    assert '[regex]::Escape($ExpectedExpert)' in source
    assert '[regex]::Escape($ExpectedSymbol)' in source
    assert '[regex]::Escape($ExpectedFromDate)' in source
    assert '[regex]::Escape($ExpectedToDate)' in source
    assert "an unauthenticated section cannot drive ONINIT_FAILED" in source
    assert source.count("-ExpectedExpert $Expert") >= 2

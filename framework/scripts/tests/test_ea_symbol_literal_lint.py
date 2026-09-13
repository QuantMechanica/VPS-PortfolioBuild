"""Regression guard for the hardcoded-``.DWX``-symbol defect class.

Hard Rule (OWNER 2026-09-06): symbols are inputs, never code literals. Diagnosis
that produced this test: `docs/ops/evidence/2026-09-13_dxz_book_v2/
REPAIR_DIAGNOSIS_DARK_SLEEVES.md` -- five EAs compared ``_Symbol`` against a
hardcoded ``.DWX`` literal, three of them sat dark in the live book for seven
weeks because the comparison is permanently false on a bare-broker-symbol chart.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "lint_ea_symbol_literals.py"
REPO_ROOT = Path(__file__).resolve().parents[3]
EA_ROOT = REPO_ROOT / "framework" / "EAs"
BASELINE = SCRIPT.parent / "ea_symbol_literal_debt_baseline.txt"

# The five EAs repaired under router ticket 5c4b7c23 (2026-09-13). They must stay
# clean; a future edit that reintroduces a literal here fails this test.
REPAIRED_EAS = (
    "QM5_12778_edgelab-audusd-eurjpy-cointegration",
    "QM5_12969_usdjpy-gotobi-nakane-fix",
    "QM5_13054_brent-tom-mom",
    "QM5_13117_eurgbp-audjpy",
    "QM5_21505_xag-weekly-lowvol-momentum",
)


def _load():
    spec = importlib.util.spec_from_file_location("lint_ea_symbol_literals_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    # dataclasses resolves __module__ through sys.modules during class creation.
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


LINT = _load()


def _codes(source: str) -> list[str]:
    return [v.code for v in LINT.lint_text(Path("QM5_0000_fixture.mq5"), source)]


def test_direct_symbol_literal_comparison_is_a_violation() -> None:
    source = 'bool Strategy_IsTarget()\n  {\n   return (_Symbol == "USDJPY.DWX");\n  }\n'
    assert _codes(source) == ["symbol_literal_comparison"]


def test_position_symbol_literal_comparison_is_a_violation() -> None:
    source = '   if(position_symbol != "XAGUSD.DWX")\n      should_close = true;\n'
    assert _codes(source) == ["symbol_literal_comparison"]


def test_literal_hidden_in_a_global_is_a_violation() -> None:
    source = (
        'string g_leg_a = "AUDUSD.DWX";\n'
        "bool Strategy_IsHostSymbol()\n"
        "  {\n"
        "   return (_Symbol == g_leg_a);\n"
        "  }\n"
    )
    assert _codes(source) == ["symbol_literal_global"]


def test_symbol_as_an_input_is_not_a_violation() -> None:
    source = (
        'input string strategy_host_symbol = "USDJPY.DWX";\n'
        "bool Strategy_IsTarget()\n"
        "  {\n"
        "   return (QM_MagicSymbolCanonical(_Symbol) =="
        " QM_MagicSymbolCanonical(strategy_host_symbol));\n"
        "  }\n"
    )
    assert _codes(source) == []


def test_reference_name_table_and_comments_are_not_violations() -> None:
    source = (
        '// the tester universe is EURUSD.DWX / GBPUSD.DWX\n'
        'const string QM_UNIVERSE[2] = {"EURUSD.DWX", "GBPUSD.DWX"};\n'
        "   for(int i = 0; i < 2; ++i)\n"
        "      SymbolSelect(QM_UNIVERSE[i], true);\n"
    )
    assert _codes(source) == []


@pytest.mark.skipif(not EA_ROOT.is_dir(), reason="EA tree not present")
@pytest.mark.parametrize("ea_dir", REPAIRED_EAS)
def test_repaired_eas_carry_no_hardcoded_symbol_literals(ea_dir: str) -> None:
    target = EA_ROOT / ea_dir
    assert target.is_dir(), f"missing EA directory: {target}"
    violations = LINT.lint_tree(target)
    assert not violations, "\n".join(v.render(EA_ROOT) for v in violations)


@pytest.mark.skipif(not EA_ROOT.is_dir(), reason="EA tree not present")
def test_no_ea_is_new_to_or_grown_beyond_the_debt_ledger() -> None:
    """Ratchet: nothing is allow-listed, but the known debt may only shrink.

    A new EA carrying the defect, or an existing one gaining a literal, fails
    here. Regenerate the ledger with --write-baseline only after a real repair.
    """
    counts = LINT.ea_counts(LINT.lint_tree(EA_ROOT), EA_ROOT)
    breaches = LINT.check_baseline(counts, LINT.read_baseline(BASELINE))
    assert not breaches, "\n".join(breaches)

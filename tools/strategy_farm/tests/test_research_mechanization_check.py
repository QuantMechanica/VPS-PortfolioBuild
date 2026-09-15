"""Tests: mechanization_check PASS / RETURN_TO_RESEARCH (incl. an ML term in rules)."""

from __future__ import annotations

import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

from research import mechanization_check as mc  # noqa: E402


def _valid_spec() -> str:
    return "\n".join(
        [
            "# Mechanical Specification — channel breakout",
            "## Structural cause",
            "Forced rebalancing flow around the monthly close creates a directional imbalance.",
            "## Price signature",
            "Price closes beyond the prior channel and continues.",
            "## Persistence",
            "The institutional rebalancing constraint persists across the sample.",
            "## Long entry",
            "Enter long at the D1 close when close is above the upper channel of length channel_len.",
            "## Short entry",
            "Enter short at the D1 close when close is below the lower channel.",
            "## No-trade conditions",
            "Stay flat during the news blackout window and outside the session.",
            "## Exit",
            "Exit on an opposite channel break or after max_hold_bars.",
            "## Stop loss",
            "Stop at atr_mult times the ATR of length atr_len below entry.",
            "## Take profit",
            "Not applicable; exit is governed by the trailing channel and time stop.",
            "## Position sizing",
            "RISK_FIXED for backtest; RISK_PERCENT for live, capped at risk_pct.",
            "## Session rules",
            "Trade only within session_start_hour to session_end_hour, broker time.",
            "## Filters",
            "Require ATR above atr_floor before any entry is allowed.",
            "## Parameter ranges",
            "| Parameter | Range | Default |",
            "|-----------|-------|---------|",
            "| channel_len | 10 .. 80 | 40 |",
            "| atr_len | 5 .. 30 | 14 |",
            "| atr_mult | 0.5 .. 4.0 | 2.0 |",
            "| atr_floor | 0.1 .. 3.0 | 0.5 |",
            "| risk_pct | 0.25 .. 2.0 | 1.0 |",
            "## Required indicators / data",
            "Native MT5 ATR and Donchian channel, plus the live news filter.",
            "## Timeframe",
            "D1 only.",
            "## Symbols",
            "Symbol applicability is passed as input parameters, one per slot.",
            "## Expected trade frequency",
            "Roughly 12 to 30 trades per year per symbol, clearing the Q02 floor.",
            "## Invalidation conditions",
            "Retire if holdout profit factor falls below 1.0.",
            "## Falsification",
            "Kill the edge if the walk-forward profit factor is below 1.0 on two folds.",
            "## Q08 / Q11 risk",
            "Behaviour through Q08 crisis stress and Q11 full-history confirmation.",
            "## FTMO fit",
            "Respects the 5% daily and 10% total drawdown boxes; swing D1 fit.",
            "## Research provenance",
            "A k-means clustering over standardized risk vectors surfaced the cluster.",
        ]
    )


def test_valid_spec_passes(tmp_path):
    spec = tmp_path / "spec.md"
    spec.write_text(_valid_spec(), encoding="utf-8")
    result = mc.check_spec(spec)
    assert result["verdict"] == "PASS", result["findings"]
    assert result["findings"] == []
    assert result["bounded_parameter_count"] == 5
    assert result["codex_implementable"] is True


def test_ml_term_in_mechanics_returns_to_research(tmp_path):
    spec_text = _valid_spec().replace(
        "Enter long at the D1 close when close is above the upper channel of length channel_len.",
        "Enter long when a random forest classifier scores the setup as favourable.",
    )
    spec = tmp_path / "spec.md"
    spec.write_text(spec_text, encoding="utf-8")
    result = mc.check_spec(spec)
    assert result["verdict"] == "RETURN_TO_RESEARCH"
    assert any(f.startswith("MECH_ML_IN_RULES") for f in result["findings"])


def test_ml_term_in_provenance_is_exempt(tmp_path):
    # The valid spec already carries "k-means clustering" in ## Research provenance.
    spec = tmp_path / "spec.md"
    spec.write_text(_valid_spec(), encoding="utf-8")
    result = mc.check_spec(spec)
    assert not any(f.startswith("MECH_ML_IN_RULES") for f in result["findings"])


def test_negated_ml_mention_is_not_flagged(tmp_path):
    spec_text = _valid_spec().replace(
        "Require ATR above atr_floor before any entry is allowed.",
        "Require ATR above atr_floor before any entry is allowed. No machine learning is used.",
    )
    spec = tmp_path / "spec.md"
    spec.write_text(spec_text, encoding="utf-8")
    result = mc.check_spec(spec)
    assert not any(f.startswith("MECH_ML_IN_RULES") for f in result["findings"])
    assert result["verdict"] == "PASS", result["findings"]


def test_missing_sections_reported(tmp_path):
    lines = [ln for ln in _valid_spec().splitlines()]
    # Drop the "## Short entry" heading and its body line.
    idx = lines.index("## Short entry")
    del lines[idx : idx + 2]
    spec = tmp_path / "spec.md"
    spec.write_text("\n".join(lines), encoding="utf-8")
    result = mc.check_spec(spec)
    assert result["verdict"] == "RETURN_TO_RESEARCH"
    missing = [f for f in result["findings"] if f.startswith("MECH_SECTIONS_MISSING")]
    assert missing and "short_entry" in missing[0]


def test_unbounded_parameter_reported(tmp_path):
    spec_text = _valid_spec().replace(
        "| risk_pct | 0.25 .. 2.0 | 1.0 |",
        "| risk_pct | unbounded | 1.0 |",
    )
    spec = tmp_path / "spec.md"
    spec.write_text(spec_text, encoding="utf-8")
    result = mc.check_spec(spec)
    assert any(f.startswith("MECH_PARAM_UNBOUNDED:risk_pct") for f in result["findings"])


def test_model_dependency_reported(tmp_path):
    spec_text = _valid_spec().replace(
        "Exit on an opposite channel break or after max_hold_bars.",
        "Exit when the research model output turns negative.",
    )
    spec = tmp_path / "spec.md"
    spec.write_text(spec_text, encoding="utf-8")
    result = mc.check_spec(spec)
    assert any(f.startswith("MECH_MODEL_DEPENDENCY") for f in result["findings"])


def test_numeric_provenance_optional_check(tmp_path):
    spec = tmp_path / "spec.md"
    spec.write_text(_valid_spec(), encoding="utf-8")

    # A research.json with quantitative claims but no computed-output hash fails.
    import json

    unbacked = tmp_path / "research_unbacked.json"
    unbacked.write_text(json.dumps({"observations": "edge magnitude 0.4"}), encoding="utf-8")
    result = mc.check_spec(spec, artifact_research_json=unbacked)
    assert any(f.startswith("RESEARCH_NUMERIC_UNBACKED") for f in result["findings"])

    # Add a computed-output hash and it passes.
    backed = tmp_path / "research_backed.json"
    backed.write_text(
        json.dumps({"observations": "edge magnitude 0.4", "computed_outputs": [{"sha256": "ab" * 32}]}),
        encoding="utf-8",
    )
    result2 = mc.check_spec(spec, artifact_research_json=backed)
    assert not any(f.startswith("RESEARCH_NUMERIC_UNBACKED") for f in result2["findings"])


def test_template_file_passes():
    template = SF / "research" / "templates" / "mechanical_spec.md"
    result = mc.check_spec(template)
    # The shipped template is a well-formed skeleton (placeholders, no ML in rules).
    assert not any(f.startswith("MECH_SECTIONS_MISSING") for f in result["findings"]), result["findings"]
    assert not any(f.startswith("MECH_ML_IN_RULES") for f in result["findings"]), result["findings"]

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


MODULE_PATH = Path(__file__).resolve().parents[1] / "card_intake_prescreen.py"
SPEC = importlib.util.spec_from_file_location("card_intake_prescreen_under_test", MODULE_PATH)
assert SPEC and SPEC.loader
prescreen = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = prescreen
SPEC.loader.exec_module(prescreen)


def _matrix(path: Path) -> Path:
    path.write_text("symbol,asset_class\nEURUSD.DWX,forex\nXAUUSD.DWX,commodities\n", encoding="utf-8")
    return path


def _card(
    path: Path,
    *,
    slug: str,
    ea_id: str = "QM5_90001",
    symbols: str = "[EURUSD.DWX]",
    timeframe: str = "H1",
    dd: str = "8",
    extra: str = "",
    fm_extra: str = "",
) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    fm_extra_block = (fm_extra.rstrip("\n") + "\n") if fm_extra else ""
    path.write_text(
        f"""---
ea_id: {ea_id}
slug: {slug}
target_symbols: {symbols}
timeframe: {timeframe}
expected_dd_pct: {dd}
r4_ml_forbidden: true
{fm_extra_block}---

# {slug}

## Structural cause
Forced institutional rebalancing flow creates a liquidity risk premium because inventory is slow to clear.

## Price signature and entry rules
Buy when the completed H1 close crosses the declared 20-bar high; sell on the mirrored close.

## Persistence
Capacity and inventory constraints keep the institutional flow from being arbitraged immediately.

## Falsification
Kill when post-cost expectancy is non-positive in the sealed test.

## Q08/Q11 risk
Crisis gaps and mandatory news blackout behavior are tested explicitly.

## FTMO fit
Daily drawdown is capped below 5% and total drawdown below 10%. Mandatory news blackout. H1 swing horizon. No HFT, ML, grid, martingale, or averaging into losers.

{extra}
""",
        encoding="utf-8",
    )
    return path


def _evaluate(candidate: Path, tmp_path: Path, approved: Path | None = None):
    approved_root = tmp_path / "approved"
    rejected_root = tmp_path / "rejected"
    approved_root.mkdir(exist_ok=True)
    rejected_root.mkdir(exist_ok=True)
    if approved:
        approved.replace(approved_root / approved.name)
    return prescreen.run_prescreen(
        [candidate],
        symbol_matrix=_matrix(tmp_path / "matrix.csv"),
        data_root=tmp_path / "data",
        approved_root=approved_root,
        rejected_root=rejected_root,
    )["results"][0]


@pytest.mark.parametrize(
    ("slug", "extra"),
    [
        ("cash-open-gap-fade", "Inventory at the cash auction creates a gap fade."),
        ("carney-abcd-h1-density", "The numeric AB=CD geometry is a declared carrier variant."),
        ("cross-sectional-short-reversion", "Currency strength ranks select one direct pair."),
        ("safe-haven-risk-rotation", "Risk-off institutional flow rotates JPY and CHF demand."),
        ("turn-of-month-ultimo", "Monthly pension rebalancing fixes the calendar clock."),
    ],
)
def test_five_kept_triage_fixtures_stay_kept(tmp_path: Path, slug: str, extra: str) -> None:
    result = _evaluate(_card(tmp_path / "review" / f"QM5_90001_{slug}.md", slug=slug, extra=extra), tmp_path)
    assert result["verdict"] == "KEEP", result["reasons"]


def test_duplicate_fixture_is_rejected(tmp_path: Path) -> None:
    approved = _card(
        tmp_path / "ref.md", slug="weekly-currency-strength-rotation", ea_id="QM5_80001"
    )
    candidate = _card(tmp_path / "review" / "candidate.md", slug="weekly-currency-strength-rotation-v2")
    result = _evaluate(candidate, tmp_path, approved)
    assert any(reason.startswith("NEAR_DUPLICATE:") for reason in result["reasons"])


@pytest.mark.parametrize(
    ("slug", "kwargs", "expected"),
    [
        ("invalid-symbol-breakout", {"symbols": "[DE40, US30]"}, "TARGET_SYMBOL_NOT_IN_DWX_MATRIX"),
        ("vix-divergence", {"extra": "Entry requires the VIX index to cross its 20-day high."}, "EXTERNAL_DATA_FEED_MISSING"),
        ("rf-sentiment", {"extra": "A pre-trained Random Forest predicts each entry."}, "PROHIBITED_MECHANICS:ML"),
    ],
)
def test_four_obvious_reject_classes(
    tmp_path: Path, slug: str, kwargs: dict[str, str], expected: str
) -> None:
    result = _evaluate(_card(tmp_path / "review" / f"{slug}.md", slug=slug, **kwargs), tmp_path)
    assert result["verdict"] == "REJECT"
    assert any(reason.startswith(expected) for reason in result["reasons"])


def test_apply_is_default_off_and_moves_only_when_called(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    candidate = _card(tmp_path / "cards_review" / "bad.md", slug="bad", symbols="[NOPE]")
    rejected = tmp_path / "cards_rejected"
    dry = prescreen.run_prescreen(
        [candidate],
        symbol_matrix=_matrix(tmp_path / "matrix.csv"),
        data_root=tmp_path / "data",
        approved_root=tmp_path / "cards_approved",
        rejected_root=rejected,
        apply=False,
    )
    assert candidate.exists()
    assert dry["summary"]["mutated"] == 0

    monkeypatch.setenv(prescreen.ARM_ENV, "1")
    applied = prescreen.run_prescreen(
        [candidate],
        symbol_matrix=tmp_path / "matrix.csv",
        data_root=tmp_path / "data",
        approved_root=tmp_path / "cards_approved",
        rejected_root=rejected,
        apply=True,
    )
    destination = rejected / "bad.md"
    assert not candidate.exists()
    assert destination.exists()
    assert "prescreen_reason:" in destination.read_text(encoding="utf-8")
    assert applied["summary"]["mutated"] == 1


def test_utf8_bom_and_wrapped_negative_prohibition_are_supported(tmp_path: Path) -> None:
    candidate = _card(tmp_path / "review" / "bom.md", slug="bom-safe")
    text = candidate.read_text(encoding="utf-8")
    text = text.replace(
        "No HFT, ML, grid, martingale, or averaging into losers.",
        "No HFT, ML, grid,\nmartingale, or averaging into losers.",
    )
    candidate.write_text("\ufeff" + text, encoding="utf-8")
    result = _evaluate(candidate, tmp_path)
    assert result["ea_id"] == "QM5_90001"
    assert result["verdict"] == "KEEP", result["reasons"]


# --- Strategy Eligibility V2 (OWNER-DEC-D3-20260915) ------------------------------


import json as _json


def _valid_risk_contract(
    path: Path,
    *,
    max_levels: int = 5,
    equity_stop_pct=8.0,
    emergency_type: str = "equity_stop",
) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        _json.dumps(
            {
                "schema": "qm.strategy-risk-contract/v1",
                "tail_amplifying": True,
                "max_levels": max_levels,
                "sizing_progression": {"type": "geometric", "multiplier": "2"},
                "max_open_positions": max(max_levels, 1),
                "max_basket_exposure": "0.5",
                "max_gross_notional": "50000",
                "max_margin_pct": 20.0,
                "max_basket_loss_pct": 1.0,
                "emergency_exit": {
                    "type": emergency_type,
                    "equity_stop_pct": equity_stop_pct,
                    "rule": "Flatten all basket legs when open basket loss reaches 1% of account equity.",
                },
                "gap_sensitivity": "NOT_EVALUATED",
                "spread_slippage_sensitivity": "NOT_EVALUATED",
                "worst_historical_sequence": {
                    "max_adverse_levels": "EVIDENCE_MISSING",
                    "max_drawdown_pct": "EVIDENCE_MISSING",
                    "evidence": "EVIDENCE_MISSING",
                },
                "stress_sequence": {
                    "scenario": "adverse trend to max_levels then continues",
                    "result_pct": "EVIDENCE_MISSING",
                    "evidence": "EVIDENCE_MISSING",
                },
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return path


def test_scalping_style_now_passes(tmp_path: Path) -> None:
    # Old doctrine rejected HFT/scalping style; Strategy Eligibility V2 does not.
    result = _evaluate(
        _card(
            tmp_path / "review" / "scalp.md",
            slug="fast-tick-scalp",
            timeframe="M15",
            extra="Entry uses a fast M15 tick-vol scalping trigger and sub-second fills.",
        ),
        tmp_path,
    )
    assert result["verdict"] == "KEEP", result["reasons"]
    assert not any("PROHIBITED_MECHANICS:HFT" in r for r in result["reasons"])


def test_martingale_without_contract_fails_closed(tmp_path: Path) -> None:
    result = _evaluate(
        _card(
            tmp_path / "review" / "mart.md",
            slug="martingale-basket",
            fm_extra="mechanism_flags: [martingale]",
        ),
        tmp_path,
    )
    assert result["verdict"] == "REJECT"
    assert "RISK_CONTRACT_MISSING" in result["reasons"]


def test_martingale_with_valid_contract_passes(tmp_path: Path) -> None:
    _valid_risk_contract(tmp_path / "review" / "rc.json")
    result = _evaluate(
        _card(
            tmp_path / "review" / "mart_ok.md",
            slug="martingale-basket-bounded",
            fm_extra="mechanism_flags: [martingale]\nrisk_contract: rc.json",
        ),
        tmp_path,
    )
    assert result["verdict"] == "KEEP", result["reasons"]


def test_unbounded_recovery_is_rejected(tmp_path: Path) -> None:
    # Structurally valid contract, but max_levels 0 == infinite recovery sequence.
    _valid_risk_contract(tmp_path / "review" / "rc0.json", max_levels=0)
    result = _evaluate(
        _card(
            tmp_path / "review" / "grid_unbounded.md",
            slug="grid-unbounded",
            fm_extra="mechanism_flags: [grid]\nrisk_contract: rc0.json",
        ),
        tmp_path,
    )
    assert result["verdict"] == "REJECT"
    assert "UNBOUNDED_RECOVERY" in result["reasons"]


def test_no_equity_stop_is_unbounded_recovery(tmp_path: Path) -> None:
    rc = tmp_path / "review" / "rc_noeq.json"
    _valid_risk_contract(rc, emergency_type="none", equity_stop_pct=None)
    payload = _json.loads(rc.read_text(encoding="utf-8"))
    payload["max_basket_loss_pct"] = "NOT_EVALUATED"  # drop the account-loss bound too
    rc.write_text(_json.dumps(payload, indent=2), encoding="utf-8")
    result = _evaluate(
        _card(
            tmp_path / "review" / "rec_noeq.md",
            slug="recovery-no-stop",
            fm_extra="mechanism_flags: [recovery]\nrisk_contract: rc_noeq.json",
        ),
        tmp_path,
    )
    assert result["verdict"] == "REJECT"
    assert "UNBOUNDED_RECOVERY" in result["reasons"]


def test_ml_runtime_card_still_rejected(tmp_path: Path) -> None:
    result = _evaluate(
        _card(
            tmp_path / "review" / "ml.md",
            slug="lstm-entry",
            extra="Each entry is produced by an online LSTM neural network at runtime.",
        ),
        tmp_path,
    )
    assert result["verdict"] == "REJECT"
    assert any(r.startswith("PROHIBITED_MECHANICS:") and "ML" in r for r in result["reasons"])


def test_positive_vs_negative_pyramiding_are_distinct(tmp_path: Path) -> None:
    # Positive pyramiding (add to winners) is NOT tail-amplifying -> KEEP w/o contract.
    positive = _evaluate(
        _card(
            tmp_path / "review" / "pos.md",
            slug="pos-pyramid",
            extra="Trade management adds to winners as the trend extends (positive pyramiding).",
        ),
        tmp_path,
    )
    assert positive["verdict"] == "KEEP", positive["reasons"]

    # Negative pyramiding (add to losers) is tail-amplifying -> needs a contract.
    negative = _evaluate(
        _card(
            tmp_path / "review2" / "neg.md",
            slug="neg-pyramid",
            extra="Trade management keeps adding to a losing position to average down.",
        ),
        tmp_path,
    )
    assert negative["verdict"] == "REJECT"
    assert "RISK_CONTRACT_MISSING" in negative["reasons"]

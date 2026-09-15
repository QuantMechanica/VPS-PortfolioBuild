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
) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"""---
ea_id: {ea_id}
slug: {slug}
target_symbols: {symbols}
timeframe: {timeframe}
expected_dd_pct: {dd}
r4_ml_forbidden: true
---

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
        ("tick-vol-scalp", {"extra": "Entry uses a 1-second tick trigger and sub-second execution."}, "PROHIBITED_MECHANICS:HFT"),
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

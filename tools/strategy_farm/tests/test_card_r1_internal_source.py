"""Regression matrix for R1 internal-research sources (contract Section 12).

Proves the directive Section 14 cases through the real intake surfaces:
``card_intake_prescreen`` and ``farmctl`` (prebuild build-ready guard +
VALID_SOURCE_TYPES).  External-card code paths are asserted unchanged.  All
paths are injected into temp dirs; nothing touches D:/QM.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import card_intake_prescreen as prescreen  # noqa: E402
import farmctl  # noqa: E402
import research_source as rs  # noqa: E402


EXAMPLE_ID = "QM-RESEARCH-2026-0000"
EXAMPLE_DIR = Path(rs.__file__).resolve().parents[2] / "strategy-seeds" / "sources" / EXAMPLE_ID


# --------------------------------------------------------------------------- #
# Fixtures / builders
# --------------------------------------------------------------------------- #
def _matrix(path: Path) -> Path:
    path.write_text(
        "symbol,asset_class\nEURUSD.DWX,forex\nXAUUSD.DWX,commodities\n", encoding="utf-8"
    )
    return path


def _valid_store(tmp_path: Path, author: str | None = None) -> tuple[Path, Path, Path, str]:
    """Copy the worked example into a temp store, seal it reviewed, return paths.

    When *author* is given, research.json.author is rewritten before sealing so
    the durable artifact carries that author (directive §37 author generalization).
    """
    import json

    store = tmp_path / "store"
    store.mkdir(exist_ok=True)
    ledger = tmp_path / "ledger.jsonl"
    search = tmp_path / "search.jsonl"
    shutil.copytree(EXAMPLE_DIR, store / EXAMPLE_ID)
    if author is not None:
        research_path = store / EXAMPLE_ID / rs.RESEARCH_JSON
        research = json.loads(research_path.read_text(encoding="utf-8"))
        research["author"] = author
        research_path.write_text(json.dumps(research, indent=2), encoding="utf-8")
    rs.seal(EXAMPLE_ID, status="reviewed", store_root=store, ledger_path=ledger)
    digest = rs.source_hash(store / EXAMPLE_ID)
    return store, ledger, search, digest


_FTMO = (
    "Daily drawdown is capped below 5% and total drawdown below 10%. "
    "Mandatory news blackout. H1 swing horizon. "
    "No HFT, ML, grid, martingale, or averaging into losers."
)


def _card(
    path: Path,
    *,
    slug: str = "xau-regime-gap-fade",
    ea_id: str = "QM5_90010",
    symbols: str = "[XAUUSD.DWX]",
    timeframe: str = "H1",
    dd: str = "8",
    extra_frontmatter: str = "",
    provenance: str = "",
    entry_extra: str = "",
) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    fm_extra = ("\n" + extra_frontmatter.strip("\n")) if extra_frontmatter.strip() else ""
    provenance_block = (
        f"\n## Research provenance\n{provenance}\n" if provenance else ""
    )
    path.write_text(
        f"""---
ea_id: {ea_id}
slug: {slug}
target_symbols: {symbols}
timeframe: {timeframe}
expected_dd_pct: {dd}
r4_ml_forbidden: PASS{fm_extra}
---

# {slug}
{provenance_block}
## Structural cause
Forced institutional rebalancing flow creates a liquidity risk premium because inventory is slow to clear.

## Price signature and entry rules
Buy when the completed H1 close crosses the declared 20-bar high; sell on the mirrored close. {entry_extra}

## Persistence
Capacity and inventory constraints keep the institutional flow from being arbitraged immediately.

## Falsification
Kill when post-cost expectancy is non-positive in the sealed test.

## Q08/Q11 risk
Crisis gaps and mandatory news blackout behavior are tested explicitly.

## FTMO fit
{_FTMO}
""",
        encoding="utf-8",
    )
    return path


def _evaluate(tmp_path: Path, candidate: Path, **research_paths) -> dict:
    return prescreen.run_prescreen(
        [candidate],
        symbol_matrix=_matrix(tmp_path / "matrix.csv"),
        data_root=tmp_path / "data",
        approved_root=tmp_path / "approved",
        rejected_root=tmp_path / "rejected",
        **research_paths,
    )["results"][0]


def _internal_frontmatter(store_digest: str, *, source_id: str = EXAMPLE_ID,
                          artifact: str = "QM-RESEARCH://2026-0000",
                          trial: str = "7", source_hash: str | None = None) -> str:
    return (
        f"source_id: {source_id}\n"
        "source_type: internal_research\n"
        "source_author: Kimi\n"
        "source_model: kimi-code/kimi-for-coding\n"
        f"source_artifact: {artifact}\n"
        f"source_hash: {source_hash if source_hash is not None else store_digest}\n"
        f"research_trial_count: {trial}"
    )


# --------------------------------------------------------------------------- #
# T1 / T2 — external cards unchanged
# --------------------------------------------------------------------------- #
def test_r1_external_unattributed_fails(tmp_path: Path) -> None:
    # No source_id -> not build-ready (farmctl R1) and the internal branch is inert.
    assert farmctl._card_r1_build_ready({}) is False
    assert farmctl._internal_research_source_error({}) is None
    card = _card(tmp_path / "review" / "unattributed.md")
    result = _evaluate(tmp_path, card, research_store_root=tmp_path / "store",
                       research_ledger=tmp_path / "l.jsonl",
                       research_search_ledger=tmp_path / "s.jsonl")
    assert not any("INTERNAL_SOURCE_UNRESOLVED" in r for r in result["reasons"])


def test_r1_external_valid_passes(tmp_path: Path) -> None:
    fm = {"source_id": "mulham-channel-breakout-20260714", "source_type": "web_forum"}
    assert farmctl._card_r1_build_ready(fm) is True
    # External cards never enter the internal-source branch (code path unchanged).
    assert farmctl._internal_research_source_error(fm) is None
    card = _card(
        tmp_path / "review" / "external.md",
        extra_frontmatter="source_id: mulham-channel-breakout-20260714\nsource_type: web_forum",
    )
    result = _evaluate(tmp_path, card, research_store_root=tmp_path / "store",
                       research_ledger=tmp_path / "l.jsonl",
                       research_search_ledger=tmp_path / "s.jsonl")
    assert result["verdict"] == "KEEP", result["reasons"]


# --------------------------------------------------------------------------- #
# T3 — valid Kimi internal research source PASSES
# --------------------------------------------------------------------------- #
def test_r1_internal_research_valid_passes(tmp_path: Path) -> None:
    store, ledger, search, digest = _valid_store(tmp_path)
    card = _card(
        tmp_path / "review" / "internal_valid.md",
        extra_frontmatter=_internal_frontmatter(digest),
        provenance="Edge discovered via a random-forest feature-importance study; "
                   "the resulting rule set is fully deterministic.",
    )
    result = _evaluate(tmp_path, card, research_store_root=store,
                       research_ledger=ledger, research_search_ledger=search)
    assert result["verdict"] == "KEEP", result["reasons"]
    # farmctl-side guard also passes for the same frontmatter.
    fm = farmctl.parse_card_frontmatter(card)
    assert farmctl._internal_research_source_error(
        fm, research_store_root=store, research_ledger=ledger,
        research_search_ledger=search,
    ) is None


# --------------------------------------------------------------------------- #
# T3b — Fable-authored internal research source PASSES (directive §37)
# --------------------------------------------------------------------------- #
def test_r1_internal_fable_authored_passes(tmp_path: Path) -> None:
    store, ledger, search, digest = _valid_store(tmp_path, author="Fable")
    card = _card(
        tmp_path / "review" / "internal_fable.md",
        extra_frontmatter=_internal_frontmatter(digest).replace(
            "source_author: Kimi", "source_author: Fable"
        ),
        provenance="Fable-originated hypothesis, deterministically reduced to rules.",
    )
    result = _evaluate(tmp_path, card, research_store_root=store,
                       research_ledger=ledger, research_search_ledger=search)
    assert result["verdict"] == "KEEP", result["reasons"]
    fm = farmctl.parse_card_frontmatter(card)
    assert farmctl._internal_research_source_error(
        fm, research_store_root=store, research_ledger=ledger,
        research_search_ledger=search,
    ) is None


def test_r1_internal_unauthorized_author_fails(tmp_path: Path) -> None:
    store, ledger, search, digest = _valid_store(tmp_path, author="Mallory")
    card = _card(
        tmp_path / "review" / "internal_unauth.md",
        extra_frontmatter=_internal_frontmatter(digest).replace(
            "source_author: Kimi", "source_author: Mallory"
        ),
        provenance="Author is not an authorized research agent.",
    )
    result = _evaluate(tmp_path, card, research_store_root=store,
                       research_ledger=ledger, research_search_ledger=search)
    assert result["verdict"] == "REJECT"
    assert any(r.startswith("INTERNAL_SOURCE_UNRESOLVED") for r in result["reasons"])
    assert any("UNAUTHORIZED_AUTHOR" in r for r in result["reasons"])
    # farmctl build-ready guard refuses too.
    fm = farmctl.parse_card_frontmatter(card)
    guard = farmctl._internal_research_source_error(
        fm, research_store_root=store, research_ledger=ledger,
        research_search_ledger=search,
    )
    assert guard is not None and "UNAUTHORIZED_AUTHOR" in guard


# --------------------------------------------------------------------------- #
# T4 / T5 — fail-closed internal cases
# --------------------------------------------------------------------------- #
def test_r1_internal_kimi_no_artifact_fails(tmp_path: Path) -> None:
    store = tmp_path / "store"
    store.mkdir()
    ledger = tmp_path / "ledger.jsonl"
    search = tmp_path / "search.jsonl"
    card = _card(
        tmp_path / "review" / "internal_no_artifact.md",
        extra_frontmatter=_internal_frontmatter(
            "0" * 64, source_id="QM-RESEARCH-2026-0777",
            artifact="QM-RESEARCH://2026-0777",
        ),
        provenance="Claimed Kimi discovery with no durable artifact.",
    )
    result = _evaluate(tmp_path, card, research_store_root=store,
                       research_ledger=ledger, research_search_ledger=search)
    assert result["verdict"] == "REJECT"
    assert any(r.startswith("INTERNAL_SOURCE_UNRESOLVED") for r in result["reasons"])
    assert any("NOT_FOUND" in r for r in result["reasons"])
    # approve-card / build-ready guard refuses too.
    fm = farmctl.parse_card_frontmatter(card)
    guard = farmctl._internal_research_source_error(
        fm, research_store_root=store, research_ledger=ledger,
        research_search_ledger=search,
    )
    assert guard is not None and guard.startswith("INTERNAL_SOURCE_UNRESOLVED")


def test_r1_internal_missing_hash_fails_closed(tmp_path: Path) -> None:
    store, ledger, search, digest = _valid_store(tmp_path)
    card = _card(
        tmp_path / "review" / "internal_bad_hash.md",
        extra_frontmatter=_internal_frontmatter(digest, source_hash="0" * 64),
        provenance="Random-forest provenance, but the card hash is stale.",
    )
    result = _evaluate(tmp_path, card, research_store_root=store,
                       research_ledger=ledger, research_search_ledger=search)
    assert result["verdict"] == "REJECT"
    assert any("HASH_MISMATCH" in r for r in result["reasons"])


def test_r1_internal_prebuild_guard_wired(tmp_path: Path) -> None:
    """The build-ready path (prebuild_validate_card) carries the same guard."""
    store = tmp_path / "store"
    store.mkdir()
    root = tmp_path / "farm"
    approved = root / "artifacts" / "cards_approved"
    approved.mkdir(parents=True)
    card = _card(
        approved / "QM5_90010_xau-regime-gap-fade.md",
        extra_frontmatter=_internal_frontmatter(
            "0" * 64, source_id="QM-RESEARCH-2026-0777",
            artifact="QM-RESEARCH://2026-0777",
        ),
        provenance="No artifact behind this id.",
    )
    fm = farmctl.parse_card_frontmatter(card)
    result = farmctl.prebuild_validate_card(
        root, card, fm, research_store_root=store,
        research_ledger=tmp_path / "l.jsonl", research_search_ledger=tmp_path / "s.jsonl",
    )
    assert result["ok"] is False
    assert any(str(e).startswith("INTERNAL_SOURCE_UNRESOLVED") for e in result["errors"])


# --------------------------------------------------------------------------- #
# T6 / T7 — ML-scan scoping
# --------------------------------------------------------------------------- #
def test_prescreen_ml_provenance_exempt(tmp_path: Path) -> None:
    # ML term only inside '## Research provenance' -> KEEP (exempt).
    kept = _card(
        tmp_path / "review" / "prov_ml.md",
        provenance="Edge discovered via a random-forest feature-importance study.",
    )
    result = _evaluate(tmp_path, kept, research_store_root=tmp_path / "store",
                       research_ledger=tmp_path / "l.jsonl",
                       research_search_ledger=tmp_path / "s.jsonl")
    assert result["verdict"] == "KEEP", result["reasons"]

    # Same ML term inside the entry/mechanics rules -> PROHIBITED_MECHANICS:ML.
    tripped = _card(
        tmp_path / "review" / "mech_ml.md",
        slug="xau-regime-gap-fade-mech",
        entry_extra="A pre-trained random forest predicts each entry.",
    )
    result2 = _evaluate(tmp_path, tripped, research_store_root=tmp_path / "store",
                        research_ledger=tmp_path / "l.jsonl",
                        research_search_ledger=tmp_path / "s.jsonl")
    assert result2["verdict"] == "REJECT"
    assert any(r.startswith("PROHIBITED_MECHANICS:") and "ML" in r for r in result2["reasons"])


def test_prescreen_r4_frontmatter_ml_trips(tmp_path: Path) -> None:
    card = _card(
        tmp_path / "review" / "fm_ml.md",
        slug="xau-fm-ml",
        extra_frontmatter="r4_ml_forbidden: false",
        provenance="Random-forest provenance (exempt), but the frontmatter claims in-EA ML.",
    )
    result = _evaluate(tmp_path, card, research_store_root=tmp_path / "store",
                       research_ledger=tmp_path / "l.jsonl",
                       research_search_ledger=tmp_path / "s.jsonl")
    assert result["verdict"] == "REJECT"
    assert any(r.startswith("PROHIBITED_MECHANICS:") and "ML" in r for r in result["reasons"])


# --------------------------------------------------------------------------- #
# T11 / T12 — VALID_SOURCE_TYPES + fingerprint distinctness
# --------------------------------------------------------------------------- #
def test_valid_source_types_internal_research(tmp_path: Path) -> None:
    assert "internal_research" in farmctl.VALID_SOURCE_TYPES
    root = tmp_path / "farm"
    ok = farmctl.add_source(root, "QM-RESEARCH://2026-0042", "XAU gap fade",
                            "internal_research")
    assert ok.get("added") is True, ok
    bad = farmctl.add_source(root, "QM-RESEARCH://2026-0043", "bad type", "not_a_type")
    assert bad.get("added") is False


def test_fingerprint_internal_ids_distinct(tmp_path: Path) -> None:
    a = _card(tmp_path / "a.md", slug="xau-regime-gap-fade",
              extra_frontmatter="source_id: QM-RESEARCH-2026-0001")
    b = _card(tmp_path / "b.md", slug="xau-regime-gap-fade",
              extra_frontmatter="source_id: QM-RESEARCH-2026-0002")
    fp_a = farmctl.strategy_card_fingerprint(a, farmctl.parse_card_frontmatter(a))
    fp_b = farmctl.strategy_card_fingerprint(b, farmctl.parse_card_frontmatter(b))
    assert fp_a != fp_b

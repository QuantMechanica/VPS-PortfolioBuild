"""Contract tests for the deterministic Strategy Wiki projection.

Fixture: 6 records spanning every projection class, a temp repo + D:\\ runtime
card layout, a temp cloud vault, plus pipeline / book / lineage read-models.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm import strategy_wiki_sync as sws


REGISTRY_HEADER = (
    "ea_id,slug,strategy_id,status,owner,created_at,retired_at,"
    "retired_reason,retired_evidence\n"
)


def _card(ea_id: str, slug: str, **extra: str) -> str:
    fm = {
        "ea_id": ea_id,
        "slug": slug,
        "type": "strategy",
        "g0_status": "APPROVED",
        "source_type": "book",
        "source_id": f"src-{slug}",
        "source_authors": "A. Author",
        "strategy_mechanic": "atr-breakout",
        "strategy_family": "breakout",
        "timeframe": "H1",
        "target_symbols": "[EURUSD.DWX, GBPUSD.DWX]",
        "parameter_family": "atr,period",
        "direction": "long",
    }
    fm.update(extra)
    lines = ["---"] + [f"{k}: {v}" for k, v in fm.items()] + ["---", "",
             f"# {slug}", "", "Entry: X. Exit: Y.", ""]
    return "\n".join(lines)


@pytest.fixture
def fixture(tmp_path):
    repo = tmp_path / "repo"
    d = tmp_path / "D"
    vault = tmp_path / "vault"
    state = tmp_path / "state"
    for sub in [
        repo / "framework" / "registry",
        repo / "strategy-seeds" / "cards" / "approved",
        repo / "artifacts" / "cards_approved",
        d / "artifacts" / "cards_rejected",
        d / "artifacts" / "card_duplicates_g0",
        vault / "09 Strategy Wiki" / "strategies",
        state,
    ]:
        sub.mkdir(parents=True, exist_ok=True)

    # Registry: 100 active, 300 retired.
    reg = repo / "framework" / "registry" / "ea_id_registry.csv"
    reg.write_text(
        REGISTRY_HEADER
        + "100,alpha-breakout,SID100,active,Dev,2026-01-01,,,\n"
        + "300,gamma-retired,SID300,retired,Dev,2026-01-01,2026-06-01,economics,\n",
        encoding="utf-8",
    )

    # ACTIVE_CANONICAL: approved repo card.
    (repo / "strategy-seeds" / "cards" / "approved" / "QM5_100_alpha-breakout_card.md"
     ).write_text(_card("QM5_100", "alpha-breakout"), encoding="utf-8")
    # DRAFT: top-level seed.
    (repo / "strategy-seeds" / "cards" / "QM5_200_beta-draft.md").write_text(
        _card("QM5_200", "beta-draft", g0_status="PENDING", status="DRAFT"),
        encoding="utf-8")
    # RETIRED: approved card but registry says retired.
    (repo / "artifacts" / "cards_approved" / "QM5_300_gamma-retired.md").write_text(
        _card("QM5_300", "gamma-retired"), encoding="utf-8")
    # REJECTED: card in the rejected store.
    (d / "artifacts" / "cards_rejected" / "QM5_400_delta-rejected.md").write_text(
        _card("QM5_400", "delta-rejected"), encoding="utf-8")
    # DUPLICATE: card in the duplicates store.
    (d / "artifacts" / "card_duplicates_g0" / "QM5_500_epsilon-dup.md").write_text(
        _card("QM5_500", "epsilon-dup"), encoding="utf-8")
    # SUPERSEDED: approved card carrying superseded_by.
    (repo / "artifacts" / "cards_approved" / "QM5_600_zeta-superseded.md").write_text(
        _card("QM5_600", "zeta-superseded", superseded_by="QM5_100"), encoding="utf-8")

    # Pipeline read-model.
    (state / "pipeline_state.json").write_text(json.dumps({"per_ea": [
        {"ea_id": "QM5_100", "latest_pass_phase": "Q08",
         "phase_verdicts": {"Q08": "PASS"}, "status": "IN_PIPELINE",
         "final_verdict": "PENDING", "phase_blockers": [],
         "last_run_utc": "2026-09-14T00:00:00+00:00"},
    ]}), encoding="utf-8")

    # Book read-models: 100 is a DXZ incumbent.
    (state / "book_evolution_dxz.json").write_text(json.dumps({
        "incumbent": {"sleeves": [{"ea_id": 100, "symbol": "EURUSD.DWX"}]},
        "challengers": [],
    }), encoding="utf-8")
    (state / "book_evolution_ftmo.json").write_text(json.dumps({
        "incumbent": {"sleeves": []}, "challengers": [],
    }), encoding="utf-8")

    # Lineage: 100 has a declared family + parent 300 (which exists → resolvable).
    (state / "lineage_map.json").write_text(json.dumps({
        "schema": "qm.lineage-map/v1",
        "generated_at_utc": "2026-09-15T00:00:00Z",
        "nodes": {"QM5_100": {"family": "breakout",
                              "card_lineage": {"parent_id": "QM5_300"}}},
        "edges": [{"from": "QM5_300", "to": "QM5_100", "relation": "parameter_variant"}],
        "families": {"breakout": ["QM5_100", "QM5_300"]},
    }), encoding="utf-8")

    return sws.default_sources(
        repo_root=repo,
        vault_override=vault,
        d_runtime=d,
        pipeline_state=state / "pipeline_state.json",
        book_dxz=state / "book_evolution_dxz.json",
        book_ftmo=state / "book_evolution_ftmo.json",
        lineage_map=state / "lineage_map.json",
        health_out=state / "strategy_wiki_sync.json",
        live_attribution=state / "live_sleeve_attribution.json",
    )


def test_build_projects_every_class(fixture):
    r = sws.build(fixture)
    assert r.class_counts[sws.CLASS_ACTIVE] == 1
    assert r.class_counts[sws.CLASS_DRAFT] == 1
    assert r.class_counts[sws.CLASS_RETIRED] == 1
    assert r.class_counts[sws.CLASS_REJECTED] == 1
    assert r.class_counts[sws.CLASS_DUPLICATE] == 1
    assert r.class_counts[sws.CLASS_SUPERSEDED] == 1
    # Files land under the class folders.
    gen = fixture.generated_dir
    assert (gen / sws.CLASS_ACTIVE / "QM5_100_alpha-breakout.md").is_file()
    assert (gen / sws.CLASS_SUPERSEDED / "QM5_600_zeta-superseded.md").is_file()


def test_field_completeness_on_every_node(fixture):
    sws.build(fixture)
    for pclass in sws.PROJECTION_CLASSES:
        d = fixture.generated_dir / pclass
        if not d.is_dir():
            continue
        for node in d.glob("*.md"):
            scalars, _ = sws.parse_frontmatter(sws._read_text(node))
            for key in sws._FRONTMATTER_ORDER:
                if key in sws._OPTIONAL_FRONTMATTER_KEYS:
                    continue  # present only when a Second-Chance Register entry exists
                assert key in scalars, f"{node.name} missing {key}"
                assert scalars[key] != "", f"{node.name} empty {key}"


def _write_register(fixture, ea_id: str) -> None:
    fixture.second_chance_register.write_text(json.dumps({
        "schema": "qm.second-chance-register/v1",
        "records": [{
            "ea_id": ea_id,
            "primary_reason": "MULTI_POSITION",
            "second_chance_status": "ELIGIBLE_FOR_RECONSIDERATION",
            "eligibility": "ELIGIBLE_FOR_RECONSIDERATION",
            "priority": 77.5,
            "portfolio_utility_challenger": False,
            "tail_risk_flag": False,
        }],
    }), encoding="utf-8")


def test_second_chance_join_renders_and_is_idempotent(fixture):
    # Build with no register: no second-chance section, capture baseline hashes.
    sws.build(fixture)
    node = fixture.generated_dir / sws.CLASS_REJECTED / "QM5_400_delta-rejected.md"
    assert "Second-chance" not in sws._read_text(node)
    baseline = sws._read_text(node)

    # Add the register and rebuild: the rejected node now carries the section.
    _write_register(fixture, "QM5_400")
    r2 = sws.build(fixture)
    text = sws._read_text(node)
    assert "## Second-chance (Strategy Eligibility V2)" in text
    assert "MULTI_POSITION" in text
    assert "second_chance_reason: MULTI_POSITION" in text
    assert r2.written >= 1  # the joined node re-rendered

    # A node WITHOUT a register entry keeps its baseline bytes (no mass churn).
    active = fixture.generated_dir / sws.CLASS_ACTIVE / "QM5_100_alpha-breakout.md"
    active_bytes = active.read_bytes()

    # Rebuild again with the SAME register: fully idempotent (nothing re-written).
    r3 = sws.build(fixture)
    assert r3.written == 0
    assert active.read_bytes() == active_bytes
    assert sws._read_text(node) == text


def test_index_then_lint_green(fixture):
    sws.build(fixture)
    idx = sws.build_index(fixture, init_root_index=True)
    assert idx["node_count"] == 6
    assert (fixture.generated_dir / "_INDEX.md").is_file()
    # Root index seeded with the generated marker block, hand text preserved.
    root = fixture.wiki_root / "_INDEX.md"
    assert sws.ROOT_INDEX_BEGIN in root.read_text(encoding="utf-8")

    h = sws.lint(fixture)
    assert h["STRATEGY_WIKI_SYNC"] == "GREEN", h["counts"]
    assert h["canonical_records"] == 1
    assert h["valid_projections"] == 1
    assert all(v == 0 for v in h["counts"].values()), h["counts"]


def test_hash_change_makes_stale(fixture):
    sws.build(fixture)
    card = (fixture.repo_root / "strategy-seeds" / "cards" / "approved"
            / "QM5_100_alpha-breakout_card.md")
    card.write_text(card.read_text(encoding="utf-8") + "\nExtra line.\n", encoding="utf-8")
    h = sws.lint(fixture)
    assert "QM5_100" in h["samples"]["stale"]
    assert h["STRATEGY_WIKI_SYNC"] == "AMBER"


def test_orphan_detection(fixture):
    sws.build(fixture)
    stray = fixture.generated_dir / sws.CLASS_ACTIVE / "QM5_999_ghost.md"
    stray.write_text("---\nea_id: QM5_999\n---\n# ghost\n", encoding="utf-8")
    h = sws.lint(fixture)
    assert h["counts"]["orphan"] >= 1
    assert h["STRATEGY_WIKI_SYNC"] == "RED"


def test_missing_active_canonical(fixture):
    sws.build(fixture)
    (fixture.generated_dir / sws.CLASS_ACTIVE / "QM5_100_alpha-breakout.md").unlink()
    h = sws.lint(fixture)
    assert "QM5_100" in h["samples"]["missing"]
    assert h["STRATEGY_WIKI_SYNC"] == "RED"


def test_idempotency_byte_identical(fixture):
    r1 = sws.build(fixture)
    active = fixture.generated_dir / sws.CLASS_ACTIVE / "QM5_100_alpha-breakout.md"
    first = active.read_bytes()
    r2 = sws.build(fixture)
    assert r1.written == 6
    assert r2.written == 0
    assert r2.skipped == 6
    assert active.read_bytes() == first


def test_live_pnl_join_renders_on_live_node(fixture):
    import json as _json
    # QM5_100 is the DXZ incumbent (ea_id 100) -> gets a live realized value.
    fixture.live_attribution.write_text(_json.dumps({
        "schema": "qm.live-sleeve-attribution/v1",
        "status": "PRESENT",
        "sleeves": [
            {"ea_id": 100, "magic": 1000000, "symbol": "EURUSD",
             "realized_pnl": 342.96, "realized_dd": 55.0, "trade_count": 7,
             "last_deal_utc": "2026-09-15T15:00:00Z"},
        ],
        "book_totals": {"realized_pnl": 342.96, "realized_dd": 55.0},
    }), encoding="utf-8")
    sws.build(fixture)
    node = fixture.generated_dir / sws.CLASS_ACTIVE / "QM5_100_alpha-breakout.md"
    scalars, _ = sws.parse_frontmatter(sws._read_text(node))
    assert scalars["live_realized_net_usd"] == "342.96"
    assert scalars["live_trade_count"] == "7"
    # A non-live EA (QM5_200 draft) with feed PRESENT renders NOT_APPLICABLE (no churn value).
    draft = fixture.generated_dir / sws.CLASS_DRAFT / "QM5_200_beta-draft.md"
    dscalars, _ = sws.parse_frontmatter(sws._read_text(draft))
    assert dscalars["live_realized_net_usd"] == sws.NOT_APPLICABLE


def test_handwritten_node_never_overwritten(fixture):
    hand = fixture.strategies_dir / "QM5_100_alpha-breakout.md"
    hand.write_text("# HAND WRITTEN\nDo not touch.\n", encoding="utf-8")
    before = hand.read_bytes()
    sws.build(fixture)
    assert hand.read_bytes() == before
    node = (fixture.generated_dir / sws.CLASS_ACTIVE / "QM5_100_alpha-breakout.md")
    scalars, _ = sws.parse_frontmatter(sws._read_text(node))
    assert scalars["handwritten_node"] == "[[strategies/QM5_100_alpha-breakout]]"


def test_build_single_hook(fixture):
    path = sws.build_single("QM5_100", sources=fixture)
    assert path is not None and path.is_file()
    assert sws.build_single("QM5_404040", sources=fixture) is None


def test_class_change_prunes_old_node(fixture):
    sws.build(fixture)
    active = fixture.generated_dir / sws.CLASS_ACTIVE / "QM5_100_alpha-breakout.md"
    assert active.is_file()
    # QM5_100 becomes RETIRED: flip the registry status.
    reg = fixture.repo_root / "framework" / "registry" / "ea_id_registry.csv"
    reg.write_text(reg.read_text(encoding="utf-8").replace(
        "100,alpha-breakout,SID100,active", "100,alpha-breakout,SID100,retired"),
        encoding="utf-8")
    r = sws.build(fixture)
    assert r.pruned == 1
    assert not active.is_file()
    assert (fixture.generated_dir / sws.CLASS_RETIRED / "QM5_100_alpha-breakout.md").is_file()
    h = sws.lint(fixture)
    assert h["counts"]["duplicate"] == 0
    assert h["counts"]["orphan"] == 0


def test_idless_records_are_not_duplicates(fixture):
    # Two id-less draft seeds with distinct slugs -> two DRAFT nodes, no dup.
    seeds = fixture.repo_root / "strategy-seeds" / "cards"
    (seeds / "idless-one.md").write_text(
        _card("TBD", "idless-one", g0_status="PENDING", status="DRAFT"), encoding="utf-8")
    (seeds / "idless-two.md").write_text(
        _card("TBD", "idless-two", g0_status="PENDING", status="DRAFT"), encoding="utf-8")
    sws.build(fixture)
    sws.build_index(fixture, init_root_index=True)
    h = sws.lint(fixture)
    assert h["counts"]["duplicate"] == 0, h["samples"]["duplicate"]

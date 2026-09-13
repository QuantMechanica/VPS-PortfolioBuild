"""Shared-grid alignment, union mode and pair exclusion for the DXZ book builder.

Before the fix `build_dxz_manifest` aligned the proposal and the incumbent on two
SEPARATE subset-union grids and then required them to be equal, so only an
incumbent self-comparison could ever pass (router ticket 3598783e; root cause in
`docs/ops/evidence/2026-09-13_dxz_book_v2/FIT_REPORT.md` section 3).  These tests
pin the repaired contract:

* one common-day grid for both sides (union-with-zero-fill over ALL compared
  keys inside the common window -- the rule `portfolio_common.align` already
  applies per subset),
* `--union` evaluating incumbent + proposal de-duplicated by (ea_id, symbol)
  across two sealed stream roots,
* `--exclude-pair` dropping a known duplicate with a recorded reason,
* an incumbent self-comparison still producing exactly the legacy metrics,
* `--analysis-only` never reaching the live risk freeze and never writing.

The not-worse gate and the concentration policy are untouched by these tests.
"""
from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import build_book_dxz as bbd
from tools.strategy_farm.portfolio import concentration_tail
from tools.strategy_farm.portfolio.book_builder_common import (
    BookBuildError,
    aligned_matrix,
    book_metrics,
    capped_inverse_vol,
    common_window,
    portfolio_daily,
)


EURUSD = (9001, "EURUSD.DWX")
GBPUSD = (9002, "GBPUSD.DWX")
USDJPY = (9003, "USDJPY.DWX")
XAUUSD = (9004, "XAUUSD.DWX")

# Day patterns chosen so the proposal-only grid ({3,4,5,8}) and the
# incumbent-only grid ({3,5,6,7,8}) genuinely differ inside the common window
# [day 3, day 8]; the shared grid is their union, {3,4,5,6,7,8}.
STREAM_DAYS = {
    EURUSD: [1, 3, 5, 9],
    GBPUSD: [2, 4, 8],
    USDJPY: [3, 6, 8],
    XAUUSD: [3, 5, 7, 9],
}
NETS = [180.0, -90.0, 240.0, -60.0, 150.0, -110.0, 300.0, -70.0, 210.0]


def _epoch(day: int) -> int:
    stamp = dt.datetime(2020, 1, day, 12, 0, tzinfo=dt.UTC)
    return int(stamp.timestamp())


def _write_stream(root: Path, key: tuple[int, str], days: list[int], *, scale: float = 1.0) -> None:
    ea_id, symbol = key
    target = root / "QM" / "q08_trades" / f"{ea_id}_{symbol.replace('.', '_')}.jsonl"
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = []
    for index, day in enumerate(days):
        lines.append(json.dumps({
            "event": "TRADE_CLOSED",
            "symbol": symbol,
            "time": _epoch(day),
            "entry_time": _epoch(day) - 3600,
            "net": round(NETS[(ea_id + index) % len(NETS)] * scale, 4),
            "volume": 0.5,
            "notional": 50_000.0,
            "mae_acct": -40.0,
            "side": "BUY" if index % 2 == 0 else "SELL",
        }))
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _bundle(root: Path, keys: list[tuple[int, str]], *, scale: float = 1.0) -> Path:
    for key in keys:
        _write_stream(root, key, STREAM_DAYS[key], scale=scale)
    return root


def _roster_file(path: Path, keys: list[tuple[int, str]]) -> Path:
    path.write_text(json.dumps({
        "book": "DXZ",
        "sleeves": [{"ea_id": ea, "symbol": symbol} for ea, symbol in keys],
    }), encoding="utf-8")
    return path


def _incumbent_file(path: Path, weights: dict[tuple[int, str], float]) -> Path:
    path.write_text(json.dumps({
        "book": "DXZ_LIVE",
        "sleeves": [
            {"ea_id": ea, "symbol": symbol, "risk_percent": weight}
            for (ea, symbol), weight in sorted(weights.items())
        ],
    }), encoding="utf-8")
    return path


@pytest.fixture(autouse=True)
def _stub_registry_and_concentration(monkeypatch: pytest.MonkeyPatch) -> None:
    """Isolate grid/union logic from the repo registries and the SP-C3 policy.

    `sleeve_bindings` resolves magic rows and backtest set-files for real EA ids,
    and `concentration_tail.evaluate` needs the OWNER-ratified policy plus the
    symbol matrix. Neither is under test here and neither is modified: the stubs
    return shapes the manifest validator accepts so the alignment path is what
    the assertions measure.
    """

    def fake_bindings(repo_root: Path, keys) -> list[dict]:
        return [
            {
                "ea_id": ea,
                "symbol": symbol,
                "magic": ea * 10_000,
                "setfile": f"framework/EAs/QM5_{ea}/sets/QM5_{ea}_{symbol}_D1_backtest.set",
                "setfile_sha256": f"{ea:064d}",
                "backtest_risk_fixed": 1000.0,
                "backtest_risk_percent": 0.0,
            }
            for ea, symbol in sorted(keys)
        ]

    def fake_evaluate(**kwargs) -> dict:
        return {
            "schema": "qm.concentration-tail-report/v1",
            "application_authority": "OWNER_ONLY",
            "deployment_action": "NONE",
            "autotrading_action": "NONE",
            "policy_status": "OWNER_RATIFIED",
            "builder_eligible": True,
            "concentration_reject": [],
            "n_keys": len(kwargs["keys"]),
            "n_days": len(kwargs["dates"]),
        }

    monkeypatch.setattr(bbd, "sleeve_bindings", fake_bindings)
    monkeypatch.setattr(concentration_tail, "evaluate", fake_evaluate)


def _build(tmp_path: Path, **overrides):
    roster = _roster_file(tmp_path / "roster.json", overrides.pop("roster_keys", [EURUSD, GBPUSD]))
    incumbent = _incumbent_file(
        tmp_path / "incumbent.json",
        overrides.pop("incumbent_weights", {USDJPY: 1.0, XAUUSD: 1.0}),
    )
    return bbd.build_dxz_manifest(
        roster_path=roster,
        incumbent_path=incumbent,
        total_risk_pct=overrides.pop("total_risk_pct", 2.0),
        sleeve_cap_pct=overrides.pop("sleeve_cap_pct", 1.5),
        as_of="2026-09-12",
        **overrides,
    )


def test_differing_rosters_resolve_to_one_shared_grid(tmp_path: Path) -> None:
    root = _bundle(tmp_path / "streams", [EURUSD, GBPUSD, USDJPY, XAUUSD])
    manifest = _build(tmp_path, stream_root=root, incumbent_stream_root=root)

    # The old builder raised INPUT_INVALID here; a status is now produced.
    assert manifest["status"] in {
        "APPLY_RECOMMENDED", "NOT_WORSE_BAR_NOT_MET",
        "CONCENTRATION_CAP_BREACH", "CONCENTRATION_POLICY_UNRATIFIED",
    }
    window = manifest["comparison"]["window"]
    assert (window["start"], window["end"]) == ("2020-01-03", "2020-01-08")
    # union of ALL four streams inside the window, not either roster's subset
    assert window["days"] == 6
    assert manifest["comparison"]["grid"] == "SHARED_COMMON_DAY_GRID_UNION_OF_ALL_COMPARED_KEYS"
    assert manifest["comparison"]["proposal"]["n_days"] == 6
    assert manifest["comparison"]["incumbent"]["n_days"] == 6
    assert set(manifest["comparison"]["not_worse_gate"]["checks"]) == {
        "return_to_maxdd_not_worse", "worst_day_not_worse", "maxdd_not_worse",
    }


def test_legacy_subset_grids_really_did_differ(tmp_path: Path) -> None:
    """Guards the fixture: without the fix these two rosters are uncomparable."""
    from tools.strategy_farm.portfolio.book_builder_common import load_daily

    root = _bundle(tmp_path / "streams", [EURUSD, GBPUSD, USDJPY, XAUUSD])
    daily, _ = load_daily(root, [EURUSD, GBPUSD, USDJPY, XAUUSD])
    start, end = common_window(daily, [EURUSD, GBPUSD, USDJPY, XAUUSD])
    _, proposal_dates, _ = aligned_matrix(daily, [EURUSD, GBPUSD], start, end)
    _, incumbent_dates, _ = aligned_matrix(daily, [USDJPY, XAUUSD], start, end)
    assert proposal_dates != incumbent_dates


def test_incumbent_self_comparison_matches_legacy_metrics(tmp_path: Path) -> None:
    """Regression guard: roster == incumbent must reproduce the old numbers."""
    from tools.strategy_farm.portfolio.book_builder_common import load_daily

    root = _bundle(tmp_path / "streams", [USDJPY, XAUUSD])
    weights = {USDJPY: 1.2, XAUUSD: 0.8}
    manifest = _build(
        tmp_path,
        roster_keys=[USDJPY, XAUUSD],
        incumbent_weights=weights,
        stream_root=root,
        incumbent_stream_root=root,
    )

    keys = [USDJPY, XAUUSD]
    daily, _ = load_daily(root, keys)
    start, end = common_window(daily, keys)
    legacy_keys, legacy_dates, legacy_matrix = aligned_matrix(daily, keys, start, end)
    legacy_weights = capped_inverse_vol(legacy_keys, legacy_matrix, total=2.0, cap=1.5)
    legacy_proposal = book_metrics(
        portfolio_daily(legacy_keys, legacy_matrix, legacy_weights), len(legacy_keys), 100_000.0
    )
    legacy_incumbent = book_metrics(
        portfolio_daily(legacy_keys, legacy_matrix, weights), len(legacy_keys), 100_000.0
    )

    assert manifest["comparison"]["window"]["days"] == len(legacy_dates)
    assert manifest["comparison"]["proposal"] == legacy_proposal
    assert manifest["comparison"]["incumbent"] == legacy_incumbent
    assert manifest["comparison"]["not_worse_gate"] == bbd._gate(legacy_proposal, legacy_incumbent)


def test_union_mode_deduplicates_and_reads_both_stream_roots(tmp_path: Path) -> None:
    proposal_root = _bundle(tmp_path / "proposal", [EURUSD, GBPUSD])
    # the overlapping sleeve exists in BOTH roots with different bytes
    incumbent_root = _bundle(tmp_path / "incumbent_streams", [GBPUSD, USDJPY], scale=3.0)

    manifest = _build(
        tmp_path,
        roster_keys=[EURUSD, GBPUSD],
        incumbent_weights={GBPUSD: 1.0, USDJPY: 1.0},
        stream_root=proposal_root,
        incumbent_stream_root=incumbent_root,
        union=True,
        total_risk_pct=3.0,
        sleeve_cap_pct=1.5,
    )

    composition = manifest["roster"]["composition"]
    assert composition["mode"] == "UNION_WITH_INCUMBENT"
    assert composition["evaluated_sleeves"] == 3
    assert composition["deduplication_rule"] == "PROPOSAL_ROW_WINS_ON_EA_SYMBOL"
    assert composition["deduplicated_overlap"] == [{"ea_id": 9002, "symbol": "GBPUSD.DWX"}]
    assert composition["incumbent_only_sleeves"] == [{"ea_id": 9003, "symbol": "USDJPY.DWX"}]
    assert [(row["ea_id"], row["symbol"]) for row in manifest["sleeves"]] == [
        EURUSD, GBPUSD, USDJPY,
    ]

    sources = manifest["stream_basis"]["sources"]
    by_root = {part["root"]: part["keys"] for part in sources}
    assert by_root[str(proposal_root.resolve())] == ["9001:EURUSD.DWX", "9002:GBPUSD.DWX"]
    assert by_root[str(incumbent_root.resolve())] == ["9003:USDJPY.DWX"]
    # proposal row wins: the overlap is NOT re-read from the incumbent bundle
    assert "9002:GBPUSD.DWX" not in by_root[str(incumbent_root.resolve())]


def test_union_mode_prefers_proposal_bytes_for_an_overlapping_sleeve(tmp_path: Path) -> None:
    proposal_root = _bundle(tmp_path / "proposal", [EURUSD, GBPUSD])
    incumbent_root = _bundle(tmp_path / "incumbent_streams", [GBPUSD, USDJPY], scale=3.0)
    kwargs = dict(
        roster_keys=[EURUSD, GBPUSD],
        incumbent_weights={GBPUSD: 1.0, USDJPY: 1.0},
        union=True,
        total_risk_pct=3.0,
        sleeve_cap_pct=1.5,
    )
    from_proposal = _build(
        tmp_path, stream_root=proposal_root, incumbent_stream_root=incumbent_root, **kwargs
    )
    # flipping which root is consulted first changes the overlap's contribution,
    # proving the sleeve really is sourced from the winning root
    from_incumbent = _build(
        tmp_path, stream_root=incumbent_root, incumbent_stream_root=incumbent_root,
        **{**kwargs, "roster_keys": [GBPUSD]},
    )
    assert (
        from_proposal["stream_basis"]["stream_sha256"]["9002:GBPUSD.DWX"]
        != from_incumbent["stream_basis"]["stream_sha256"]["9002:GBPUSD.DWX"]
    )


def test_exclude_pair_drops_the_duplicate_with_a_recorded_reason(tmp_path: Path) -> None:
    root = _bundle(tmp_path / "streams", [EURUSD, GBPUSD, USDJPY, XAUUSD])
    manifest = _build(
        tmp_path,
        roster_keys=[EURUSD, GBPUSD],
        stream_root=root,
        incumbent_stream_root=root,
        exclude_pairs=[GBPUSD],
        total_risk_pct=1.0,
        sleeve_cap_pct=1.0,
    )
    assert [(row["ea_id"], row["symbol"]) for row in manifest["sleeves"]] == [EURUSD]
    dropped = manifest["roster"]["composition"]["dropped"]
    assert dropped == [{
        "ea_id": 9002,
        "symbol": "GBPUSD.DWX",
        "reason": "EXCLUDED_BY_OPERATOR_EXCLUDE_PAIR",
        "was_in_proposal": True,
        "was_in_incumbent": False,
    }]
    # the incumbent baseline is never edited by an exclusion
    assert manifest["comparison"]["incumbent"]["n_sleeves"] == 2


def test_exclude_pair_absent_from_the_roster_is_recorded_not_silent(tmp_path: Path) -> None:
    root = _bundle(tmp_path / "streams", [EURUSD, GBPUSD, USDJPY, XAUUSD])
    manifest = _build(
        tmp_path, stream_root=root, incumbent_stream_root=root, exclude_pairs=[(4242, "NZDUSD.DWX")]
    )
    assert manifest["roster"]["composition"]["dropped"] == [{
        "ea_id": 4242,
        "symbol": "NZDUSD.DWX",
        "reason": "EXCLUDE_PAIR_NOT_IN_EVALUATED_ROSTER",
        "was_in_proposal": False,
        "was_in_incumbent": False,
    }]


def test_excluding_every_sleeve_fails_closed(tmp_path: Path) -> None:
    root = _bundle(tmp_path / "streams", [EURUSD, GBPUSD, USDJPY, XAUUSD])
    with pytest.raises(BookBuildError, match="nothing left to evaluate"):
        _build(
            tmp_path, stream_root=root, incumbent_stream_root=root,
            exclude_pairs=[EURUSD, GBPUSD],
        )


def test_a_sleeve_no_root_seals_is_still_fail_closed(tmp_path: Path) -> None:
    proposal_root = _bundle(tmp_path / "proposal", [EURUSD, GBPUSD])
    incumbent_root = _bundle(tmp_path / "incumbent_streams", [USDJPY])
    with pytest.raises(BookBuildError, match="missing roster sleeves: 9004:XAUUSD.DWX"):
        _build(
            tmp_path, stream_root=proposal_root, incumbent_stream_root=incumbent_root,
            incumbent_weights={USDJPY: 1.0, XAUUSD: 1.0},
        )


def test_parse_pair_normalizes_and_rejects_garbage() -> None:
    assert bbd.parse_pair("41221:eurusd.dwx") == (41221, "EURUSD.DWX")
    assert bbd.parse_pair(" 41221 : EURUSD ") == (41221, "EURUSD.DWX")
    with pytest.raises(BookBuildError, match="must be EA:SYMBOL"):
        bbd.parse_pair("41221")


def test_analysis_only_prints_status_and_never_touches_the_risk_freeze(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    root = _bundle(tmp_path / "streams", [EURUSD, GBPUSD, USDJPY, XAUUSD])
    roster = _roster_file(tmp_path / "roster.json", [EURUSD, GBPUSD])
    incumbent = _incumbent_file(tmp_path / "incumbent.json", {USDJPY: 1.0, XAUUSD: 1.0})
    out_dir = tmp_path / "out"

    monkeypatch.setattr(
        bbd.book_build_guard, "require_book_build_allowed", lambda *a, **k: None
    )
    freeze_calls: list[str] = []

    def spy(reason: str) -> None:
        freeze_calls.append(reason)

    monkeypatch.setattr(bbd.risk_freeze, "assert_live_book_mutation_allowed", spy)

    code = bbd.main([
        "--roster", str(roster),
        "--incumbent", str(incumbent),
        "--stream-root", str(root),
        "--incumbent-stream-root", str(root),
        "--total-risk-pct", "1.0",
        "--sleeve-cap-pct", "1.0",
        "--as-of", "2026-09-12",
        "--out-dir", str(out_dir),
        "--exclude-pair", "9002:GBPUSD.DWX",
        "--analysis-only",
    ])
    assert code == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["analysis_only"] is True
    assert payload["manifest_written"] is False
    assert payload["sleeves"] == 1
    # excluding GBPUSD removes its trading days from the shared grid too
    assert payload["window"]["days"] == 5
    assert payload["deployment_action"] == "NONE"
    assert payload["autotrading_action"] == "NONE"
    assert payload["roster_composition"]["dropped"][0]["reason"] == "EXCLUDED_BY_OPERATOR_EXCLUDE_PAIR"
    # the freeze governs MINTING only; analysis never consults it and writes nothing
    assert freeze_calls == []
    assert not out_dir.exists()


def test_mint_path_still_runs_the_risk_freeze_before_any_write(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    root = _bundle(tmp_path / "streams", [EURUSD, GBPUSD, USDJPY, XAUUSD])
    roster = _roster_file(tmp_path / "roster.json", [EURUSD, GBPUSD])
    incumbent = _incumbent_file(tmp_path / "incumbent.json", {USDJPY: 1.0, XAUUSD: 1.0})
    out_dir = tmp_path / "out"

    monkeypatch.setattr(
        bbd.book_build_guard, "require_book_build_allowed", lambda *a, **k: None
    )

    def blocked(reason: str) -> None:
        raise bbd.risk_freeze.RiskFreezeBlocked("freeze active", {"status": "ACTIVE"})

    monkeypatch.setattr(bbd.risk_freeze, "assert_live_book_mutation_allowed", blocked)

    code = bbd.main([
        "--roster", str(roster),
        "--incumbent", str(incumbent),
        "--stream-root", str(root),
        "--incumbent-stream-root", str(root),
        "--total-risk-pct", "2.0",
        "--sleeve-cap-pct", "1.5",
        "--as-of", "2026-09-12",
        "--out-dir", str(out_dir),
    ])
    captured = capsys.readouterr()
    assert code == 2
    assert json.loads(captured.out)["status"] == "LIVE_RISK_FREEZE_BLOCKED"
    # the analytic verdict is still emitted (on stderr) before the guard refuses
    assert json.loads(captured.err)["window"]["days"] == 6
    assert not out_dir.exists()

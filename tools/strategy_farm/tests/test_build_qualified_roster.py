from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.build_qualified_roster import (
    RosterBuildError,
    build_qualified_roster,
)
from tools.strategy_farm.portfolio.book_builder_common import (
    SCHEMA,
    resolve_roster,
)


REQUIRED_SLEEVE_FIELDS = {
    "ea_id", "symbol", "q10_verdict", "family", "timeframe", "magic",
    "ex5", "ex5_sha256", "setfile", "setfile_sha256",
    "backtest_risk_fixed", "backtest_risk_percent",
}


def _make_ea(
    repo_root: Path,
    ea_id: int,
    slug: str,
    symbol: str,
    timeframe: str,
    *,
    with_ex5: bool = True,
) -> None:
    ea_dir = repo_root / "framework" / "EAs" / f"QM5_{ea_id}_{slug}"
    (ea_dir / "sets").mkdir(parents=True, exist_ok=True)
    if with_ex5:
        (ea_dir / f"QM5_{ea_id}_{slug}.ex5").write_bytes(
            f"EX5::{ea_id}::{symbol}".encode("ascii")
        )
    setname = f"QM5_{ea_id}_{slug}_{symbol}_{timeframe}_backtest.set"
    (ea_dir / "sets" / setname).write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8"
    )


def _write_magic(repo_root: Path, rows: list[tuple[int, str, int, str, int]]) -> None:
    registry = repo_root / "framework" / "registry" / "magic_numbers.csv"
    registry.parent.mkdir(parents=True, exist_ok=True)
    lines = ["ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status"]
    for ea_id, slug, slot, symbol, magic in rows:
        lines.append(f"{ea_id},{slug},{slot},{symbol},{magic},2026-01-01,Test,active")
    registry.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _fixture_repo(tmp_path: Path, *, ea90003_ex5: bool = True, magic_for_90003: bool = True) -> Path:
    """A minimal repo tree with three synthetic qualified sleeves."""
    repo = tmp_path / "repo"
    _make_ea(repo, 90001, "alpha-mr", "EURUSD.DWX", "H1")
    _make_ea(repo, 90002, "beta-bo", "GBPUSD.DWX", "D1")
    _make_ea(repo, 90003, "gamma-tr", "USDJPY.DWX", "H4", with_ex5=ea90003_ex5)
    rows = [
        (90001, "alpha-mr", 0, "EURUSD.DWX", 900010000),
        (90002, "beta-bo", 0, "GBPUSD.DWX", 900020000),
    ]
    if magic_for_90003:
        rows.append((90003, "gamma-tr", 0, "USDJPY.DWX", 900030000))
    _write_magic(repo, rows)
    return repo


def _rows(*pairs: tuple[str, str]) -> list[dict[str, str]]:
    return [{"ea_id": ea, "symbol": symbol} for ea, symbol in pairs]


def test_synthetic_guard_rows_produce_a_builder_loadable_roster(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    roster = build_qualified_roster(
        venue="dxz",
        db_path=tmp_path / "unused.sqlite",  # never read: rows are injected
        order_dir=tmp_path / "orders",  # absent order -> guard refuses (expected)
        repo_root=repo,
        qualified_rows=_rows(("90002", "GBPUSD.DWX"), ("90001", "EURUSD.DWX")),
        generated_at="2026-09-03T00:00:00Z",
    )

    assert roster["schema"] == SCHEMA
    assert len(roster["q10_pass"]) == 2
    for sleeve in roster["q10_pass"]:
        assert REQUIRED_SLEEVE_FIELDS <= set(sleeve), sorted(REQUIRED_SLEEVE_FIELDS - set(sleeve))
        assert sleeve["q10_verdict"] == "PASS"
        assert sleeve["backtest_risk_fixed"] > 0
        assert sleeve["backtest_risk_percent"] == 0
        assert len(sleeve["ex5_sha256"]) == 64

    # Per-sleeve identity is canonicalised and sorted (ea_id asc).
    identities = [(s["ea_id"], s["symbol"], s["timeframe"]) for s in roster["q10_pass"]]
    assert identities == [
        (90001, "EURUSD.DWX", "H1"),
        (90002, "GBPUSD.DWX", "D1"),
    ]
    # ex5 sha256 is the real digest of the fixture binary.
    ex5_abs = repo / "framework" / "EAs" / "QM5_90001_alpha-mr" / "QM5_90001_alpha-mr.ex5"
    assert roster["q10_pass"][0]["ex5_sha256"] == hashlib.sha256(ex5_abs.read_bytes()).hexdigest()

    # The builders load a roster through book_builder_common.resolve_roster.
    roster_path = tmp_path / "roster.json"
    roster_path.write_text(json.dumps(roster), encoding="utf-8")
    keys, provenance = resolve_roster(roster_path)
    assert keys == [(90001, "EURUSD.DWX"), (90002, "GBPUSD.DWX")]
    assert provenance["mode"] == SCHEMA


def test_roster_binds_the_census_snapshot_and_qualified_ids(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    roster = build_qualified_roster(
        venue="ftmo",
        db_path=tmp_path / "unused.sqlite",
        order_dir=tmp_path / "orders",
        repo_root=repo,
        qualified_rows=_rows(("90001", "EURUSD.DWX"), ("90002", "GBPUSD.DWX")),
        generated_at="2026-09-03T12:34:56Z",
    )
    census = roster["census"]
    assert census["qualified_pairs"] == 2
    assert census["qualified_ids"] == [
        {"ea_id": 90001, "symbol": "EURUSD.DWX"},
        {"ea_id": 90002, "symbol": "GBPUSD.DWX"},
    ]
    # The guard's own status snapshot is embedded verbatim (dataclass fields).
    guard = census["guard_status"]
    assert guard["qualified_pairs"] == 2
    assert guard["allowed"] is False  # no OWNER order in the scratch order-dir
    assert set(guard) == {
        "allowed", "qualified_pairs", "distinct_eas",
        "strategy_families", "order_artifact", "reasons",
    }
    assert roster["generated_at"] == "2026-09-03T12:34:56Z"
    assert roster["venue"] == "ftmo"
    assert roster["provenance"]["census_source"] == "book_build_guard._qualified_pair_rows"
    assert roster["provenance"]["db_access_mode"] == "ro"
    assert roster["q16_outcomes"] == []


def test_pair_missing_ex5_is_refused_with_a_reason(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path, ea90003_ex5=False)
    with pytest.raises(RosterBuildError, match="90003:USDJPY.DWX: ex5 binary missing"):
        build_qualified_roster(
            venue="dxz",
            db_path=tmp_path / "unused.sqlite",
            order_dir=tmp_path / "orders",
            repo_root=repo,
            qualified_rows=_rows(("90001", "EURUSD.DWX"), ("90003", "USDJPY.DWX")),
            generated_at="2026-09-03T00:00:00Z",
        )


def test_pair_missing_magic_registry_row_is_refused_with_a_reason(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path, magic_for_90003=False)
    with pytest.raises(RosterBuildError, match="90003:USDJPY.DWX: active magic registry row missing"):
        build_qualified_roster(
            venue="dxz",
            db_path=tmp_path / "unused.sqlite",
            order_dir=tmp_path / "orders",
            repo_root=repo,
            qualified_rows=_rows(("90001", "EURUSD.DWX"), ("90003", "USDJPY.DWX")),
            generated_at="2026-09-03T00:00:00Z",
        )


def test_unsupported_venue_is_rejected(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    with pytest.raises(ValueError, match="venue must be one of"):
        build_qualified_roster(
            venue="crypto",
            db_path=tmp_path / "unused.sqlite",
            order_dir=tmp_path / "orders",
            repo_root=repo,
            qualified_rows=_rows(("90001", "EURUSD.DWX")),
            generated_at="2026-09-03T00:00:00Z",
        )

from __future__ import annotations

import datetime as dt
import inspect
import re
from pathlib import Path
from types import MappingProxyType

import pytest

from tools.strategy_farm import agent_router, book_build_guard, deploy_tlive_book
from tools.strategy_farm.portfolio import (
    build_book_dxz,
    build_book_ftmo,
    portfolio_periodic_report,
)


REPO_ROOT = Path(__file__).resolve().parents[3]


def _rows(count: int, *, eas: int | None = None) -> list[dict]:
    distinct = count if eas is None else eas
    return [
        {
            "ea_id": f"QM5_{900000 + (index % distinct)}",
            "symbol": f"SYM{index}.DWX",
        }
        for index in range(count)
    ]


def _pool(monkeypatch: pytest.MonkeyPatch, count: int, *, eas: int | None = None) -> None:
    rows = _rows(count, eas=eas)
    monkeypatch.setattr(book_build_guard, "_qualified_pair_rows", lambda *_args: rows)
    monkeypatch.setattr(
        book_build_guard,
        "_count_strategy_families",
        lambda values: len({row["ea_id"] for row in values}),
    )


def _order(
    order_dir: Path,
    venue: str,
    date: dt.date | None = None,
    line: str | None = None,
) -> Path:
    stamp = date or dt.date.today()
    path = order_dir / f"{stamp.isoformat()}_owner_book_order_{venue}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    expected = f"OWNER-ORDER: BOOK_BUILD {venue} {stamp.isoformat()}"
    path.write_text((line if line is not None else expected) + "\n", encoding="utf-8")
    return path


def test_below_25_refuses_even_with_owner_order(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _pool(monkeypatch, 24, eas=8)
    _order(tmp_path, "dxz")

    result = book_build_guard.check_book_build_allowed("dxz", tmp_path / "state.db", tmp_path)

    assert result.allowed is False
    assert result.qualified_pairs == 24
    assert result.distinct_eas == 8
    assert result.strategy_families == 8
    assert any(
        "qualified_pairs_below_minimum: 24 < 25" in reason
        for reason in result.reasons
    )


@pytest.mark.parametrize(
    ("setup", "reason"),
    [
        ("missing", "owner_order_missing"),
        ("invalid", "owner_order_invalid"),
        ("wrong", "owner_order_wrong_venue"),
        ("future", "owner_order_future_dated"),
    ],
)
def test_missing_invalid_wrong_venue_and_future_orders_refuse(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    setup: str,
    reason: str,
) -> None:
    _pool(monkeypatch, 25)
    if setup == "invalid":
        _order(tmp_path, "dxz", line="OWNER approval without the machine line")
    elif setup == "wrong":
        _order(tmp_path, "ftmo")
    elif setup == "future":
        _order(tmp_path, "dxz", date=dt.date.today() + dt.timedelta(days=1))

    result = book_build_guard.check_book_build_allowed("dxz", tmp_path / "state.db", tmp_path)

    assert result.allowed is False
    assert result.qualified_pairs == 25
    assert result.order_artifact is None
    assert any(item.startswith(reason) for item in result.reasons)


def test_25_and_matching_owner_order_pass(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _pool(monkeypatch, 25, eas=10)
    artifact = _order(tmp_path, "dxz")

    result = book_build_guard.check_book_build_allowed("DXZ", tmp_path / "state.db", tmp_path)

    assert result.allowed is True
    assert result.qualified_pairs == 25
    assert result.distinct_eas == 10
    assert result.strategy_families == 10
    assert result.order_artifact == str(artifact.resolve())
    assert result.reasons == []


def test_dxz_and_ftmo_orders_are_independent(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _pool(monkeypatch, 25)
    _order(tmp_path, "dxz")

    dxz = book_build_guard.check_book_build_allowed("dxz", tmp_path / "state.db", tmp_path)
    ftmo = book_build_guard.check_book_build_allowed("ftmo", tmp_path / "state.db", tmp_path)

    assert dxz.allowed is True
    assert ftmo.allowed is False
    assert any("owner_order_wrong_venue" in reason for reason in ftmo.reasons)


def test_both_order_authorizes_each_venue(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _pool(monkeypatch, 25)
    _order(tmp_path, "both")

    assert book_build_guard.check_book_build_allowed(
        "dxz", tmp_path / "state.db", tmp_path
    ).allowed
    assert book_build_guard.check_book_build_allowed(
        "ftmo", tmp_path / "state.db", tmp_path
    ).allowed
    assert book_build_guard.check_book_build_allowed(
        "both", tmp_path / "state.db", tmp_path
    ).allowed


def test_require_raises_book_build_refused_with_result(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _pool(monkeypatch, 0)
    with pytest.raises(book_build_guard.BookBuildRefused) as raised:
        book_build_guard.require_book_build_allowed("dxz", tmp_path / "missing.db", tmp_path)
    assert raised.value.result.qualified_pairs == 0


def test_qualified_rows_delegate_to_rebaseline_census(monkeypatch: pytest.MonkeyPatch) -> None:
    class Connection:
        closed = False

        def close(self) -> None:
            self.closed = True

    connection = Connection()
    monkeypatch.setattr(book_build_guard.rebaseline_census, "open_ro", lambda _path: connection)
    monkeypatch.setattr(
        book_build_guard.rebaseline_census,
        "build_pairs",
        lambda _connection, limit: {
            ("QM5_1", "EURUSD.DWX"): {"frontier": "Q16"},
            ("QM5_2", "GBPUSD.DWX"): {"frontier": "Q15"},
        },
    )
    monkeypatch.setattr(
        book_build_guard.rebaseline_census,
        "summarise_pair",
        lambda record: {"highest_contiguous_valid_gate": record["frontier"]},
    )

    rows = book_build_guard._qualified_pair_rows(Path("unused.db"), "Q16")

    assert rows == [{"ea_id": "QM5_1", "symbol": "EURUSD.DWX"}]
    assert connection.closed is True


def test_manifest_accessor_resolves_v3_and_future_v4_without_consumer_literals() -> None:
    active = book_build_guard.gate_manifest.load_gate_manifest()
    expected_active = next(
        gate.id for gate in active.gates
        if gate.evidence_role.startswith(
            "SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT"
        )
    )
    assert active.terminal_requalification_gate == expected_active
    assert book_build_guard.gate_manifest.load_gate_manifest(
        book_build_guard.gate_manifest.V3_MANIFEST
    ).terminal_requalification_gate == "Q16"

    future = book_build_guard.gate_manifest.GateManifest(
        schema_version="qm.gate-manifest/v4",
        pipeline_version="fixture",
        sha256="0" * 64,
        gates=(
            book_build_guard.gate_manifest.Gate(
                id="Q14",
                ordinal=14,
                name="Best-Settings Head-to-Head + Holdout",
                authority="PIPELINE",
                runner="AUTOMATED",
                evidence_role="SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT",
                next=None,
            ),
        ),
        legacy_aliases=MappingProxyType({}),
        verdict_dimensions=(),
    )
    assert future.terminal_requalification_gate == "Q14"


def test_guard_refuses_before_each_entry_path_does_work(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    refused = book_build_guard.GuardResult(False, 0, 0, 0, None, ["fixture"])

    def deny(*_args: object) -> None:
        raise book_build_guard.BookBuildRefused(refused)

    with pytest.raises(book_build_guard.BookBuildRefused):
        deploy_tlive_book.execute(tmp_path / "missing-plan.json", book_guard=deny)
    assert not (tmp_path / "missing-plan.json").exists()

    with pytest.raises(book_build_guard.BookBuildRefused):
        portfolio_periodic_report.build_report(
            candidates_db=tmp_path / "missing.db", common_dir=tmp_path, guard=deny
        )

    runtime_root = tmp_path / "runtime"
    with pytest.raises(book_build_guard.BookBuildRefused):
        agent_router.sync_q11_candidates(runtime_root, guard=deny)
    assert not runtime_root.exists()

    monkeypatch.setattr(book_build_guard, "require_book_build_allowed", deny)
    with pytest.raises(book_build_guard.BookBuildRefused):
        build_book_dxz.main([])
    with pytest.raises(book_build_guard.BookBuildRefused):
        build_book_ftmo.main([])


def test_grep_guard_no_auto_book_path_bypasses_the_guard() -> None:
    entry_sources = {
        "deploy_tlive_book.py": (
            inspect.getsource(deploy_tlive_book.execute),
            "book_guard(\"dxz\"",
            "load_and_validate_plan(",
        ),
        "portfolio/portfolio_periodic_report.py": (
            inspect.getsource(portfolio_periodic_report.build_report),
            "guard(venue",
            "pairs = robust_pairs(",
        ),
        "agent_router.py": (
            inspect.getsource(agent_router.sync_q11_candidates),
            "guard(venue",
            "with closing(connect(root))",
        ),
        "portfolio/build_book_dxz.py": (
            inspect.getsource(build_book_dxz.main),
            "require_book_build_allowed(\"dxz\"",
            "out_dir =",
        ),
        "portfolio/build_book_ftmo.py": (
            inspect.getsource(build_book_ftmo.main),
            "require_book_build_allowed(\"ftmo\"",
            "out_dir =",
        ),
    }
    for relative, (entry_source, guard_call, downstream_call) in entry_sources.items():
        file_source = (REPO_ROOT / "tools" / "strategy_farm" / relative).read_text(
            encoding="utf-8-sig"
        )
        assert "require_book_build_allowed" in file_source, relative
        assert entry_source.index(guard_call) < entry_source.index(downstream_call), relative

    auto_sources = "\n".join(
        (REPO_ROOT / "tools" / "strategy_farm" / name).read_text(encoding="utf-8-sig")
        for name in ("agent_router.py", "farmctl.py")
    )
    assert re.search(r"(?:Q10|Q11)[^\n]{0,120}>=\s*5", auto_sources, re.IGNORECASE) is None
    assert "rebaseline_census.build_pairs" in inspect.getsource(
        book_build_guard._qualified_pair_rows
    )

"""Contract tests for OWNER-DEC-13036-XAU universe expansion."""
from __future__ import annotations

import csv
import inspect
import json
import os
import sqlite3
import sys
from pathlib import Path

import pytest


sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import farmctl  # noqa: E402
import universe_expansion as expansion  # noqa: E402


def _write_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _connection() -> sqlite3.Connection:
    connection = sqlite3.connect(":memory:")
    connection.row_factory = sqlite3.Row
    connection.execute(
        "CREATE TABLE work_items ("
        "id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT, status TEXT,"
        "verdict TEXT, payload_json TEXT, created_at TEXT, updated_at TEXT,"
        "gate_contract_version TEXT)"
    )
    return connection


def _insert(
    connection: sqlite3.Connection,
    row_id: str,
    ea_id: str,
    symbol: str,
    phase: str = "Q02",
    verdict: str = "PASS",
) -> None:
    connection.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?)",
        (
            row_id,
            phase,
            ea_id,
            symbol,
            "done",
            verdict,
            "{}",
            "2026-01-01T00:00:00+00:00",
            "2026-01-01T01:00:00+00:00",
            "v3",
        ),
    )


def _fixture_repo(tmp_path: Path) -> tuple[Path, Path]:
    repo = tmp_path / "repo"
    farm = tmp_path / "farm"
    matrix_rows = [
        {"symbol": symbol, "asset_class": family, "canonical_name_verified": "true"}
        for symbol, family in (
            ("GDAXI.DWX", "indices"),
            ("NDX.DWX", "indices"),
            ("SP500.DWX", "indices"),
            ("UK100.DWX", "indices"),
            ("WS30.DWX", "indices"),
            ("XAUUSD.DWX", "commodities"),
            *((f"{base}.DWX", "forex") for base in expansion.MAJOR_BASES),
        )
    ]
    _write_csv(
        repo / "framework/registry/dwx_symbol_matrix.csv",
        ["symbol", "asset_class", "canonical_name_verified"],
        matrix_rows,
    )
    history_rows = [
        {
            "symbol": row["symbol"],
            "period": "H1",
            "first_year": 2017,
            "last_year": 2026,
        }
        for row in matrix_rows
    ]
    _write_csv(
        repo / "framework/registry/dwx_symbol_history_ranges.csv",
        ["symbol", "period", "first_year", "last_year"],
        history_rows,
    )
    return repo, farm


def _add_ea(
    repo: Path,
    farm: Path,
    numeric: int,
    *,
    registry_status: str = "active",
    card_status: str = "APPROVED",
    single: bool = False,
    built: bool = True,
) -> tuple[str, str]:
    ea_id = f"QM5_{numeric}"
    slug = f"fixture-{numeric}"
    registry_path = repo / "framework/registry/ea_id_registry.csv"
    rows = read = []
    if registry_path.exists():
        read = expansion.read_csv(registry_path)
        rows = list(read)
    rows.append({"ea_id": numeric, "slug": slug, "status": registry_status})
    _write_csv(registry_path, ["ea_id", "slug", "status"], rows)
    magic_path = repo / "framework/registry/magic_numbers.csv"
    magic = expansion.read_csv(magic_path) if magic_path.exists() else []
    magic.append({
        "ea_id": numeric,
        "ea_slug": slug,
        "symbol_slot": 0,
        "symbol": "EURUSD.DWX",
        "magic": numeric * 10_000,
        "reserved_at": "2026-01-01",
        "reserved_by": "test",
        "status": "active",
    })
    _write_csv(
        magic_path,
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "reserved_at", "reserved_by", "status"],
        magic,
    )
    ea_label = f"{ea_id}_{slug}"
    ea_dir = repo / "framework/EAs" / ea_label
    ea_dir.mkdir(parents=True, exist_ok=True)
    (ea_dir / f"{ea_label}.mq5").write_text("input ENUM_TIMEFRAMES tf=PERIOD_H1;\n", encoding="utf-8")
    if built:
        (ea_dir / f"{ea_label}.ex5").write_bytes(b"EX5")
    card_dir = farm / "artifacts/cards_approved"
    card_dir.mkdir(parents=True, exist_ok=True)
    (card_dir / f"{ea_label}.md").write_text(
        "---\n"
        f"ea_id: {ea_id}\n"
        f"slug: {slug}\n"
        f"status: {card_status}\n"
        "g0_status: APPROVED\n"
        "period: H1\n"
        "target_symbols: [EURUSD.DWX]\n"
        f"single_symbol_only: {'true' if single else 'false'}\n"
        "---\n",
        encoding="utf-8",
    )
    return ea_id, ea_label


def test_policy_filters_and_reports_wider_cohort(tmp_path: Path) -> None:
    repo, farm = _fixture_repo(tmp_path)
    active, _ = _add_ea(repo, farm, 9001)
    no_pass, _ = _add_ea(repo, farm, 9002)
    retired, _ = _add_ea(repo, farm, 9003, registry_status="retired")
    unbuilt, _ = _add_ea(repo, farm, 9004, built=False)
    connection = _connection()
    _insert(connection, "native-active", active, "EURUSD.DWX")
    _insert(connection, "native-retired", retired, "EURUSD.DWX")
    _insert(connection, "native-unbuilt", unbuilt, "EURUSD.DWX")

    result = expansion.build_plan(connection, repo=repo, farm_root=farm)

    assert result["wider_cohort_count"] == 2  # active + no-pass
    assert result["start_cohort_count"] == 1
    assert {row["ea_id"] for row in result["rows"]} == {active}
    assert "SP500.DWX" in result["target_universe"]
    assert no_pass not in {row["ea_id"] for row in result["rows"]}


def test_existing_pair_in_any_phase_is_never_candidate(tmp_path: Path) -> None:
    repo, farm = _fixture_repo(tmp_path)
    ea_id, _ = _add_ea(repo, farm, 9010)
    connection = _connection()
    _insert(connection, "native", ea_id, "EURUSD.DWX")
    _insert(connection, "already-q04", ea_id, "SP500.DWX", phase="Q04")

    result = expansion.build_plan(connection, repo=repo, farm_root=farm)
    symbols = {row["symbol"] for row in result["rows"]}

    assert "SP500.DWX" not in symbols
    assert "EURUSD.DWX" not in symbols
    assert "XAUUSD.DWX" in symbols


def test_ranking_deepest_multi_then_single(tmp_path: Path) -> None:
    repo, farm = _fixture_repo(tmp_path)
    shallow, _ = _add_ea(repo, farm, 9020)
    deep, _ = _add_ea(repo, farm, 9021)
    single, _ = _add_ea(repo, farm, 9022, single=True)
    connection = _connection()
    for ea_id in (shallow, deep, single):
        _insert(connection, f"{ea_id}-q02", ea_id, "EURUSD.DWX")
    _insert(connection, "deep-q03", deep, "EURUSD.DWX", phase="Q03")

    result = expansion.build_plan(connection, repo=repo, farm_root=farm)
    first_rank = {}
    for row in result["rows"]:
        first_rank.setdefault(row["ea_id"], row["rank"])

    assert first_rank[deep] < first_rank[shallow] < first_rank[single]
    assert all(
        row["policy_tag"] == "CARD_SINGLE_SYMBOL"
        for row in result["rows"] if row["ea_id"] == single
    )


def test_pending_claim_order_places_universe_below_backfill(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-08-23T12:00:00+00:00"
    with sqlite3.connect(root / "state/farm_state.sqlite") as connection:
        for row_id, payload in (
            ("ordinary-backfill", {}),
            ("recovery-backfill", {"recovery_class": "INFRA"}),
            (
                "universe",
                {
                    "recovery_class": "UNIVERSE_EXPANSION_LOW_PRIORITY",
                    "universe_expansion": True,
                },
            ),
        ):
            connection.execute(
                "INSERT INTO work_items "
                "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,"
                "payload_json,created_at,updated_at) "
                "VALUES (?,'backtest','Q02','QM5_9999',?,'x.set','pending',0,?,?,?)",
                (row_id, f"{row_id}.DWX", json.dumps(payload), now, now),
            )
        ordered = [row[0] for row in connection.execute(
            "SELECT id FROM (" + farmctl.pending_claim_order_sql() + ")"
        )]

    assert ordered == ["ordinary-backfill", "recovery-backfill", "universe"]


@pytest.mark.parametrize(
    "argv",
    (
        ["--apply", "--max-rows", "1"],
        ["--apply", "--i-understand-append-only"],
        ["--apply", "--i-understand-append-only", "--max-rows", "0"],
    ),
)
def test_apply_requires_both_guards(argv: list[str]) -> None:
    with pytest.raises(SystemExit) as error:
        expansion.main(argv)
    assert error.value.code == 2


def test_card_target_update_is_union_not_replacement() -> None:
    text = (
        "---\n"
        "ea_id: QM5_1\n"
        "target_symbols: [EURUSD.DWX, XTIUSD.DWX]\n"
        "---\n"
        "body\n"
    )
    updated = expansion._expand_target_symbols(text, ["SP500.DWX", "EURUSD.DWX"])

    assert "target_symbols: [EURUSD.DWX, SP500.DWX, XTIUSD.DWX]" in updated
    assert updated.endswith("body\n")


def test_open_ro_is_query_only(tmp_path: Path) -> None:
    db = tmp_path / "state.sqlite"
    connection = sqlite3.connect(db)
    connection.execute("CREATE TABLE marker (value TEXT)")
    connection.commit()
    connection.close()

    readonly = expansion.open_ro(db)
    assert readonly.execute("PRAGMA query_only").fetchone()[0] == 1
    with pytest.raises(sqlite3.OperationalError):
        readonly.execute("INSERT INTO marker VALUES ('forbidden')")
    readonly.close()


def test_apply_preserves_active_magic_rows_in_sparse_worktrees() -> None:
    source = inspect.getsource(expansion._prepare_apply)

    assert '"--keep-obsolete"' in source
    assert '"--allow-dropped"' not in source
    assert source.count('"pwsh"') == 1
    assert '"powershell"' not in source
    build_source = inspect.getsource(expansion._run_scoped_build_check)
    assert '"-CompileWorkItemId"' in build_source
    assert '"-ClaimedTerminal"' in build_source
    assert '"-EALabel", ea_label' in build_source
    assert '"-SkipCompile"' in build_source
    assert '"-SkipMaeHookCheck"' in build_source
    assert '"-SkipSetValidation"' not in build_source
    assert '"-SkipMagicCheck"' not in build_source


def test_scoped_build_check_keeps_unrelated_static_failure_as_evidence(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
) -> None:
    monkeypatch.setattr(expansion.include_mirror, "running_terminal_names", lambda: set())
    monkeypatch.setattr(
        expansion,
        "_run",
        lambda argv, cwd: {
            "argv": argv,
            "returncode": 1,
            "stdout": (
                'build_check.compile_guard={"ok": true}\n'
                "ERROR: EA_Q08_MAE_HOOK_MISSING: legacy source\n"
                "build_check.report=D:/report.json\n"
                "build_check.result=FAIL\n"
            ),
            "stderr": "",
        },
    )

    receipt = expansion._run_scoped_build_check(
        repo=tmp_path, ea_label="QM5_9999_fixture", validation_id="12345678",
    )

    assert receipt["returncode"] == 1
    assert receipt["relevant_contract_pass"] is True


def test_scoped_build_check_rejects_setfile_failure(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
) -> None:
    monkeypatch.setattr(expansion.include_mirror, "running_terminal_names", lambda: set())
    monkeypatch.setattr(
        expansion,
        "_run",
        lambda argv, cwd: {
            "argv": argv,
            "returncode": 1,
            "stdout": (
                'build_check.compile_guard={"ok": true}\n'
                "ERROR: BUILD_CHECK_SETFILE_HEADER_INCOMPLETE: missing build_hash\n"
                "build_check.report=D:/report.json\n"
                "build_check.result=FAIL\n"
            ),
            "stderr": "",
        },
    )

    receipt = expansion._run_scoped_build_check(
        repo=tmp_path, ea_label="QM5_9999_fixture", validation_id="12345678",
    )

    assert receipt["relevant_contract_pass"] is False


def test_worktree_override_is_scoped_to_farmctl_child() -> None:
    source = inspect.getsource(expansion.apply_plan)

    assert 'farmctl_env["QM_ALLOW_NONCANONICAL"] = "1"' in source
    assert "_run(command, cwd=repo, env=farmctl_env)" in source


def test_apply_restores_nonselected_setfiles_after_scoped_build_check() -> None:
    source = inspect.getsource(expansion._prepare_apply)

    assert 'backup_dir / "nonselected_sets" / relative' in source
    assert source.count("for item in nonselected_set_backups:") == 2

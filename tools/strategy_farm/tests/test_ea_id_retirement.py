from __future__ import annotations

import csv
from pathlib import Path

from tools.strategy_farm import farmctl


REGISTRY_FIELDS = ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"]


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _fixture(tmp_path: Path, monkeypatch) -> tuple[Path, Path, Path]:
    repo = tmp_path / "repo"
    farm = tmp_path / "farm"
    _write_csv(
        repo / "framework" / "registry" / "ea_id_registry.csv",
        REGISTRY_FIELDS,
        [
            {
                "ea_id": str(ea_id),
                "slug": f"unused-{ea_id}",
                "strategy_id": "unmaterialized",
                "status": "active",
                "owner": "Research",
                "created_at": "2026-08-01",
            }
            for ea_id in range(1001, 1006)
        ],
    )
    _write_csv(
        repo / "framework" / "registry" / "magic_numbers.csv",
        ["ea_id", "magic"],
        [],
    )
    (repo / "framework" / "EAs").mkdir(parents=True)
    evidence = repo / "docs" / "ops" / "evidence" / "decision.csv"
    _write_csv(
        evidence,
        ["ea_id", "action"],
        [
            {"ea_id": "QM5_1001", "action": "RETIRE"},
            {"ea_id": "QM5_1002", "action": "ADJUDICATE"},
        ],
    )
    monkeypatch.setattr(farmctl, "REPO_ROOT", repo)
    monkeypatch.setenv("QM_AGENT_ID", "controller")
    return repo, farm, evidence


def _registry_rows(repo: Path) -> list[dict[str, str]]:
    path = repo / "framework" / "registry" / "ea_id_registry.csv"
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def _retire(
    farm: Path,
    repo: Path,
    evidence: Path,
    ea_ids: list[str],
    *,
    apply: bool = False,
    limit: int | None = None,
) -> dict:
    return farmctl.retire_ea_ids(
        farm,
        ea_ids,
        reason="OWNER-approved disposition",
        evidence=str(evidence),
        apply=apply,
        limit=limit,
        repo_root=repo,
    )


def test_retirement_csv_filters_every_non_retire_action_and_dry_runs_by_default(
    tmp_path: Path, monkeypatch
) -> None:
    repo, farm, evidence = _fixture(tmp_path, monkeypatch)
    before = (repo / "framework" / "registry" / "ea_id_registry.csv").read_bytes()

    ids, metadata = farmctl.load_retirement_ea_ids([], str(evidence), repo_root=repo)
    result = _retire(farm, repo, evidence, ids)

    assert ids == ["QM5_1001"]
    assert metadata["filtered_non_retire_count"] == 1
    assert metadata["filtered_actions"] == {"ADJUDICATE": 1, "RETIRE": 1}
    assert result["mode"] == "dry_run"
    assert result["planned_count"] == 1
    assert result["applied_count"] == 0
    assert (repo / "framework" / "registry" / "ea_id_registry.csv").read_bytes() == before


def test_retirement_refuses_magic_row_without_registry_mutation(
    tmp_path: Path, monkeypatch
) -> None:
    repo, farm, evidence = _fixture(tmp_path, monkeypatch)
    registry = repo / "framework" / "registry" / "ea_id_registry.csv"
    _write_csv(
        repo / "framework" / "registry" / "magic_numbers.csv",
        ["ea_id", "magic"],
        [{"ea_id": "QM5_1001", "magic": "100100001"}],
    )
    before = registry.read_bytes()

    result = _retire(farm, repo, evidence, ["1001"], apply=True, limit=1)

    assert result["ok"] is False
    assert result["applied_count"] == 0
    assert result["refused"] == [
        {"ea_id": "QM5_1001", "reasons": ["magic_rows_exist"]}
    ]
    assert registry.read_bytes() == before


def test_retirement_refuses_any_work_item_reference_without_registry_mutation(
    tmp_path: Path, monkeypatch
) -> None:
    repo, farm, evidence = _fixture(tmp_path, monkeypatch)
    registry = repo / "framework" / "registry" / "ea_id_registry.csv"
    farmctl.init_db(farm)
    now = "2026-08-21T00:00:00Z"
    with farmctl.connect(farm) as conn:
        conn.execute(
            "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, "
            "status, attempt_count, payload_json, created_at, updated_at) "
            "VALUES (?, 'backtest', 'Q05', ?, 'EURUSD.DWX', 'fixture.set', "
            "'pending', 0, '{}', ?, ?)",
            ("fixture-work-item", "QM5_1001_unused-1001", now, now),
        )
        conn.commit()
    before = registry.read_bytes()

    result = _retire(farm, repo, evidence, ["QM5_1001"], apply=True, limit=1)

    assert result["ok"] is False
    assert result["applied_count"] == 0
    assert result["refused"] == [
        {"ea_id": "QM5_1001", "reasons": ["work_items_exist"]}
    ]
    assert registry.read_bytes() == before


def test_retirement_refuses_materialized_ea_directory(
    tmp_path: Path, monkeypatch
) -> None:
    repo, farm, evidence = _fixture(tmp_path, monkeypatch)
    registry = repo / "framework" / "registry" / "ea_id_registry.csv"
    (repo / "framework" / "EAs" / "QM5_1001_unused-1001").mkdir()
    before = registry.read_bytes()

    result = _retire(farm, repo, evidence, ["1001"], apply=True, limit=1)

    assert result["ok"] is False
    assert result["refused"][0]["reasons"] == ["ea_directory_exists"]
    assert registry.read_bytes() == before


def test_retirement_apply_requires_limit_and_second_apply_is_noop(
    tmp_path: Path, monkeypatch
) -> None:
    repo, farm, evidence = _fixture(tmp_path, monkeypatch)
    registry = repo / "framework" / "registry" / "ea_id_registry.csv"

    missing_limit = _retire(farm, repo, evidence, ["1001"], apply=True)
    first = _retire(farm, repo, evidence, ["1001"], apply=True, limit=1)
    after_first = registry.read_bytes()
    second = _retire(farm, repo, evidence, ["1001"], apply=True, limit=1)

    assert missing_limit["reason"] == "apply_requires_explicit_positive_limit"
    assert first["ok"] is True
    assert first["applied_count"] == 1
    assert second["ok"] is True
    assert second["applied_count"] == 0
    assert second["already_retired_count"] == 1
    assert registry.read_bytes() == after_first
    row = _registry_rows(repo)[0]
    assert row["status"] == "retired"
    assert row["retired_reason"] == "OWNER-approved disposition"
    assert row["retired_evidence"] == "docs/ops/evidence/decision.csv"
    assert row["retired_at"]

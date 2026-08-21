from __future__ import annotations

import csv
import json
from pathlib import Path

from tools.strategy_farm import agent_router, farmctl


def _write_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _card(path: Path, ea_id: int, slug: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"---\nea_id: QM5_{ea_id}\nslug: {slug}\ng0_status: APPROVED\n"
        "target_symbols: [EURUSD.DWX, GBPUSD.DWX]\n---\n",
        encoding="utf-8",
    )
    return path


def _fixture(tmp_path: Path) -> tuple[Path, Path]:
    repo = tmp_path / "repo"
    farm = tmp_path / "farm"
    registry = repo / "framework" / "registry"
    _write_csv(
        registry / "ea_id_registry.csv",
        ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"],
        [
            {"ea_id": "11899", "slug": "never", "strategy_id": "x", "status": "active", "owner": "x", "created_at": "x"},
            {"ea_id": "11900", "slug": "retired", "strategy_id": "x", "status": "active", "owner": "x", "created_at": "x"},
            {"ea_id": "11901", "slug": "stale-resolver", "strategy_id": "x", "status": "active", "owner": "x", "created_at": "x"},
        ],
    )
    _write_csv(
        registry / "magic_numbers.csv",
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "reserved_at", "reserved_by", "status"],
        [
            {"ea_id": "11900", "ea_slug": "retired", "symbol_slot": "0", "symbol": "EURUSD.DWX", "magic": "119000000", "reserved_at": "x", "reserved_by": "x", "status": "retired"},
            {"ea_id": "11901", "ea_slug": "stale-resolver", "symbol_slot": "0", "symbol": "EURUSD.DWX", "magic": "119010000", "reserved_at": "x", "reserved_by": "x", "status": "active"},
        ],
    )
    resolver = repo / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    resolver.parent.mkdir(parents=True)
    resolver.write_text(
        "static const int QM_MAGIC_REG_EA_ID[0] = {};\n",
        encoding="utf-8",
    )
    approved = farm / "artifacts" / "cards_approved"
    _card(approved / "QM5_11899_never.md", 11899, "never")
    _card(approved / "QM5_11900_retired.md", 11900, "retired")
    _card(approved / "QM5_11901_stale-resolver.md", 11901, "stale-resolver")
    return farm, repo


def test_inventory_classifies_never_retired_and_resolver_miss(tmp_path: Path) -> None:
    farm, repo = _fixture(tmp_path)

    result = farmctl.missing_magic_allocation_inventory(farm, repo_root=repo)

    assert result["finding_count"] == 3
    assert result["classification_counts"] == {
        "allocated_then_retired": 1,
        "never_allocated": 1,
        "resolver_regeneration_missed": 1,
    }
    by_id = {row["ea_id"]: row for row in result["findings"]}
    assert by_id["QM5_11899"]["action"] == "GOVERNED_ALLOCATE"
    assert by_id["QM5_11900"]["action"] == "REVIEW_REQUIRED_DO_NOT_UNRETIRE"
    assert by_id["QM5_11901"]["action"] == "REGENERATE_AND_VERIFY_RESOLVER"


def test_router_magic_task_is_actionable_and_idempotent(tmp_path: Path) -> None:
    farm, repo = _fixture(tmp_path)
    card = farm / "artifacts" / "cards_approved" / "QM5_11899_never.md"
    precheck = farmctl.magic_allocation_precheck(
        farmctl.parse_card_frontmatter(card), repo_root=repo
    )

    first = agent_router.ensure_magic_precondition_task(farm, card, precheck)
    second = agent_router.ensure_magic_precondition_task(farm, card, precheck)

    assert first["enqueued"] is True
    assert second["idempotent"] is True
    assert second["task_id"] == first["task_id"]
    with agent_router.connect(farm) as conn:
        rows = conn.execute("SELECT payload_json FROM agent_tasks").fetchall()
    assert len(rows) == 1
    payload = json.loads(rows[0]["payload_json"])
    assert "governed_magic_allocator.py" in payload["command"]
    assert "--card" in payload["command"]


def test_render_build_precheck_emits_actionable_task(tmp_path: Path, monkeypatch) -> None:
    card = _card(
        tmp_path / "farm" / "artifacts" / "cards_approved" / "QM5_11899_never.md",
        11899,
        "never",
    )
    missing = {
        "ready": False,
        "classification": "never_allocated",
        "action": "GOVERNED_ALLOCATE",
    }
    monkeypatch.setattr(
        farmctl,
        "prebuild_validate_card",
        lambda *_args, **_kwargs: {"ok": True, "errors": [], "warnings": []},
    )
    monkeypatch.setattr(farmctl, "magic_allocation_precheck", lambda *_args, **_kwargs: missing)
    monkeypatch.setattr(
        farmctl,
        "_ensure_magic_precondition_task",
        lambda *_args, **_kwargs: {"enqueued": True, "task_id": "allocation-task"},
    )

    result = farmctl.render_codex_build_prompt(tmp_path / "farm", str(card), None)

    assert result["written"] is False
    assert result["actionable_task"]["task_id"] == "allocation-task"
    assert "magic_precondition_failed:never_allocated" in result["prebuild_errors"][0]

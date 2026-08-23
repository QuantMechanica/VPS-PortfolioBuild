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
        "source_id: fixture-source\n"
        "target_symbols: [EURUSD.DWX, GBPUSD.DWX]\n---\n",
        encoding="utf-8",
    )
    return path


def _resolver(path: Path, rows: list[tuple[int, int, str, int]]) -> None:
    ea_ids = ", ".join(str(row[0]) for row in rows)
    slots = ", ".join(str(row[1]) for row in rows)
    symbols = ", ".join(f'"{row[2]}"' for row in rows)
    magics = ", ".join(str(row[3]) for row in rows)
    path.write_text(
        f"static const int QM_MAGIC_REG_EA_ID[{len(rows)}] = {{{ea_ids}}};\n"
        f"static const int QM_MAGIC_REG_SLOT[{len(rows)}] = {{{slots}}};\n"
        f"static const string QM_MAGIC_REG_SYMBOL[{len(rows)}] = {{{symbols}}};\n"
        f"static const int QM_MAGIC_REG_MAGIC[{len(rows)}] = {{{magics}}};\n",
        encoding="utf-8",
    )


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
            {"ea_id": "11901", "ea_slug": "stale-resolver", "symbol_slot": "1", "symbol": "GBPUSD.DWX", "magic": "119010001", "reserved_at": "x", "reserved_by": "x", "status": "active"},
        ],
    )
    resolver = repo / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    resolver.parent.mkdir(parents=True)
    _resolver(resolver, [])
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


def test_precheck_requires_complete_magic_and_exact_resolver_tuples(tmp_path: Path) -> None:
    farm, repo = _fixture(tmp_path)
    card = farm / "artifacts" / "cards_approved" / "QM5_11901_stale-resolver.md"
    fm = farmctl.parse_card_frontmatter(card)
    magic = repo / "framework" / "registry" / "magic_numbers.csv"
    fields, rows = farmctl._read_csv_dicts_with_columns(magic)
    _write_csv(magic, fields, [row for row in rows if row.get("symbol_slot") != "1"])

    partial = farmctl.magic_allocation_precheck(fm, repo_root=repo)

    assert partial["ready"] is False
    assert partial["classification"] == "active_magic_contract_mismatch"
    assert any("active_row_count" in issue for issue in partial["contract_issues"])

    _write_csv(magic, fields, rows)
    resolver = repo / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    _resolver(resolver, [(11901, 0, "EURUSD.DWX", 119010000)])
    incomplete_resolver = farmctl.magic_allocation_precheck(fm, repo_root=repo)
    assert incomplete_resolver["classification"] == "resolver_regeneration_missed"

    _resolver(
        resolver,
        [
            (11901, 0, "EURUSD.DWX", 119010000),
            (11901, 1, "GBPUSD.DWX", 119010001),
        ],
    )
    ready = farmctl.magic_allocation_precheck(fm, repo_root=repo)
    assert ready["ready"] is True
    assert ready["classification"] == "ready"


def test_missing_identity_is_governed_allocator_work_and_is_in_inventory(tmp_path: Path) -> None:
    farm, repo = _fixture(tmp_path)
    card = _card(
        farm / "artifacts" / "cards_approved" / "QM5_11902_post-worklist.md",
        11902,
        "post-worklist",
    )

    precheck = farmctl.magic_allocation_precheck(
        farmctl.parse_card_frontmatter(card), repo_root=repo
    )
    inventory = farmctl.missing_magic_allocation_inventory(farm, repo_root=repo)

    assert precheck["classification"] == "ea_id_not_registered"
    assert precheck["action"] == "GOVERNED_ALLOCATE"
    assert any(row["ea_id"] == "QM5_11902" for row in inventory["findings"])


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
    with farmctl.connect(tmp_path / "farm") as conn:
        assert conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0] == 0


def test_render_build_dispatches_only_after_positive_magic_proof(
    tmp_path: Path,
    monkeypatch,
) -> None:
    farm = tmp_path / "farm"
    card = _card(farm / "artifacts/cards_approved/QM5_11903_ready.md", 11903, "ready")
    template = tmp_path / "build_prompt.md"
    template.write_text("{{task_id}} {{ea_id}} {{slug}}", encoding="utf-8")
    monkeypatch.setattr(
        farmctl,
        "prebuild_validate_card",
        lambda *_args, **_kwargs: {"ok": True, "errors": [], "warnings": []},
    )
    monkeypatch.setattr(
        farmctl,
        "magic_allocation_precheck",
        lambda *_args, **_kwargs: {
            "ready": True,
            "classification": "ready",
            "action": "NONE",
        },
    )
    monkeypatch.setattr(farmctl, "CODEX_BUILD_TEMPLATE", template)
    monkeypatch.setattr(farmctl, "FRAMEWORK_EAS_DIR", tmp_path / "repo/framework/EAs")

    result = farmctl.render_codex_build_prompt(farm, str(card), None)

    assert result["written"] is True
    with farmctl.connect(farm) as conn:
        rows = conn.execute("SELECT kind FROM tasks").fetchall()
    assert [row["kind"] for row in rows] == ["build_ea"]


def test_approval_calls_registry_precondition_on_final_card(
    tmp_path: Path,
    monkeypatch,
) -> None:
    farm = tmp_path / "farm"
    card = _card(farm / "artifacts/cards_draft/QM5_11904_approval-link.md", 11904, "approval-link")
    card.write_text(card.read_text(encoding="utf-8") + "\nMarket EURUSD.DWX H1 entry exit risk 12 trades per year.\n", encoding="utf-8")
    called: list[Path] = []
    monkeypatch.setattr(farmctl, "strategy_card_r_gate_consistency", lambda *_args: {"ok": True, "errors": []})
    monkeypatch.setattr(farmctl, "_approval_card_contract_issues", lambda *_args: [])
    monkeypatch.setattr(farmctl, "_verify_card_body_coverage", lambda *_args: {"ok": True, "missing": []})
    monkeypatch.setattr(farmctl, "_infer_expected_trades_per_year_per_symbol", lambda *_args: 12)
    monkeypatch.setattr(farmctl, "custom_history_archive_admission", lambda *_args, **_kwargs: {"ok": True})

    def linked(_root: Path, final_card: Path) -> dict:
        called.append(final_card)
        return {
            "precheck": {"ready": False, "classification": "ea_id_not_registered"},
            "task": {"enqueued": True, "task_id": "registry-task"},
        }

    monkeypatch.setattr(farmctl, "_approved_card_registry_precondition", linked)

    result = farmctl.approve_card(farm, str(card), "fixture approval")

    expected = farm / "artifacts/cards_approved" / card.name
    assert result["approved"] is True
    assert called == [expected]
    assert result["registry_precondition"]["task"]["task_id"] == "registry-task"

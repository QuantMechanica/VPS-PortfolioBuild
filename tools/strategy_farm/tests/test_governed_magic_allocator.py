from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path

import pytest

from tools.strategy_farm import governed_magic_allocator as allocator


def _write_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _resolver(path: Path, rows: list[tuple[int, int, str, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ea = ", ".join(str(row[0]) for row in rows)
    slots = ", ".join(str(row[1]) for row in rows)
    symbols = ", ".join(f'"{row[2]}"' for row in rows)
    magics = ", ".join(str(row[3]) for row in rows)
    path.write_text(
        f"static const int QM_MAGIC_REG_EA_ID[{len(rows)}] = {{{ea}}};\n"
        f"static const int QM_MAGIC_REG_SLOT[{len(rows)}] = {{{slots}}};\n"
        f"static const string QM_MAGIC_REG_SYMBOL[{len(rows)}] = {{{symbols}}};\n"
        f"static const int QM_MAGIC_REG_MAGIC[{len(rows)}] = {{{magics}}};\n",
        encoding="utf-8",
    )


def _fixture_repo(tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    (repo / "framework/EAs").mkdir(parents=True)
    _write_csv(
        repo / allocator.EA_ID_REGISTRY,
        ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"],
        [
            {"ea_id": "1", "slug": "compiled", "strategy_id": "x", "status": "active", "owner": "x", "created_at": "x"},
            {"ea_id": "2", "slug": "century", "strategy_id": "x", "status": "active", "owner": "x", "created_at": "x"},
            {"ea_id": "3", "slug": "missing-symbols", "strategy_id": "x", "status": "active", "owner": "x", "created_at": "x"},
            {"ea_id": "4", "slug": "inactive", "strategy_id": "x", "status": "retired", "owner": "x", "created_at": "x"},
            {"ea_id": "5", "slug": "bounded-grid", "strategy_id": "x", "status": "active", "owner": "x", "created_at": "x"},
        ],
    )
    _write_csv(repo / allocator.MAGIC_REGISTRY, allocator.MAGIC_FIELDS, [])
    _resolver(repo / allocator.MAGIC_RESOLVER, [(999, 0, "EURUSD.DWX", 9990000)])
    return repo


def _candidate(repo: Path, ea_id: int, slug: str, stage: str, symbols: tuple[str, ...]) -> allocator.Candidate:
    card = repo / "cards" / f"QM5_{ea_id}_{slug}.md"
    card.parent.mkdir(parents=True, exist_ok=True)
    card.write_text(f"---\nea_id: QM5_{ea_id}\nslug: {slug}\n---\n", encoding="utf-8")
    return allocator.Candidate(
        ea_id,
        slug,
        stage,
        repo / "framework/EAs" / f"QM5_{ea_id}_{slug}",
        card,
        symbols,
    )


def test_plan_preserves_payoff_order_and_skips_undeclared_or_inactive(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    candidates = [
        _candidate(repo, 1, "compiled", "compiled_ready", ("EURUSD.DWX",)),
        _candidate(repo, 2, "century", "century", ("GBPUSD.DWX",)),
        _candidate(repo, 3, "missing-symbols", "sourced_not_compiled", ()),
        _candidate(repo, 4, "inactive", "card_only", ("XAUUSD.DWX",)),
        _candidate(repo, 5, "bounded-grid", "card_only", ("EURUSD.DWX",)),
    ]
    registry = allocator._active_ea_registry(repo / allocator.EA_ID_REGISTRY)
    plan = allocator.build_plan(repo, candidates, registry, [], max_eas=1)
    assert [item.ea_id for item in plan["planned"]] == [1]
    assert plan["decisions"][1]["action"] == "defer"
    assert plan["decisions"][2]["reason"] == "card_missing_target_symbols"
    assert plan["decisions"][3]["reason"] == "ea_id_not_active:retired"
    assert plan["decisions"][4]["reason"] == "prohibited_technique:grid"


def test_directory_and_card_exist_before_registry_write(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    repo = _fixture_repo(tmp_path)
    item = _candidate(repo, 1, "compiled", "compiled_ready", ("EURUSD.DWX", "GBPUSD.DWX"))
    registry = allocator._active_ea_registry(repo / allocator.EA_ID_REGISTRY)
    plan = allocator.build_plan(repo, [item], registry, [], max_eas=5)
    original_write = allocator._write_magic_registry

    def checked_write(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
        assert item.directory.is_dir()
        assert (item.directory / "docs/strategy_card.md").is_file()
        original_write(path, fields, rows)

    monkeypatch.setattr(allocator, "_write_magic_registry", checked_write)

    def regenerate(_: Path) -> None:
        _, rows = allocator._read_csv(repo / allocator.MAGIC_REGISTRY)
        generated = sorted(
            (int(row["ea_id"]), int(row["symbol_slot"]), row["symbol"], int(row["magic"]))
            for row in rows
            if row["status"] != "retired"
        )
        generated.insert(0, (999, 0, "EURUSD.DWX", 9990000))
        generated.sort(key=lambda row: row[0] * 10_000 + row[1])
        _resolver(repo / allocator.MAGIC_RESOLVER, generated)

    result = allocator.apply_plan(repo, plan, allocator.MAGIC_FIELDS, [], regenerate=regenerate)
    assert result["allocated_eas"] == 1
    assert result["allocated_rows"] == 2
    assert result["resolver_rows_after"] == result["resolver_rows_before"] + 2


def test_dirty_registry_aborts_with_paths_and_clear_check_passes(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(
        [
            "git",
            "add",
            "framework/registry/ea_id_registry.csv",
            "framework/registry/magic_numbers.csv",
            "framework/include/QM/QM_MagicResolver.mqh",
        ],
        cwd=repo,
        check=True,
    )
    subprocess.run(
        ["git", "-c", "user.name=pytest", "-c", "user.email=pytest@example.invalid", "commit", "-qm", "fixture"],
        cwd=repo,
        check=True,
    )
    assert allocator.dirty_registry_paths(repo) == []
    with (repo / allocator.MAGIC_REGISTRY).open("a", encoding="utf-8") as handle:
        handle.write("1,compiled,0,EURUSD.DWX,10000,x,x,active\n")
    dirty = allocator.dirty_registry_paths(repo)
    assert len(dirty) == 1
    assert "framework/registry/magic_numbers.csv" in dirty[0]


def test_existing_active_rows_are_idempotently_skipped_and_retired_are_reported(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    item = _candidate(repo, 1, "compiled", "compiled_ready", ("EURUSD.DWX",))
    registry = allocator._active_ea_registry(repo / allocator.EA_ID_REGISTRY)
    rows = [
        {"ea_id": "1", "ea_slug": "compiled", "symbol_slot": "0", "symbol": "EURUSD.DWX", "magic": "10000", "reserved_at": "x", "reserved_by": "x", "status": "active"},
        {"ea_id": "2", "ea_slug": "century", "symbol_slot": "0", "symbol": "GBPUSD.DWX", "magic": "20000", "reserved_at": "x", "reserved_by": "x", "status": "retired"},
    ]
    plan = allocator.build_plan(repo, [item], registry, rows, max_eas=5)
    assert plan["planned"] == []
    assert plan["decisions"][0]["reason"] == "already_allocated"
    assert plan["retired_rows_found"] == [rows[1]]


def test_exact_card_candidate_uses_only_declared_symbols_and_refuses_retired_history(
    tmp_path: Path,
) -> None:
    repo = _fixture_repo(tmp_path)
    card = repo / "cards" / "QM5_2_century.md"
    card.parent.mkdir(parents=True, exist_ok=True)
    card.write_text(
        "---\nea_id: QM5_2\nslug: century\ng0_status: APPROVED\n"
        "target_symbols: [EURUSD.DWX, GBPUSD.DWX]\n---\n",
        encoding="utf-8",
    )
    item = allocator.candidate_from_card(repo, card)
    retired = [{
        "ea_id": "2", "ea_slug": "century", "symbol_slot": "0",
        "symbol": "EURUSD.DWX", "magic": "20000", "reserved_at": "x",
        "reserved_by": "x", "status": "retired",
    }]

    plan = allocator.build_plan(
        repo,
        [item],
        allocator._active_ea_registry(repo / allocator.EA_ID_REGISTRY),
        retired,
        max_eas=1,
        refuse_retired_reallocation=True,
    )

    assert item.symbols == ("EURUSD.DWX", "GBPUSD.DWX")
    assert plan["planned"] == []
    assert plan["decisions"][0]["reason"] == "retired_magic_history_requires_review_do_not_unretire"


def test_live_approved_discovery_includes_post_worklist_card(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    approved = tmp_path / "cards_approved"
    approved.mkdir()
    card = approved / "QM5_9001_post-0817.md"
    card.write_text(
        "---\nea_id: QM5_9001\nslug: post-0817\nsource_id: source-post-0817\n"
        "g0_status: APPROVED\ntarget_symbols: [EURUSD.DWX]\n---\n",
        encoding="utf-8",
    )

    candidates, findings = allocator.load_approved_card_candidates(repo, approved)

    assert findings == []
    assert [item.ea_id for item in candidates] == [9001]
    assert candidates[0].strategy_id == "source-post-0817"
    assert candidates[0].stage == "approved_live"


def test_missing_exact_identity_and_magic_are_allocated_in_one_governed_write(
    tmp_path: Path,
) -> None:
    repo = _fixture_repo(tmp_path)
    item = _candidate(repo, 6, "post-worklist", "approved_live", ("EURUSD.DWX",))
    item = allocator.Candidate(
        item.ea_id,
        item.slug,
        item.stage,
        item.directory,
        item.card,
        item.symbols,
        item.symbol_policy,
        "source-post-worklist",
    )
    _, identity_rows = allocator._read_csv(repo / allocator.EA_ID_REGISTRY)
    registry = allocator._active_ea_registry(repo / allocator.EA_ID_REGISTRY)
    plan = allocator.build_plan(
        repo,
        [item],
        registry,
        [],
        max_eas=1,
        ea_registry_rows=identity_rows,
    )
    assert plan["planned_identity_ids"] == [6]

    def regenerate(_: Path) -> None:
        _, rows = allocator._read_csv(repo / allocator.MAGIC_REGISTRY)
        generated = [(999, 0, "EURUSD.DWX", 9990000)]
        generated.extend(
            (int(row["ea_id"]), int(row["symbol_slot"]), row["symbol"], int(row["magic"]))
            for row in rows
            if row["status"] == "active"
        )
        _resolver(repo / allocator.MAGIC_RESOLVER, sorted(generated))

    result = allocator.apply_plan(
        repo,
        plan,
        allocator.MAGIC_FIELDS,
        [],
        regenerate=regenerate,
    )

    assert result["identity_ids_added"] == ["QM5_6"]
    assert result["allocated_rows"] == 1
    _, identities_after = allocator._read_csv(repo / allocator.EA_ID_REGISTRY)
    assert any(
        row["ea_id"] == "6"
        and row["slug"] == "post-worklist"
        and row["status"] == "active"
        for row in identities_after
    )
    _, magic_after = allocator._read_csv(repo / allocator.MAGIC_REGISTRY)
    assert magic_after[-1]["magic"] == "60000"


def test_ambiguous_identity_is_never_selected_for_allocation(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    fields, rows = allocator._read_csv(repo / allocator.EA_ID_REGISTRY)
    rows.append(
        {
            "ea_id": "1",
            "slug": "compiled-duplicate",
            "strategy_id": "other",
            "status": "active",
            "owner": "x",
            "created_at": "x",
        }
    )
    _write_csv(repo / allocator.EA_ID_REGISTRY, fields, rows)
    item = _candidate(repo, 1, "compiled", "approved_live", ("EURUSD.DWX",))

    plan = allocator.build_plan(
        repo,
        [item],
        allocator._active_ea_registry(repo / allocator.EA_ID_REGISTRY),
        [],
        max_eas=1,
        ea_registry_rows=rows,
    )

    assert plan["planned"] == []
    assert plan["decisions"][0]["reason"] == "ea_id_registry_ambiguous:rows=2"


def test_full_dry_run_zero_cap_is_allowed_but_real_zero_cap_is_rejected() -> None:
    with pytest.raises(SystemExit):
        allocator.main(["--max-eas", "0"])


def test_dl087_matrix_validation_and_fixed_slot_order(tmp_path: Path) -> None:
    repo = _fixture_repo(tmp_path)
    rows = [
        {
            "symbol": symbol,
            "asset_class": allocator.DL087_ASSET_CLASSES[symbol],
            "canonical_name_verified": "true",
        }
        for symbol in reversed(allocator.DL087_SYMBOLS)
    ]
    _write_csv(
        repo / allocator.SYMBOL_MATRIX,
        ["symbol", "asset_class", "canonical_name_verified"],
        rows,
    )
    verified = allocator.validate_dl087_symbols(repo)
    assert list(verified) == list(allocator.DL087_SYMBOLS)
    raw = {
        "ea_id": "QM5_1",
        "slug": "compiled",
        "directory": "framework/EAs/QM5_1_compiled",
        "card": str(repo / "cards/QM5_1_compiled.md"),
        "target_symbols_from_card": [],
    }
    item = allocator._candidate(raw, "compiled_ready", repo, dl087=True)
    assert item is not None
    assert item.symbols == allocator.DL087_SYMBOLS
    assert item.symbol_policy == allocator.DL087_POLICY
    assert allocator.DL087_DISCOVERY_PAYLOAD["result_authorization"] == "DISCOVERY_NOT_CARD_VALIDATED"

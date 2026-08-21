"""MNT-011 regression tests for build-lane dirty-tree classification."""

import os
import sys
from pathlib import Path
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import farmctl  # noqa: E402


EA = "framework/EAs/QM5_34004_kositsin-step-trend-parabolic-envelope"
LABEL = "QM5_34004_kositsin-step-trend-parabolic-envelope"


def _guard_for(stdout: str) -> tuple[dict, mock.Mock]:
    status_result = mock.Mock(returncode=0, stdout=stdout, stderr="")
    with (
        mock.patch.dict(os.environ, {}, clear=False),
        mock.patch.object(farmctl.subprocess, "run", return_value=status_result) as run,
    ):
        os.environ.pop(farmctl.DIRTY_REPO_BUILD_GUARD_ENV, None)
        result = farmctl._repo_dirty_status(Path("C:/test/repo"))
    return result, run


def test_generated_only_tree_leaves_build_gate_open() -> None:
    result, run = _guard_for(
        "\n".join(
            [
                f" M {EA}/{LABEL}.ex5",
                f"?? {EA}/sets/{LABEL}_XAUUSD.DWX_H1_backtest.set",
                f"?? {EA}/SPEC.md",
                f"?? {EA}/docs/strategy_card.md",
                f"?? {EA}/{LABEL}.mq5",
            ]
        )
        + "\n"
    )

    assert result["blocked"] is False
    assert result["count"] == 0
    assert result["total_count"] == 5
    assert result["generated_count"] == 5
    assert result["generated_by_class"] == {
        "compiled_binary": 1,
        "generated_card_mirror": 1,
        "generated_ea_scaffold": 1,
        "generated_setfile": 1,
        "generated_spec": 1,
    }
    assert "--untracked-files=all" in run.call_args.args[0]


def test_human_source_tree_closes_build_gate_in_both_required_roots() -> None:
    tracked_ea_source = f"{EA}/{LABEL}.mq5"
    result, _ = _guard_for(
        "\n".join(
            [
                " M framework/include/QM/QM_Risk.mqh",
                "?? tools/strategy_farm/local_patch.py",
                " M scripts/ops_helper.ps1",
                " M framework/scripts/gen_setfile.ps1",
                " M framework/registry/magic_numbers.csv",
                " M docs/ops/human_note.md",
                f" M {tracked_ea_source}",
            ]
        )
        + "\n"
    )

    assert result["blocked"] is True
    assert result["count"] == 7
    assert result["generated_count"] == 0
    assert result["blocking_by_class"] == {
        "docs": 1,
        "framework_include": 1,
        "framework_registry": 1,
        "framework_scripts": 1,
        "scripts": 1,
        "tools": 1,
        "tracked_ea_source": 1,
    }


def test_auto_commit_batches_scaffold_spec_binary_and_setfile() -> None:
    entries = [
        f"?? {EA}/{LABEL}.mq5",
        f"?? {EA}/SPEC.md",
        f"?? {EA}/{LABEL}.ex5",
        f"?? {EA}/sets/{LABEL}_XAUUSD.DWX_H1_backtest.set",
        f"?? {EA}/docs/strategy_card.md",
    ]

    plan = farmctl._plan_artifact_auto_commit(entries, active_eas=set())

    assert plan["valid"] is True
    assert plan["candidate_count"] == 4
    assert plan["commit_paths"] == sorted(
        [
            f"{EA}/{LABEL}.mq5",
            f"{EA}/SPEC.md",
            f"{EA}/{LABEL}.ex5",
            f"{EA}/sets/{LABEL}_XAUUSD.DWX_H1_backtest.set",
        ]
    )
    assert plan["skipped_source_dirty_paths"] == []
    assert plan["rejected_dirty_paths"] == [f"{EA}/docs/strategy_card.md"]


def test_modified_tracked_ea_source_is_not_scaffold_and_holds_its_binary() -> None:
    entries = [
        f" M {EA}/{LABEL}.mq5",
        f" M {EA}/{LABEL}.ex5",
    ]

    plan = farmctl._plan_artifact_auto_commit(entries, active_eas=set())

    assert plan["commit_paths"] == []
    assert plan["rejected_dirty_paths"] == [f"{EA}/{LABEL}.mq5"]
    assert plan["skipped_source_dirty_paths"] == [f"{EA}/{LABEL}.ex5"]

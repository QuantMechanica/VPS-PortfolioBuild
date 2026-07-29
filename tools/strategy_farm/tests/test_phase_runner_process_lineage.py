import argparse
import contextlib
import importlib.util
import json
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "framework" / "scripts"))
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


WORK_ITEM_ID = "000034e8-7161-430b-be4f-e140cb99789b"
WORK_ITEM_ROOT = Path(r"D:\QM\reports\work_items") / WORK_ITEM_ID


def _row(phase: str) -> dict[str, str]:
    return {
        "id": WORK_ITEM_ID,
        "phase": phase,
        "ea_id": "QM5_9999",
        "symbol": "EURUSD.DWX",
        "setfile_path": "dummy.set",
        "payload_json": "{}",
    }


def test_python_and_powershell_consume_the_same_versioned_allowlist() -> None:
    payload = json.loads(
        (REPO / "tools" / "strategy_farm" / "phase_runner_allowlist.v1.json")
        .read_text(encoding="utf-8")
    )
    expected_paths = {
        str(entry["phase"]): str(entry["repo_relative_path"])
        for entry in payload["entries"]
    }

    assert payload["schema_version"] == "qm-phase-runner-allowlist/v1"
    assert farmctl.PHASE_RUNNER_ALLOWLIST_VERSION == payload["schema_version"]
    assert farmctl.PHASE_RUNNER_REPO_PATHS == expected_paths
    assert len(expected_paths) == 16
    assert len(expected_paths) == len(set(expected_paths.values()))


@pytest.mark.parametrize("mutation", ["schema_mismatch", "duplicate_path"])
def test_python_allowlist_loader_fails_closed_like_powershell(
    monkeypatch,
    tmp_path: Path,
    mutation: str,
) -> None:
    payload = json.loads(
        farmctl.PHASE_RUNNER_ALLOWLIST_PATH.read_text(encoding="utf-8")
    )
    if mutation == "schema_mismatch":
        payload["schema_version"] = "qm-phase-runner-allowlist/v999"
    else:
        payload["entries"][1]["repo_relative_path"] = (
            payload["entries"][0]["repo_relative_path"].replace(
                "framework", "FRAMEWORK"
            )
        )
    invalid_path = tmp_path / "invalid_allowlist.json"
    invalid_path.write_text(json.dumps(payload), encoding="utf-8")
    monkeypatch.setattr(farmctl, "PHASE_RUNNER_ALLOWLIST_PATH", invalid_path)

    with pytest.raises(RuntimeError):
        farmctl._load_phase_runner_allowlist()


class _ParsedWithoutExecution(Exception):
    def __init__(self, namespace: argparse.Namespace) -> None:
        super().__init__("argument parsing completed")
        self.namespace = namespace


def _load_runner_main(script_path: Path):
    module_name = "_mnt046_parser_" + "_".join(script_path.parts[-3:]).replace(".", "_")
    spec = importlib.util.spec_from_file_location(module_name, script_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module.main


def test_all_allowlisted_factory_commands_parse_and_carry_uuid_lineage(
    monkeypatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(farmctl, "_detect_ea_period", lambda *_args: "H1")
    monkeypatch.setattr(farmctl, "_ea_dir_from_setfile_path", lambda *_args: None)
    monkeypatch.setattr(farmctl, "_load_basket_manifest", lambda *_args: None)
    monkeypatch.setattr(
        farmctl,
        "_phase_runner_inputs",
        lambda *_args: {
            "calibration_json": tmp_path / "calibration.json",
            "slices_csv": tmp_path / "slices.csv",
            "sweep_pass_rows": tmp_path / "sweep.csv",
            "multiseed_rows": tmp_path / "multiseed.csv",
        },
    )
    monkeypatch.setattr(farmctl, "connect", lambda *_args: contextlib.nullcontext(None))
    monkeypatch.setattr(farmctl, "assert_q10_dependency_gate", lambda *_args: None)

    q09_plan = tmp_path / "q09_run_plan.json"
    q09_plan.write_text("{}\n", encoding="utf-8")
    allowlist = json.loads(
        farmctl.PHASE_RUNNER_ALLOWLIST_PATH.read_text(encoding="utf-8")
    )["entries"]
    selector_by_phase = {
        str(entry["phase"]): str(entry["terminal_selector"])
        for entry in allowlist
    }

    commands: dict[str, list[str]] = {}
    for phase in selector_by_phase:
        row = _row(phase)
        if phase == "Q09_NEWS":
            row["payload_json"] = json.dumps({"q09_run_plan_path": str(q09_plan)})
        cmd = farmctl._phase_runner_cmd_for_work_item(
            Path(r"D:\QM\strategy_farm"),
            row,
            WORK_ITEM_ROOT,
            "T10",
            REPO,
        )

        assert cmd is not None, phase
        assert cmd.count("--out-prefix") == 1, phase
        marker_index = cmd.index("--out-prefix")
        assert Path(cmd[marker_index + 1]) == WORK_ITEM_ROOT, phase
        assert Path(cmd[1]).resolve() == (
            REPO / farmctl.PHASE_RUNNER_REPO_PATHS[phase]
        ).resolve(), phase
        if selector_by_phase[phase] == "required":
            assert cmd.count("--terminal") == 1, phase
            assert cmd[cmd.index("--terminal") + 1] == "T10", phase
        else:
            assert cmd.count("--terminal") <= 1, phase
        commands[phase] = cmd

    # Invoke each runner's real ArgumentParser and stop immediately after a
    # successful parse.  No runner body, MT5 process, or filesystem output is
    # reached; unknown/duplicate-incompatible arguments still fail normally.
    original_parse_args = argparse.ArgumentParser.parse_args

    def parse_then_stop(parser, args=None, namespace=None):
        parsed = original_parse_args(parser, args=args, namespace=namespace)
        raise _ParsedWithoutExecution(parsed)

    monkeypatch.setattr(argparse.ArgumentParser, "parse_args", parse_then_stop)
    for phase, cmd in commands.items():
        main = _load_runner_main(Path(cmd[1]))
        monkeypatch.setattr(sys, "argv", [cmd[1], *cmd[2:]])
        with pytest.raises(_ParsedWithoutExecution):
            main()

    # Feed those exact argv vectors (not independently reconstructed fixtures)
    # into the PowerShell classifier in one read-only process.
    scope_path = REPO / "tools" / "strategy_farm" / "factory_process_scope.ps1"
    classifier_script = rf"""
. '{scope_path}'
$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$result = foreach ($entry in @($payload)) {{
    $classification = Get-QmFactoryPhaseRunnerClassification -CommandLine ([string]$entry.command_line)
    [pscustomobject]@{{
        phase = [string]$entry.phase
        disposition = [string]$classification.Disposition
        classified_phase = [string]$classification.Phase
        work_item_id = [string]$classification.WorkItemId
    }}
}}
@($result) | ConvertTo-Json -Depth 4 -Compress
"""
    classifier_input = [
        {"phase": phase, "command_line": subprocess.list2cmdline(cmd)}
        for phase, cmd in commands.items()
    ]
    classified = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            classifier_script,
        ],
        input=json.dumps(classifier_input),
        text=True,
        capture_output=True,
        check=False,
        cwd=REPO,
    )
    assert classified.returncode == 0, classified.stderr
    classifier_rows = json.loads(classified.stdout)
    assert len(classifier_rows) == len(selector_by_phase)
    for row in classifier_rows:
        assert row["disposition"] == "FACTORY_OWNED", row
        assert row["classified_phase"] == row["phase"], row
        assert row["work_item_id"] == WORK_ITEM_ID, row


def test_q_runner_parsers_accept_the_nonfunctional_lineage_marker() -> None:
    parser_sources = (
        "framework/scripts/q04_walkforward.py",
        "framework/scripts/q05_stress_medium.py",
        "framework/scripts/q06_stress_harsh.py",
        "framework/scripts/q07_multiseed.py",
        "framework/scripts/q08_davey/aggregate.py",
        "framework/scripts/q10_confirmation.py",
        "tools/strategy_farm/q09_news_runner.py",
        "tools/strategy_farm/portfolio/portfolio_q08_contribution.py",
    )
    for relative in parser_sources:
        source = (REPO / relative).read_text(encoding="utf-8")
        assert '"--out-prefix"' in source, relative
        assert "argparse.SUPPRESS" in source, relative


@pytest.mark.parametrize("legacy_count", [1, 2])
def test_legacy_parent_dispatch_is_fail_closed_without_all_or_per_terminal_spawn(
    monkeypatch,
    tmp_path: Path,
    legacy_count: int,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = farmctl.utc_now()
    task_ids = [
        "100034e8-7161-430b-be4f-e140cb99789b",
        "200034e8-7161-430b-be4f-e140cb99789b",
    ][:legacy_count]
    with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
        for index, task_id in enumerate(task_ids):
            phase = "P2" if index == 0 else "P3"
            conn.execute(
                """
                INSERT INTO tasks
                  (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                VALUES (?, ?, 'pending', NULL, 'QM5_9999', ?, ?, ?)
                """,
                (
                    task_id,
                    f"backtest_{phase.lower()}",
                    json.dumps({
                        "phase": phase,
                        "ea_id": "QM5_9999",
                        "surviving_symbols": ["EURUSD.DWX"],
                    }),
                    now,
                    now,
                ),
            )
        conn.commit()

    monkeypatch.setattr(farmctl, "_running_mt5_terminals", lambda: set())
    # Adversarial input includes both structurally forbidden names. The legacy
    # path must remain non-spawning regardless of the fleet provider.
    monkeypatch.setattr(
        farmctl,
        "active_mt5_terminals",
        lambda: ("T1", "T5", "T_Live"),
    )

    def forbidden_spawn(*_args, **_kwargs):
        pytest.fail("deprecated legacy parent path attempted subprocess.Popen")

    monkeypatch.setattr(farmctl.subprocess, "Popen", forbidden_spawn)
    result = farmctl.dispatch_tick(root)

    blocked = [
        action for action in result["actions"]
        if action.get("action") == "legacy_direct_spawn_blocked"
    ]
    assert len(blocked) == legacy_count
    assert result["mode"] == "legacy_direct_spawn_deprecated"
    assert all(action["all_mode_disabled"] is True for action in blocked)
    assert not any(action.get("action") == "started" for action in result["actions"])
    with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
        rows = conn.execute(
            "SELECT status, payload_json FROM tasks ORDER BY created_at, id"
        ).fetchall()
    assert [row[0] for row in rows] == ["pending"] * legacy_count
    assert all("assigned_terminal" not in json.loads(row[1]) for row in rows)


def test_legacy_dispatch_source_has_no_direct_runner_spawn_callsite() -> None:
    source = (REPO / "tools" / "strategy_farm" / "farmctl.py").read_text(
        encoding="utf-8"
    )
    dispatch_body = source.split("def dispatch_tick(", 1)[1].split(
        "\ndef render_codex_build_prompt(", 1
    )[0]
    assert "_phase_runner_cmd(" not in dispatch_body
    assert "subprocess.Popen(" not in dispatch_body
    assert 'dispatch_mode = "legacy_direct_spawn_deprecated"' in dispatch_body
    assert '"action": "legacy_direct_spawn_blocked"' in dispatch_body


def test_phase_runner_terminal_scope_excludes_t5_live_and_all_before_preflight(
    monkeypatch,
) -> None:
    assert farmctl.PHASE_RUNNER_TERMINALS == (
        "T1", "T2", "T3", "T4", "T6", "T7", "T8", "T9", "T10"
    )
    monkeypatch.setattr(
        farmctl,
        "_news_calendar_preflight",
        lambda **_kwargs: pytest.fail("scope rejection must precede preflight"),
    )
    for terminal in ("T5", "T_Live", "ALL", ""):
        result = farmctl._spawn_work_item_runner(
            Path(r"D:\QM\strategy_farm"),
            _row("Q07"),
            terminal,
        )
        assert result["spawned"] is False
        assert result["phase_runner_scope_blocked"] is True
        assert terminal in result["reason"]


def test_work_item_dispatch_does_not_claim_real_phase_runner_on_t5(
    monkeypatch,
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status,
               attempt_count, payload_json, created_at, updated_at)
            VALUES (?, 'backtest', 'Q07', 'QM5_9999', 'EURUSD.DWX',
                    'dummy.set', 'pending', 0, '{}', ?, ?)
            """,
            (WORK_ITEM_ID, now, now),
        )
        conn.commit()

    monkeypatch.setattr(farmctl, "active_mt5_terminals", lambda: ("T5",))
    monkeypatch.setattr(farmctl, "_running_mt5_terminals", lambda: set())
    monkeypatch.setattr(
        farmctl,
        "_news_calendar_preflight",
        lambda **_kwargs: {"ok": True, "status": "VALID"},
    )
    monkeypatch.setattr(
        farmctl.subprocess,
        "Popen",
        lambda *_args, **_kwargs: pytest.fail("Q07 must not spawn on T5"),
    )

    result = farmctl.dispatch_work_items(root, timeout_minutes=8)

    deferred = [
        action for action in result["actions"]
        if action.get("action") == "phase_runner_terminal_scope_deferred"
    ]
    assert len(deferred) == 1
    assert deferred[0]["excluded_terminals"] == ["T5"]
    with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
        row = conn.execute(
            "SELECT status, claimed_by FROM work_items WHERE id=?",
            (WORK_ITEM_ID,),
        ).fetchone()
    assert row == ("pending", None)

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[1]
TOOLS = EA_ROOT / "tools"
LAUNCHER = TOOLS / "run_research_phase.ps1"
SUPPORT = TOOLS / "research_launcher_support.psm1"
FRAMEWORK_SCRIPTS = EA_ROOT.parents[1] / "scripts"
PWSh = shutil.which("pwsh")
ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def _pwsh(command: str, *arguments: str) -> subprocess.CompletedProcess[str]:
    if PWSh is None:
        pytest.skip("PowerShell 7 is required for launcher contract tests")
    return subprocess.run(
        [PWSh, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", command, *arguments],
        check=False,
        capture_output=True,
        text=True,
    )


def _normalized_output(result: subprocess.CompletedProcess[str]) -> str:
    """Collapse PowerShell's host-dependent ANSI wrapping for message checks."""
    plain = ANSI_ESCAPE.sub("", result.stderr + result.stdout)
    return " ".join(plain.split())


def _module_command(body: str) -> str:
    return (
        "& { param($modulePath, $arg1, $arg2, $arg3) "
        "Import-Module -Name $modulePath -Force -ErrorAction Stop; "
        f"{body}" + " }"
    )


def test_launcher_has_one_fixed_terminal_entrypoint_and_pre_post_fences() -> None:
    text = LAUNCHER.read_text(encoding="utf-8-sig")
    assert text.startswith("#requires -Version 7.0")
    assert "docs\\research_protocol_v5.json" in text
    assert "QM5_20009_RESEARCH_FREEZE_V5" in text
    assert "'runner_dev1_controller'" in text
    assert "'runner_dispatch_pipeline'" in text
    assert "'runner_dispatch_gates'" in text
    assert "$snapshotRoleBindings.Count -ne $requiredSnapshotRoles.Count" in text
    assert "$snapshotRunDev1Path" in text
    assert "terminal64.exe" not in text
    assert "metatester64.exe" not in text
    assert "Start-Process" not in text
    assert "Get-Command python.exe -All" in text
    assert "$pythonCommands[0].Source" in text
    assert "--receipt', $preReceiptPath" in text
    assert "'--postflight-receipt', $preReceiptPath" in text
    assert "'--preflight-receipt-sha256', $preReceiptSha256" in text
    assert text.count("Assert-QmPreboundRuntimeClosure -Snapshot $snapshotBinding") == 3
    assert "Get-QmSha256 -Path $PreReceiptPath" in text
    assert "binding drifted after PRE" in text
    assert "-WorkingDirectory $snapshotRepoRoot" in text
    assert "-SetFile', $snapshotSetPath" in text
    assert text.index("'--receipt', $preReceiptPath") < text.index(
        "Invoke-QmCapturedProcess -FilePath $pwshPath"
    )
    assert text.index("Invoke-QmCapturedProcess -FilePath $pwshPath") < text.index(
        "$postProcess = Invoke-QmCapturedProcess"
    )


def test_launcher_fixes_tester_cost_and_account_contract() -> None:
    text = LAUNCHER.read_text(encoding="utf-8-sig")
    for literal in (
        "'-EAId', '20009'",
        "'-MinTrades', '0'",
        "'-Model', '4'",
        "'-CommissionPerLot', '0'",
        "'-CommissionPerSideNative', '0'",
        "'-TesterCurrencyOverride', 'USD'",
        "'-TesterDepositOverride', '100000'",
    ):
        assert literal in text
    assert "-AllowMissingRealTicksLogMarker" not in text
    assert "direct_terminal_start_forbidden = $true" in text


def test_launcher_requires_native_report_audit_and_detached_atomic_receipt() -> None:
    launcher = LAUNCHER.read_text(encoding="utf-8-sig")
    support = SUPPORT.read_text(encoding="utf-8-sig")
    assert "'report_auditor'" in launcher
    assert "$snapshotAuditPath" in launcher
    assert "--duplicate-report" in launcher
    assert "Assert-QmCostAudit" in launcher
    assert "canonical_deal_sequence_sha256" in launcher
    assert "Write-QmDetachedJsonReceipt" in launcher
    assert "research_run_receipt.json" in launcher
    assert "[System.IO.File]::Move($temporary, $full, $true)" in support
    assert "Flush($true)" in support
    assert "direct_runner_output_is_not_verdict_evidence = $true" in launcher
    assert "dev_smoke_may_never_satisfy_verdict_gate" in launcher


def test_launcher_retains_and_binds_snapshot_on_pass_or_rejection() -> None:
    launcher = LAUNCHER.read_text(encoding="utf-8-sig")
    assert "runtime_snapshot = $snapshotBinding" in launcher
    assert "external_runtime = $prePayload['external_runtime']" in launcher
    assert "runtime_snapshot_retained = ($null -ne $snapshotBinding)" in launcher
    assert "runtime_snapshot = if ($null -ne $prePayload)" in launcher
    assert "Remove-Item -LiteralPath $snapshot" not in launcher
    assert "validator_final_snapshot.json" in launcher


def test_run_smoke_deploys_binary_from_its_own_resolved_repo_root() -> None:
    run_smoke = (FRAMEWORK_SCRIPTS / "run_smoke.ps1").read_text(
        encoding="utf-8-sig"
    )
    assert 'Join-Path $PSScriptRoot "..\\.."' in run_smoke
    assert 'Join-Path (Join-Path $localRepoRoot "framework\\EAs")' in run_smoke
    assert 'Join-Path "C:\\QM\\repo\\framework\\EAs"' not in run_smoke


def test_controller_child_and_smoke_have_no_moving_repo_literal() -> None:
    for name in ("run_dev1_smoke.ps1", "invoke_dev1_smoke_task.ps1", "run_smoke.ps1"):
        text = (FRAMEWORK_SCRIPTS / name).read_text(encoding="utf-8-sig")
        assert r"C:\QM\repo" not in text
        assert "C:/QM/repo" not in text
        assert "Join-Path $PSScriptRoot" in text
    child = (FRAMEWORK_SCRIPTS / "invoke_dev1_smoke_task.ps1").read_text(
        encoding="utf-8-sig"
    )
    assert "$startInfo.WorkingDirectory = ConvertTo-QmFullPath -Path (Join-Path $PSScriptRoot '..\\..')" in child


def test_dispatch_resolver_imports_only_snapshot_relative_local_dependencies(
    tmp_path: Path,
) -> None:
    snapshot_repo = tmp_path / "runtime_snapshot" / "repo"
    relative_files = (
        "framework/scripts/resolve_backtest_target.py",
        "framework/scripts/pipeline_dispatcher.py",
        "framework/scripts/dl054_gates.py",
        "framework/registry/tester_defaults.json",
    )
    repo_root = EA_ROOT.parents[2]
    for relative in relative_files:
        destination = snapshot_repo / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo_root / relative, destination)

    resolver = snapshot_repo / relative_files[0]
    completed = subprocess.run(
        [sys.executable, "-B", str(resolver), "--help"],
        cwd=snapshot_repo,
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    gate_path = subprocess.run(
        [
            sys.executable,
            "-B",
            "-c",
            (
                "from framework.scripts.dl054_gates import TESTER_DEFAULTS_PATH;"
                "print(TESTER_DEFAULTS_PATH.resolve())"
            ),
        ],
        cwd=snapshot_repo,
        check=False,
        capture_output=True,
        text=True,
    )
    assert gate_path.returncode == 0, gate_path.stdout + gate_path.stderr
    assert Path(gate_path.stdout.strip()) == (snapshot_repo / relative_files[3]).resolve()


def test_powershell_sources_parse_without_executing_launcher() -> None:
    command = (
        "& { param($first, $second) $bad=@(); foreach($path in @($first,$second)){"
        "$tokens=$null;$errors=$null;"
        "[void][System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors);"
        "$bad += @($errors) }; if($bad.Count){$bad|ForEach-Object{$_.Message};exit 2} }"
    )
    completed = _pwsh(command, str(LAUNCHER), str(SUPPORT))
    assert completed.returncode == 0, completed.stdout + completed.stderr


def test_contract_helper_separates_nonbinding_smoke_from_binding_dev() -> None:
    valid = _pwsh(
        _module_command(
            "$c=Get-QmResearchContract -Phase DEV_SMOKE_2022 -Symbol NDX.DWX "
            "-Timeframe M1 -Variant center -FromDate 2022-01-01 -ToDate 2022-12-31 -Runs 1;"
            "$c|ConvertTo-Json -Compress"
        ),
        str(SUPPORT),
        "unused",
        "unused",
        "unused",
    )
    assert valid.returncode == 0, valid.stdout + valid.stderr
    contract = json.loads(valid.stdout)
    assert contract["binding"] is False
    assert contract["infrastructure_only"] is True
    assert contract["runs"] == 1

    eur_smoke = _pwsh(
        _module_command(
            "$c=Get-QmResearchContract -Phase DEV_SMOKE_2022 -Symbol EURUSD.DWX "
            "-Timeframe M5 -Variant center -FromDate 2022-01-01 -ToDate 2022-12-31 -Runs 1;"
            "$c|ConvertTo-Json -Compress"
        ),
        str(SUPPORT),
        "unused",
        "unused",
        "unused",
    )
    assert eur_smoke.returncode == 0, eur_smoke.stdout + eur_smoke.stderr
    eur_contract = json.loads(eur_smoke.stdout)
    assert eur_contract["binding"] is False
    assert eur_contract["symbol"] == "EURUSD.DWX"
    assert eur_contract["timeframe"] == "M5"

    smoke_two = _pwsh(
        _module_command(
            "Get-QmResearchContract -Phase DEV_SMOKE_2022 -Symbol NDX.DWX "
            "-Timeframe M1 -Variant center -FromDate 2022-01-01 -ToDate 2022-12-31 -Runs 2"
        ),
        str(SUPPORT),
        "unused",
        "unused",
        "unused",
    )
    assert smoke_two.returncode != 0
    assert "requires exactly one" in _normalized_output(smoke_two)

    invalid = _pwsh(
        _module_command(
            "Get-QmResearchContract -Phase DEV -Symbol NDX.DWX -Timeframe M1 "
            "-Variant center -FromDate 2021-01-01 -ToDate 2022-12-31 -Runs 1"
        ),
        str(SUPPORT),
        "unused",
        "unused",
        "unused",
    )
    assert invalid.returncode != 0
    assert "requires exactly two runs" in _normalized_output(invalid)


def test_report_set_match_preserves_empty_governors_and_rejects_extra_empty_input(
    tmp_path: Path,
) -> None:
    expected = {
        "qm_ea_id": "20009",
        "InpQMSimCommissionPerLot": "0.0",
        "strategy_governor_policy_id": "",
        "strategy_challenge_instance_id": "",
    }
    actual = dict(expected)
    expected_path = tmp_path / "expected.json"
    actual_path = tmp_path / "actual.json"
    expected_path.write_text(json.dumps(expected), encoding="utf-8")
    actual_path.write_text(json.dumps(actual), encoding="utf-8")
    command = _module_command(
        "$a=Get-Content -Raw $arg1|ConvertFrom-Json -AsHashtable -DateKind String;"
        "$e=Get-Content -Raw $arg2|ConvertFrom-Json -AsHashtable -DateKind String;"
        "Assert-QmInputMapMatchesSet -Actual $a -Expected $e;'PASS'"
    )

    valid = _pwsh(command, str(SUPPORT), str(actual_path), str(expected_path), "unused")
    assert valid.returncode == 0, valid.stdout + valid.stderr
    assert "PASS" in valid.stdout

    actual["unexpected_empty_input"] = ""
    actual_path.write_text(json.dumps(actual), encoding="utf-8")
    invalid = _pwsh(command, str(SUPPORT), str(actual_path), str(expected_path), "unused")

    assert invalid.returncode != 0
    assert "Report/set input count drift" in _normalized_output(invalid)


def _mock_contract(report_dir: Path) -> tuple[dict[str, object], dict[str, object]]:
    reports: list[dict[str, object]] = []
    for ordinal in (1, 2):
        report = report_dir / "raw" / f"run_{ordinal:02d}" / "report.htm"
        report.parent.mkdir(parents=True)
        report.write_text("mock", encoding="utf-8")
        (report.parent / "tester.ini").write_text("[Tester]\n", encoding="ascii")
        tester_log = report.parent / "tester.log"
        tester_log.write_text("log", encoding="utf-8")
        reports.append(
            {
                "status": "OK",
                "real_ticks_marker": True,
                "report_canonical_path": str(report),
                "tester_log_path": str(tester_log),
            }
        )
    contract: dict[str, object] = {
        "phase": "DEV",
        "symbol": "NDX.DWX",
        "timeframe": "M1",
        "kind": "index",
        "variant": "center",
        "from": "2021-01-01",
        "to": "2022-12-31",
        "runs": 2,
        "binding": True,
        "infrastructure_only": False,
        "requires_resolved_cost_axes": False,
    }
    summary: dict[str, object] = {
        "result": "PASS",
        "ea_id": 20009,
        "expert": r"QM\QM5_20009_ict-liquidity-portfolio",
        "symbol": "NDX.DWX",
        "terminal": "DEV1",
        "model": 4,
        "period": "M1",
        "requested_runs": 2,
        "min_trades_required": 0,
        "deterministic": True,
        "model4_log_marker_detected": True,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "report_dir": str(report_dir),
        "commission_group": {
            "commission_per_lot": 0,
            "commission_per_side_native": 0,
            "injected_sha256": "a" * 64,
            "canonical_sha256": "a" * 64,
            "restored_sha256": "a" * 64,
            "restored_to_canonical": True,
        },
        "runs": reports,
    }
    return contract, summary


def test_mocked_summary_requires_model4_and_every_raw_report(tmp_path: Path) -> None:
    contract, summary = _mock_contract(tmp_path / "report")
    contract_path = tmp_path / "contract.json"
    summary_path = tmp_path / "summary.json"
    contract_path.write_text(json.dumps(contract), encoding="utf-8")
    summary_path.write_text(json.dumps(summary), encoding="utf-8")
    command = _module_command(
        "$s=Get-Content -Raw -LiteralPath $arg1|ConvertFrom-Json -AsHashtable -DateKind String;"
        "$c=Get-Content -Raw -LiteralPath $arg2|ConvertFrom-Json -AsHashtable -DateKind String;"
        "$r=Assert-QmResearchSummary -Summary $s -Contract $c;$r|ConvertTo-Json -Compress"
    )
    valid = _pwsh(command, str(SUPPORT), str(summary_path), str(contract_path), "unused")
    assert valid.returncode == 0, valid.stdout + valid.stderr
    assert len(json.loads(valid.stdout)["reports"]) == 2
    assert len(json.loads(valid.stdout)["tester_inis"]) == 2
    assert len(json.loads(valid.stdout)["tester_logs"]) == 2

    summary["model4_log_marker_detected"] = False
    summary_path.write_text(json.dumps(summary), encoding="utf-8")
    invalid = _pwsh(command, str(SUPPORT), str(summary_path), str(contract_path), "unused")
    assert invalid.returncode != 0
    assert "model4_log_marker_detected=true" in _normalized_output(invalid)


def _mock_cost_audit(contract: dict[str, object], report_paths: list[str]) -> tuple[dict, dict]:
    inputs = {f"input_{index:02d}": str(index) for index in range(33)}
    inputs.update({"qm_ea_id": "20009", "InpQMSimCommissionPerLot": "0.0"})
    deal_hash = "b" * 64
    run_hash = "c" * 64
    audits = []
    for report_path in report_paths:
        audits.append(
            {
                "status": "PASS",
                "report": {"path": report_path},
                "header": {
                    "symbol": contract["symbol"],
                    "timeframe": contract["timeframe"],
                    "from_date": contract["from"],
                    "to_date": contract["to"],
                    "initial_deposit": "100000.00",
                    "currency": "USD",
                    "inputs": inputs,
                },
                "identity": {
                    "canonical_deal_sequence_sha256": deal_hash,
                    "run_fingerprint_sha256": run_hash,
                },
                "native_integrity": {
                    "commission_exactly_zero": True,
                    "simulated_commission_input_exactly_zero": True,
                },
                "metrics": {"closed_positions": 1},
                "same_day_swap_proof": {"status": "PASS"},
            }
        )
    return (
        {
            "artifact_type": "QM5_20009_DEV1_MT5_REPORT_AUDIT_RECEIPT",
            "status": "PASS",
            "duplicate_count": 2,
            "duplicate_fingerprint_check": "PASS",
            "canonical_deal_sequence_sha256": deal_hash,
            "run_fingerprint_sha256": run_hash,
            "reports": audits,
        },
        inputs,
    )


def test_mocked_cost_audit_rejects_duplicate_deal_sequence_drift(tmp_path: Path) -> None:
    contract, summary = _mock_contract(tmp_path / "report")
    report_paths = [row["report_canonical_path"] for row in summary["runs"]]
    audit, inputs = _mock_cost_audit(contract, report_paths)
    contract_path = tmp_path / "contract.json"
    audit_path = tmp_path / "audit.json"
    inputs_path = tmp_path / "inputs.json"
    reports_path = tmp_path / "reports.json"
    contract_path.write_text(json.dumps(contract), encoding="utf-8")
    audit_path.write_text(json.dumps(audit), encoding="utf-8")
    inputs_path.write_text(json.dumps(inputs), encoding="utf-8")
    reports_path.write_text(json.dumps(report_paths), encoding="utf-8")
    command = _module_command(
        "$a=Get-Content -Raw $arg1|ConvertFrom-Json -AsHashtable -DateKind String;"
        "$c=Get-Content -Raw $arg2|ConvertFrom-Json -AsHashtable -DateKind String;"
        "$i=Get-Content -Raw $arg3|ConvertFrom-Json -AsHashtable -DateKind String;"
        f"$r=Get-Content -Raw '{reports_path}'|ConvertFrom-Json;"
        "$o=Assert-QmCostAudit -Audit $a -Contract $c -SetInputs $i -ExpectedReports $r;"
        "$o|ConvertTo-Json -Compress -Depth 10"
    )
    valid = _pwsh(command, str(SUPPORT), str(audit_path), str(contract_path), str(inputs_path))
    assert valid.returncode == 0, valid.stdout + valid.stderr
    assert json.loads(valid.stdout)["pass_candidate"] is True

    audit["reports"][0]["metrics"]["closed_positions"] = 0
    audit["reports"][0]["same_day_swap_proof"]["status"] = "NOT_APPLICABLE_NO_CLOSED_POSITIONS"
    audit_path.write_text(json.dumps(audit), encoding="utf-8")
    valid_fail_evidence = _pwsh(
        command, str(SUPPORT), str(audit_path), str(contract_path), str(inputs_path)
    )
    assert valid_fail_evidence.returncode == 0, valid_fail_evidence.stdout + valid_fail_evidence.stderr
    observations = json.loads(valid_fail_evidence.stdout)
    assert observations["pass_candidate"] is False
    assert "ZERO_TRADES_OBSERVED" in observations["candidate_block_reasons"]
    assert "SAME_DAY_ZERO_SWAP_PROOF_NOT_PASS" in observations["candidate_block_reasons"]

    audit["reports"][1]["identity"]["canonical_deal_sequence_sha256"] = "d" * 64
    audit_path.write_text(json.dumps(audit), encoding="utf-8")
    invalid = _pwsh(command, str(SUPPORT), str(audit_path), str(contract_path), str(inputs_path))
    assert invalid.returncode != 0
    assert "fingerprint drift" in _normalized_output(invalid).lower()


def test_detached_receipt_hash_binds_atomic_json(tmp_path: Path) -> None:
    receipt = tmp_path / "receipt.json"
    command = _module_command(
        "$payload=[ordered]@{schema_version=1;status='PASS';verdict='NOT_ADJUDICATED'};"
        "$b=Write-QmDetachedJsonReceipt -Path $arg1 -Payload $payload;$b|ConvertTo-Json -Compress"
    )
    completed = _pwsh(command, str(SUPPORT), str(receipt), "unused", "unused")
    assert completed.returncode == 0, completed.stdout + completed.stderr
    binding = json.loads(completed.stdout)
    actual = hashlib.sha256(receipt.read_bytes()).hexdigest()
    assert binding["sha256"] == actual
    assert Path(f"{receipt}.sha256").read_text(encoding="utf-8").strip() == actual

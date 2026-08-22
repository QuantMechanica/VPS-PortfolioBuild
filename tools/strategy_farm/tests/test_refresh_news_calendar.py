from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tools" / "strategy_farm" / "refresh_news_calendar.ps1"
PRIMARY_NAME = "news_calendar_2015_2025.csv"
SECONDARY_NAME = "forex_factory_calendar_clean.csv"
PRIMARY_HEADER = (
    "datetime,currency,event_name,impact,actual,forecast,previous,"
    "impact_numeric,is_high_impact,is_nfp,is_fomc,is_ecb,is_boe,is_gdp,"
    "is_cpi,is_pmi,day_of_week,hour,day,is_first_friday"
)
SECONDARY_HEADER = (
    "Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,Actual,Forecast,"
    "Previous"
)
REAL_FACTORY_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")


_TEST_GATE_WRAPPER = r'''from __future__ import annotations
import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.environ["QM_CAL_TEST_TOOLS"])
import news_calendar_gate as gate


def policy():
    return gate._test_publication_policy(
        source_dir=Path(os.environ["QM_CAL_TEST_SOURCE"]),
        common_dirs=[Path(value) for value in json.loads(os.environ["QM_CAL_TEST_COMMONS"])],
        factory_off_flag=Path(os.environ["QM_CAL_TEST_FLAG"]),
        refresh_script=Path(__file__).with_name("refresh_news_calendar.ps1"),
        evidence_dir=Path(os.environ["QM_CAL_TEST_EVIDENCE"]),
    )


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    plan = sub.add_parser("multi-plan")
    plan.add_argument("--primary-candidate", type=Path, required=True)
    plan.add_argument("--secondary-candidate", type=Path, required=True)
    plan.add_argument("--generated-at")
    plan.add_argument("--output", type=Path)
    publish = sub.add_parser("multi-publish")
    publish.add_argument("--plan", type=Path, required=True)
    publish.add_argument("--expected-plan-sha256", required=True)
    generation = publish.add_mutually_exclusive_group(required=True)
    generation.add_argument("--expected-factory-off-sha256")
    generation.add_argument("--allow-factory-on", action="store_true")
    publish.add_argument("--apply", action="store_true")
    publish.add_argument("--journal-output", type=Path, required=True)
    publish.add_argument("--receipt-output", type=Path, required=True)
    args = parser.parse_args()
    test_policy = policy()
    try:
        if args.command == "multi-plan":
            result = gate.build_multi_principal_publication_plan(
                args.primary_candidate,
                args.secondary_candidate,
                generated_at=args.generated_at,
                _policy=test_policy,
            )
            if args.output is not None:
                gate._write_json_atomic_output(args.output, result)
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        if not args.apply:
            raise gate.NewsCalendarError("test wrapper permits only explicit apply")
        plan_value = gate._read_plan(args.plan)
        result = gate.execute_multi_principal_publication(
            plan_value,
            expected_plan_sha256=args.expected_plan_sha256,
            expected_factory_off_sha256=args.expected_factory_off_sha256,
            allow_factory_on=args.allow_factory_on,
            journal_output=args.journal_output,
            receipt_output=args.receipt_output,
            _policy=test_policy,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return gate._publication_outcome_exit_code(result)
    except (gate.NewsCalendarError, OSError, RuntimeError, ValueError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
'''


def _make_test_harness(
    *, base: Path, common: Path, state: Path
) -> tuple[Path, dict[str, str]]:
    harness = state.parent / f".{state.name}-calendar-test-harness"
    harness.mkdir(parents=True, exist_ok=True)
    script = harness / SCRIPT.name
    fake_flag = state.parent / f".{state.name}-factory-state" / "FACTORY_OFF.flag"
    script_text = SCRIPT.read_text(encoding="ascii")
    for production_value, test_value in (
        (r"D:\QM\data\news_calendar", str(base)),
        (r"D:\QM\reports\state", str(state)),
        (r"D:\QM\strategy_farm\state\FACTORY_OFF.flag", str(fake_flag)),
        (r"C:\Python311\python.exe", sys.executable),
    ):
        script_text = script_text.replace(production_value, test_value)
    script.write_text(script_text, encoding="ascii", newline="")
    shutil.copy2(REPO / "tools" / "strategy_farm" / "news_calendar_repin.py", harness)
    (harness / "news_calendar_gate.py").write_text(
        _TEST_GATE_WRAPPER, encoding="ascii", newline="\n"
    )
    registry = harness / "dxz23_execution_contracts.json"
    receipt_dir = harness / "repin-receipts"
    bundle_root = harness / "repin-bundles"
    lock_path = harness / "locks" / "news_calendar_repin.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    primary = base / PRIMARY_NAME
    secondary = base / SECONDARY_NAME
    if not registry.exists() and primary.is_file():
        raw = primary.read_bytes()
        secondary_raw = secondary.read_bytes() if secondary.is_file() else raw
        dates = []
        for line in raw.decode("ascii").splitlines()[1:]:
            if line:
                dates.append(line.split(",", 1)[0][:10])
        start = min(dates) if dates else None
        end = max(dates) if dates else None
        pinned = hashlib.sha256(raw).hexdigest()
        secondary_pinned = hashlib.sha256(secondary_raw).hexdigest()
        registry.write_text(
            json.dumps(
                {
                    "contracts": [
                        {
                            "calendar": {
                                "sources": [
                                    {
                                        "role": "SHARED_PRIMARY",
                                        "path": str(primary.resolve()),
                                        "sha256": pinned,
                                        "coverage_start": start,
                                        "coverage_end": end,
                                    },
                                    {
                                        "role": "TEST_COMMON_PRIMARY",
                                        "path": str((common / PRIMARY_NAME).resolve()),
                                        "sha256": pinned,
                                        "coverage_start": start,
                                        "coverage_end": end,
                                    },
                                    {
                                        "role": "SHARED_SECONDARY",
                                        "path": str(secondary.resolve()),
                                        "sha256": secondary_pinned,
                                        "coverage_start": start,
                                        "coverage_end": end,
                                    },
                                    {
                                        "role": "TEST_COMMON_SECONDARY",
                                        "path": str((common / SECONDARY_NAME).resolve()),
                                        "sha256": secondary_pinned,
                                        "coverage_start": start,
                                        "coverage_end": end,
                                    },
                                ]
                            }
                        }
                    ]
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
        old_bundle = bundle_root / "initial-pinned-calendar"
        old_bundle.mkdir(parents=True, exist_ok=True)
        (old_bundle / PRIMARY_NAME).write_bytes(raw)
        (old_bundle / SECONDARY_NAME).write_bytes(secondary_raw)
    env = os.environ.copy()
    env.update(
        {
            "QM_CAL_TEST_TOOLS": str(REPO / "tools" / "strategy_farm"),
            "QM_CAL_TEST_SOURCE": str(base),
            "QM_CAL_TEST_COMMONS": json.dumps([str(common)]),
            "QM_CAL_TEST_FLAG": str(fake_flag),
            "QM_CAL_TEST_EVIDENCE": str(state),
            "QM_CALENDAR_REPIN_REGISTRY": str(registry),
            "QM_CALENDAR_REPIN_RECEIPT_DIR": str(receipt_dir),
            "QM_CALENDAR_REPIN_BUNDLE_ROOT": str(bundle_root),
            "QM_CALENDAR_REPIN_LOCK": str(lock_path),
            "QM_CALENDAR_REPIN_TEST_MODE": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
    )
    return script, env


def _run_refresh(
    *,
    base: Path,
    common: Path,
    state: Path,
    feed: Path,
    now_utc: str,
) -> subprocess.CompletedProcess[str]:
    pwsh = shutil.which("pwsh")
    if not pwsh:
        pytest.skip("PowerShell 7 is required for calendar refresh tests")
    harness_script, env = _make_test_harness(base=base, common=common, state=state)
    assert not REAL_FACTORY_LOCK.exists()
    command = (
            pwsh,
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(harness_script),
            "-FeedPath",
            str(feed),
            "-NowUtc",
            now_utc,
            "-CoverageDays",
            "2",
        )
    assert str(REAL_FACTORY_LOCK) not in command
    result = subprocess.run(
        command,
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert not REAL_FACTORY_LOCK.exists()
    return result


def _write_seed(path: Path, header: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((header + "\r\n").encode("ascii"))


def test_refresh_is_idempotent_and_preserves_csv_contracts(tmp_path: Path) -> None:
    base = tmp_path / "base"
    common = tmp_path / "common"
    state = tmp_path / "state"
    _write_seed(base / PRIMARY_NAME, PRIMARY_HEADER)
    _write_seed(base / SECONDARY_NAME, SECONDARY_HEADER)
    feed = tmp_path / "feed.json"
    feed.write_text(
        json.dumps(
            [
                {
                    "title": "Consumer Confidence \u2014 Flash",
                    "country": "USD",
                    "date": "2026-07-22T08:30:00-04:00",
                    "impact": "High",
                    "forecast": "101.2",
                    "previous": "100.0",
                }
            ],
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    stale_run = _run_refresh(
        base=base,
        common=common,
        state=state,
        feed=feed,
        now_utc="2026-07-25T00:00:00Z",
    )
    assert stale_run.returncode == 0, stale_run.stderr or stale_run.stdout
    assert "primary +1, secondary +1" in stale_run.stdout
    assert (state / "news_calendar_stale.flag").exists()

    primary = (base / PRIMARY_NAME).read_bytes()
    secondary = (base / SECONDARY_NAME).read_bytes()
    assert primary.startswith(PRIMARY_HEADER.encode("ascii") + b"\r\n")
    assert secondary.startswith(SECONDARY_HEADER.encode("ascii") + b"\r\n")
    assert not primary.startswith(b"\xef\xbb\xbf")
    assert b"\n" not in primary.replace(b"\r\n", b"")
    assert b"\n" not in secondary.replace(b"\r\n", b"")
    primary_row = primary.decode("ascii").splitlines()[1]
    secondary_row = secondary.decode("ascii").splitlines()[1]
    assert len(primary_row.split(",")) == 20
    assert len(secondary_row.split(",")) == 9
    assert "2026-07-22 12:30:00,USD,Consumer Confidence - Flash,high" in primary_row
    assert ",2026.07.22 12:30,2026.07.22 15:30,USD,High," in secondary_row
    assert (common / PRIMARY_NAME).read_bytes() == primary
    assert (common / SECONDARY_NAME).read_bytes() == secondary
    harness = state.parent / f".{state.name}-calendar-test-harness"
    receipts = sorted((harness / "repin-receipts").glob("*.json"))
    assert len(receipts) == 1
    registry = json.loads((harness / "dxz23_execution_contracts.json").read_text())
    pinned = {
        source["role"]: source["sha256"]
        for contract in registry["contracts"]
        for source in contract["calendar"]["sources"]
    }
    assert pinned == {
        "SHARED_PRIMARY": hashlib.sha256(primary).hexdigest(),
        "TEST_COMMON_PRIMARY": hashlib.sha256(primary).hexdigest(),
        "SHARED_SECONDARY": hashlib.sha256(secondary).hexdigest(),
        "TEST_COMMON_SECONDARY": hashlib.sha256(secondary).hexdigest(),
    }
    verify = subprocess.run(
        (
            sys.executable,
            str(harness / "news_calendar_repin.py"),
            "verify",
            "--calendar",
            str(base / PRIMARY_NAME),
            "--registry",
            str(harness / "dxz23_execution_contracts.json"),
            "--receipt-dir",
            str(harness / "repin-receipts"),
        ),
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    assert verify.returncode == 0, verify.stdout + verify.stderr

    current_run = _run_refresh(
        base=base,
        common=common,
        state=state,
        feed=feed,
        now_utc="2026-07-19T00:00:00Z",
    )
    assert current_run.returncode == 0, current_run.stderr or current_run.stdout
    assert "primary +0, secondary +0" in current_run.stdout
    assert not (state / "news_calendar_stale.flag").exists()
    assert len((base / PRIMARY_NAME).read_text(encoding="ascii").splitlines()) == 2
    assert len((base / SECONDARY_NAME).read_text(encoding="ascii").splitlines()) == 2
    assert len(list((harness / "repin-receipts").glob("*.json"))) == 1


def test_missing_seed_is_not_created_or_appended(tmp_path: Path) -> None:
    base = tmp_path / "base"
    primary = base / PRIMARY_NAME
    _write_seed(primary, PRIMARY_HEADER)
    original = primary.read_bytes()
    feed = tmp_path / "feed.json"
    feed.write_text("[]", encoding="ascii")

    result = _run_refresh(
        base=base,
        common=tmp_path / "common",
        state=tmp_path / "state",
        feed=feed,
        now_utc="2026-07-19T00:00:00Z",
    )

    assert result.returncode == 0, result.stderr or result.stdout
    assert primary.read_bytes() == original
    assert not (base / SECONDARY_NAME).exists()
    assert "refresh skipped" in (result.stdout + result.stderr)


def test_feed_parse_failure_does_not_publish_or_advance_source_mtimes(
    tmp_path: Path,
) -> None:
    base = tmp_path / "base"
    common = tmp_path / "common"
    state = tmp_path / "state"
    _write_seed(base / PRIMARY_NAME, PRIMARY_HEADER)
    _write_seed(base / SECONDARY_NAME, SECONDARY_HEADER)
    fixed_ns = 1_700_000_000_123_456_700
    for name in (PRIMARY_NAME, SECONDARY_NAME):
        os.utime(base / name, ns=(fixed_ns, fixed_ns))
    before = {
        name: ((base / name).read_bytes(), (base / name).stat().st_mtime_ns)
        for name in (PRIMARY_NAME, SECONDARY_NAME)
    }
    malformed_feed = tmp_path / "malformed.json"
    malformed_feed.write_text("{not-json", encoding="ascii")

    result = _run_refresh(
        base=base,
        common=common,
        state=state,
        feed=malformed_feed,
        now_utc="2026-07-19T00:00:00Z",
    )

    assert result.returncode == 0, result.stderr or result.stdout
    assert "no publication" in (result.stdout + result.stderr)
    assert {
        name: ((base / name).read_bytes(), (base / name).stat().st_mtime_ns)
        for name in (PRIMARY_NAME, SECONDARY_NAME)
    } == before
    assert not common.exists()
    assert not state.exists()


def test_publication_target_failure_is_loud_and_nonzero(tmp_path: Path) -> None:
    base = tmp_path / "base"
    _write_seed(base / PRIMARY_NAME, PRIMARY_HEADER)
    _write_seed(base / SECONDARY_NAME, SECONDARY_HEADER)
    feed = tmp_path / "feed.json"
    feed.write_text(
        json.dumps(
            [
                {
                    "title": "CPI",
                    "country": "USD",
                    "date": "2026-07-19T08:30:00Z",
                    "impact": "High",
                    "forecast": "2.1",
                    "previous": "2.0",
                }
            ]
        ),
        encoding="ascii",
    )
    # A regular file where the Common root must be makes publication fail.
    common = tmp_path / "common"
    common.write_text("not a directory", encoding="ascii")

    result = _run_refresh(
        base=base, common=common, state=tmp_path / "state", feed=feed,
        now_utc="2026-07-19T00:00:00Z",
    )

    assert result.returncode != 0
    output = result.stdout + result.stderr
    assert "news-calendar gate failed" in output
    assert common.name in output


def test_reconciliation_plan_only_is_side_effect_free(tmp_path: Path) -> None:
    base = tmp_path / "base"
    common = tmp_path / "common"
    state = tmp_path / "state-does-not-exist"
    primary = PRIMARY_HEADER + "\r\n2026-07-19 08:30:00,USD,CPI,high,,,,3,1,0,0,0,0,0,1,0,6,8,19,0\r\n"
    secondary = SECONDARY_HEADER + "\r\n2026.07.19,2026.07.19 08:30,2026.07.19 11:30,USD,High,CPI,,,\r\n"
    (base / PRIMARY_NAME).parent.mkdir(parents=True)
    (base / PRIMARY_NAME).write_bytes(primary.encode("ascii"))
    (base / SECONDARY_NAME).write_bytes(secondary.encode("ascii"))
    pwsh = shutil.which("pwsh")
    if not pwsh:
        pytest.skip("PowerShell 7 is required for calendar refresh tests")

    harness_script, env = _make_test_harness(base=base, common=common, state=state)
    before_base = sorted(
        (str(path.relative_to(base)), path.read_bytes(), path.stat().st_mtime_ns)
        for path in base.rglob("*")
        if path.is_file()
    )
    assert not REAL_FACTORY_LOCK.exists()
    command = (
            pwsh,
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(harness_script),
            "-NowUtc",
            "2026-07-19T00:00:00Z",
            "-ReconciliationPlanOnly",
        )
    assert str(REAL_FACTORY_LOCK) not in command
    result = subprocess.run(
        command,
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert not REAL_FACTORY_LOCK.exists()

    assert result.returncode == 0, result.stderr or result.stdout
    plan = json.loads(result.stdout)
    assert plan["schema"] == "qm-news-calendar-multi-principal-publication-plan/v1"
    assert plan["targets"][0] == {"role": "source", "path": str(base.resolve())}
    assert plan["targets"][1] == {"role": "common", "path": str(common.resolve())}
    after_base = sorted(
        (str(path.relative_to(base)), path.read_bytes(), path.stat().st_mtime_ns)
        for path in base.rglob("*")
        if path.is_file()
    )
    assert after_base == before_base
    assert not state.exists()


def test_scheduled_defaults_cover_all_principals_without_legacy_copy() -> None:
    text = SCRIPT.read_text(encoding="ascii")
    assert "C:\\Users\\Administrator\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files" in text
    assert "C:\\Windows\\System32\\config\\systemprofile\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files" in text
    assert "C:\\Users\\QMDev1\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files" in text
    assert "multi-publish" in text
    assert "news_calendar_repin.py" in text
    assert "QM_NEWS_CALENDAR_REFRESH_PARENT_PID" in text
    assert "--publication-receipt" in text
    assert "--publication-journal" in text
    assert "--expected-plan-sha256" in text
    assert "--journal-output" in text
    assert "--receipt-output" in text
    assert "--source-dir" not in text
    assert "--common-dir" not in text
    assert "--factory-off-flag" not in text
    assert "--provenance-kind" not in text
    assert "$pythonExe = 'C:\\Python311\\python.exe'" in text
    assert "[string]$PythonExe" not in text
    assert "-PythonExe" not in text
    assert "$ErrorActionPreference = 'Stop'" in text
    assert "Copy-Item" not in text


def test_absolute_python_is_pinned_and_checked_before_any_side_effect() -> None:
    text = SCRIPT.read_text(encoding="ascii")

    assignment = "$pythonExe = 'C:\\Python311\\python.exe'"
    validation = "absolute Python interpreter is missing"
    first_operation = "if ($ReconciliationPlanOnly)"
    assert assignment in text
    assert validation in text
    assert text.index(assignment) < text.index(validation) < text.index(first_operation)
    assert "[string]$PythonExe" not in text
    assert "-PythonExe" not in text


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_refresh_script_is_ascii_and_parses_in_windows_powershell() -> None:
    assert all(byte < 128 for byte in SCRIPT.read_bytes())
    parser = (
        "$tokens=$null;$errors=$null;"
        f"[System.Management.Automation.Language.Parser]::ParseFile('{SCRIPT}',"
        "[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count){$errors|ForEach-Object{Write-Error $_};exit 1}"
    )
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", parser),
        cwd=REPO,
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout

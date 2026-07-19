from __future__ import annotations

import json
import os
import shutil
import subprocess
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
    return subprocess.run(
        (
            pwsh,
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(SCRIPT),
            "-Base",
            str(base),
            "-Common",
            str(common),
            "-StateDir",
            str(state),
            "-FeedPath",
            str(feed),
            "-NowUtc",
            now_utc,
            "-CoverageDays",
            "2",
        ),
        cwd=REPO,
        env=os.environ.copy(),
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


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
    assert "append skipped" in (result.stdout + result.stderr)


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

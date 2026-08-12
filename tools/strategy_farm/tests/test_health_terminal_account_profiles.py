"""Read-only health coverage for portable MT5 account/profile faults."""

from pathlib import Path

from tools.strategy_farm import health


def _profile(root: Path, terminal: str, log_text: str, *, complete: bool = True) -> None:
    config = root / terminal / "Config"
    logs = root / terminal / "logs"
    config.mkdir(parents=True)
    logs.mkdir(parents=True)
    if complete:
        (config / "accounts.dat").write_bytes(b"account fixture")
        (config / "servers.dat").write_bytes(b"server fixture")
        (config / "common.ini").write_text(
            "[Common]\nLogin=4000090541\nServer=Darwinex-Live\n",
            encoding="utf-8",
        )
    (logs / "20260802.log").write_bytes(log_text.encode("utf-16-le"))


def test_current_launch_account_failure_is_fail(tmp_path: Path) -> None:
    _profile(
        tmp_path,
        "T3",
        "Startup successfully initialized from start config tester.ini\r\n"
        "Tester tester not started because the account is not specified\r\n",
    )

    result = health.chk_terminal_account_profiles(
        mt5_root=tmp_path,
        terminals=("T3",),
        disabled=set(),
    )

    assert result["status"] == "FAIL"
    assert result["value"] == 1
    assert "T3:20260802.log" in result["detail"]


def test_stale_account_failure_before_latest_launch_is_not_reused(tmp_path: Path) -> None:
    _profile(
        tmp_path,
        "T3",
        "Tester tester not started because the account is not specified\r\n"
        "Startup successfully initialized from start config tester.ini\r\n"
        "Tester last test passed with result \"successfully finished\"\r\n",
    )

    result = health.chk_terminal_account_profiles(
        mt5_root=tmp_path,
        terminals=("T3",),
        disabled=set(),
    )

    assert result["status"] == "OK"


def test_missing_profile_files_warn_without_mutation(tmp_path: Path) -> None:
    _profile(
        tmp_path,
        "T3",
        "Startup successfully initialized from start config tester.ini\r\n",
        complete=False,
    )

    result = health.chk_terminal_account_profiles(
        mt5_root=tmp_path,
        terminals=("T3",),
        disabled=set(),
    )

    assert result["status"] == "WARN"
    assert "accounts.dat_missing_or_empty" in result["detail"]
    assert "common.ini_Login_missing" in result["detail"]


def test_inflight_launch_without_readiness_is_warn_not_ok(tmp_path: Path) -> None:
    _profile(
        tmp_path,
        "T3",
        "Startup successfully initialized from start config tester.ini\r\n"
        "Terminal launched with tester.ini\r\n",
    )

    result = health.chk_terminal_account_profiles(
        mt5_root=tmp_path,
        terminals=("T3",),
        disabled=set(),
    )

    assert result["status"] == "WARN"
    assert "has not yet proved account readiness" in result["detail"]

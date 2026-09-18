"""The FTMO demo instrumentation verifier must stay pinned to the ACTIVE book.

GAPS G1 of `docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6` (router
ops_issue 57bfd3af item 1): `verify_ftmo_demo_instrumentation_contract.ps1` is
the gate `FTMO_ON.ps1` / scheduled task `QM_FTMO_AtLogon` runs before launching
the FTMO demo terminal. A pin left on a superseded book makes it exit 2 and the
terminal never comes back after a reboot (the 2026-09-09 regression).

These tests re-derive every pinned value from the package itself -- roster.json,
sets/, collector/, bin/, governor_rebind_receipt.json -- so a hand-edit that
drifts from the package fails here rather than at logon. They read only repo
files; the PowerShell round-trip builds a synthetic data dir under tmp_path and
never touches the live terminal (it reads one unchanged governor .ex5 for its
hash and skips if that is not present).
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "strategy_farm" / "verify_ftmo_demo_instrumentation_contract.ps1"
PKG = ROOT / "docs" / "ops" / "evidence" / "2026-09-18_ftmo_demo_book_v3_D2g6"
GOVERNOR_PRESET = ROOT / (
    "framework/EAs/QM5_13206_ftmo-account-governor/sets/"
    "QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set"
)
LIVE_DATA_DIR = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850"
)
LIVE_GOVERNOR_EX5 = LIVE_DATA_DIR / "MQL5/Experts/QM_FTMO/QM5_13206_ftmo-account-governor.ex5"

# The six sleeves the incumbent book carried and D2g6 retires. None of them may
# survive anywhere in the pin.
RETIRED_SLUGS = (
    "ohlc-daily-squeeze-reversal-d1",
    "larry-williams-18ma-2outside-bars-d1",
    "brent-tom-mom",
    "wti-preholiday",
    "aa-vol-sma10",
    "xag-weekly-lowvol-momentum",
)
RETIRED_MAGICS = ("114210000", "119100006", "130540000", "200480000", "15370001", "215050000")


def sha_raw(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def sha_lf(path: Path) -> str:
    """Digest of the LINE-ENDING-NORMALIZED bytes.

    Text presets are pinned this way because `core.autocrlf` gives the same
    committed content a different raw digest per checkout -- the same
    `pin_basis` rule the FTMO binding records (2026-09-18, ticket a5cf99d0).
    The bytes `demo_install` copies into the terminal are the LF ones.
    """
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest().upper()


def script_text() -> str:
    return SCRIPT.read_text(encoding="utf-8")


def parse_legs() -> list[dict]:
    text = script_text()
    block = text.split("$legs = @(", 1)[1].split("\n)\n", 1)[0]
    legs = []
    for line in block.splitlines():
        if "[pscustomobject]" not in line:
            continue
        row = dict(re.findall(r"(\w+)='([^']*)'", line))
        row["ea_id"] = re.search(r"ea_id=(\d+)", line).group(1)
        legs.append(row)
    return legs


def scalar(name: str) -> str:
    match = re.search(rf"^\${name} = '([^']*)'", script_text(), re.MULTILINE)
    assert match, f"${name} not found in the verifier"
    return match.group(1)


@pytest.fixture(scope="module")
def roster() -> dict:
    return json.loads((PKG / "roster.json").read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def rebind_receipt() -> dict:
    return json.loads((PKG / "governor_rebind_receipt.json").read_text(encoding="utf-8"))


def test_legs_are_exactly_the_d2g6_roster(roster) -> None:
    legs = {int(leg["ea_id"]): leg for leg in parse_legs()}
    assert len(legs) == 6

    expected = {int(row["ea_id"]): row for row in roster["candidates"]}
    assert set(legs) == set(expected)

    for ea_id, row in expected.items():
        leg = legs[ea_id]
        assert leg["symbol"] == row["ftmo_symbol"], ea_id
        assert not leg["symbol"].upper().endswith(".DWX"), ea_id
        assert int(leg["slot"]) == row["slot"], ea_id
        assert float(leg["risk_percent"]) == row["risk_percent"], ea_id
        # magic formula ea_id*10000+slot
        assert int(leg["ea_id"]) * 10000 + int(leg["slot"]) == row["magic"], ea_id
        # period_type=1 is "hours"; H1 = 1/1, D1 = 1/24 (CHART_PLAN 2c)
        assert leg["period_type"] == "1", ea_id
        assert leg["period_size"] == {"H1": "1", "D1": "24"}[row["timeframe"]], ea_id
        assert leg["expertmode"] == "1", ea_id
        assert leg["risk_fixed"] == "0", ea_id
        assert leg["portfolio_weight"] == "1", ea_id
        assert row["ea_label"] == f"QM5_{ea_id}_{leg['slug']}", ea_id


def test_only_13213_runs_at_half_risk() -> None:
    legs = {int(leg["ea_id"]): leg for leg in parse_legs()}
    assert legs[13213]["risk_percent"] == "0.15625"
    others = {leg["risk_percent"] for ea, leg in legs.items() if ea != 13213}
    assert others == {"0.3125"}
    book = sum(float(leg["risk_percent"]) for leg in legs.values())
    assert round(book, 8) == 1.71875


def test_sleeve_preset_and_binary_hashes_come_from_the_package() -> None:
    for leg in parse_legs():
        preset = PKG / "sets" / leg["preset"]
        assert preset.is_file(), leg["preset"]
        assert leg["preset_sha"] == sha_lf(preset), leg["preset"]

        ea_name = f"QM5_{leg['ea_id']}_{leg['slug']}.ex5"
        binary = PKG / "bin" / ea_name
        assert binary.is_file(), ea_name
        assert leg["binary_sha"] == sha_raw(binary), ea_name


def test_governor_pins_match_the_rebind_receipt(rebind_receipt) -> None:
    updates = rebind_receipt["updates"]
    assert scalar("governorChallengeId") == updates["challenge_id"]
    assert scalar("governorAllowedMagicsCsv") == updates["allowed_magics_csv"]
    assert scalar("governorEaIdsCsv") == updates["governed_ea_ids_csv"]
    assert scalar("governorSymbolsCsv") == updates["governed_symbols_csv"]
    # The rebound active preset, not the pre-rebind one.
    after = rebind_receipt["presets"]["active"]["sha256_after"].upper()
    assert scalar("governorPresetSha") == after
    assert scalar("governorPresetSha") == sha_lf(GOVERNOR_PRESET)


def test_telemetry_pins_bind_the_collector_to_the_new_cycle() -> None:
    collector = PKG / "collector" / "QM_FTMO_TrialTelemetry_1514536732.set"
    assert scalar("telemetryPresetSha") == sha_lf(collector)
    assert scalar("telemetryBinarySha") == sha_raw(PKG / "bin" / "QM_FTMO_TrialTelemetry.ex5")

    values = dict(
        line.split("=", 1)
        for line in collector.read_text(encoding="utf-8").splitlines()
        if "=" in line and not line.startswith(";")
    )
    assert scalar("telemetryTrialId") == values["InpTrialId"]
    assert scalar("telemetryOutputDir") == values["InpOutputDir"]
    assert json.loads((PKG / "roster.json").read_text(encoding="utf-8"))["cycle_id"] in (
        values["InpOutputDir"]
    )


def test_profile_is_the_nine_chart_d2g6_shape() -> None:
    text = script_text()
    expected = re.search(
        r"\$expected = @\((.*?)\) \| Sort-Object", text, re.DOTALL
    ).group(1)
    files = re.findall(r"'([^']+)'", expected)
    assert files == [f"chart0{i}.chr" for i in range(1, 10)] + ["order.wnd"]
    # governor + 6 sleeves + collector + blank == 9 charts
    charts = {leg["chart"] for leg in parse_legs()}
    charts |= {scalar("governorChartName"), scalar("telemetryChartName"), scalar("blankChartName")}
    assert len(charts) == 9
    assert charts == set(files[:-1])


def test_presets_are_read_from_the_demo_install_target_directory() -> None:
    text = script_text()
    assert r"MQL5\Profiles\Presets\QM_FTMO_M13" in text
    # The flat legacy MQL5\Presets copy is not the install target any more.
    assert not re.search(r"Join-Path \$dataDir 'MQL5\\Presets'", text)


def test_no_retired_sleeve_survives_the_repin() -> None:
    text = script_text()
    legs_block = text.split("$legs = @(", 1)[1].split("\n)\n", 1)[0]
    for slug in RETIRED_SLUGS:
        assert slug not in legs_block, slug
    for magic in RETIRED_MAGICS:
        assert magic not in scalar("governorAllowedMagicsCsv"), magic


def test_header_records_the_repin_provenance() -> None:
    text = script_text()
    assert "2026-09-18" in text
    assert "OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917" in text
    assert r"docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6" in text
    # The chart-numbering assumption must stay stated: MT5 renumbers on save.
    assert "MT5 renumbers" in text


def test_script_stays_fail_closed() -> None:
    text = script_text()
    assert "exit 2" in text
    assert text.count("exit 0") == 1
    assert "FTMO demo instrumentation contract verification failed" in text
    # Read-only: it must never launch, attach, or toggle anything.
    for forbidden in ("Start-Process", "Set-Content", "Out-File", "Remove-Item", "Copy-Item"):
        assert forbidden not in text, forbidden


# --------------------------------------------------------------------------
# PowerShell round-trip: the pinned table must parse and match a profile built
# to exactly the field list CHART_PLAN.md specifies, and must reject a drift.
# --------------------------------------------------------------------------

EA_DIR = "Experts" + chr(92) + "QM_FTMO" + chr(92)


def _pairs(path: Path, strip_ranges: bool = False) -> list[tuple[str, str]]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        if strip_ranges and "||" in value:
            value = value.split("||", 1)[0]
        out.append((key.strip(), value.strip()))
    return out


def _write_chart(profile: Path, name, *, symbol, period_type, period_size, expert=None) -> None:
    lines = [
        "<chart>", "id=13000000001", "symbol=" + symbol,
        "period_type=" + period_type, "period_size=" + period_size,
        "digits=5", "scale=16", "mode=1",
    ]
    if expert is not None:
        lines += ["<expert>", "name=" + expert["name"], "path=" + expert["path"],
                  "expertmode=1", "<inputs>"]
        lines += [f"{k}={v}" for k, v in expert["inputs"]]
        lines += ["</inputs>", "</expert>"]
    lines += ["<window>", "height=100.000000", "</window>", "</chart>", ""]
    (profile / name).write_bytes(
        b"\xff\xfe" + "\r\n".join(lines).encode("utf-16-le")
    )


def _copy_lf(src: Path, dst: Path) -> None:
    dst.write_bytes(src.read_bytes().replace(b"\r\n", b"\n"))


def build_fixture(root: Path, roster: dict) -> Path:
    """A synthetic data dir matching the CHART_PLAN.md expected field list."""
    profile = root / "MQL5/Profiles/Charts/Default"
    presets = root / "MQL5/Profiles/Presets/QM_FTMO_M13"
    experts = root / "MQL5/Experts/QM_FTMO"
    config = root / "config"
    for directory in (profile, presets, experts, config):
        directory.mkdir(parents=True, exist_ok=True)

    legs = {int(leg["ea_id"]): leg for leg in parse_legs()}
    for row in roster["candidates"]:
        leg = legs[int(row["ea_id"])]
        src = PKG / "sets" / leg["preset"]
        _copy_lf(src, presets / leg["preset"])
        ea_name = f"QM5_{leg['ea_id']}_{leg['slug']}"
        shutil.copyfile(PKG / "bin" / f"{ea_name}.ex5", experts / f"{ea_name}.ex5")
        inputs = _pairs(src)
        # MT5 enumerates every EA input in the .chr, not only the keys the
        # derived preset carries; two D2g6 presets omit qm_ea_id.
        have = {k for k, _ in inputs}
        extra = [(k, v) for k, v in (
            ("qm_ea_id", leg["ea_id"]), ("qm_magic_slot_offset", leg["slot"])
        ) if k not in have]
        _write_chart(
            profile, leg["chart"], symbol=leg["symbol"],
            period_type=leg["period_type"], period_size=leg["period_size"],
            expert={"name": ea_name, "path": EA_DIR + ea_name + ".ex5",
                    "inputs": extra + inputs},
        )

    _copy_lf(GOVERNOR_PRESET, presets / GOVERNOR_PRESET.name)
    shutil.copyfile(LIVE_GOVERNOR_EX5, experts / LIVE_GOVERNOR_EX5.name)
    _write_chart(
        profile, scalar("governorChartName"), symbol="EURUSD",
        period_type="0", period_size="1",
        expert={"name": "QM5_13206_ftmo-account-governor",
                "path": EA_DIR + "QM5_13206_ftmo-account-governor.ex5",
                "inputs": _pairs(GOVERNOR_PRESET, strip_ranges=True)},
    )

    collector = PKG / "collector" / "QM_FTMO_TrialTelemetry_1514536732.set"
    _copy_lf(collector, presets / collector.name)
    shutil.copyfile(PKG / "bin" / "QM_FTMO_TrialTelemetry.ex5",
                    experts / "QM_FTMO_TrialTelemetry.ex5")
    _write_chart(
        profile, scalar("telemetryChartName"), symbol="EURUSD",
        period_type="0", period_size="1",
        expert={"name": "QM_FTMO_TrialTelemetry",
                "path": EA_DIR + "QM_FTMO_TrialTelemetry.ex5",
                "inputs": _pairs(collector)},
    )

    _write_chart(profile, scalar("blankChartName"), symbol="EURUSD",
                 period_type="1", period_size="24")
    (profile / "order.wnd").write_bytes(b"\xff\xfe" + "order\r\n".encode("utf-16-le"))
    (config / "common.ini").write_bytes(
        b"\xff\xfe"
        + "[Common]\r\nLogin=1514536732\r\nServer=FTMO-Demo\r\n".encode("utf-16-le")
    )
    return root


def run_verifier(data_dir: Path) -> subprocess.CompletedProcess:
    # Drop any inherited PSModulePath: a POSIX-shell parent mangles it (path
    # separators / missing v1.0\Modules) and Microsoft.PowerShell.Utility then
    # fails to autoload, so Get-FileHash is missing and every run looks broken.
    # Removing it lets PowerShell compute its own default.
    env = {k: v for k, v in os.environ.items() if k.upper() != "PSMODULEPATH"}
    return subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", str(SCRIPT), "-DataDir", str(data_dir)],
        capture_output=True, text=True, timeout=180, env=env,
    )


def assert_refused(result: subprocess.CompletedProcess) -> None:
    """A refusal must be non-zero -- which is exactly what the launcher tests.

    The script's own `exit 2` is reported as 1 by Windows PowerShell 5.1 when
    invoked with `-File` and the script wrote to the error stream, so pinning
    the literal 2 here would test the host, not the contract. `FTMO_ON.ps1`
    aborts on `$LASTEXITCODE -ne 0` (profile_contract_failed), so non-zero is
    the property that matters.
    """
    assert result.returncode != 0, result.stdout + result.stderr
    assert "contract verification failed" in (result.stdout + result.stderr)


requires_powershell = pytest.mark.skipif(
    os.name != "nt" or shutil.which("powershell") is None
    or not LIVE_GOVERNOR_EX5.is_file(),
    reason="needs Windows PowerShell and the unchanged governor .ex5 for its pinned hash",
)


@requires_powershell
def test_pinned_table_verifies_against_a_synthetic_d2g6_profile(tmp_path, roster) -> None:
    data_dir = build_fixture(tmp_path / "data", roster)
    result = run_verifier(data_dir)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "six SHA-pinned D2g6 sleeves" in result.stdout


@requires_powershell
def test_verifier_rejects_a_13213_risk_drift(tmp_path, roster) -> None:
    """0.3125 on 13213 silently turns a 1.71875 % book into 1.875 %."""
    data_dir = build_fixture(tmp_path / "data", roster)
    chart = next(
        data_dir / "MQL5/Profiles/Charts/Default" / leg["chart"]
        for leg in parse_legs() if leg["ea_id"] == "13213"
    )
    text = chart.read_bytes().decode("utf-16")  # decode() consumes the BOM
    drifted = text.replace("RISK_PERCENT=0.15625", "RISK_PERCENT=0.3125")
    assert drifted != text
    chart.write_bytes(b"\xff\xfe" + drifted.encode("utf-16-le"))
    result = run_verifier(data_dir)
    assert_refused(result)


@requires_powershell
def test_verifier_rejects_a_retired_sleeve_left_attached(tmp_path, roster) -> None:
    data_dir = build_fixture(tmp_path / "data", roster)
    profile = data_dir / "MQL5/Profiles/Charts/Default"
    shutil.copyfile(profile / "chart02.chr", profile / "chart10.chr")
    result = run_verifier(data_dir)
    assert_refused(result)
    assert "unexpected Default profile file set" in (result.stdout + result.stderr)

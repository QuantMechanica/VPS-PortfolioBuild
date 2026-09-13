"""Ticket 24df7ddd / 2026-09-13 — current-run scoping of the real-ticks marker.

run_smoke.ps1 used to prove the "generating based on real ticks" marker with an
UNSCOPED full-file Select-String over the copied daily tester journal. MetaTester
reuses one journal per terminal agent, so that journal carries markers from
earlier Model=4 runs of OTHER cells. For work item 2a897e8e (QM5_41405 Model-1
PRESCREEN cell on T2) the unscoped scan hit those older markers, wrote
model4_log_marker_detected=True / runs[0].real_ticks_marker=True into summary.json,
and farmctl._derive_prescreen_verdict_from_summary returned INFRA_FAIL
PRESCREEN_EVIDENCE_CLASS_MISMATCH.

The fix (Get-TesterLogRealTicksMarker) scopes the full-log scan to the current run
(last "started with inputs" marker) before checking for the real-ticks marker, and
is class-aware: REAL_TICKS falls back to the legacy full scan when the start marker
cannot be located; the Model-1 PRESCREEN class never accepts an unscoped hit.

The test slices the two PowerShell function bodies out of run_smoke.ps1 into a
temporary harness (the same technique as test_buildcheck_predicate_fix.py), runs
them under Windows PowerShell, and asserts the returned booleans.
"""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[3]
RUN_SMOKE = ROOT / 'framework/scripts/run_smoke.ps1'

EXPERT = r'QM\QM5_41405_test'
SYMBOL = 'USDJPY.DWX'
FROM = '2019.01.01'
TO = '2019.12.31'

# Real copied journal from the incident (skip cleanly if it has aged out).
INCIDENT_LOG = Path(
    r'D:\QM\reports\work_items\2a897e8e-35d4-5a4c-bc07-0affa5c9de30'
    r'\QM5_41405\20260913_142412\raw\run_01\20260913.log'
)


def _slice_function(source, name):
    start = source.index('function ' + name + ' {')
    nxt = source.index('\nfunction ', start + 1)
    return source[start:nxt]


def _write_utf16le_bom(path, lines):
    # MetaTester writes the daily journal as UTF-16LE with a BOM and CRLF lines.
    text = '\r\n'.join(lines) + '\r\n'
    path.write_bytes(b'\xff\xfe' + text.encode('utf-16-le'))


def _start_line(expert, symbol, from_date, to_date):
    return (
        'CS\t0\t16:24:20.998\tTester\t' + symbol + ',H1: testing of Experts\\'
        + expert + '.ex5 from ' + from_date + ' 00:00 to ' + to_date
        + ' 00:00 started with inputs:'
    )


MARKER = ('IK\t0\t16:24:21.100\t' + SYMBOL
          + ',H1: 2019.01.01 00:00:00   generating based on real ticks')


def _build_harness(tmp_path):
    source = RUN_SMOKE.read_text(encoding='utf-8-sig')
    body = (_slice_function(source, 'Get-TesterLogCurrentRunText') + '\n'
            + _slice_function(source, 'Get-TesterLogRealTicksMarker') + '\n')
    driver = (
        "$ErrorActionPreference='Stop'\n"
        "Set-StrictMode -Version Latest\n"
        + body +
        "$spec = Get-Content -Raw -LiteralPath $args[0] | ConvertFrom-Json\n"
        "$out = [ordered]@{}\n"
        "foreach ($c in $spec) {\n"
        "  $r = Get-TesterLogRealTicksMarker -TesterLogPath $c.path "
        "-RequiresRealTicksMarker ([bool]$c.requires) -ExpectedExpert $c.expert "
        "-ExpectedSymbol $c.symbol -ExpectedFromDate $c.from -ExpectedToDate $c.to\n"
        "  $out[$c.name] = [bool]$r\n"
        "}\n"
        "ConvertTo-Json -InputObject $out -Compress\n"
    )
    harness = tmp_path / 'harness.ps1'
    harness.write_text(driver, encoding='utf-8')
    return harness


def _run(tmp_path, cases):
    harness = _build_harness(tmp_path)
    spec = tmp_path / 'spec.json'
    spec.write_text(json.dumps(cases), encoding='utf-8')
    run = subprocess.run(
        ['powershell', '-NoProfile', '-NonInteractive', '-File',
         str(harness), str(spec)],
        capture_output=True, text=True)
    assert run.returncode == 0, run.stderr
    return json.loads(run.stdout.splitlines()[-1])


def _case(name, path, requires):
    return {'name': name, 'path': str(path), 'requires': requires,
            'expert': EXPERT, 'symbol': SYMBOL, 'from': FROM, 'to': TO}


def test_marker_scope_behaviour(tmp_path):
    # (a) older run with the marker, then the current Model-1 run WITHOUT it.
    log_a = tmp_path / 'a.log'
    _write_utf16le_bom(log_a, [
        _start_line(r'QM\QM5_41398_other', SYMBOL, '2024.01.01', '2024.12.31'),
        MARKER,
        'CS\t0\t12:31:59\tTester\tfinal balance 100000.00 USD',
        _start_line(EXPERT, SYMBOL, FROM, TO),
        'CS\t0\t16:24:59\tTester\tUSDJPY.DWX,H1: 0 deals, final balance 100000.00 USD',
    ])

    # (b) current run section containing the marker.
    log_b = tmp_path / 'b.log'
    _write_utf16le_bom(log_b, [
        _start_line(EXPERT, SYMBOL, FROM, TO),
        MARKER,
        'CS\t0\t16:25:59\tTester\tUSDJPY.DWX,H1: 120 deals',
    ])

    # (c) no start marker at all, but a marker line is present in the file.
    log_c = tmp_path / 'c.log'
    _write_utf16le_bom(log_c, [
        'CS\t0\t16:24:00\tTester\tsome preamble without a start marker',
        MARKER,
    ])

    cases = [
        _case('a_prescreen', log_a, False),
        _case('a_realticks', log_a, True),
        _case('b_prescreen', log_b, False),
        _case('b_realticks', log_b, True),
        _case('c_prescreen', log_c, False),
        _case('c_realticks', log_c, True),
    ]
    res = _run(tmp_path, cases)

    # (a) current-run start marker found, no marker inside -> False for BOTH.
    assert res['a_prescreen'] is False, res
    assert res['a_realticks'] is False, res
    # (b) marker inside the current-run section -> True for both.
    assert res['b_prescreen'] is True, res
    assert res['b_realticks'] is True, res
    # (c) empty scoped section: REAL_TICKS legacy full-scan True; PRESCREEN False.
    assert res['c_prescreen'] is False, res
    assert res['c_realticks'] is True, res


# Exact identity of the incident work item's current run (summary.json for
# 2a897e8e). Only these values authenticate the current-run section in the copied
# journal; the placeholder EXPERT above deliberately does not.
INCIDENT_EXPERT = r'QM\QM5_41405_balke-clock-audit-opt'
INCIDENT_SYMBOL = 'USDJPY.DWX'
INCIDENT_FROM = '2019.01.01'
INCIDENT_TO = '2019.12.31'


def test_incident_log_current_run_has_no_marker(tmp_path):
    if not INCIDENT_LOG.exists():
        pytest.skip('incident log aged out: ' + str(INCIDENT_LOG))
    # Copy so the read never touches the live evidence file.
    local = tmp_path / '20260913.log'
    shutil.copy2(INCIDENT_LOG, local)

    def incident_case(name, requires):
        return {'name': name, 'path': str(local), 'requires': requires,
                'expert': INCIDENT_EXPERT, 'symbol': INCIDENT_SYMBOL,
                'from': INCIDENT_FROM, 'to': INCIDENT_TO}

    cases = [
        incident_case('incident_prescreen', False),
        incident_case('incident_realticks', True),
    ]
    res = _run(tmp_path, cases)
    # Model-1 PRESCREEN cell: the current run generated no real ticks; the 10
    # markers in the journal belong to earlier Model=4 cells above line ~20040.
    assert res['incident_prescreen'] is False, res
    # The current-run start marker is present, so the scoped scan is authoritative
    # even for the REAL_TICKS class: no marker inside the current run -> False.
    assert res['incident_realticks'] is False, res

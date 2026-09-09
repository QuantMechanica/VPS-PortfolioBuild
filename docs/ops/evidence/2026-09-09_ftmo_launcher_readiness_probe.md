# FTMO / T_Live launcher-readiness health probe — 2026-09-09

Task: `734baee6-3e6a-41b2-a25d-41bfe220e2e0`  
Mode: read-only verification; no terminal process, profile, preset, EX5,
AutoTrading setting, threshold, or gate changed.

## Result

Two named checks now remain separate from `live_mt5_uptime`:

| Check | Current status | Evidence |
|---|---|---|
| `ftmo_launcher_readiness` | **FAIL** | Native FTMO verifier rc=0, but the latest FTMO launcher receipt on the current boot is exit 2, `profile_contract_failed`, at `2026-09-09T16:44:50.270Z`. |
| `t_live_launcher_readiness` | **OK** | Native DXZ profile verifier rc=0 and the latest DXZ launcher receipt on the current boot is exit 0, `launched`, at `2026-09-09T16:44:55.970Z`. |

The boot boundary is read from
`Win32_OperatingSystem.LastBootUpTime`; observed boot time was
`2026-09-09T16:43:53Z`. Launcher receipts come from
`D:/QM/reports/state/live_launcher_events.jsonl`. A verifier failure always
fails closed. A non-zero launcher receipt from the current boot remains FAIL
even after the verifier is repaired: the clearing condition is the next
successful run of that same launcher writing a later current-boot
`exit_code=0` receipt.

Windows PowerShell is invoked with its native module roots explicitly pinned.
This matters when Python inherits a PowerShell-7 `PSModulePath`; without the
pin, Windows PowerShell could not auto-load `Get-FileHash`, falsely failing both
read-only verifiers.

## Surfaces

- `silent_failure_monitor.py` produces the two contract-versioned health rows.
- `farmctl health` imports them as independent checks; it does not merge them
  into `live_mt5_uptime`.
- The 06:00 `morning_brief.py` reads the health sidecar and renders dedicated
  FTMO and T_Live launcher-readiness rows in HTML and plaintext.
- `FTMO_M13_CAPTURE_RUNBOOK_2026-09-06.md` now requires re-running and re-pinning
  the verifier in the same reviewed commit after every FTMO attach/detach,
  rebuild, or preset change.

## Focused verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_launcher_readiness_health.py \
  tools/strategy_farm/tests/test_silent_failure_live_uptime.py \
  tools/strategy_farm/tests/test_morning_brief_live_status.py
84 passed

python tools/strategy_farm/silent_failure_monitor.py
runtime=10.4s; sidecar refreshed

python tools/strategy_farm/farmctl.py health
ftmo_launcher_readiness: FAIL, value=2, verifier_rc=0
t_live_launcher_readiness: OK, value=0, verifier_rc=0

python tools/strategy_farm/morning_brief.py --dry-run
NO mail sent; HTML contains both dedicated launcher-readiness rows
```

The simulated exit-code-2 regression test proves that a repaired verifier does
not erase a failed current-boot launch receipt. A second test proves a later
exit-0 receipt clears it, and a third proves verifier drift fails even when the
launcher receipt is successful.

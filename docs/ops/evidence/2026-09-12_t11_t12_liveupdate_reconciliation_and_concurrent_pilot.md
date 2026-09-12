# T11/T12 LiveUpdate reconciliation and one-shot concurrent pilot

Date: 2026-09-12 08:52–08:59 UTC  
Router task: `ad4eb945-d7d5-4d65-81e0-8d6763bcf5c1`

## Verdict

**REVIEW — LiveUpdate is reconciled and reversibly blocked at its write path,
but T11+T12 are not approved beside a saturated weekday fleet.** The one
authorized concurrent pilot completed with a valid T12 identity report but a
zero-trade T11 report. CPU reached a 99.9% five-sample mean on both seats.

## Root cause and documented control

`/skipupdate` prevents a new update check at launch. It does not suppress the
updater handoff when an earlier terminal session has already staged payloads.
The 09:36 local T12 journal records build 6182 being downloaded into its
SYSTEM-profile `liveupdate` directory; both 09:38 launches then start that
staged `terminal64.exe /update /path:<seat>` and exit without a test.

MetaTrader's own `origin.txt` binds the profile directories to the seats:

| Seat | Profile hash | `origin.txt` value |
|---|---|---|
| T11 | `F5D9412A6437C1548F3DA4241E8C78A6` | `D:\QM\mt5\T11` |
| T12 | `D033A12192D0AC53D574B7C2799994E6` | `D:\QM\mt5\T12` |

The pre-change receipt hashes three build-6182 payloads per seat: `mt5clw64.6182`
(`902aa4c5...97b412`), `mt5clwtst64.6182` (`706fa7dd...cce3f9`) and
`terminal64.exe` (`86c563c8...526ed`). MQL5 community guidance documents
revoking write access to LiveUpdate storage as the persistent, reversible
mechanism; it explicitly warns that this is a power-user permissions operation:
<https://www.mql5.com/en/forum/425911/page3>.

`tools/strategy_farm/manage_research_liveupdate_guard.ps1` implements that
control for T11/T12 only. It verifies the two exact roots and `origin.txt`
bindings, refuses while either seat is active or free RAM is below 12 GiB,
moves staged payloads to a named quarantine, creates an empty per-seat
`liveupdate` directory, and adds an explicit inheritable SYSTEM deny for
payload writes/deletes while retaining ACL administration rights. It never
enumerates or changes T1–T10, T_Live, or FTMO.

Current inspection is `GUARD_PRESENT`: zero pending payloads, both exact ACL
denies present, no whole-program firewall rule, and no T11/T12 process. The
rollback is explicit and bounded:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\manage_research_liveupdate_guard.ps1 -Mode Restore
```

Rollback removes only the two named ACL entries/rules and restores the two
quarantined directories after requiring empty destinations.

## Receipts before the pilot

| Receipt | Result | SHA-256 |
|---|---|---|
| `D:/QM/reports/research/AD4EB945_LIVEUPDATE_GUARD_20260912/20260912_085242_inspect.json` | 3 staged files/seat, no guard | `ea35c85d...078270` |
| `D:/QM/reports/research/AD4EB945_LIVEUPDATE_GUARD_20260912/20260912_085935_apply.json` | ACL control applied; firewall removed | `3b91dcbf...3ec985` |
| `D:/QM/reports/research/AD4EB945_LIVEUPDATE_GUARD_20260912/20260912_085949_inspect.json` | `GUARD_PRESENT`, 0 pending/seat | `2139b7b6...fa444b` |
| `D:/QM/reports/research/AD4EB945_DRYRUN_T11_20260912/20260912_085349_24dd9def/receipt.json` | `DRY_RUN_PASS`, handoff `CLEAR` | `dae36ce1...3fa16a` |
| `D:/QM/reports/research/AD4EB945_DRYRUN_T12_20260912/20260912_085349_8e5ddac1/receipt.json` | `DRY_RUN_PASS`, handoff `CLEAR` | `a8914a71...92957` |

The hash-bound inputs were identical on both seats: EX5
`68d37d3a...137c01`; setfile `afa42711...bf47c`, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `qm_news_stale_max_hours=336`. Immediate pre-pilot free
RAM was 23.73 GiB, above the 12 GiB abort boundary.

## Exactly one concurrent T11+T12 pilot

Both governed controllers began at 08:54:19–20 UTC with Model 4 and one local
agent. No retry was made.

| Metric | T11 | T12 |
|---|---:|---:|
| Status | `COMPLETED_REVIEW_REQUIRED` | `COMPLETED_REVIEW_REQUIRED` |
| Tester wall time | 45.531 s | 161.235 s |
| Admission CPU mean | 86.08% | 85.86% |
| Runtime CPU mean of five-sample means | 83.675% | 82.258% |
| Runtime CPU maximum five-sample mean | 99.90% | 99.90% |
| Minimum observed free RAM | 22.26 GiB | 22.34 GiB |
| Total net profit | 0 | 2,941.71 |
| Profit factor | 0.00 | 1.03 |
| Total trades | 0 | 208 |

T11 receipt:
`D:/QM/reports/research/AD4EB945_CONCURRENT_T11_20260912/20260912_085419_5c5872cb/receipt.json`
(SHA-256 `b80b2ee0...dcc66d`); native report SHA-256
`ee3e6960...6ea68`. T12 receipt:
`D:/QM/reports/research/AD4EB945_CONCURRENT_T12_20260912/20260912_085419_9624aaf7/receipt.json`
(SHA-256 `33dcc899...cef8e`); native report SHA-256
`eb1d3c9c...d48af`.

The first implementation used exact-program outbound blocks. The pilot
demonstrated why that was too broad: both journals record no trade-server
connection. T11 then logged `not synchronized with trade server` and returned
zero trades, while T12 completed from cached state and reproduced the accepted
identity metrics. Immediately after the one-shot pilot the firewall rules were
removed and replaced with the documented LiveUpdate-directory ACL control.
The final state therefore preserves normal terminal networking, but it was not
re-piloted because the task authorized exactly one concurrent pilot.

T12's isolation receipt notes one ordinary fleet row added during its 169-second
window (`148106 -> 148107`); worker PID and signed activation hashes were
unchanged, T12 remained absent from the T1–T10 activation, and the research
controller never claimed or wrote a farm row.

## Verification and weekday decision

- `python -m pytest tools/strategy_farm/tests/test_research_canary.py -q`:
  **42 passed**.
- `python -m py_compile tools/strategy_farm/research_canary.py`: PASS.
- Dry runs explicitly record `liveupdate_handoff.status=CLEAR` and zero pending
  files for both seats.
- Post-pilot process census: no T11/T12 terminal or tester process.
- No T_Live/FTMO, AutoTrading, factory claim, fleet process, or signed archive
  change.

**Weekday viability: NO.** The one-shot cell did not produce two valid results,
and both seats touched 99.9% CPU means. A later, separately authorized window
must test the final ACL-only control before either seat is scheduled alongside
a saturated weekday fleet.


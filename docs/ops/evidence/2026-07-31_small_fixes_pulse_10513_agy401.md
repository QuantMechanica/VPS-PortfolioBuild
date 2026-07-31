# Small fixes: pulse baseline state, QM5_10513 Q10 path, and Agy 401

Date: 2026-07-31  
Router task: `efaa2682-3f16-4966-b6e8-a9ea3b17c26c`  
Operator: Codex  
Disposition: ready for Claude review, with the requested QM5_10513 enqueue withheld because the current authenticated Q10 contract cannot be formed from the available evidence.

## 1. Live-book pulse dormant overcount

### Finding

`live_book_pulse.py` derived KS loader state from only the last 4 MiB of each EA log. On a noisy sleeve the loader event could age out while later log traffic remained, so an armed sleeve was reported dormant. The live QM5_10706 log is 27 MiB and demonstrates this condition.

The authoritative scan now streams every matching log line-by-line and retains only bounded per-sleeve state. A `KS_BASELINE_LOADED` or `KS_BASELINE_ABSENT` observation is associated with the same sleeve's successful initialization cycle; an incomplete/rejected initialization cannot replace the last confirmed state. The existing 4 MiB tail remains in use for unrelated pulse metrics.

Real-log verification after the change returned:

```text
10706|GBPUSD = KS_BASELINE_LOADED
timestamp    = 2026-07-31T20:56:08.921Z
sha256       = 5ca7599cd758921093333ff93c75c90226fdfee4f5de3165408a8cc91389fd1c
path         = QM\baselines\QM5_10706_GBPUSD.json
```

Commit: `18223a893` (`fix pulse baseline lifecycle scan`)

Verification:

```text
python -m pytest tools/strategy_farm/tests/test_live_book_pulse.py -q
15 passed
```

The regression suite includes a synthetic log larger than 4 MiB whose loader event occurs before the noise block.

## 2. QM5_10513 / XAUUSD Q10 re-confirmation path

### Existing current-binary evidence

The database already contains one completed individual Q10 row:

| Field | Value |
|---|---|
| work-item ID | `297c0127-7a8e-4bcd-bbbb-c4a57e823477` |
| phase / symbol | `Q10` / `XAUUSD.DWX` |
| status / verdict | `done` / `PASS` |
| aggregate | `D:\QM\reports\pipeline\QM5_10513\Q10\XAUUSD_DWX\aggregate.json` |
| native summary | `D:\QM\reports\pipeline\QM5_10513\20260725_163009\summary.json` |

The native runner evidence—not the later sealed-manifest alias—binds a provenance-clean execution identity:

| Identity | Evidence |
|---|---|
| current canonical EX5 | `C:\QM\repo\framework\EAs\QM5_10513_mql5-ichimoku\QM5_10513_mql5-ichimoku.ex5`; SHA-256 `04b62af28c6466e01741aacaa915d9a68714cd7c23288ae277615ae068d63898` |
| deployed EX5 during run | same SHA; `source_matches_deployed=true`, `stable_during_run=true` |
| tuned Q10 set | `...XAUUSD.DWX_D1_backtest_grid_008_q10_confirmation.set`; SHA-256 `e32be4b5c42f5e7fff60be1ba44e05314e970a2b84a3e99d1d89aadc11ef8202` |
| set deployment | same SHA; `source_matches_deployed=true`, `stable_during_run=true` |
| report | SHA-256 `3fc4e1c543e9086a664fa51305de8c7574c7af27b5d82854855618ade3eed7f3` |
| result | 104 trades, PF 1.98, DD 4.14037%, Q10 PASS |

The canonical EX5 and tuned set still hash to those exact values on 2026-07-31. This distinguishes the actual Q10 run from the documented sealed-manifest defect, which selected an older parameterless alias rather than the tuned `6/18/68/18` configuration.

### Why no new row was enqueued

The current canonical Q10 enqueue path is dependency-authenticated. It requires eligible `Q09_NEWS` and `Q09_PORTFOLIO` parents and a resulting locked contract. QM5_10513 has no `Q09_NEWS` work item. Its historical Q09 portfolio rows are either `NEED_MORE_DATA` or an old `PASS_PORTFOLIO` row whose cited aggregate is absent. Therefore the present farm cannot construct an executable Q10 item without bypassing the gate, fabricating evidence, or creating a permanently unclaimable row.

No MNT-007 wave was changed, no broad enqueue was used, and no staging baseline was deployed. The requested single enqueue is intentionally withheld: the existing row already supplies current-binary/tuned-set evidence, and a second row cannot satisfy today's Q10 contract. The safe follow-up is a separately routed Q09 lineage repair (or an explicit reviewer ruling that the existing native Q10 identity is sufficient), followed by the normal individual Q10 enqueue and `gen_q10_baseline` chain.

## 3. Agy quota HTTP 401

### Diagnosis

`agy_quota.py` reads Windows Credential Manager target `gemini:antigravity`. The scheduled task `QM_StrategyFarm_AgyGovernor` runs as SYSTEM but launches the governor inside the `qm-admin` console session, so the credential belongs to that user context. No credential value was printed or persisted during this investigation.

The quota receipt reports `token_expired=true` and expiry `2026-07-31T18:45:12.2842886+02:00`; the governor log then records HTTP 401 pulls. This is an expired interactive OAuth token, not a quota-limit result.

### Fail-safe correction

Credential/read/authentication failures now return structured, secret-free metadata. The governor treats unknown quota as conservative stop: it writes its owned `AGY_LOW_QUOTA.flag` with `reason=quota_unknown`, and stale reset timing cannot clear that gate. Only a later authenticated pull at or above the configured remaining-quota floor may clear an owned gate. An unrelated/unowned gate remains untouched.

Commit: `25255b76e` (`fix agy quota auth fail-safe`)

Verification:

```text
python -m pytest tools/strategy_farm/tests/test_agy_governor.py tools/strategy_farm/tests/test_mnt003_installer_alignment.py -q
8 passed
```

The first scheduled governor run after the commit naturally recorded at `2026-07-31T21:20:03Z`:

```text
GATE agy: quota unknown (token_expired) -> AGY_LOW_QUOTA.flag
```

The resulting flag is governor-owned with `reason=quota_unknown` and `failure_class=token_expired`. Codex did not manually run the governor or mutate the flag.

### OWNER refresh action

Reconnect to Windows session 1 as `qm-admin` and run `C:\Users\Administrator\AppData\Local\agy\bin\agy.exe models`; complete the browser OAuth flow if prompted. Then verify from that same user context with `python C:\QM\repo\tools\strategy_farm\agy_quota.py --json`; `ok` must be `true` before the governor may clear its gate.

## Guardrails observed

- No Factory task, process, wave, or flag was manually changed.
- No T_Live file was written and neither AutoTrading nor any terminal was started.
- No staging baseline was deployed.
- No credential value was read into evidence, logs, or the repository.
- Pipeline claims above come only from the existing Q10 aggregate and its hash-bound native runner evidence.

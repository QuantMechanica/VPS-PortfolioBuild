# Claude EA-review: QM5_35005 (sma-crossover-pullback-system)

- Review task: `954f01d5-652a-4d01-bf2b-0e243bf8955f`
- Build task: `da39e160-b043-4528-8592-4a23f672fc55` (source_agent=gemini, backend=agy)
- Prior review task (RECYCLE, 2026-08-21): `3281881e-4597-4243-9a2b-e8d7c4fa6360`
- Verdict: **REJECT_REWORK — remain in REVIEW; no pipeline handoff**

## Prior findings — source-level remediation check

The 2026-08-21 RECYCLE close cited 4 findings against the then-current `.mq5`
(SHA `deb2750e74c...`). The current `.mq5` (SHA
`758b0021667e9354415331c20dbee6389934813db590e3f837c242f4bac5be90`) resolves
all four at the source level:

1. **Untracked source/binary** — resolved. `.mq5`/`.ex5`/`SPEC.md` are
   committed in the canonical checkout (`git status --porcelain` clean).
2. **GMT rollover evaluated in broker time** — resolved. `Strategy_NoTradeFilter`
   now converts via `QM_BrokerToUTC(TimeCurrent())` before the 23:55-00:05
   window check (`.mq5:91-96`), matching the DST-aware helper pattern used
   elsewhere in the framework (`QM_NewsFilter.mqh`, `QM_Mod_FtmoJoint*`).
3. **Card loss limits not implemented** — resolved. `strategy_daily_loss_halt_pct`
   (2.0%) drives `StrategyDailyEntryHalt()`; `strategy_daily_hard_stop_pct`
   (2.5%) and `strategy_total_dd_halt_pct` (5.0%) are passed into the EA's own
   `QM_KillSwitchInit` call in `OnInit`, which overwrites
   `QM_FrameworkInit`'s internal generic 3.0%/0.0% defaults (plain global
   assignment in `QM_KillSwitch.mqh:477-494`, last call wins).
4. **Entry-only filters suspended trailing management** — resolved.
   `Strategy_ManageOpenPosition()` (trailing) now runs before
   `Strategy_NoTradeFilter()` in `OnTick` (`.mq5:255-282`), so rollover/spread
   halts no longer suspend protection of an open position.

Magic numbers: registry rows (350050000/1/2 for EURUSD/GBPUSD/EURJPY slots
0/1/2) match the `ea_id*10000+slot` formula and are each present exactly once
in the generated `QM_MagicResolver.mqh`. Setfiles for all 3 registered symbols
exist with `RISK_FIXED=1000`/`RISK_PERCENT=0`. `validate_build_guardrails.py`
on the EA dir: PASS, 0 findings (news-stale ceiling 336h respected). No raw
`iMA`/`iATR`/`iStoch`/bespoke-`IsNewBar` calls — uses pooled `QM_SMA`/`QM_Stoch_*`/
`QM_ATR`/`QM_IsNewBar`. No ML, no adaptive/PnL-conditioned parameters.

## New block finding: the reviewed EX5 was never recompiled against the fixed source

The build artifact (`artifacts/builds/da39e160-....json`) claims
`"compile_succeeded": true` at `"built_at": "2026-08-23T11:24:55Z"` — implying
a fresh compile of the remediated source. The filesystem disproves this:

| File | mtime (UTC) |
|---|---|
| `.mq5` (current, fixed source) | 2026-08-23T11:21:39Z |
| `.ex5` (current, on disk) | **2026-08-17T20:36:40Z** |

`D:\QM\reports\compile\QM5_35005_sma-crossover-pullback-system\result.json`
— the only compile record for this EA — is dated `2026-08-17T20:36:40Z` and
records `"mq5_mtime_utc": "2026-08-17T20:35:59+00:00"`, i.e. it compiled the
**pre-fix** source (the one the 08-21 RECYCLE was closed against), not the
current one. The on-disk `.ex5` SHA256
(`28ef9a97341ab09666f4b8ac6a817bbdabe806c968fbc96279a0e1be0b2fbd59`) is
byte-identical to the EX5 SHA already recorded in the 08-18/08-21 review
evidence — the binary has not changed since that compile. No compile log
newer than `20260817_203616` exists for this EA.

This is the stale-`.ex5` defect class from
`docs/ops/evidence` history (predicate must be build **date**, not a claimed
success flag or file size) — matches the 2026-08-17 "veraltetes .ex5 verwirft
gesunde backtests" incident. If this EA is dispatched to Q02 now, the tester
will exercise the **unpatched** binary: broker-time (not UTC) rollover
blackout and the framework's generic 3.0%/0.0% kill-switch thresholds instead
of the card's 2.0/2.5/5.0% limits — while the repo and this review would
appear to certify the fixed logic. Evidence-over-claims (Hard Rules) requires
treating the `"compile_succeeded": true` claim in the build artifact as
unverified/false until a compile record post-dates the current `.mq5` mtime.

## Rework directive

Recompile `QM5_35005_sma-crossover-pullback-system.mq5` via the canonical
`compile_ea.py` path (COMPILE_EA queue / OFF-window discipline per current
operating rules) and produce a fresh `result.json` /
`ex5_sha256` that differs from `28ef9a97...` (or whose `ex5_mtime_utc`
post-dates `2026-08-23T11:21:39Z`), then resubmit the build artifact for
review. Do not fanout to Q02 on the current `.ex5`.

## Independent verification commands run

- `certutil -hashfile *.mq5/*.ex5 SHA256` — matched build artifact's recorded
  hashes (the artifact's own hashes are internally consistent; the problem is
  they don't correspond to a compile event of that source).
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_35005_sma-crossover-pullback-system` — PASS.
- `grep 35005 framework/registry/magic_numbers.csv` — 3 active rows, slots 0/1/2.
- PowerShell `Get-Item` mtimes on `.mq5`/`.ex5`.

No registry, work-item, or pipeline state was changed by this review.

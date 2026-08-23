# Claude EA-review: QM5_36003 (nnfx-hull-ma-zerolag-macd-stc)

- Review task: `c8791ede-3188-4a25-8777-c755e0c71bd4`
- Build task: `019d50ff-a716-46a4-b097-c5c650dea63b` (source_agent=gemini, backend=agy)
- Prior review task (RECYCLE, 2026-08-21): `b4c223a0-818d-444d-bb7d-1336da8abdd2`
- Verdict: **REJECT_REWORK — remain in REVIEW; no pipeline handoff**

## Prior findings — source-level remediation check

The 2026-08-21 RECYCLE cited 6 findings against the then-current `.mq5`
(SHA `b9f28c34...`). The current `.mq5`
(SHA `197a2c09c011c443cfcbb61a0487c34b135a2d6923c06200d881321ca0895187`)
addresses all six at the source level:

1. **ZeroLag EMA formula wrong** — resolved. `Strategy_ZeroLagEMA` now builds
   the adjusted-price series `adj_prices[k] = 2*c - EMA(c, period)` over a
   40-bar lookback and applies a genuine second EMA recursion over that
   series (`.mq5:131-152`), matching the card's `EMA(Price + (Price -
   EMA(Price, period)), period)` definition — no longer a single-bar alpha
   update on one adjusted price.
2. **TP1 50% + runner collapsed to full-position TP** — resolved. Entry no
   longer attaches a broker TP (`req.tp = 0.0`); `Strategy_ManageOpenPosition`
   partial-closes 50% at +1 ATR via `QM_TM_PartialClose` and moves SL to
   breakeven, and `Strategy_ExitSignal` closes the runner only on the
   ZL-MACD/signal crossover (`.mq5:297-380`).
3. **Unauthorized 1.02 BetterVol=HIGH rule** — resolved. `Strategy_BetterVolumeHigh`
   now compares the current bar's tick volume against the mean of the
   following 20 closed bars with no injected multiplier (`.mq5:207-222`);
   current bar is correctly excluded from its own average.
4. **GMT rollover in broker time + missing loss limits** — resolved, same
   fix pattern as the sibling QM5_35005 review today: `QM_BrokerToUTC`
   conversion before the rollover check, and
   `strategy_daily_loss_halt_pct`/`daily_hard_stop_pct`/`total_dd_halt_pct`
   wired into `StrategyDailyEntryHalt` and the EA's own `QM_KillSwitchInit`
   call (overwrites `QM_FrameworkInit`'s generic 3.0%/0.0% defaults).
5. **Strict build check FAIL on raw `iClose`** — annotations added
   (`// perf-allowed: closed-bar ... behind QM_IsNewBar()`) on every raw
   `iClose`/`iTickVolume` call. Could not independently re-run
   `build_check.ps1 -SkipCompile` to confirm the checker accepts this form —
   it fail-closed with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` (terminal64
   processes alive; ad-hoc compile is correctly blocked while the factory is
   live). Not re-verified mechanically; flagged as unconfirmed rather than
   resolved.
6. **Entry-only filters suspended runner exit** — resolved.
   `Strategy_ManageOpenPosition()` and the `Strategy_ExitSignal()` close loop
   both run before `Strategy_NoTradeFilter()` in `OnTick` (`.mq5:439-472`).

Magic numbers (360030000/1/2, EURUSD/GBPUSD/XAUUSD slots 0/1/2) match
`ea_id*10000+slot`, each present exactly once in `QM_MagicResolver.mqh`.
`target_symbols` in the card (3) equals `symbols_registered` (3) — P2
saturation satisfied. Setfiles for all 3 symbols carry `RISK_FIXED=1000`/
`RISK_PERCENT=0`. `validate_build_guardrails.py`: PASS, 0 findings
(336h news ceiling respected). No ML, no adaptive/PnL-conditioned parameters.

## Same block finding as QM5_35005 (today): EX5 never recompiled against the fixed source

| File | mtime (UTC) |
|---|---|
| `.mq5` (current, fixed source) | 2026-08-23T11:29:07Z |
| `.ex5` (current, on disk) | **2026-08-17T21:06:48Z** |

`D:\QM\reports\compile\QM5_36003_nnfx-hull-ma-zerolag-macd-stc\result.json`
is the only compile record for this EA, dated `2026-08-17T21:06:49Z`,
`mq5_mtime_utc: 2026-08-17T21:06:02Z` — the **pre-fix** source (the one the
08-21 RECYCLE was closed against). The on-disk `.ex5` SHA256
(`baffb41f8b8af18990919b622acf8c27d5c98a4543dc2c9160f7b020a1a3be47`) is
unchanged since that compile — identical to the SHA already recorded in the
08-18/08-21 review evidence.

This is the same systemic defect found minutes earlier reviewing QM5_35005
(same build task pattern: `SOURCE_READY_REMEDIATED ... ready for codex
review`, `built_at` stamped fresh, `compile_succeeded: true` claimed, but no
compile actually run). Two-for-two on the gemini remediation path today —
worth a root-cause look at whatever step is supposed to invoke
`compile_ea.py`/`farmctl.py enqueue-compile` after a source edit; it is not
firing. Evidence-over-claims requires treating `"compile_succeeded": true`
as unverified/false until a compile record post-dates the current `.mq5`
mtime. Dispatching to Q02 now would test the pre-fix binary (wrong ZeroLag
EMA formula, collapsed TP1/runner, unauthorized volume rule, broker-time
rollover, missing loss limits) while the repo shows remediated source.

## Rework directive

Recompile `QM5_36003_nnfx-hull-ma-zerolag-macd-stc.mq5` via
`python tools/strategy_farm/farmctl.py enqueue-compile <label>` (governed
queue; ad-hoc compile is correctly refused while the factory is live) and
produce a fresh `result.json`/`ex5_sha256` differing from `baffb41f8...`
(or `ex5_mtime_utc` post-dating `2026-08-23T11:29:07Z`), then resubmit for
review — at which point item 5 (strict build check) should also be
re-verified live.

No registry, work-item, or pipeline state was changed by this review.

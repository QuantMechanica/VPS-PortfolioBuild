# Independent `review_ea` — QM5_11537 Carter H1 EMA/BB/RSI

- Task: `a91ce051-fe84-4156-a3fb-0f566aca2365`
- EA: `QM5_11537_carter-t-h1-ema5s5-ema75-bb-rsi`
- Reviewer: Codex
- Review date: 2026-08-21
- Verdict: **CHANGES_REQUIRED — keep in REVIEW; no pipeline handoff**

This is an independent review of the approved card and canonical build, not a
rubber-stamp of the earlier build-task verdict for
`985081a7-3fe8-4012-a6d6-a0dea7d47db2`.

## Blocking finding

### The H1 runtime contract is undeclared

The mechanism reads H1 close/EMA75/Bollinger-middle/RSI values
(`.mq5:100-103`), but the entry gate is the no-argument `QM_IsNewBar()`
(`.mq5:244`), which follows the attached chart. `OnInit` calls legacy
`QM_FrameworkInit` and returns success (`.mq5:174-195`) without calling
`QM_FrameworkDeclareExecutionContract(PERIOD_H1, ...)`. A wrong-period chart can
therefore evaluate the same closed H1 state on the wrong cadence instead of
failing at init. The current framework's Card-v2 contract supplies the required
fail-closed timeframe and explicit Friday-close declaration
(`QM_Common.mqh:442-489`).

Required repair: declare the H1 execution contract and the card's Friday-close
mode, recompile, refresh the set build hashes, commit the exact build identity,
and return it for review.

## Checks that passed

- Card fidelity otherwise passes. The EA implements close above/below EMA75 and
  the Bollinger middle with RSI14 above/below 50 (`.mq5:100-108`), a five-bar
  swing stop capped at 40 pips (`.mq5:118-139`), a 2R target, one position per
  magic, 15-pip entry spread cap, and no-Friday entry. Omitting EMA(5,shift5) as
  an entry input is consistent with the card's explicit P2 simplification.
- All 23 framework/strategy inputs have a non-declaration use. The one caveat is
  informational: `strategy_bb_deviation` is passed to `QM_BB_Middle`, but the
  Bollinger middle is mathematically independent of deviation. The card's later
  2.0/2.5 P3 sweep is therefore a no-op and must not be presented as sensitivity
  evidence.
- Registry rows are unique and active: EURUSD.DWX slot 0 is `115370000` and
  GBPUSD.DWX slot 1 is `115370001`, exactly `11537*10000+slot`. Both occur once
  in the registry/resolver; requests propagate `qm_magic_slot_offset`
  (`.mq5:148`).
- Both tracked, clean H1 backtest sets use `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  and the correct slot (0/1). Each carries a 64-hex build-hash header.
- The approved card contains no explicit daily-loss or total-drawdown hard-stop
  label, so the legacy framework `3.0/0.0` defaults do not replace a card-stated
  limit. The 40-pip SL is implemented separately.
- The only strategy calendar rule uses `TimeCurrent()` broker time for Friday
  (`.mq5:91-95`); there is no hardcoded GMT/DST conversion. The framework Friday
  close is broker hour 21.
- `qm_news_stale_max_hours` is 336, and `validate_build_guardrails.py` returned
  PASS with no findings. Focused scan found no direct indicator handles,
  `CopyBuffer`, raw `OrderSend`, DLL/ML calls, or blocking `Sleep`.
- The pre-management spread return does not suppress a custom strategy exit in
  this EA: `Strategy_ManageOpenPosition` is empty and `Strategy_ExitSignal`
  returns false; every position is protected by server-side SL/TP and the
  framework Friday close runs first.

## Build verification

- Canonical source SHA-256:
  `9797890d9f32e5cbd28f994565d0c2c2a031427add1f75e147618d68b987b39a`
- Canonical EX5 SHA-256:
  `5be000517de4d42f4f124447d8275dc0c1b509cea2b91b1fa5bc69f9856ad3c3`
- Non-mutating current-tree static check (`-SkipCompile -SkipSetValidation`):
  PASS, 0 failures, 0 warnings; report
  `D:\QM\reports\framework\21\codex_review_20260821_11537\build_check_20260821_090058.json`.
- Full strict check in a disposable checkout: compile PASS, 0 errors, 0 warnings;
  build check PASS, 0 failures, 0 warnings. Reports:
  `D:\QM\reports\compile\20260821_090646\summary.csv` and
  `D:\QM\reports\framework\21\codex_review_20260821_11537_full_scratch\build_check_20260821_090646.json`.

The current strict static gate does not detect the missing execution declaration,
so its PASS does not override the semantic finding. The producer's governed smoke
was deferred; no smoke, Q-phase, live, or profitability verdict is inferred.

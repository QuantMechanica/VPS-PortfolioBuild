# Independent `review_ea` — QM5_11533 Carter H1 ribbon

- Task: `e70b7248-0abd-4e9d-9683-95297a51ff58`
- EA: `QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21`
- Reviewer: Codex
- Review date: 2026-08-21
- Verdict: **CHANGES_REQUIRED — keep in REVIEW; no pipeline handoff**

This is an independent review of the approved card and the canonical build, not
acceptance of the earlier `APPROVED_WITH_INFO` verdict on build task
`abfb4871-b012-4a57-b800-47e73a63e647`.

## Blocking findings

### 1. The spread entry filter can suppress the card's indicator exit

The card and `SPEC.md` define the 15-pip spread cap as a fresh-entry filter, while
the reverse EMA3/EMA5 state or RSI(21) crossing 50 is the position exit. In the EA,
`Strategy_NoTradeFilter()` returns true on an invalid quote or excessive spread
(`.mq5:57-68`). `OnTick` returns on that result at line 216, before
`Strategy_ExitSignal()` is evaluated at lines 220-230. An existing position can
therefore remain open through a valid indicator exit until the spread/quote guard
clears. The broker-side 25-pip SL remains attached, but that does not make the
card's indicator exit optional.

Required repair: make the quote/spread condition entry-only, or otherwise prove
that it cannot pre-empt management and strategy exits.

### 2. The H1 runtime contract is undeclared

The signals read `PERIOD_H1` (`.mq5:75-82,94-101,179-181`), but the bar gate is
the no-argument `QM_IsNewBar()` (`.mq5:239`), which follows the attached chart.
`OnInit` calls legacy `QM_FrameworkInit` and returns success (`.mq5:196-203`)
without `QM_FrameworkDeclareExecutionContract(PERIOD_H1, ...)`. A wrong-period
attachment therefore changes the evaluation cadence instead of failing at init.
The current framework's Card-v2 contract explicitly provides the fail-closed
timeframe and Friday-mode check (`QM_Common.mqh:442-489`).

Required repair: declare and enforce the H1 execution contract, with the card's
Friday-close mode stated explicitly, then compile again.

### 3. The approved card's medium-cross rule is not implemented exactly

The card concept says both fast EMAs cross EMA13 and EMA21, and its implementation
note says to check bars 1 and 2. The EA detects only the EMA3/EMA5 cross with
bar-1/bar-2 values (`.mq5:84,103`). Its medium conditions compare bar-1 values for
alignment beyond EMA13/EMA21 (`.mq5:85-87,104-106`); they do not detect a cross of
either medium EMA. The card's short bullet is itself abbreviated/asymmetric, but
that ambiguity is not a durable authorization to replace the explicit cross rule
with a state filter.

Required repair: obtain a corrected approved-card clarification or implement the
specified bar-1/bar-2 medium-cross behavior. Do not silently retain a nearby
ribbon-alignment idea.

### 4. The canonical set is not bound to a committed build identity

The only set file is tracked and clean, and its runtime values are correct, but
its header still says `build_hash: pending` (`...EURUSD.DWX_H1_backtest.set:13`).
The review-dispatch identity contract requires a 64-hex build hash. A full strict
checker run in a disposable checkout normalized the scratch copy and passed; that
does not bind the untouched canonical set. The canonical EA/set paths were left
unchanged by this review.

Required repair: after the source fixes, run the canonical build path so the EX5
and set hash are refreshed together, then commit the exact build paths before a
new review.

## Checks that passed

- All 23 framework/strategy inputs have at least one non-declaration use. The
  strategy defaults match the card: EMA 3/5/13/21/80, RSI 21/50, SL 25 pips,
  spread cap 15 pips.
- Registry binding is unique and active: EURUSD.DWX slot 0 resolves to
  `115330000 = 11533*10000+0`; the generated resolver contains that magic once.
  The request propagates `qm_magic_slot_offset` (`.mq5:144`).
- The backtest set uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and slot 0. The EA's
  stale-news ceiling is exactly 336 hours, and `validate_build_guardrails.py`
  returned PASS with no findings.
- The approved card contains no explicit daily-loss or total-drawdown hard-stop
  label. Consequently the legacy framework `3.0/0.0` kill-switch defaults do not
  override a card-stated value. `expected_dd_pct: 18.0` is an expectation, not a
  loss-limit contract.
- The only strategy calendar rule is no-Friday-entry and it uses `TimeCurrent()`
  broker time (`.mq5:124-127`); there is no raw GMT/DST offset.
- Focused scan found no direct indicator handles, `CopyBuffer`, raw `OrderSend`,
  DLL/ML calls, or blocking `Sleep`.

## Build verification

- Canonical source SHA-256:
  `e4a21d6e023af2d22dd3cb956b1d39428934703dee8716eb0f907f8339735de1`
- Canonical EX5 SHA-256:
  `1d0b8e7fb1dda4734c1f357590a783f8288c23e93cb48624efa273313b3722cd`
- Non-mutating current-tree static check (`-SkipCompile -SkipSetValidation`):
  PASS, 0 failures, 0 warnings; report
  `D:\QM\reports\framework\21\codex_review_20260821_11533\build_check_20260821_090058.json`.
- Full strict check in a disposable checkout: compile PASS, 0 errors, 0 warnings;
  build check PASS, 0 failures, 0 warnings. Reports:
  `D:\QM\reports\compile\20260821_090735\summary.csv` and
  `D:\QM\reports\framework\21\codex_review_20260821_11533_full_scratch\build_check_20260821_090735.json`.

The strict gate currently does not detect findings 1-3, and its normal set
validation mutates `build_hash`; its PASS is therefore necessary but not
sufficient for acceptance of the canonical build. No smoke, Q-phase, live, or
profitability verdict is inferred.

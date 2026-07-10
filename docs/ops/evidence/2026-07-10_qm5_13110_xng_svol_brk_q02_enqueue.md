# QM5_13110 XNG Source-Seasonal Volatility Q02 Enqueue

Date: 2026-07-10  
Branch: `agents/board-advisor`

## Outcome

One new structural natural-gas sleeve was carded, built, compiled, and
enqueued:

- EA: `QM5_13110_xng-svol-brk`.
- Signal: once-weekly `XNGUSD.DWX` H4 close beyond the prior completed D1
  range during May-September or November-January; symmetric long/short.
- Q02 work item: `a4e141ed-3058-4964-944e-1c0520b527e2`.
- Handoff: pending, unclaimed, `XNGUSD.DWX`, H4.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Magic: `131100000`, slot 0.

No manual MT5 run was launched. The CPU guard found active path-anchored,
non-live terminal runs on T1, T3, T4, and T6; paced terminal workers covered
T1, T2, T3, T4, T6, T7, and T8. The build therefore used
`deferred_p2_smoke` and handed the setfile to Q02 without competing with the
factory or FTMO refresh.

## Source And Mechanization

Primary source: Suenaga, Hiroaki; Smith, Aaron; and Williams, Jeffrey C.
(2008), "Volatility Dynamics of NYMEX Natural Gas Futures Prices,"
*Journal of Futures Markets* 28(5), 438-463, DOI
https://doi.org/10.1002/fut.20317. Author-hosted full paper:
https://files.asmith.ucdavis.edu/2008_JFutMkt_SSW_NGfutures.pdf.

The full 26-page paper was reviewed. It identifies materially seasonal
natural-gas volatility linked to demand, storage, and time to maturity,
including broad increases from early May through late September and early
November through mid-January.

The source assumes martingale daily price changes in its hedge derivation and
does not publish a directional alpha rule. The card therefore uses the calendar
only as a volatility regime: a completed H4 close beyond the prior D1 range
discovers direction. It permits one accepted entry per week, places a structural
stop beyond the opposite D1 extreme, targets 1.75R, and exits after 36 hours,
outside the source months, or through framework Friday close. No POTS/GARCH/
Kalman model or external runtime data is used.

## Non-Duplicate Decision

Repository dedup returned CLEAN before allocating QM5_13110. Manual content
review also separated the edge from:

- `QM5_12567`: cumulative-RSI2 pullback;
- `QM5_12586`: winter D1 30-bar Donchian plus SMA;
- `QM5_12588`: summer long-only squeeze/20-bar channel;
- `QM5_12817`: multi-day volatility-shock fade;
- `QM5_13101`: five-day continuation in low volatility;
- `QM5_13104`: compressed-Friday, Monday-only expansion;
- `QM5_13105`: inside/NR4 breakout.

The new build is source-window high-volatility range expansion, symmetric,
prior-D1 referenced, H4 close-confirmed, and weekly gated. It is not a parameter
variant of those families. Portfolio orthogonality is intentionally unclaimed;
only a surviving Q09 return stream may establish it.

## Build Evidence

- Card of record: `strategy-seeds/cards/xng-svol-brk_card.md`.
- Source packet: `strategy-seeds/sources/SUENAGA-XNG-SEASVOL-2008/source.md`.
- EA source, binary, setfile, SPEC, and build-time card:
  `framework/EAs/QM5_13110_xng-svol-brk/`.
- Build record: `artifacts/qm5_13110_build_result.json`.
- Enqueue record: `artifacts/qm5_13110_q02_enqueue_20260710.json`.

Verification:

- Directory-first EA-ID allocation: QM5_13110.
- Research dedup: CLEAN.
- Card schema lint and G0 lint: PASS.
- SPEC validation: PASS.
- Symbol scope: `SINGLE_SYMBOL_OK`, zero violations.
- Magic resolver: `131100000` present after regeneration.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, Friday close enabled.
- Q02 enqueue: one pending row, zero skipped.

Resolver generation repeated three pre-existing missing-directory warnings for
EA IDs 1001, 1015, and 1016. None was caused or repaired by QM5_13110.

## Guardrails

- No `T_Live` file or process action.
- No AutoTrading action.
- No live setfile or deploy manifest.
- No portfolio gate, admission, KPI, or correlation-code change.
- Existing unrelated dirty FTMO/Q08 paths were left untouched.


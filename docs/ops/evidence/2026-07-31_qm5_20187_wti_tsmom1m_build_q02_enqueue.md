# QM5_20187 WTI one-month TSMOM — build and Q02 enqueue

Date: 2026-07-31 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency energy candidate was carded, registered,
built, strictly compiled, and handed to the paced Q02 pipeline. On the first
tradable D1 bar of each broker month, `QM5_20187_wti-tsmom1m` trades the sign
of XTI's immediately preceding completed broker-calendar-month return and
holds to the next month boundary.

This is a Q02 research candidate, not a certified portfolio admission. No
profitability, decorrelation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source and claim boundary

The primary source is Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. Sections 3.1-3.2 define own-return-sign
time-series momentum; Table 2 Panel B reports the commodity-futures `k=1`,
`h=1` result; Appendix A.4 includes NYMEX WTI in the commodity universe.

The complete 23-page read and retrieval evidence are preserved under
`strategy-seeds/sources/MOP-TSMOM-2012/`. The retrieved author-hosted PDF has
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper tests a pooled futures universe with futures excess returns and
inverse-volatility scaling. It does not test Darwinex `XTIUSD.DWX`, the QM
close-to-close CFD translation, fixed cash risk, the ATR disaster stop, or
portfolio correlation. Those are explicit Q02/Q09 hypotheses.

## Non-duplicate boundary

Before ID allocation, the deterministic research check found no exact slug or
strategy-ID collision. Manual semantic review separated this mechanic from:

- existing WTI own-trend horizons at 2, 3, 6, 9, and 12 months;
- `QM5_12709` one-month cross-sectional commodity reversal, which ranks a
  four-symbol basket and trades the opposite cross-sectional direction;
- `QM5_13150` twelve-month sign-count momentum;
- `QM5_13100` the 1/6-month price-mean rule;
- `QM5_20008` the three-month channel breakout; and
- `QM5_12567` the cumulative-RSI commodity pullback.

The absent fingerprint was a single-symbol WTI rule using exactly one
completed calendar month, its own return sign, symmetric direction, and a
one-month hold. Realized correlation remains an unchanged Q09 portfolio-gate
question.

## Frozen baseline

- Host/timeframe: exact `XTIUSD.DWX`, D1
- Identity: EA ID `20187`, slot `0`, magic `201870000`
- Decision clock: first tradable D1 bar of each broker month
- Signal: log of latest completed month-end close divided by the preceding
  completed month-end close
- Direction: positive buy, negative sell, exact zero/invalid history flat
- Lifecycle: close the prior package at the month boundary; 40-calendar-day
  stale guard
- Protection: frozen `3.5 * ATR(20)` hard stop; no take-profit or trailing
- Entry spread ceiling: 1,500 points
- Attempt state: persist broker `YYYYMM` before fallible entry gates; no retry
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- News axes: OFF; Friday close: OFF

Only the locked backtest setfile was created. There is no live setfile,
parameter sweep, external runtime signal, grid, martingale, scale-in, or
pyramiding.

## Build evidence

- Card-schema lint: PASS, no missing sections and no ML hits
- G0 card lint: PASS
- Seven-section SPEC validation: PASS
- Build prerequisite guard: PASS
- V5 guardrails: PASS
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings
- P1 artifact validation: PASS
- V5 strict build check: PASS, 0 failures, 0 warnings
- Compile log:
  `C:/QM/repo/framework/build/compile/20260731_153245/QM5_20187_wti-tsmom1m.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260731_153245.json`
- MQ5 SHA-256:
  `C19AD270C93FBD648ADA444A3A07EBCD74BBA40FDE2C9DE28BFFD314535AA82D`
- EX5 SHA-256:
  `16AA43E4A038ED8116B2218205ADB39978E9EFECF014C61596A4A2A487BB73BE`
- Setfile header build hash:
  `529e5729e51d23dd9e4fc102776600c722992becc0a97ca949a8cf158a8f5f02`
- Resolver registry hash:
  `BE2DE54779F8D2612B8E782373B687C124D5E7AE52A0D9D43F6BDB825D452FAA`
- Build commit: `254bc8328`

## Paced Q02 handoff

The pre-mutation path-anchored process scan found three T1-T10 factory tester
processes, below the documented seven-process CPU ceiling. `T_Live` was
excluded by path and was not touched.

The scoped dry-run and applied sweep used `--ea QM5_20187`,
`--symbols XTIUSD.DWX`, and `--max-part2-per-run 0`. Each reported exactly one
eligible/enqueued Q02 row, zero stranded retries, and zero deferred
promotions.

- Work item: `402dc257-b6bc-4ad5-b359-2156441513f0`
- Phase/status after insertion: `Q02` / `pending`
- Attempt count: `0`
- Claim state: unclaimed
- Symbol: `XTIUSD.DWX`
- Setfile: `QM5_20187_wti-tsmom1m_XTIUSD.DWX_D1_backtest.set`
- Read-only recheck: exactly one work item exists for `QM5_20187`

No manual tester, smoke run, dispatch tick, or pipeline phase runner was
started. The normal paced workers own execution.

## Safety boundary

No `T_Live` file or manifest, AutoTrading state, deploy manifest, portfolio
gate, or portfolio admission record was touched.

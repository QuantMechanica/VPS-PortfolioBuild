# QM5_20136 WTI same-calendar trend agreement — build and Q02 enqueue

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20136_wti-caltrend`

Strategy ID: `KELOHARJU-MOP-WTI-CALTREND-2026_S01`

## Outcome

One new low-frequency structural WTI candidate was carded, registered, built,
strictly compiled, and handed to the paced pipeline. On the first tradable D1
bar of each broker month, it estimates WTI's historical return sign for that
same calendar month over up to ten prior years and compares it with WTI's
completed 63-D1 return sign. It trades only when the two non-zero signs agree.

This is a Q02 research candidate, not a certified portfolio admission. No
profitability, decorrelation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source And Claim Boundary

The approved composite source packet preserves two existing, completely read
repository lineages:

- Keloharju, Linnainmaa, and Nyberg (2016), a peer-reviewed *Journal of
  Finance* paper with a complete NBER working paper, supplies recurring
  same-calendar-month return information and explicitly includes crude oil.
- Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of Financial
  Economics* paper, supplies the instrument-own trailing-return-sign
  time-series-momentum mechanic.

Neither paper tests their conjunction, the Darwinex continuous WTI CFD,
monthly fixed-risk renewal, the ATR stop, or QM portfolio behavior. Those are
explicit QM hypotheses. This work imported no new web claim. Runtime reads no
external feed, inventory, futures curve, COT, volume, open interest, analyst
forecast, CSV, API, or ML output.

## Non-Duplicate Boundary

Before allocation, the deterministic check scanned 4,193 EA-registry rows and
376 research cards and returned CLEAN. Manual semantic review resolved the
closest candidates:

- `QM5_20099_wti-samecal` trades the historical seasonal state alone.
- `QM5_20055_wti-tsmom3m` trades the completed 63-D1 trend state alone.
- `QM5_20135_wti-winter-trend` uses a fixed November-May window and a 252-D1
  trend; it never estimates prior matching-calendar returns.
- `QM5_13115_energy-samecal` ranks WTI against XNG in a two-leg basket.
- `QM5_12576_eia-wti-season` uses fixed demand months, SMA(84), and 21-D1 ROC.
- `QM5_12983_wti-tom-mom` trades a turn-of-month timing window.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The load-bearing new state is the predeclared agreement of WTI's adaptive
prior-year same-calendar sign and its completed 63-D1 trend sign. Removing
either component recreates an already-built parent mechanic. Realized
correlation remains a downstream Q09 and unchanged portfolio-gate question.

## Frozen Baseline

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `201360000`
- Decision clock: first tradable D1 bar of each broker month
- Seasonal state: mean of up to ten prior completed same-calendar-month WTI
  log returns; at least five valid samples
- Trend state: completed 63-D1 WTI log-return sign
- Direction: buy only when both states are positive; sell only when both are
  negative; disagreement, zero, or invalid state remains flat
- Lifecycle: close before monthly renewal; 35-day stale exit
- Risk control: frozen `3.5 * ATR(20)` hard stop; no take-profit or trailing
- Entry spread ceiling: 1,500 points
- Attempt state: persist broker `YYYYMM` before fallible gates; no retry
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF; Friday close: OFF

Only the locked baseline setfile was created. There is no parameter sweep,
live setfile, external signal, grid, martingale, scale-in, or pyramiding.

## Deterministic Identity And Hashes

- EA registry:
  `20136,wti-caltrend,KELOHARJU-MOP-WTI-CALTREND-2026_S01`
- Magic registry:
  `20136,wti-caltrend,0,XTIUSD.DWX,201360000`
- Card SHA-256:
  `477C7B7A0E044DB9B402C688CEFF66C04307DC6900403F6141390DC18F10C7A6`
- Source packet SHA-256:
  `311CDB1B5EC735D61CF4AC3D990E471D07C40CD992141B5B9BC097EB2821A45A`
- MQ5 SHA-256:
  `699B1EFAD359A794AD0298C8F8D98050D20021E6237CAB21F2991B8516FB06EA`
- EX5 SHA-256:
  `6B3659DFD0CFE94CC63EE556DCD330D3DD4910291D644B91B3F56DC5401AE8B4`
- SPEC SHA-256:
  `E7AAE5C8CFDDADA72F463D71FE63077E211AA4C7C2F485CF2D65FB2D91CF568B`
- Setfile SHA-256:
  `596542225C0E9F219DBB369DFD05B4155A1166A6612D74EBCA40500A8C5A9E87`
- EA-ID registry SHA-256:
  `5509737C737D5AFE5D63371C26AD85F503035E9EB48930B8095EF2A2F6A63E33`
- Magic registry SHA-256:
  `4AA41E92E4B1DE711CC12048DBA42EAE7EC3EF88B6F15BB9512276A08DC05696`
- Generated resolver SHA-256:
  `D47E7E8CDDF6674BF9A65554C01C482E7ADCF0D64F736D41AB4DE5F84B211B74`

The resolver was regenerated from the canonical registry after the EA
directory and magic row existed. Generated magic `201360000` was verified.

## Validation Evidence

- Strategy-card schema lint: PASS, no missing sections and no ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build guard: PASS; approved card, EA registry, magic registry,
  exact folder, and exact slug agree.
- Candidate registry validation: PASS; one EA-ID row, one slot row, correct
  formula magic, and no collision for `201360000`.
- V5 build guardrails: PASS.
- V5 strict build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_044238/QM5_20136_wti-caltrend.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_044238.json`

No manual smoke test or pipeline runner was started.

## Paced Q02 Handoff

- Build task: `23cb27a1-f8ce-4772-bea5-607597baebb9`, status `done`
- Q02 work item: `1dc49254-5e14-401c-b2cb-440d98817ff4`
- Phase/status: `Q02` / `pending`
- Attempt count: 0
- Claimed by: none
- Created: `2026-07-25T04:45:06+00:00`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Setfile:
  `QM5_20136_wti-caltrend_XTIUSD.DWX_D1_backtest.set`
- Initial auto-enqueue: exactly 1 enqueued, 0 skipped
- Read-only database recheck: exactly one Q02 row for this EA/build

At enqueue time `D:/QM/strategy_farm/state/FACTORY_OFF.flag` was present and
the farm reported no pipeline MT5 terminal. The only observed terminal process
was the pre-existing live terminal; it was not touched. Manual backtest CPU use
was zero, so the backtest CPU ceiling was not hit.

AutoTrading, the portfolio gate, the T_Live manifest, and all T_Live files
were not touched.

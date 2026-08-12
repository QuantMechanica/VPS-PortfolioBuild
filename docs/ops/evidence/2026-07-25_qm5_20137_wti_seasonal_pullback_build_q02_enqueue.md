# QM5_20137 WTI seasonal pullback — build and Q02 enqueue

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20137_wti-seas-pb`

Strategy ID: `KELOHARJU-YANG-WTI-SEASPULL-2026_S01`

## Outcome

One new low-frequency structural WTI candidate was carded, registered, built,
strictly compiled, and handed to the paced pipeline. On the first tradable D1
bar of each broker month, it estimates WTI's historical return sign for that
same calendar month over up to ten prior years and reconstructs the exact
immediately completed broker-month return. It follows the seasonal direction
only when the two non-zero signs disagree.

This is a Q02 research candidate, not a certified portfolio admission. No
profitability, decorrelation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source And Claim Boundary

The approved composite source packet preserves two existing, completely read
repository lineages:

- Keloharju, Linnainmaa, and Nyberg (2016), a peer-reviewed *Journal of
  Finance* paper with a complete NBER working paper, supplies recurring
  same-calendar-month return information and explicitly includes crude oil.
- Yang, Goncu, and Pantelous (2017) supplies governed academic
  commodity-futures momentum/reversal lineage.

Neither source tests the interaction, the Darwinex continuous WTI CFD,
monthly fixed-risk renewal, the ATR stop, or QM portfolio behavior. Those are
explicit QM hypotheses. No new web claim was imported. Runtime reads no
external feed, inventory, futures curve, COT, volume, open interest, analyst
forecast, CSV, API, or trained output.

## Non-Duplicate Boundary

Before allocation, the deterministic helper scanned 4,194 EA-registry rows
and 376 research cards and returned CLEAN. Manual semantic review resolved the
closest candidates:

- `QM5_20099_wti-samecal` follows the historical seasonal sign without a
  counter-move gate.
- `QM5_20136_wti-caltrend` requires agreement with a completed 63-D1 return;
  the new edge requires disagreement with the exact completed broker month.
- `QM5_12709_commodity-reversal-1m` ranks four commodities into a paired
  winner/loser basket and has no month-of-year estimator.
- `QM5_12594_yang-wti-reversal` uses a weekly medium-horizon overextension
  fade toward an SMA.
- `QM5_20047_wti-mon-loss-bnc` is a one-session Tuesday bounce after a Monday
  loss.
- `QM5_13120_energy-momrev` is an XTI/XNG 12/18-month opposite-rank package.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The load-bearing information object is the conjunction of WTI's adaptive
prior-year same-calendar sign and the exact immediately completed
broker-month return having the opposite sign. Removing the counter-move gate
recreates the unconditional seasonal parent. Replacing it with
medium-horizon agreement recreates the neighboring trend-confirmation object.
Realized correlation remains a downstream Q09 and unchanged portfolio-gate
question.

## Frozen Baseline

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `201370000`
- Decision clock: first tradable D1 bar of each broker month
- Seasonal state: mean of up to ten prior completed same-calendar-month WTI
  log returns; at least five valid samples
- Pullback state: exact immediately completed broker-month log return,
  reconstructed from two consecutive completed month-end closes
- Direction: buy only for positive seasonal/negative pullback; sell only for
  negative seasonal/positive pullback; alignment, zero, or invalid state stays
  flat
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
  `20137,wti-seas-pb,KELOHARJU-YANG-WTI-SEASPULL-2026_S01`
- Magic registry:
  `20137,wti-seas-pb,0,XTIUSD.DWX,201370000`
- Card SHA-256:
  `7BA8B3ED293E4C827C0C7ED2E060FB0C9C993023EABE7AB3D082CAC3FB756874`
- Source packet SHA-256:
  `29F0E8AF6FCA5BF7F36EE2177FC70162D602E9E573BFB6637FCDE48C8257A916`
- MQ5 SHA-256:
  `47CE5BBEEDF40B4163F08C771DE738750AB837B78ADA4825CEFCE48A54F7C5D5`
- EX5 SHA-256:
  `035A3ED0ADE1F0980E22BA9880676CD3BFA08FEF2733B21D220F04A4CD4A4453`
- SPEC SHA-256:
  `32230D48189AE5B4EBEC4B62FA6333F4B80BBB10FD2321A0FB4B509B1EEFABC9`
- Setfile SHA-256:
  `7895EE51A9E73FFC50488677697F01CA9F0359D248B570C2DE9E19F808F75CCA`
- EA-ID registry SHA-256:
  `129AB15E10AE087B40317E467C93266F624F300A1D560FD7D7E769890E194FE3`
- Magic registry SHA-256:
  `62FD46F57E183489729201327CC34AEEBB54EB8B5105511C95080E42220D4FE5`
- Generated resolver SHA-256:
  `FEF1461E8A65DDF734BBB96B6F7D98E2D605A7D3F0F907D31E1C537424A174EB`

The resolver was regenerated from the canonical registry after the EA
directory and magic row existed. Generated magic `201370000` was verified.

## Validation Evidence

- Strategy-card schema lint: PASS, no missing sections and no forbidden
  library hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build guard: PASS; approved card, EA registry, magic registry,
  exact folder, and exact slug agree.
- Targeted candidate registry validation: PASS; one EA-ID row, one slot row,
  correct formula magic, generated resolver membership, and no candidate
  collision.
- V5 build guardrails: PASS.
- V5 strict build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_054012/QM5_20137_wti-seas-pb.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_054012.json`

No manual smoke test or pipeline runner was started.

## Paced Q02 Handoff

- Build task: `5beef69c-8a2b-4792-bd69-a5c654566f14`, status `done`
- Q02 work item: `7dff45e1-d4c7-4f5c-b8e0-2f2ea254a725`
- Phase/status: `Q02` / `pending`
- Attempt count: 0
- Claimed by: none
- Created: `2026-07-25T05:41:13+00:00`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Setfile:
  `QM5_20137_wti-seas-pb_XTIUSD.DWX_D1_backtest.set`
- Read-only database recheck: exactly one Q02 row for this EA/build
- Idempotent build record: skipped one duplicate enqueue because that pending
  row already existed

At the pre-record capacity check, the paced fleet reported four active
factory terminals, below the documented ceiling of seven. The pre-existing
live terminal was separately identified and not touched. The repository's
`FACTORY_OFF.flag` remained present, no manual tester was started, and the
new row remained pending at attempt 0.

AutoTrading, the portfolio gate, the T_Live manifest, and all T_Live files
were not touched.

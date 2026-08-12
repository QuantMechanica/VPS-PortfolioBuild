# QM5_20128 XNG storage-release false-break fade — build and Q02 enqueue

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20128_xng-stor-fade`

Strategy ID: `EIA-XNG-STORAGE-INTRADAY-2026_S02`

## Outcome

One new low-frequency energy candidate was carded, registered, built, compiled,
and handed to the paced pipeline. The EA trades only `XNGUSD.DWX` M30. On a
standard Thursday it waits for both the 10:30-11:00 New York EIA release bar
and the 11:00-11:30 reclaim bar to complete. It fades a release break only
after price closes back inside the pre-release range and through the release
midpoint. The release open is the target, the hard stop is beyond the event
extreme plus 0.25 ATR(20), and every trade is flattened in the same New York
session.

This is a research candidate, not a certified portfolio admission. No
profitability, correlation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source and non-duplicate boundary

The existing OWNER-approved EIA packet was extended with strategy ID
`EIA-XNG-STORAGE-INTRADAY-2026_S02`. Its tier-A official sources identify the
Weekly Natural Gas Storage Report and its regular/holiday release schedule:

- `https://www.eia.gov/naturalgas/storage/`
- `https://www.eia.gov/naturalgas/data.php`
- `https://ir.eia.gov/ngs/schedule.html`

EIA supports only the event identity and clock. The false-break/reclaim rule,
target, stop, and expected cadence are QM hypotheses.

The deterministic dedup check covered 4,185 EA-registry rows and 375 strategy
cards. Its two fuzzy neighbors were manually resolved:

- `QM5_20124_xng-stor-m30` enters with the release impulse at 11:00; this EA
  waits for a completed rejection bar and enters the opposite direction at
  11:30.
- `QM5_12744_eia-xng-storfade` is a D1 slow-SMA storage-exhaustion fade that
  may hold for days; this EA is an exact-clock M30 failed break with no SMA and
  a same-session lifecycle.

`QM5_12567_cum-rsi2-commodity` is also mechanically distinct: it is a D1
cumulative-RSI pullback rather than a scheduled-event price-action reversal.
Realized correlation remains a downstream Q09/portfolio-gate question; the
portfolio gate was not changed.

## Deterministic identity and build artifacts

- EA registry: `20128,xng-stor-fade,EIA-XNG-STORAGE-INTRADAY-2026_S02`
- Magic registry: slot 0, `XNGUSD.DWX`, magic `201280000`
- Host: exact `XNGUSD.DWX`, M30
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- News axes: OFF for Q02; no external calendar or storage feed
- Card SHA-256:
  `2B0580991B606A3200ED44AD71BEF02D0957F2701317A7C6002E5216E1587516`
- MQ5 SHA-256:
  `9E5C099EBD4262C50332E626A7C067E52ECD27B6DF8A09A3BFC5EA82E7CE7186`
- EX5 SHA-256:
  `FF038468DDEBC2BF295BB0269639974B58B3CD4B8B0AE3C74687FF61E4BFFCDC`
- SPEC SHA-256:
  `8F90BAE8623A6420F70977F7061CE04426476B64B1DE34C1C09B8D0AD4066747`
- Setfile SHA-256:
  `4E3B838F75552BA00EBAEA53E4CA863F361954A50FAD37A8DC37AA46CA55F58D`
- Magic registry SHA-256:
  `FD73F33B1CE0B4CADCB36759632821ED0D71A629CEC2EEFE148482C4CC8D4C5B`
- Generated resolver SHA-256:
  `9F7FED396330655CDA5D4E274E49A2BE598DF257DCE9D5DC140D3FBC2F59A66A`

## Validation evidence

- Strategy-card schema lint: PASS, no missing sections, no ML hits.
- G0 card lint: PASS.
- V5 build guard: PASS for EA 20128 and magic 201280000.
- SPEC validation: PASS.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
  Compile log:
  `C:/QM/repo/framework/build/compile/20260724_232702/QM5_20128_xng-stor-fade.compile.log`
- Strict targeted build check: PASS, 0 failures, 0 warnings.
  Compiling report:
  `D:/QM/reports/framework/21/build_check_20260724_232702.json`
- Final targeted no-compile consistency check: PASS, 0 failures, 0 warnings.
  Final report:
  `D:/QM/reports/framework/21/build_check_20260724_233226.json`

No manual backtest or pipeline runner was started.

## Paced Q02 handoff

- Build task: `382d3008-3590-4687-9f8a-64274f6d940b`, status `done`
- Q02 work item: `7120d80d-a807-4353-901a-6cde7013a88f`
- Phase/status: `Q02` / `pending`
- Attempt count: 0
- Symbol/timeframe: `XNGUSD.DWX` / M30
- Setfile:
  `QM5_20128_xng-stor-fade_XNGUSD.DWX_M30_backtest.set`
- Auto-enqueue result: exactly 1 enqueued, 0 skipped

At enqueue time `D:/QM/strategy_farm/state/FACTORY_OFF.flag` was present and
the farm reported zero running backtest terminals, so smoke was explicitly
deferred to the paced Q02 worker. The existing `T_Live` terminal process was
observed read-only and was not touched. AutoTrading, the portfolio gate, and
the T_Live manifest were not touched.

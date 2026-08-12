# QM5_20135 WTI winter-regime trend — build and Q02 enqueue

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20135_wti-winter-trend`

Strategy ID: `BURAKOV-MOP-WTI-WINTER-TREND-2026_S01`

## Outcome

One new low-frequency structural WTI candidate was carded, registered, built,
strictly compiled, and handed to the paced pipeline. On the first tradable D1
bar of each November-May broker month, it closes any older package and trades
the sign of WTI's completed 252-D1 log return. June-October is forced flat.
Each monthly package has a frozen `4.0 * ATR(20)` hard stop and a 35-calendar-
day stale guard.

This is a Q02 research candidate, not a certified portfolio admission. No
profitability, decorrelation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source and claim boundary

The approved composite source packet preserves two existing, completely read
repository lineages:

- Burakov, Freidin, and Solovyev (2018), a peer-reviewed open-access paper,
  supplies the alternative-two West Texas November-May regime.
- Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed journal paper, supplies
  the instrument-own trailing-return-sign time-series-momentum mechanic.

Neither paper tests their conjunction, the Darwinex continuous WTI CFD,
monthly fixed-risk renewal, the ATR stop, or QM portfolio behavior. Those are
explicit QM hypotheses. This work imported no new web claims. Runtime reads no
external feed, inventory, futures curve, COT, volume, open interest, analyst
forecast, CSV, API, or ML output.

## Non-duplicate boundary

Before allocation, the deterministic check scanned 4,192 EA-registry rows and
376 research cards and returned CLEAN. Manual semantic review resolved the
closest candidates:

- `QM5_12603_wti-tsmom12m` trades the same slow return sign year-round; it has
  no November-May gate or forced June season exit.
- `QM5_20015_wti-halloween-winter` is unconditional long-only in winter and
  does not use price direction.
- `QM5_20046_wti-halloween-ls` maps the calendar directly to direction and
  does not use a trailing-return signal.
- `QM5_12576_eia-wti-season` uses different demand months, SMA(84), 21-D1
  ROC confirmation, and Friday flattening.
- `QM5_20052_xng-seas-trend` is natural gas with different physical windows,
  a 126-D1 horizon, and a two-percent deadband.
- `QM5_12963_wti-winter-exhaust` is a short-only price-stretch fade.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The load-bearing new state is the conjunction of the fixed WTI November-May
regime and completed 252-D1 own-return sign. Removing either component
recreates an already-built parent mechanic. Realized correlation remains a
downstream Q09 and unchanged portfolio-gate question.

## Frozen baseline

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `201350000`
- Decision clock: first tradable D1 bar of each broker month
- Active months: November through May; June through October forced flat
- Direction: buy strictly positive completed 252-D1 log return; sell strictly
  negative; exact zero or invalid history stays flat
- Lifecycle: close before monthly renewal; 35-day stale exit
- Risk control: frozen `4.0 * ATR(20)` hard stop; no take-profit or trailing
- Entry spread ceiling: 1,500 points
- Attempt state: persist broker `YYYYMM` before fallible gates; no retry
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF; Friday close: OFF

Only the locked baseline setfile was created. There is no parameter sweep,
live setfile, external signal, grid, martingale, scale-in, or pyramiding.

## Deterministic identity and hashes

- EA registry:
  `20135,wti-winter-trend,BURAKOV-MOP-WTI-WINTER-TREND-2026_S01`
- Magic registry:
  `20135,wti-winter-trend,0,XTIUSD.DWX,201350000`
- Card SHA-256:
  `E32F62B35CADBCF0DB0032F5F8D1AD58393575ADFD482B8925C31F7A14483900`
- Source packet SHA-256:
  `F8440E8E0F2C31EAFB8CC37D03ACD1C19376A41DBF4FCA9269181313774B09DF`
- MQ5 SHA-256:
  `2C402F0448ADFC416A981B28555BB085B567E15743D9C86AF973852A7C4EC8DB`
- EX5 SHA-256:
  `41881C9F35C84B4C4CEC9EA84A1FE7D5F65D5A93E9C9BF04FF5C05795D3A0E85`
- SPEC SHA-256:
  `C3EEB8A002503FF1F0507AAF25C2C5AFDD4A189BE31F50835BAAEC7B48EC8E10`
- Setfile SHA-256:
  `96F32ADE3733834D4616E09A2B4C2AB1A8BC9EBDE71EAAA224DC93C17BDEE25D`
- EA-ID registry SHA-256:
  `203E3600DF4206DC5C37EDA74C206E73489C3591EECBC00A532715AF511C332F`
- Magic registry SHA-256:
  `3BDD53B5F337375E6558E1069A3CB5668F7A711900B05EBF0DAFAE81DC232A85`
- Generated resolver SHA-256:
  `A31983BC01889D6EC521C2F1CD9A9429FC13E76A65AF7035B72E104F3AF82701`

The resolver was regenerated from the canonical registry after the EA
directory and magic row existed. Generated magic `201350000` was verified.

## Validation evidence

- Strategy-card schema lint: PASS, no missing sections and no ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build guard: PASS; approved card, EA registry, magic registry,
  exact folder, and exact slug all agree.
- Candidate registry validation: PASS; one EA-ID row, one slot row, correct
  formula magic, and no collision for `201350000`.
- V5 build guardrails: PASS.
- V5 strict build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_034639/QM5_20135_wti-winter-trend.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_034652.json`

No manual smoke test or pipeline runner was started.

## Paced Q02 handoff

- Build task: `cbc28003-dc43-4c3c-8ee2-ac2a71fb6e06`, status `done`
- Q02 work item: `063e9d6c-8a54-461a-8113-a3f098e3e5e7`
- Phase/status: `Q02` / `pending`
- Attempt count: 0
- Created: `2026-07-25T03:48:28+00:00`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Setfile:
  `QM5_20135_wti-winter-trend_XTIUSD.DWX_D1_backtest.set`
- Initial auto-enqueue: exactly 1 enqueued, 0 skipped
- Read-only database recheck: exactly one Q02 row for this EA/build

At enqueue time `D:/QM/strategy_farm/state/FACTORY_OFF.flag` was present and
the farm reported no pipeline MT5 terminal. The only observed terminal process
was the pre-existing `T_Live` terminal; it was not touched. Manual backtest CPU
use was zero, so the backtest CPU ceiling was not hit.

AutoTrading, the portfolio gate, the T_Live manifest, and all T_Live files
were not touched.

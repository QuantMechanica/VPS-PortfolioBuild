# QM5_20149 WTI Monday/trend agreement — build and Q02 CPU-ceiling stop

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20149_wti-montrend`

Strategy ID: `QUAY-MOP-WTI-MONTREND-2026_S01`

## Outcome

One new low-frequency structural WTI candidate was carded, registered, built,
and strictly compiled. On the first executable quote of each genuine Monday
D1 bar immediately following a completed Friday bar, it may open one
`XTIUSD.DWX` short only when WTI's strictly completed 252-D1 log return is
negative. The package has a frozen `3.0 * ATR(20)` hard stop, consumes the
broker week before fallible gates, and closes at the first non-Monday D1
boundary.

Q01 is PASS. Q02 is PENDING and was **not enqueued**. The authoritative
immediate pre-enqueue scan found all seven allowed factory terminals active,
so work stopped under the mission's explicit backtest CPU-ceiling condition.
This candidate is not certified and no profitability, decorrelation,
diversification, correlation, or portfolio-admission result is claimed.

## Source And Claim Boundary

The approved composite packet preserves two governed peer-reviewed source
lineages that were read completely:

- Quayyum, Khan, and Ali (2020), *Seasonality in crude oil returns*,
  supplies the weak WTI Monday direction.
- Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, supplies the
  instrument-own completed 12-month return-sign state.

Neither paper tests their conjunction, the Darwinex continuous WTI CFD, a
Monday-open execution carrier, the fixed ATR stop, or QM portfolio behavior.
In particular, a Monday-open EA omits the Friday-close to Monday-open
component of a close-to-close calendar effect. Those translations are
declared QM hypotheses and Q02 kill risks. Runtime uses native MT5
price/calendar data only: no ML, banned indicator, external feed, futures
curve, inventory, volume, COT, analyst forecast, CSV, or API.

## Non-Duplicate Boundary

Before allocation, the deterministic helper scanned 4,206 EA-registry rows
and 376 research cards and returned CLEAN. Manual review resolved the closest
mechanics:

- `QM5_12596_wti-mon-fade`: unconditional Monday short; no trend state.
- `QM5_12603_wti-tsmom12m`: year-round symmetric monthly trend; no weekday
  package.
- `QM5_12750/12779`: Monday gap trades with gap-fill targets; this EA never
  reads the opening gap.
- `QM5_20016_xti-xng-mon-rv`: two-leg XTI/XNG Monday basket with fixed
  opposing directions.
- `QM5_20029_wti-monfri-daily`: unconditional Monday short plus Friday long.
- `QM5_20141_wti-sumtrend`: July-November weekly WTI short in negative trend.
- `QM5_20145_wti-fri-trend`: Friday long in positive trend.
- `QM5_12567_cum-rsi2-commodity`: two-day oscillator pullback.

The jointly load-bearing new state is a genuine Monday WTI short plus a
strictly negative completed 252-D1 return. Removing either component recreates
an already-built parent mechanic.

## Frozen Baseline

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `201490000`
- Decision clock: first five minutes of a genuine Monday D1 bar whose prior
  completed bar is Friday
- Trend state: strictly negative completed 252-D1 WTI log return
- Direction: short only
- Risk control: frozen `3.0 * ATR(20)` hard stop; no take-profit or trailing
- Exit: first non-Monday D1 boundary, with wrong-side and two-calendar-day
  repair exits
- Friday close: enabled at broker hour 21 as a fail-safe
- Entry spread ceiling: 1,500 points
- Attempt state: persist the Monday-anchored broker-week key before fallible
  gates; no same-week retry
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF

Only the locked backtest setfile was created. There is no parameter sweep,
live setfile, grid, martingale, scale-in, pyramiding, or manual tester run.

## Deterministic Identity And Hashes

- EA registry:
  `20149,wti-montrend,QUAY-MOP-WTI-MONTREND-2026_S01`
- Magic registry:
  `20149,wti-montrend,0,XTIUSD.DWX,201490000`
- Card SHA-256:
  `34D14B18512938DD659F823B436CF70CC7222636295549317E93D2A0499B5B0E`
- Source packet SHA-256:
  `E55A8BA2E5A795294F846E1318896F39730609DFCAD4B24085EF1A8D1733099A`
- MQ5 SHA-256:
  `BB77FF8A7F113800113E262975F38476E583DDDDE556A9A22D337B2E641EEDF9`
- EX5 SHA-256:
  `A2DF63F4B05F558E98C039C84EF39D050A544842A9E1CA10E161B1AC4FDB3BB5`
- SPEC SHA-256:
  `76F1FC535D781B08C134F85567BE1D276578814DA761397C8B7F0B91C4CA0481`
- EA-local card SHA-256:
  `EEB3B2C324E05DF186BB94CF395B23E9C79A8AC8D5E0D944DCDB9E44CC5071A7`
- Setfile SHA-256:
  `4506ADAE290D1236B2C2A3C396A4686A52F69B182C770DCEABC9DAB13B2FFCF9`

The EA directory existed before registry allocation. The resolver was then
regenerated from the canonical registry and generated magic `201490000` was
verified before compilation. Its regeneration retained only the pre-existing
missing-directory warnings for legacy IDs 1001, 1015, and 1016.

## Validation Evidence

- Strategy-card schema lint: PASS, no missing sections and no ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build guard: PASS; approved G0 card, EA registry, magic registry,
  exact folder, and exact slug agree.
- V5 strict build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_091919/QM5_20149_wti-montrend.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_092129.json`
- Machine-readable build record:
  `C:/QM/repo/artifacts/qm5_20149_wti_montrend_build_q02_cpu_ceiling_20260725.json`

The execution contract remains DRAFT.

## Q02 Capacity Stop

- Immediate pre-enqueue scan:
  `python tools/strategy_farm/farmctl.py mt5-slots`
- Scan timestamp: `2026-07-25T09:22:48+00:00`
- Active factory terminals:
  `T1,T2,T3,T4,T7,T8,T10` (`7/7`)
- Total observed `terminal64.exe` processes: 8
- Separate pre-existing `T_Live` terminal: observed and excluded from the
  factory count
- `farmctl work-items --ea QM5_20149`: `count=0`
- Q02 work item: none
- Build task: none created
- `record-build`: not called
- Manual tester: not started

No queue/database mutation followed the ceiling observation. The compiled
candidate is a capacity-blocked handoff only; this evidence does not authorize
bypassing the normal paced fleet.

AutoTrading, `T_Live`, the T_Live manifest, the portfolio gate, and all
portfolio-admission controls were not touched.

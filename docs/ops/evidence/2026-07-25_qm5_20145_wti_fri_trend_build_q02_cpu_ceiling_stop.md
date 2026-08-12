# QM5_20145 WTI Friday/trend agreement — build and Q02 CPU-ceiling stop

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20145_wti-fri-trend`

Strategy ID: `GORSKA-MOP-WTI-FRITREND-2026_S01`

## Outcome

One new low-frequency structural WTI candidate was carded, registered, built,
and strictly compiled. On the first executable quote of each genuine Friday
D1 bar, it may open one `XTIUSD.DWX` long only when WTI's strictly completed
252-D1 log return is positive. The package has a frozen `3.0 * ATR(20)` hard
stop, consumes the broker week before fallible gates, and uses the framework
Friday close at broker hour 21.

Q01 is PASS. Q02 is PENDING and was **not enqueued**. The authoritative
immediate pre-enqueue scan found all seven allowed factory terminals active,
so work stopped under the mission's explicit backtest CPU-ceiling condition.
This candidate is not certified and no profitability, decorrelation,
diversification, correlation, or portfolio-admission result is claimed.

## Source And Claim Boundary

The approved composite packet preserves two governed academic source
lineages that were read completely:

- Gorska and Krawiec (2015), *Calendar Effects in the Market of Crude Oil*,
  supplies the positive WTI Friday-return state.
- Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, supplies the
  instrument-own completed 12-month return-sign state.

Neither paper tests their conjunction, the Darwinex continuous WTI CFD, a
Friday-open execution carrier, the fixed ATR stop, or QM portfolio behavior.
In particular, a Friday-open EA omits the Thursday-close to Friday-open
component of a close-to-close calendar effect. Those translations are
declared QM hypotheses and Q02 kill risks. Runtime uses native MT5
price/calendar data only: no ML, banned indicator, external feed, futures
curve, inventory, volume, COT, analyst forecast, CSV, or API.

## Non-Duplicate Boundary

Before allocation, the deterministic check scanned 4,202 EA-registry rows and
376 cards and returned CLEAN. Manual review resolved the closest mechanics:

- `QM5_12597_wti-fri-prem`: unconditional Friday long; no trend state.
- `QM5_12603_wti-tsmom12m`: year-round trend; no Friday-only package.
- `QM5_20141_wti-sumtrend`: July-November weekly short in negative trend.
- `QM5_20135_wti-winter-trend`: November-May monthly trend package.
- `QM5_20117_wti-fri-lagrev`: Friday short after a large positive Thursday.
- `QM5_12753_wti-thu-pb-fri-bounce`: Friday long after a Thursday pullback.
- `QM5_12567_cum-rsi2-commodity`: two-day oscillator pullback.

The jointly load-bearing new state is a genuine Friday WTI long plus a
strictly positive completed 252-D1 return. Removing either component recreates
an existing parent mechanic.

## Frozen Baseline

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `201450000`
- Decision clock: first five minutes of a genuine Friday D1 bar whose prior
  completed bar is Thursday
- Trend state: strictly positive completed 252-D1 WTI log return
- Direction: long only
- Risk control: frozen `3.0 * ATR(20)` hard stop; no take-profit or trailing
- Exit: Friday close at broker hour 21, with non-Friday, wrong-side, and
  three-calendar-day repair exits
- Entry spread ceiling: 1,500 points
- Attempt state: persist the Monday-anchored broker-week key before fallible
  gates; no same-week retry
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF

Only the locked backtest setfile was created. There is no parameter sweep,
live setfile, grid, martingale, scale-in, pyramiding, or manual tester run.

## Deterministic Identity And Hashes

- EA registry:
  `20145,wti-fri-trend,GORSKA-MOP-WTI-FRITREND-2026_S01`
- Magic registry:
  `20145,wti-fri-trend,0,XTIUSD.DWX,201450000`
- Card SHA-256:
  `F834E2EF8AF828CBCD269B190B9ACF139DB2B1C64D65A1ACBBB92761224B280F`
- EA-local card SHA-256:
  `F834E2EF8AF828CBCD269B190B9ACF139DB2B1C64D65A1ACBBB92761224B280F`
- Source packet SHA-256:
  `A34B7E3CEF535388E1D2E16E03258B55D11522294B6F837EF9CFD41AFEF534A2`
- MQ5 SHA-256:
  `BB5E2601DA953E4DDEFFCAE13F823F2249ECE17E4B1C84493E1048B5F5D59736`
- EX5 SHA-256:
  `D9DD7862E0EF651D236698B0D2CD6C0EC74DA6F244C293E89DD6D7BC3E8E3BDF`
- SPEC SHA-256:
  `886ACE1D86E107448E2FF0CC717667670C66F2AB5AF96F102FEC5D0C333BD28F`
- Setfile SHA-256:
  `EEC7F185A90B96CAEA976FBA83BDFEDEA89D37E51B0C939F7B76C5A50245F838`
- EA-ID registry SHA-256:
  `87336DEAB6972F92BD7449DCDDA72FBFC28FF584FE36CD2FCA968649BB42EE34`
- Magic registry SHA-256:
  `E2A499EC521713B253FC90B21D4CE582E1766015A3C961185933B7117B2A2A0E`
- Generated resolver SHA-256:
  `079781FFC197DF920E03CA3BE29D84EAE557EB97FBA913BB97BF5A30EFC681F9`

The resolver was regenerated from the canonical registry and generated magic
`201450000` was verified. Its strict whole-registry run retains the
pre-existing missing-EA-directory warnings for IDs 1001, 1015, and 1016;
candidate-scoped identity and build guards pass.

## Validation Evidence

- Strategy-card schema lint: PASS.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build guard: PASS; approved G0 card, EA registry, magic registry,
  folder, and slug agree.
- V5 build guardrails: PASS, 0 findings.
- V5 strict build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_075651/QM5_20145_wti-fri-trend.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_080216.json`

The execution contract remains DRAFT.

## Q02 Capacity Stop

- Prepared build task: `4597adf4-ac91-4987-80fa-a33aba3b385f`
- Build-task database status: `pending`
- Prepared result:
  `D:/QM/strategy_farm/artifacts/builds/4597adf4-ac91-4987-80fa-a33aba3b385f.json`
- `farmctl work-items --ea QM5_20145`: `count=0`
- Q02 work item: none
- `record-build`: not called
- `FACTORY_OFF.flag`: absent
- Factory terminals at the immediate pre-enqueue check:
  `T1,T2,T3,T4,T8,T9,T10` (`7/7`)
- Separate pre-existing `T_Live` terminal: observed and excluded from the
  factory count

No queue/database mutation followed the ceiling observation. The prepared
build task remains available for a future capacity-safe `record-build`
handoff; this evidence does not authorize bypassing the normal paced fleet.

AutoTrading, `T_Live`, the T_Live manifest, the portfolio gate, and all
portfolio-admission controls were not touched.

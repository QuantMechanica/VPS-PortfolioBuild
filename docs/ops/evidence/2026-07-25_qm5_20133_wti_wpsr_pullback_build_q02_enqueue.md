# QM5_20133 WTI WPSR shallow-pullback continuation — build and Q02 enqueue

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20133_wti-wpsr-pb`

Strategy ID: `EIA-WTI-WPSR-INTRADAY-2026_S01`

## Outcome

One new low-frequency WTI candidate was sourced, carded, registered, built,
compiled, and handed to the paced pipeline. On a standard Wednesday, the EA
requires the completed 10:30 New York WPSR bar to break the preceding one-hour
range. It then requires the separate 11:00 bar to pull back against the
impulse while still closing outside the old range. Entry at 11:30 follows the
original impulse direction with an event-sequence structural stop, fixed
`1.50R` target, and same-session exit.

This is a Q02 research candidate, not a certified portfolio admission. No
profitability, decorrelation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source and claim boundary

The approved `EIA-WTI-WPSR-INTRADAY-2026` packet uses the existing repository
lineage for the official EIA Weekly Petroleum Status Report event, release
schedule, and standard-clock implementation. Deterministic retrieval attempts
for the two official EIA URLs returned `DEFERRED:SOURCE_POLICY`; no alternate
browser, proxy, cache, authentication, or policy bypass was attempted, and no
new webpage text was imported.

EIA supports only the event and schedule lineage. The impulse threshold,
shallow-pullback band, continuation direction, stop, target, and lifecycle are
QM hypotheses. Runtime reads no inventory value, consensus, surprise, calendar
file, API, futures curve, volume, or external market data.

## Non-duplicate boundary

The deterministic check scanned 4,190 EA-registry rows and 376 research cards
and returned CLEAN. A targeted search across 304 approved cards and EA source
manually resolved the closest neighbors:

- `QM5_1121` uses an M5 pre-release stop straddle and can trigger inside the
  event window; this EA waits for two completed post-release M30 bars.
- `QM5_10319` follows the release-bar sign in a late broker-time window and
  has no required shallow counter-bar or pre-release-range breakout.
- `QM5_12579`, `QM5_12590`, `QM5_12752`, and `QM5_12988` use D1 event,
  consolidation, exhaustion, or multiweek states.
- `QM5_13042`, `QM5_13044`, and `QM5_13063` are seasonal D1 long-only proxy
  sleeves with SMA filters and multi-day pullbacks.
- `QM5_20124` enters XNG immediately after an impulse; `QM5_20128` fades an
  XNG full reclaim. This EA requires a WTI shallow non-reclaiming pullback and
  trades continuation.
- `QM5_12567` is a D1 cumulative-RSI pullback with a multiday lifecycle.

The new decision state is therefore the completed WTI
impulse-plus-shallow-pullback sequence, not a renamed parameter variant.
Realized correlation remains a downstream Q09 and unchanged portfolio-gate
question.

## Frozen baseline

- Host: exact `XTIUSD.DWX`, M30, slot 0, magic `201330000`
- Pre-release range: completed 09:30 and 10:00 New York bars
- Release impulse: range at least `0.75 * ATR(20)`, body/range at least `0.50`
- Break confirmation: release close at least `0.05 * ATR(20)` outside range
- Pullback: opposite-color 11:00 bar, `0.15-0.50` release-range retracement,
  close still outside the pre-release range
- Entry: 11:30 New York in the impulse direction, maximum gap `0.25 * ATR(20)`
- Stop: beyond the adverse release/pullback extreme by `0.10 * ATR(20)`
- Stop-distance band: `0.25-3.00 * ATR(20)`
- Target: `1.50R`
- Exit: 15:55 New York, date change, six-hour stale guard, or broker SL/TP
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF because the scheduled release is the signal

The New York date is persisted before history, signal, news, spread, quote,
gap, geometry, and order gates. Rejection, restart, stop, or a blocked gate
cannot retry that date. Holiday-shifted weeks are skipped, and there is no
baseline parameter sweep.

## Deterministic identity and hashes

- EA registry:
  `20133,wti-wpsr-pb,EIA-WTI-WPSR-INTRADAY-2026_S01`
- Magic registry: `20133,wti-wpsr-pb,0,XTIUSD.DWX,201330000`
- Card SHA-256:
  `CA9150D936427A7BBB5E2966C2EA1C6425C36537CCB4CF16CF525BB233284287`
- Source packet SHA-256:
  `83C863389F0CD85B5F5C838EF696CDE3F8F04A833D3C76FFEC36C511FBB9D48B`
- MQ5 SHA-256:
  `C97C977289EBAA7AB6EC404A0A3348D9B7FBAC08E52D250ADD5786C4B6002894`
- EX5 SHA-256:
  `06702D7E26D1AC795F20A6C2FF73424D15B3FA025855B38C6EF6A23AC230230E`
- SPEC SHA-256:
  `A06F85504A9011DE731DDFF9EA87EDC21BF107F9AECC38D3DECA656AA85BCC5E`
- Setfile SHA-256:
  `273694DD2C51FD52DCC1C008DDC68FEBF9D6DF1378E49D0CF311746E3DABB017`
- Magic registry SHA-256:
  `F138E9D9BBC7694CD7A43E54F06D126AF37CB60495E34C10CA16C7EE20240E3C`
- Generated resolver SHA-256:
  `6D714D5D48F9B6F4BF075B8EA1400ED1F2C1F96B289842C44C234E27D5AF2E85`

The resolver was regenerated from the canonical registry and adds 20133
without hand editing.

## Validation evidence

- Strategy-card schema lint: PASS, no missing sections and no ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- V5 strict build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_014229/QM5_20133_wti-wpsr-pb.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_014229.json`

No manual smoke test or pipeline runner was started.

## Paced Q02 handoff

- Build task: `697cad68-6a97-4f33-9cf6-3e24fb54d437`, status `done`
- Q02 work item: `c8f77304-f43b-4d5b-bd00-a4b9afbaa482`
- Phase/status: `Q02` / `pending`
- Attempt count: 0
- Created: `2026-07-25T01:45:58+00:00`
- Symbol/timeframe: `XTIUSD.DWX` / M30
- Setfile:
  `QM5_20133_wti-wpsr-pb_XTIUSD.DWX_M30_backtest.set`
- Initial auto-enqueue: exactly 1 enqueued, 0 skipped
- Idempotence recheck: `existing_q02_pending` for work-item prefix
  `c8f77304`; the queue still contained exactly one Q02 item

At enqueue time `D:/QM/strategy_farm/state/FACTORY_OFF.flag` was present and
the farm reported zero running pipeline MT5 terminals. Smoke was therefore
deferred to paced Q02. The only observed terminal process was the pre-existing
`T_Live` terminal; it was not touched. AutoTrading, the portfolio gate, and the
T_Live manifest were not touched.

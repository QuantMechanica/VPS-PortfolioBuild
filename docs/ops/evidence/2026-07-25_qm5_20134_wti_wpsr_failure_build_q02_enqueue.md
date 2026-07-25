# QM5_20134 WTI WPSR deep-reclaim failure fade — build and Q02 enqueue

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20134_wti-wpsr-fail`

Strategy ID: `EIA-WTI-WPSR-INTRADAY-2026_S02`

## Outcome

One new low-frequency WTI candidate was carded, registered, built, compiled,
and handed to the paced pipeline. On a standard Wednesday, the EA requires
the completed 10:30 New York WPSR bar to break the preceding one-hour range.
The separate 11:00 bar must then reverse the impulse, return inside that old
range, cross its midpoint, and close in the far half. Entry at 11:30 fades
the failed break, with a stop beyond the complete event-sequence extreme, a
target at the opposite side of the frozen pre-release range, and a
same-session exit.

This is a Q02 research candidate, not a certified portfolio admission. No
profitability, decorrelation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source and claim boundary

The approved `EIA-WTI-WPSR-INTRADAY-2026` packet uses existing repository
lineage for the official U.S. Energy Information Administration Weekly
Petroleum Status Report event, release schedule, and standard-clock
implementation. It is a tier-A official-government source under R1.

The packet already records that deterministic generic-URL retrieval of the
two official EIA pages was `DEFERRED:SOURCE_POLICY` on 2026-07-25. This work
did not import new webpage text or attempt another browser, proxy, cache,
authentication, or policy bypass.

EIA supports only event identity and schedule lineage. The release threshold,
deep-reclaim definition, reversal direction, stop, target, and lifecycle are
QM hypotheses. Runtime reads no inventory value, consensus, surprise,
calendar file, API, futures curve, volume, open interest, or external market
data.

## Non-duplicate boundary

Before allocation, the deterministic check scanned 4,191 EA-registry rows and
376 research cards and returned CLEAN. Targeted repository searches resolved
the closest mechanics:

- `QM5_1121` uses an M5 pre-release stop straddle and can trigger inside the
  event window; this EA waits for two completed post-release M30 bars.
- `QM5_10319` follows the release-bar sign in a later broker-time window and
  has no required deep old-range reclaim.
- `QM5_12579` follows a completed D1 event bar; `QM5_12590` fades a stretched
  completed D1 event bar. Neither isolates an intraday failed auction.
- `QM5_12752` trades a post-event D1 inside-bar breakout, and `QM5_12988`
  requires two aligned weekly reactions.
- `QM5_20133` requires the 11:00 pullback to remain outside the pre-release
  range and trades continuation. This EA requires the opposite state: a
  reclaim through the old-range midpoint and a reversal trade.
- `QM5_20128` fades an XNG storage-release failure, but it uses another
  commodity/report, reclaims only through the release-bar midpoint, and
  targets the release open. This WTI mechanic requires a deeper
  pre-range-midpoint cross, targets the opposite frozen range boundary,
  limits entry gaps, and freezes a stop-distance band.
- `QM5_12567` is a D1 cumulative-RSI pullback with a multiday lifecycle.

The new decision state is the completed WTI impulse-break plus deep
old-range reclaim. Realized correlation remains a downstream Q09 and
unchanged portfolio-gate question.

## Frozen baseline

- Host: exact `XTIUSD.DWX`, M30, slot 0, magic `201340000`
- Pre-release range: completed 09:30 and 10:00 New York bars
- Release impulse: range at least `0.75 * ATR(20)`, body/range at least `0.50`
- Break confirmation: release close at least `0.05 * ATR(20)` outside range
- Reclaim: opposite-color 11:00 bar closing in the far half of the old range
- Entry: 11:30 New York opposite the release impulse
- Maximum executable gap: `0.25 * ATR(20)` from the reclaim close
- Stop: beyond the adverse release/reclaim extreme by `0.10 * ATR(20)`
- Stop-distance band: `0.25-3.00 * ATR(20)`
- Target: opposite frozen pre-release boundary, minimum `0.75R`
- Exit: 15:55 New York, date change, six-hour stale guard, or broker SL/TP
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF because the scheduled WPSR release is the signal

The New York date is persisted before history, signal, news, spread, quote,
gap, geometry, and order gates. Rejection, restart, stop, or a blocked gate
cannot retry that date. Holiday-shifted weeks are skipped, and there is no
baseline parameter sweep.

## Deterministic identity and hashes

- EA registry:
  `20134,wti-wpsr-fail,EIA-WTI-WPSR-INTRADAY-2026_S02`
- Magic registry:
  `20134,wti-wpsr-fail,0,XTIUSD.DWX,201340000`
- Card SHA-256:
  `7A7040B0B7F61BC47AC664726F3911BF31FD3729FBBEF6818D60B443BDF25A18`
- Source packet SHA-256:
  `0F7232F876636F27B23BC5A1828176B5906C368C2D4B3BBD3769E686D18A1566`
- MQ5 SHA-256:
  `7C13C696D492AF1EFC8F12CDB97763BEF08802ECCFC341EDAF8A9E0E14B59C32`
- EX5 SHA-256:
  `EDB1FC8568D9A2242BE0E1412760E81CB315904BD722D1DAEBEB327470822FB8`
- SPEC SHA-256:
  `35F084C71FBE10123C1F98BC9A162716A88E8AA3437244AB7161F552210E21ED`
- Setfile SHA-256:
  `9A43F110F417705A52F59799396FA67ED7F5F124ED294A73F15D7A96D3B2D4CF`
- EA-ID registry SHA-256:
  `0935037B80112B2272B44C2162DC627FF6D85D1A54B467DC271ACB41D925E5A7`
- Magic registry SHA-256:
  `6E5B4F85D6C37AFD9FEC3345E861DF35B5780E72C0EDCB746AAB371806E388DA`
- Generated resolver SHA-256:
  `BD42B7754C9D45A8E82F23C697E177B2C34F4B10C8B457F4828B1986804B632C`

The resolver was regenerated from the canonical registry and adds 20134
without hand editing.

## Validation evidence

- Strategy-card schema lint: PASS, no missing sections and no ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate registry validation: PASS; one EA-ID row, one slot row, and no
  collision for magic `201340000`.
- V5 strict build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_023921/QM5_20134_wti-wpsr-fail.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_024200.json`

No manual smoke test or pipeline runner was started.

## Paced Q02 handoff

- Build task: `db1461bf-68bf-40c8-951a-1ba2c0987987`, status `done`
- Q02 work item: `bba6ba7f-788d-46a6-9568-b5ad69c06613`
- Phase/status: `Q02` / `pending`
- Attempt count: 0
- Created: `2026-07-25T02:40:43+00:00`
- Symbol/timeframe: `XTIUSD.DWX` / M30
- Setfile:
  `QM5_20134_wti-wpsr-fail_XTIUSD.DWX_M30_backtest.set`
- Initial auto-enqueue: exactly 1 enqueued, 0 skipped
- Idempotence recheck: `existing_q02_pending` for work-item prefix
  `bba6ba7f`; the queue still contained exactly one Q02 item

At enqueue time `D:/QM/strategy_farm/state/FACTORY_OFF.flag` was present and
the farm reported no pipeline MT5 terminal. The only observed terminal
process was the pre-existing `T_Live` terminal; it was not touched. Manual
backtest CPU use was zero, so the backtest CPU ceiling was not hit.

AutoTrading, the portfolio gate, the T_Live manifest, and all T_Live files
were not touched.

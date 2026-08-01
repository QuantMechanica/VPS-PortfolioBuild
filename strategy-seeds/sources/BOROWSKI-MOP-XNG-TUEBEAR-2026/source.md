---
source_id: BOROWSKI-MOP-XNG-TUEBEAR-2026
title: XNG Tuesday premium in a negative slow-return regime
source_type: governed_composite_research_packet
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-08-01
strategy_ids: [BOROWSKI-MOP-XNG-TUEBEAR-2026_S01]
---

# XNG Tuesday Bear-Regime Bounce Source Packet

This bounded packet combines two completely reviewed, peer-reviewed lineages:

- `strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md` preserves
  Borowski (2016), who reports a positive Tuesday sample mean for NYMEX
  natural-gas futures. The paper's statistically distinguished natural-gas
  weekday is Wednesday, not Tuesday, so Tuesday is treated as a weak
  falsification lead rather than a confirmed anomaly.
- `strategy-seeds/sources/MOP-TSMOM-2012/source.md` preserves the complete
  Moskowitz, Ooi, and Pedersen (2012) paper and its use of an instrument's own
  completed trailing-return sign as a slow state.

The OWNER-authorized QM hypothesis is narrower than either parent: buy
`XNGUSD.DWX` for a genuine Tuesday D1 session only when its completed 252-D1
log return is strictly negative, then flatten at the next D1 boundary. This
tests whether the positive Tuesday sample direction behaves as a bear-regime
bounce. The weekday, negative slow state, and long direction are jointly
load-bearing.

Neither paper tests this conjunction, predicts reversal from a negative
252-D1 state, studies the Darwinex continuous CFD, or supplies the attachment,
stop, spread, persistence, or portfolio rules. No paper statistic is imported
as an expected return, profit factor, drawdown, density, or correlation claim.

## Fixed Mechanization Boundary

- Exact carrier and clock: `XNGUSD.DWX`, D1.
- Genuine Tuesday: current broker D1 bar is Tuesday and the immediately prior
  completed broker D1 bar is Monday.
- Entry: first executable tick within five minutes of the Tuesday bar open.
- State: `ln(Close[1] / Close[253]) < 0`; equality and invalid history stay
  flat.
- Direction and hold: one BUY, closed on the first non-Tuesday D1 bar.
- Risk plumbing: one frozen `3.0 * ATR(20,D1)` stop, 2,500-point spread cap,
  two-calendar-day stale repair, and one restart-safe consumed attempt per
  broker week.
- Runtime: registered native MT5 OHLC, ATR, quote, calendar, position, deal,
  and terminal-persistent state only.

## Reputable-Source Criteria

- R1: PASS. Borowski is a named-author peer-reviewed journal study with a
  complete public copy; Moskowitz, Ooi, and Pedersen is a peer-reviewed
  *Journal of Financial Economics* paper with a complete-paper repository
  review and retrieval hash. The countertrend conjunction remains a QM
  hypothesis, not an author claim.
- R2: PASS. Weekday boundary, state horizon and sign, direction, attempt
  persistence, stop, spread cap, and exits are deterministic and frozen.
- R3: PASS. `XNGUSD.DWX` D1 is registered and the rule needs no external
  runtime feed.
- R4: PASS. Calendar, logarithm, and ATR arithmetic only; no trained model,
  adaptive fitting, grid, martingale, scale-in, or pyramiding.

## Duplicate Boundary

The deterministic pre-allocation scan returned `CLEAN` across 4,254 registry
rows and 381 cards for slug `xng-tue-bear`, strategy ID
`BOROWSKI-MOP-XNG-TUEBEAR-2026_S01`, and mechanic `Tuesday XNG long only when
completed 252-D1 return is negative`.

- `QM5_12818_xng-tue-prem` is unconditional and reads no slow state.
- `QM5_20158_xng-tue-trend` buys Tuesday only in a strictly positive 252-D1
  state; this candidate owns the disjoint negative state.
- `QM5_12603_xng-tsmom12m` is a year-round symmetric monthly trend carrier.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback, not a
  weekly calendar/slow-regime interaction.

Realized diversification is unproven. Q02 and later portfolio gates retain
full authority to retire the candidate; no correlation waiver is authorized.

## Safety Boundary

This packet authorizes one card, deterministic allocation, one EA build, one
fixed-risk backtest setfile, strict compile, and one paced Q02 enqueue. It does
not authorize manual backtesting, live artifacts, AutoTrading, T_Live,
deployment, portfolio admission, or changes to a portfolio or live manifest.

# QM5_12929_brooks-expanded-micro-channel-h1 — Strategy Spec

**EA ID:** QM5_12929
**Slug:** `brooks-expanded-micro-channel-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

This is a low-frequency H1 trend-continuation strategy. On a completed H1 bar,
it searches windows of 8 through 20 closed bars for a bullish higher-high and
higher-low staircase, or the bearish mirror. A staircase may tolerate at most
0.25 ATR of adverse low/high noise between adjacent bars. Every bar body must
be no larger than 1.50 ATR, the least-squares slope of the relevant extremes
must be at least 0.15 ATR per bar in the trade direction, and total window range
divided by its bar count must be no larger than 0.50 ATR. Longs additionally
require `close > SMA(50) > SMA(200)`; shorts use the inverse relation.

After a valid bullish window, the EA places a buy stop at the newest high plus
0.50 ATR; the bearish mirror places a sell stop at the newest low minus 0.50
ATR. Pending orders expire after three H1 bars. Initial stop loss is 0.50 ATR
beyond the opposite channel extreme, capped at 3.00 ATR from entry, and take
profit is 2.00 ATR from entry. On each new H1 bar, an open trade's stop trails
one way behind the lowest low or highest high of the last three bars with a
0.10 ATR buffer. A position is closed after 36 bars if neither protective exit
has fired. A 12-bar reuse guard, 07:00–21:00 broker-time session, 1.5-times
20-bar average spread ceiling, framework news controls, Friday close, and one
position per registered magic constrain entries.

### Framework alignment

| Card rule | Implementation |
|---|---|
| 8–20-bar HH/HL or LL/LH staircase | `Strategy_DetectExpandedChannel` |
| No-thrust, slope, and compactness gates | `Strategy_DetectExpandedChannel` and `Strategy_RegressionSlope` |
| SMA50/SMA200 macro bias | `Strategy_EntrySignal` |
| Buffered three-bar stop entry | `Strategy_EntrySignal` via `QM_BUY_STOP` / `QM_SELL_STOP` |
| Structural stop, fixed target, one-way trail, time stop | `Strategy_EntrySignal`, `Strategy_ManageOpenPosition`, `Strategy_ExitSignal` |
| Reuse, session, spread, news, and Friday controls | Strategy filters plus the V5 framework |

---

## 2. Parameters

Only strategy-specific inputs are listed here; framework risk, news, stress,
Friday-close, identity, and RNG inputs are defined in
`framework/V5_FRAMEWORK_DESIGN.md`.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_H1` | H1 only | Signal, management, and time-stop timeframe. |
| `strategy_atr_period` | 14 | 14 (card-fixed) | ATR period used by every normalized threshold. |
| `strategy_fast_sma_period` | 50 | 50 (card-fixed) | Fast macro-trend average. |
| `strategy_slow_sma_period` | 200 | 200 (card-fixed) | Slow macro-trend average. |
| `strategy_channel_min_bars` | 8 | 8–20 | Shortest candidate expanded micro-channel. |
| `strategy_channel_max_bars` | 20 | 8–20, not below minimum | Longest candidate expanded micro-channel. |
| `strategy_stair_noise_atr` | 0.25 | 0.25 (card-fixed) | Maximum adverse staircase noise in ATR units. |
| `strategy_max_body_atr` | 1.50 | 1.50 (card-fixed) | Largest permitted bar body in ATR units. |
| `strategy_min_slope_atr_per_bar` | 0.15 | 0.15 (card-fixed) | Minimum regression slope magnitude per bar. |
| `strategy_max_range_atr_per_bar` | 0.50 | 0.50 (card-fixed) | Maximum window range per bar in ATR units. |
| `strategy_entry_buffer_atr` | 0.50 | 0.50 (card-fixed) | Stop-entry offset beyond the newest extreme. |
| `strategy_initial_sl_buffer_atr` | 0.50 | 0.50 (card-fixed) | Stop-loss offset beyond the channel structure. |
| `strategy_initial_sl_cap_atr` | 3.00 | 3.00 (card-fixed) | Maximum initial stop distance from entry. |
| `strategy_tp_atr` | 2.00 | 2.00 (card-fixed) | Fixed take-profit distance from entry. |
| `strategy_pending_valid_bars` | 3 | 3 (card-fixed) | Pending-order lifetime in H1 bars. |
| `strategy_trail_lookback_bars` | 3 | 3 (card-fixed) | Closed bars used by the structural trail. |
| `strategy_trail_buffer_atr` | 0.10 | 0.10 (card-fixed) | Trail offset beyond the three-bar extreme. |
| `strategy_time_stop_bars` | 36 | 36 (card-fixed) | Maximum holding period in H1 bars. |
| `strategy_reuse_guard_bars` | 12 | 12 (card-fixed) | Minimum bars before the symbol may reuse a pattern. |
| `strategy_spread_lookback_bars` | 20 | 20 (card-fixed) | Closed-bar samples used for mean spread. |
| `strategy_spread_average_multiplier` | 1.50 | 1.50 (card-fixed) | Maximum current spread divided by mean spread. |
| `strategy_session_start_hour` | 7 | 7 (card baseline) | Inclusive broker-time entry hour. |
| `strategy_session_end_hour` | 21 | 21 baseline; 24-hour variant only at P3 | Exclusive broker-time entry hour. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`,
  `USDCAD.DWX`, and `NZDUSD.DWX` — liquid major FX markets supply the diverse
  directional continuation surface prioritized for this build.
- `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, and `WS30.DWX` — liquid
  index CFDs covered by the approved card.
- `XAUUSD.DWX` — the approved liquid-metal carrier for the same structural
  trend pattern.

Each listed carrier has an active deterministic `magic_registry.csv` row and a
matching `RISK_FIXED` backtest setfile.

**Explicitly NOT for:**

- `XAGUSD.DWX`, `XNGUSD.DWX`, and `XTIUSD.DWX` — these carriers are outside
  this card's approved instrument surface.
- Crypto and rates — no validated `.DWX` carrier is registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_tf)`; all structural OHLC reads use closed bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Low frequency; Q01 design prior 5–20, with actual cadence measured at Q02 |
| Typical hold time | Intraday to about 36 H1 bars (approximately 1.5 calendar days) |
| Expected drawdown profile | Clustered losing breakouts in choppy transitions; fixed-risk and capped structural stops bound per-trade loss |
| Regime preference | Persistent directional trends with compact stair-step continuation |
| Win rate target (qualitative) | Medium; payoff comes from trend continuation rather than a high hit rate |

These values are expectations, not acceptance evidence. Q02 and later gates
measure trade count, loss distribution, and robustness on each carrier.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book plus public trading-forum source cluster
**Pointer:** Al Brooks, *Trading Price Action: Trends* (Wiley, 2012), ISBN
978-1-118-06624-0, chapters 12 and 14; runtime card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12929_brooks-expanded-micro-channel-h1.md`
**R1–R4 verdict (Q00):** all PASS; see the approved runtime card above.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | `RISK_FIXED` | $1,000 per trade (HR4); all 13 committed backtest setfiles use `RISK_PERCENT=0` |
| Live burn-in (Q13) | `RISK_PERCENT` | Minimum-lot equivalent under an OWNER-signed manifest |
| Full live (post-Q13 PASS) | `RISK_PERCENT × PORTFOLIO_WEIGHT` | Allocated only by the approved portfolio and OWNER-signed manifest |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This build does not authorize live use.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-21 | Initial implementation from approved card | Agent task `7b431d7a-a902-4947-a932-ffa8ef3a54d7` |
| v1.1 | 2026-08-23 | Q01 recycle: document full spec and approve new-bar raw-series reads | Same agent task; compile/test deferred at active terminal ceiling |

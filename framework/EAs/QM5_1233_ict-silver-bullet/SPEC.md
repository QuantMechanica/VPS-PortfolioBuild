# QM5_1233_ict-silver-bullet - Strategy Spec

**EA ID:** QM5_1233
**Slug:** ict-silver-bullet
**Source:** fa90d4d7-7a46-5439-9ff6-96ee841913b3 (see `sources/babypips-ict-silver-bullet`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades the New York 10:00-11:00 ICT Silver Bullet window on M5. At the window start it derives buy-side and sell-side liquidity from the previous completed H1 candle and the 09:00-09:59 New York M5 range. A setup requires a sweep beyond one side of that liquidity, a close back inside the level within three M5 bars, and a three-bar Fair Value Gap; the EA places a limit order at the FVG midpoint with a structural stop and either the opposing 09:00-10:00 liquidity target or a 2.0R fallback. Open positions are closed by SL/TP, framework Friday close, or the 11:55 New York time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | M5 only for baseline | Execution timeframe for the sweep and FVG pattern. |
| `strategy_ny_entry_start_hhmm` | `1000` | 0000-2359 | New York time when the EA starts arming setups. |
| `strategy_ny_entry_end_hhmm` | `1100` | 0000-2359 | New York time when new entries stop and pending orders are cancelled. |
| `strategy_ny_time_exit_hhmm` | `1155` | 0000-2359 | New York time stop for open positions. |
| `strategy_sweep_buffer_points` | `5` | >=0 | Minimum penetration beyond liquidity before a sweep counts. |
| `strategy_stop_buffer_points` | `5` | >=0 | Stop buffer beyond the sweep/FVG stop side. |
| `strategy_min_stop_points` | `25` | >0 | Minimum entry-to-stop distance in points. |
| `strategy_atr_period_m5` | `14` | >0 | ATR period for M5 stop-distance and volatility checks. |
| `strategy_atr_period_h1` | `14` | >0 | ATR period for H1 session-quality check. |
| `strategy_max_stop_atr_mult` | `1.50` | >0 | Maximum stop distance as a multiple of M5 ATR. |
| `strategy_min_reward_risk` | `1.50` | >0 | Minimum RR required for the opposing-liquidity target. |
| `strategy_take_profit_rr` | `2.00` | >0 | Fixed RR fallback target when liquidity target is too close. |
| `strategy_max_displacement_bars` | `3` | 1-10 | Maximum M5 bars allowed between sweep and return inside liquidity. |
| `strategy_min_range_atr_h1_mult` | `0.35` | >=0 | Minimum 09:00-10:00 range versus H1 ATR. |
| `strategy_min_atr_m5_mult` | `0.50` | >=0 | Minimum current M5 ATR versus historical same-hour ATR proxy. |
| `strategy_atr_median_days` | `20` | 1-20 | Lookback days for the volatility median proxy. |
| `strategy_max_spread_points` | `35` | >=0 | Absolute spread cap; zero modeled `.DWX` spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX symbol with M5/H1 DWX history.
- `GBPUSD.DWX` - card-listed major FX symbol with M5/H1 DWX history.
- `USDJPY.DWX` - card-listed major FX symbol with M5/H1 DWX history.
- `AUDUSD.DWX` - card-listed major FX symbol with M5/H1 DWX history.
- `USDCAD.DWX` - card-listed major FX symbol with M5/H1 DWX history.
- `NZDUSD.DWX` - card-listed major FX symbol with M5/H1 DWX history.
- `XAUUSD.DWX` - card-listed gold symbol with M5/H1 DWX history.
- `XTIUSD.DWX` - card-listed crude oil symbol with M5/H1 DWX history.
- `NDX.DWX` - card-listed Nasdaq index mapping in the DWX registry.
- `WS30.DWX` - card-listed Dow index mapping in the DWX registry.
- `GDAXI.DWX` - card-listed DAX index mapping in the DWX registry.
- `UK100.DWX` - card-listed FTSE index mapping in the DWX registry.

**Explicitly NOT for:**
- `SPX500.DWX` - not present in the DWX symbol matrix.
- `SPY.DWX` - not present in the DWX symbol matrix.
- `ES.DWX` - not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | Previous completed `H1` candle for reference liquidity and H1 ATR for range-quality filtering |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Intraday, normally minutes; forced flat by 11:55 New York time |
| Expected drawdown profile | Event-like intraday losses bounded by one fixed-risk position per symbol/session |
| Regime preference | Liquidity-sweep reversal or continuation during active New York AM conditions |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fa90d4d7-7a46-5439-9ff6-96ee841913b3
**Source type:** public web education source
**Pointer:** `https://www.babypips.com/learn/forex/ict-silver-bullet`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1233_ict-silver-bullet.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | f4d481cb-fe64-4705-ae47-ff271a77c226 |

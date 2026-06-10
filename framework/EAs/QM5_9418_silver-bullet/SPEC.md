# QM5_9418_silver-bullet — Strategy Spec

**EA ID:** QM5_9418
**Slug:** `silver-bullet`
**Source:** `fa90d4d7-7a46-5439-9ff6-96ee841913b3` (see `strategy-seeds/sources/fa90d4d7-7a46-5439-9ff6-96ee841913b3/`)
**Author of this spec:** Development
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

At the start of each ICT Silver Bullet session window (10:00 broker / 03:00 ET and 17:00 broker / 10:00 ET), the EA locks the high and low of the immediately preceding completed H1 candle. During the window, it monitors M5 bars for a liquidity sweep: price trading beyond the prior H1 level by a small ATR-based threshold. Once a sweep occurs, the EA waits for an M5 bar to close back through the swept level (reentry). If an optional 3-candle fair value gap (FVG) exists on the reentry candle or either of the two preceding M5 candles, a market order is entered in the reentry direction. The stop loss is placed beyond the sweep extreme by a buffer, and the take profit targets the opposite side of the prior H1 range capped at 2R. A time stop closes any remaining position 90 minutes after the window opened. One trade is allowed per session window per symbol.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sweep_atr_mult` | 0.05 | 0.0–0.5 | Sweep threshold = mult × ATR(14, M5); price must breach prior H1 level by this much |
| `strategy_stop_atr_mult` | 0.10 | 0.0–0.5 | SL buffer beyond sweep extreme in ATR units |
| `strategy_spread_atr_limit` | 0.20 | 0.0–1.0 | Skip entry if current spread exceeds this fraction of ATR(14, M5) |
| `strategy_atr_period` | 14 | 5–50 | ATR period on M5 timeframe |
| `strategy_fvg_required` | true | bool | Require 3-candle FVG confluence on the reentry candle |
| `strategy_use_london_window` | true | bool | Enable 10:00 broker window (03:00 ET London pre-open) |
| `strategy_use_ny_window` | true | bool | Enable 17:00 broker window (10:00 ET New York cash open) |
| `strategy_entry_cutoff_min` | 45 | 10–60 | No new entries after this many minutes into the window |
| `strategy_time_stop_min` | 90 | 60–180 | Close any open position after this many minutes from window start |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major liquid FX pair; high-volume during both London and NY windows, tight spreads
- `GBPUSD.DWX` — major liquid FX pair; strong liquidity sweeps around ICT session opens
- `XAUUSD.DWX` — gold; highly reactive to NY open session, suitable session liquidity sweep behaviour
- `NDX.DWX` — Nasdaq 100 index CFD; NY open window directly aligns with cash market open
- `GDAXI.DWX` — DAX 40 (ported from card's GER40.DWX, which has no DWX equivalent; GDAXI.DWX is the canonical DAX CFD); active during London window

**Explicitly NOT for:**
- `GER40.DWX` — not in DWX symbol matrix; GDAXI.DWX used instead

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_H1` for prior-hour high/low reference at window start |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~60 |
| Typical hold time | 15 minutes to 90 minutes (time stop) |
| Expected drawdown profile | Intraday only; no overnight hold; individual DD bounded by 2R per trade |
| Regime preference | mean-revert / liquidity-sweep |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fa90d4d7-7a46-5439-9ff6-96ee841913b3`
**Source type:** `forum`
**Pointer:** BabyPips — ICT Silver Bullet (https://www.babypips.com/trading/what-is-ict-trading-the-most-accurate-strategy-in-forex, Michael Huddleston / ICT)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9418_silver-bullet.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | b760527c-92e8-42a0-b366-6a8581b885f3 |

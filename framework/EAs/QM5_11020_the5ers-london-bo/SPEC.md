# QM5_11020_the5ers-london-bo — Strategy Spec

**EA ID:** QM5_11020
**Slug:** `the5ers-london-bo`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (The5ers blog interview with Jacques S)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Pre-London breakout on M15. Each London day, the EA builds a pre-London range from
the high/low of the M15 bars whose London local time falls in 06:00–07:00. At/after
07:00 London it places two pending stop orders: a BUY_STOP one tick above the range
high and a SELL_STOP one tick below the range low. When one side fills, the opposite
unfilled order is cancelled. Any orders still unfilled at 10:00 London are cancelled.
The stop loss sits on the opposite side of the range plus a 0.1×ATR(M15,96) buffer;
the take profit is 2R from the stop-order price. An open position is closed at 12:00
London (signal exit) and force-closed by 16:00 London (end-of-day). The range is only
traded when its height is between 0.4× and 1.5× ATR(M15,96), the SL distance is at
least 3× the current spread and at most 1.5× ATR, and the spread is below 20% of the
range height (spread checks fail open on .DWX zero modeled spread). Trades Tuesday–
Friday only (Monday optional input, default off). One trade per symbol per day, one
position per magic. London session timing is derived from each bar's broker timestamp
(DXZ NY-Close GMT+2/+3) via QM_BrokerToUTC then a self-derived UK-DST offset
(BST = UTC+1 from last Sunday of March to last Sunday of October, else GMT = UTC+0).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_start_hhmm` | 600 | 0-2359 | Pre-London range window start (London local) |
| `strategy_range_end_hhmm` | 700 | 0-2359 | Pre-London range window end, exclusive (London local) |
| `strategy_place_hhmm` | 700 | 0-2359 | Place the bracket at/after this London time |
| `strategy_cancel_hhmm` | 1000 | 0-2359 | Cancel unfilled brackets at/after this London time |
| `strategy_signal_exit_hhmm` | 1200 | 0-2359 | Close open position at/after this London time |
| `strategy_eod_exit_hhmm` | 1600 | 0-2359 | Hard end-of-day close (London local) |
| `strategy_atr_period` | 96 | 14-200 | ATR(M15) period for range/stop sizing |
| `strategy_range_min_atr_mult` | 0.4 | 0.1-1.0 | Skip if range height < this × ATR |
| `strategy_range_max_atr_mult` | 1.5 | 1.0-3.0 | Skip if range height > this × ATR (also stop-distance cap) |
| `strategy_stop_buffer_atr_mult` | 0.1 | 0.0-0.5 | SL buffer beyond opposite range side, in ATR |
| `strategy_reward_r` | 2.0 | 1.0-3.0 | Take-profit R multiple |
| `strategy_breakout_ticks` | 1 | 1-10 | Stop-order offset beyond the range edge, in ticks |
| `strategy_min_stop_spread_mult` | 3.0 | 1.0-10.0 | Skip if SL distance < this × current spread |
| `strategy_spread_pct_of_range` | 20.0 | 5.0-50.0 | Skip if spread > this % of range height |
| `strategy_trade_monday` | false | bool | Trade Monday too (card default Tue–Fri only) |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — primary London-liquidity major; cable is the canonical London-breakout pair.
- `EURUSD.DWX` — most-liquid major, strong London-session volume expansion.
- `EURJPY.DWX` — JPY cross with strong London participation; range-breakout friendly.
- `GBPJPY.DWX` — high-volatility JPY cross, classic London-breakout vehicle.
- `XAUUSD.DWX` — gold reacts to London fix flows; session-range breakout applies.

**Explicitly NOT for:**
- US-index symbols (NDX/WS30/SP500.DWX) — cash session is afternoon broker time, not London open; the pre-London range window would land in dead hours.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` (ATR + range both on M15) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~140` |
| Typical hold time | `intraday — minutes to a few hours (closed by 16:00 London at latest)` |
| Expected drawdown profile | `clustered intraday losing streaks during low-volatility / news-quiet weeks` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `low-to-medium (2R target offsets sub-50% hit rate)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** `forum` (trading-firm blog interview)
**Pointer:** `https://the5ers.com/trends-in-the-market/` (The5ers Team interview with Jacques S)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11020_the5ers-london-bo.md`

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
| v1 | 2026-06-17 | Initial build from card | pending-stop London bracket, broker-time UK-DST session |

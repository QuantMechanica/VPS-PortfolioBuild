# QM5_9300_mql5-london-break — Strategy Spec

**EA ID:** QM5_9300
**Slug:** `mql5-london-break`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Each broker trading day, the EA measures the price range from 03:00 to 08:00 broker time (the pre-London window) using M15 bars. The setup is only valid when the range width falls between `MinRangePoints` (100) and `MaxRangePoints` (300) — filtering out both choppy and already-extended days.

At the 08:00 M15 bar open, the EA places a buy-stop order `OrderOffsetPoints` above the pre-London high and a sell-stop order `OrderOffsetPoints` below the pre-London low. Whichever stop is triggered first becomes the active position; the opposing order is immediately cancelled. Unfilled pending orders are cancelled at `SessionExpiryHour` (12:00 broker time). Stop loss is a fixed `StopLossPoints` (500) from entry; take profit is `StopLossPoints × RRRatio` (1:1 default). No trailing or partial close. Maximum one position per magic number.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pre_london_start_hour` | 3 | 0–6 | Broker hour for start of pre-London range measurement |
| `strategy_pre_london_end_hour` | 8 | 6–10 | London open hour; orders placed at this bar's opening |
| `strategy_min_range_points` | 100 | 20–500 | Minimum valid range width in points (filters tight sessions) |
| `strategy_max_range_points` | 300 | 100–1000 | Maximum valid range width in points (filters already-extended sessions) |
| `strategy_order_offset_points` | 10 | 0–50 | Entry offset beyond range high (buy) or range low (sell) in points |
| `strategy_stop_loss_points` | 500 | 100–2000 | Fixed stop-loss distance from entry in points |
| `strategy_rr_ratio` | 1.0 | 0.5–5.0 | TP = SL × RRRatio (1.0 = 1:1 risk:reward) |
| `strategy_session_expiry_hour` | 12 | 9–17 | Broker hour at which unfilled pending orders are cancelled |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary FX pair with strong London session participation and reliable daily range structure
- `GBPUSD.DWX` — Cable is the most London-centric FX pair; highest ATR in the 08:00–12:00 window
- `GBPJPY.DWX` — High-volatility cross with strong directional momentum during London open
- `GDAXI.DWX` — German DAX 40 index; listed as GER40 in card, mapped to canonical DWX symbol GDAXI.DWX; opens at 09:00 CET / 08:00 broker time, making it a natural London-open breakout candidate

**Explicitly NOT for:**
- `GER40.DWX` — Not a valid DWX symbol (not in dwx_symbol_matrix.csv); mapped to GDAXI.DWX
- Commodity or equity symbols outside the London session overlap

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~120 (source estimate after range and one-position filters) |
| Typical hold time | Minutes to hours (intraday; closed by SL/TP or 21:00 Friday-close) |
| Expected drawdown profile | Moderate; fixed SL limits per-trade loss; max 1 open position |
| Regime preference | Volatility-expansion / breakout; London directional momentum |
| Win rate target (qualitative) | medium (1:1 RR needs >50% to be profitable) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article (MQL5 community)
**Pointer:** "Automating Trading Strategies in MQL5 (Part 24): London Session Breakout System with Risk Management and Trailing Stops", Allan Munene Mutiiria, MQL5 Articles, 2025-07-23
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9300_mql5-london-break.md`

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
| v1 | 2026-06-10 | Initial build from card | 8816db79-aa35-42a5-85f2-ccd179a3d562 |

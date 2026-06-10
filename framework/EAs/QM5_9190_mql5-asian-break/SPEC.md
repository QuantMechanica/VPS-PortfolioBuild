<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9190_mql5-asian-break — Strategy Spec

**EA ID:** QM5_9190
**Slug:** `mql5-asian-break`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA identifies a daily "Asian session box" by scanning M15 bars whose broker-time hour falls within the configurable session window (default 01:00–05:00 broker, equivalent to 23:00–03:00 UTC at UTC+2). It caches the session high and low once per day after the session closes. A 50-period SMA acts as a trend filter: if the last closed bar's close is above the SMA, a buy-stop is placed at BoxHigh + offset pips; if below, a sell-stop at BoxLow − offset pips. The stop loss sits at the opposite box edge (BoxLow − offset for longs, BoxHigh + offset for shorts). Take profit is set at entry ± (entry−SL distance) × RR ratio (default 2.0). All pending orders are cancelled and all open positions closed at the daily exit hour (default 22:00 broker).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 50 | 10–200 | SMA period for trend filter (price vs SMA direction) |
| `strategy_asian_start_hour` | 1 | 0–23 | Asian session box start, broker hour (01:00 = 23:00 UTC at UTC+2) |
| `strategy_asian_end_hour` | 5 | 0–23 | Asian session box end, broker hour (05:00 = 03:00 UTC at UTC+2) |
| `strategy_exit_hour` | 22 | 1–23 | Broker hour to cancel all pending orders and close open positions |
| `strategy_breakout_offset_pips` | 5 | 1–50 | Buffer pips outside box for pending stop entry level |
| `strategy_rr_ratio` | 2.0 | 0.5–10.0 | Take-profit = SL distance × this ratio |
| `strategy_max_spread_pips` | 3 | 0–20 | Skip entry if spread exceeds this (0 = disabled) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair, tight spread, well-defined Asian session range
- `GBPUSD.DWX` — liquid major FX pair, active during European follow-through after Asian box
- `XAUUSD.DWX` — gold CFD, significant Asian-session activity (Tokyo and HK markets)

**Explicitly NOT for:**
- Index CFDs — Asian session behaviour is index-specific and the strategy is calibrated for FX/metals spread assumptions

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
| Trades / year / symbol | ~100 |
| Typical hold time | Hours (intraday; closed by exit_hour at latest) |
| Expected drawdown profile | Moderate intraday; daily time-exit prevents overnight exposure |
| Regime preference | breakout / trend-continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 9): Building an Expert Advisor for the Asian Breakout Strategy", MQL5 Articles, 2025-02-25
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9190_mql5-asian-break.md`

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
| v1 | 2026-06-10 | Initial build from card | dab0ebda-7de4-4b03-9c44-296a42617019 |

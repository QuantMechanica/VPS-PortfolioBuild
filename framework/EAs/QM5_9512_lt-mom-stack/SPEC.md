# QM5_9512_lt-mom-stack — Strategy Spec

**EA ID:** QM5_9512
**Slug:** `lt-mom-stack`
**Source:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c` (see `strategy-seeds/sources/1a059d6d-84fa-5d0c-94c5-86dd0481637c/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed D1 bar, six SMA crossover pairs (fast/slow: 2/8, 4/16, 8/32, 16/64, 32/128, 64/256) are computed. Each pair produces a raw signal (SMA_fast minus SMA_slow), which is divided by a volatility proxy (ATR-25 as InstrumentRiskPriceUnits) and multiplied by the Carver-supplied scaling factor, then clamped to ±20. The six forecasts are averaged into a single combined forecast. The EA goes long when combined_forecast exceeds +2 and goes short when it falls below −2. A long position is closed when the forecast drops to or below 0; a short is closed when the forecast rises to or above 0. Re-entry on the opposite side requires the forecast to breach ±2 on a later D1 close. An emergency hard stop is set at 2.5 × ATR(20, D1) from entry. At least three valid pair forecasts are required before any position is opened.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_risk_atr_period` | 25 | 10–50 | ATR lookback for InstrumentRiskPriceUnits (forecast denominator) |
| `strategy_sl_atr_period` | 20 | 10–50 | ATR lookback for emergency stop distance |
| `strategy_sl_atr_mult` | 2.5 | 1.5–4.0 | Emergency stop = ATR × this multiplier |
| `strategy_entry_threshold` | 2.0 | 1.0–5.0 | Enter long/short only if |combined_forecast| exceeds this |
| `strategy_min_forecasts` | 3 | 1–6 | Minimum valid SMA-pair forecasts before trading is allowed |
| `strategy_spread_mult` | 2.0 | 1.5–4.0 | Block new entry if current spread exceeds mult × EWMA spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair, strong trend characteristics, well-suited to daily momentum
- `GBPUSD.DWX` — liquid major FX pair with persistent trend regimes
- `USDJPY.DWX` — major FX pair, clear trend-following history on D1
- `AUDUSD.DWX` — commodity-linked FX, responds well to macro momentum signals
- `GDAXI.DWX` — DAX 40 index (card named GER40.DWX; ported to GDAXI.DWX, the canonical DWX symbol for the DAX)
- `NDX.DWX` — Nasdaq 100, strong trend momentum on D1
- `WS30.DWX` — Dow Jones 30, diversified US index exposure
- `XAUUSD.DWX` — Gold, well-known trend-following instrument in multi-asset momentum systems

**Explicitly NOT for:**
- `GER40.DWX` — not in dwx_symbol_matrix.csv; canonical DAX symbol is GDAXI.DWX (see open_questions)
- `SP500.DWX` — card does not name SP500; not registered for this EA

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (D1 chart) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~50 |
| Typical hold time | days to weeks |
| Expected drawdown profile | moderate trend-following drawdowns; emergency stop at 2.5 × ATR(20) |
| Regime preference | trend |
| Win rate target (qualitative) | low (classic trend-follower profile: many small losses, fewer large wins) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c`
**Source type:** book
**Pointer:** Robert Carver, *Leveraged Trading*, Harriman House, 2019 (ISBN 9780857197214), Chapters 6, 8, 10; official companion spreadsheet tab "Moving average crossover forecasts"
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9512_lt-mom-stack.md`

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
| v1 | 2026-06-11 | Initial build from card | b0c05c14-68cc-41e7-90b1-40db9cb14d15 |

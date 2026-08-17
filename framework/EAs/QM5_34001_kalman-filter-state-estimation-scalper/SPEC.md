# QM5_34001_kalman-filter-state-estimation-scalper - Strategy Spec

**EA ID:** QM5_34001
**Slug:** `kalman-filter-state-estimation-scalper`
**Source:** `kalman-filter-state-estimation-scalper-official-source` (see `strategy-seeds/sources/kalman-filter-state-estimation-scalper-official-source/`)
**Author of this spec:** Development
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_34001_kalman-filter-state-estimation-scalper.md`. See that card body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_34001_kalman-filter-state-estimation-scalper.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

- Discrete 1D Kalman Filter state estimation on closed M15 bar prices.
- Innovation Z-Score calculation: Z = (Close - predicted_state) / sqrt(innovation_covariance).
- Long Entry: Z <= -2.00 AND Close[1] > Open[1].
- Short Entry: Z >= +2.00 AND Close[1] < Open[1].
- Stop Loss: 1.5 * ATR(14, M15)[1].
- Take Profit: Placed at Kalman State Estimate (equilibrium reversion).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_process_noise_q` | 0.0001 | 0.00001 - 0.01 | Process noise covariance parameter Q |
| `strategy_measurement_noise_r` | 0.01 | 0.001 - 0.1 | Measurement noise variance parameter R |
| `strategy_z_threshold` | 2.00 | 1.5 - 3.0 | Innovation Z-Score threshold |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for stop loss sizing |
| `strategy_sl_atr_mult` | 1.5 | 1.0 - 2.5 | Initial SL in ATR multiples |
| `strategy_spread_atr_period` | 14 | 10 - 20 | Spread filter ATR period |
| `strategy_spread_atr_mult` | 1.8 | 1.2 - 2.5 | Spread filter threshold |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - registered in magic_numbers.csv for this EA (slot 0)
- `GBPUSD.DWX` - registered in magic_numbers.csv for this EA (slot 1)
- `USDJPY.DWX` - registered in magic_numbers.csv for this EA (slot 2)

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M15)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Cadence note | 80-160 high-conviction trades per year |
| Typical hold time | Intraday scalping / mean reversion |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Mean-reverting / ranging |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `kalman-filter-state-estimation-scalper-official-source`
**Pointer:** `strategy-seeds/sources/kalman-filter-state-estimation-scalper-official-source/`
**R1-R4 verdict (Q00):** all PASS - see
`artifacts/cards_approved/QM5_34001_kalman-filter-state-estimation-scalper.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

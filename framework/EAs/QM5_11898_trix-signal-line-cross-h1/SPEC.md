# QM5_11898_trix-signal-line-cross-h1 — Strategy Spec

**EA ID:** QM5_11898
**Slug:** trix-signal-line-cross-h1
**Source:** e7b3d2c8-5a91-5d46-9f72-c4b8e1f6d3a5
**Author of this spec:** gemini
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Trades momentum crossover signals using the Jack Hutson TRIX indicator (ema_period=14, signal_period=9) on the H1 timeframe. A bullish signal-line cross occurs when TRIX crosses above its Signal line from below, and is trend-filtered to require TRIX > 0. A bearish cross occurs when TRIX crosses below its Signal line from above, and is trend-filtered to require TRIX < 0. Initial stop loss is set at 2.0 × ATR(14) from entry, and take profit is set at 2.0 × the initial risk (2:1 RR). Open positions are also closed immediately on opposite signal-line crossovers or after a hard timeout of 96 H1 bars (4 days).

---

## 2. Parameters

Table of every input parameter, its default, range, and meaning.

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | "H1" | "H1" | Strategy timeframe |
| `strategy_trix_ema_period` | 14 | 10-20 | EMA period used for TRIX calculation |
| `strategy_trix_signal_period` | 9 | 5-15 | SMA period used for Signal line calculation |
| `strategy_zero_line_filter` | `true` | `true/false` | Enable/disable zero line directional filter |
| `strategy_atr_period_for_stop` | 14 | 10-20 | ATR period for stop loss calculation |
| `strategy_atr_stop_mult` | 2.0 | 1.5-3.0 | ATR multiplier for stop loss distance |
| `strategy_target_rr` | 2.0 | 1.0-3.0 | Risk-to-reward ratio for take profit |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- `EURUSD.DWX` — liquid major forex pair
- `GBPUSD.DWX` — liquid major forex pair
- `USDJPY.DWX` — liquid major forex pair
- `USDCAD.DWX` — liquid major forex pair
- `USDCHF.DWX` — liquid major forex pair
- `AUDUSD.DWX` — liquid major forex pair
- `NZDUSD.DWX` — liquid major forex pair
- `EURJPY.DWX` — liquid forex cross pair
- `GBPJPY.DWX` — liquid forex cross pair
- `AUDJPY.DWX` — liquid forex cross pair

**Explicitly NOT for:**
- None

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | 1-4 days |
| Expected drawdown profile | medium |
| Regime preference | trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e7b3d2c8-5a91-5d46-9f72-c4b8e1f6d3a5
**Source type:** forum
**Pointer:** `forexstrategiesresources.com, 'TRIX Strategy Trading System' (~2013)`
**R1–R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11898_trix-signal-line-cross-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-10 | Initial build from card | ccde1b2a-b70f-466a-bdf6-e626b2af48b4 |

# QM5_1629_ehlers-cybernetic-cycle-h4 — Strategy Spec

**EA ID:** QM5_1629
**Slug:** `ehlers-cybernetic-cycle-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

This EA mechanizes the approved Ehlers Cybernetic Cycle strategy on H4 bars. It computes a 4-bar weighted smoothing of median price, then runs a 2-pole IIR high-pass cycle filter with a fixed smoothing constant alpha=0.07. Long trades enter on a closed-bar zero line upward crossover of the cycle waveform, confirmed by recent cycle amplitude exceeding 0.5% of price and a D1 SMA(200) macro trend filter. Short trades mirror this logic on downward zero crossings below the D1 SMA(200). Trades use a 2.0 ATR hard stop and take profit, break-even trailing at 1.0 ATR favorable excursion, exit on opposite strong cycle crosses, and close after a 20-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_alpha` | 0.07 | 0.01-0.50 | Fixed Cybernetic Cycle smoothing constant. |
| `strategy_amplitude_window` | 20 | >=2 | Lookback window for recent cycle amplitude calculation. |
| `strategy_amplitude_threshold` | 0.005 | >0.0 | Minimum required cycle amplitude as a fraction of price (0.5%). |
| `strategy_d1_sma_period` | 200 | >=10 | D1 SMA period for macro trend filter. |
| `strategy_atr_period` | 14 | >=2 | ATR period for stop-loss and take-profit sizing. |
| `strategy_sl_atr_mult` | 2.0 | >0.0 | Stop loss distance in ATR multiples. |
| `strategy_tp_atr_mult` | 2.0 | >0.0 | Take profit distance in ATR multiples. |
| `strategy_be_trigger_atr_mult` | 1.0 | >0.0 | Profit trigger in ATR multiples to move stop loss to break-even. |
| `strategy_time_stop_bars` | 20 | >=1 | Maximum holding duration in H4 bars before time-stop exit. |
| `strategy_spread_atr_mult` | 0.3 | >0.0 | Maximum allowed spread as a fraction of ATR(14). |
| `strategy_cooldown_bars` | 4 | >=0 | Minimum H4 bars between consecutive entries in the same direction. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major with full H4 and D1 price history.
- `GBPUSD.DWX` — liquid FX major with strong cyclical characteristics.
- `USDJPY.DWX` — liquid FX major with trending and cycle regimes.
- `AUDUSD.DWX` — liquid commodity currency pair.
- `USDCAD.DWX` — liquid North American currency pair.
- `USDCHF.DWX` — liquid European currency pair.
- `NZDUSD.DWX` — liquid Pacific currency pair.
- `NDX.DWX` — liquid US tech equity index CFD.
- `WS30.DWX` — liquid US broad equity index CFD.
- `SP500.DWX` — liquid US large-cap equity index CFD.
- `GDAXI.DWX` — liquid European equity index CFD.
- `UK100.DWX` — liquid UK equity index CFD.
- `XAUUSD.DWX` — liquid precious metals CFD.
- `XTIUSD.DWX` — liquid energy CFD.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` — unsupported by broker data feeds.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` close vs SMA(200) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | `16 to 24 H4 bars (cycles complete rapidly; bounded by 20-bar time stop)` |
| Expected drawdown profile | `Controlled drawdown profile with 2.0 ATR stop loss and 1.0 ATR break-even move` |
| Regime preference | `Cyclical momentum in alignment with macro daily trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `book / trade-press`
**Pointer:** `John F. Ehlers — Cybernetic Analysis for Stocks and Futures (Wiley 2004, ISBN 978-0-471-46307-8) ch. 4 pp. 31-45`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1629_ehlers-cybernetic-cycle-h4.md`

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
| v1 | 2026-08-22 | Initial build from card | 810145d0-5aeb-4a8f-9830-b0bdaadac57f |

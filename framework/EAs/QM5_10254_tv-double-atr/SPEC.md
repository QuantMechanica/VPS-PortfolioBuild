# QM5_10254_tv-double-atr — Strategy Spec

**EA ID:** QM5_10254
**Slug:** `tv-double-atr`
**Source:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5` (see `strategy-seeds/sources/c84ae47e-8ea0-56f1-8b25-4436b6dda5b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA computes ATR(14) and maintains a directional trailing stop at two times ATR from the most recent closed bar. In bull mode the stop ratchets upward as `max(previous stop, close - 2.0 * ATR)`; in bear mode it ratchets downward as `min(previous stop, close + 2.0 * ATR)`. A long signal occurs when the prior state is bear mode and the closed bar finishes above the active bear stop, and a short signal occurs when the prior state is bull mode and the closed bar finishes below the active bull stop. Opposite flips close the current position and open the new direction at the next bar open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | MT5 timeframe enum | Timeframe used for ATR and close/stop flip evaluation. |
| `strategy_atr_period` | `14` | `1+` | ATR lookback used by the Double ATR stop. |
| `strategy_atr_stop_mult` | `2.0` | `> 0` | Multiplier for the ratcheting ATR stop. |
| `strategy_catastrophic_mult` | `5.0` | `> 0` | Maximum catastrophic stop distance in ATR units. |
| `strategy_warmup_bars` | `120` | `strategy_atr_period + 2+` | Closed bars used once to seed the ratcheting stop state. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — card primary symbol and a liquid ATR-friendly metals market.
- `NDX.DWX` — portable DWX index from the card's default P2 basket.
- `WS30.DWX` — portable DWX index from the card's default P2 basket.
- `EURUSD.DWX` — portable DWX forex major from the card's default P2 basket.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — no broker or custom-symbol tick data is guaranteed for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `65` |
| Typical hold time | hours to days, until the opposite ATR stop flip |
| Expected drawdown profile | stop-led trend/reversal drawdowns bounded by the active ATR stop and 5xATR catastrophic cap |
| Regime preference | reversal with trend-following trailing phase |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5`
**Source type:** TradingView public Pine script
**Pointer:** `https://www.tradingview.com/script/xG3SlzJB-Double-ATR-Reversal/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10254_tv-double-atr.md`

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
| v1 | 2026-06-09 | Initial build from card | deee5241-5931-4c0f-a390-a64b4ab08e10 |

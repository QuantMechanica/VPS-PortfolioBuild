# QM5_10254_tv-double-atr - Strategy Spec

**EA ID:** QM5_10254
**Slug:** tv-double-atr
**Source:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5 (see `sources/tradingview-top-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA computes ATR(14) and maintains a ratcheting Double ATR stop with a 2.0 multiplier. In bull mode, the stop can only rise and is based on close minus 2.0 ATR; in bear mode, the stop can only fall and is based on close plus 2.0 ATR. A long signal occurs when the prior state was bear mode and the last closed bar closes above the active bear stop. A short signal occurs when the prior state was bull mode and the last closed bar closes below the active bull stop. Opposite flips close the current position and open the reversed direction at the next bar's market entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR lookback used for the Double ATR stop. |
| `strategy_double_atr_mult` | 2.0 | > 0 | Multiplier for the active ratcheting stop. |
| `strategy_catastrophic_atr_mult` | 5.0 | > 0 | Fallback hard-stop distance from entry if the active stop is invalid. |
| `strategy_bootstrap_bars` | 200 | `strategy_atr_period + 2` or higher | Number of closed bars used once at startup to seed the ATR stop state. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card primary symbol; liquid DWX gold market with OHLC and ATR data.
- `NDX.DWX` - Card P2 portable symbol; liquid DWX index market with OHLC and ATR data.
- `WS30.DWX` - Card P2 portable symbol; liquid DWX index market with OHLC and ATR data.
- `EURUSD.DWX` - Card P2 portable symbol; liquid DWX forex market with OHLC and ATR data.

**Explicitly NOT for:**
- None specified by the approved card.

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
| Trades / year / symbol | 65 |
| Typical hold time | Not specified in frontmatter; reversal positions hold until the next opposite ATR-stop flip, SL, or Friday close. |
| Expected drawdown profile | Not specified in frontmatter; stop-led reversal profile with V5 kill-switch protection. |
| Regime preference | Reversal and trend-following phases from ATR-stop flips. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
**Source type:** TradingView public open-source script
**Pointer:** `https://www.tradingview.com/script/xG3SlzJB-Double-ATR-Reversal/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10254_tv-double-atr.md`

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
| v1 | 2026-06-09 | Initial build from card | deee5241-5931-4c0f-a390-a64b4ab08e10 |

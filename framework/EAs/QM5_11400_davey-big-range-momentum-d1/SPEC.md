# QM5_11400_davey-big-range-momentum-d1 - Strategy Spec

**EA ID:** QM5_11400
**Slug:** `davey-big-range-momentum-d1`
**Source:** `fcee8d26-0910-56f3-a0f4-7a0d0a1dfdc9` (see `strategy-seeds/sources/fcee8d26-0910-56f3-a0f4-7a0d0a1dfdc9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates the most recently closed D1 bar. It compares that bar's high-low range to the average and standard deviation of the prior range sample; if the range is greater than `average + 2.0 * standard deviation`, the bar is treated as an exceptional range expansion. It buys on the next bar when the closed bar's close is above the close from `daysback` bars ago, and sells when the closed bar's close is below that reference close. Exits are handled by an ATR(14) take-profit, ATR(14) stop-loss capped at 80 pips, break-even movement at +1 ATR, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_lookback` | 20 | 10-30 P3 sweep; >=2 required | Number of prior closed bars used for range average and standard deviation. |
| `strategy_daysback` | 5 | 3-10 P3 sweep; >=1 required | Reference close offset for determining long or short momentum direction. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for SL, TP, and break-even trigger. |
| `strategy_range_std_mult` | 2.0 | >0 | Standard deviation multiplier in the range outlier test. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiple for the initial stop-loss before applying the 80-pip cap. |
| `strategy_atr_tp_mult` | 2.0 | 1.5-2.5 P3 sweep; >0 | ATR multiple for the take-profit. |
| `strategy_sl_cap_pips` | 80 | >0, or 0 to disable | Maximum stop-loss distance in pips for P2. |
| `strategy_spread_cap_pips` | 25 | >0, or 0 to disable | Maximum allowed spread in pips before entry is suppressed. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed D1 DWX FX major with sufficient daily range data.
- `GBPUSD.DWX` - Card-listed D1 DWX FX major with sufficient daily range data.
- `USDJPY.DWX` - Card-listed D1 DWX FX major with sufficient daily range data.
- `AUDUSD.DWX` - Card-listed D1 DWX FX major with sufficient daily range data.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use `.DWX` custom symbols.
- Symbols outside `dwx_symbol_matrix.csv` - no broker/custom-symbol tick data is registered for them.
- Intraday-only venues - the card specifies D1 bars and daily range statistics.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Not specified in card frontmatter; expected to be multi-day D1 bracket trades. |
| Expected drawdown profile | Volatility-expansion momentum entries with fixed-risk ATR brackets; drawdown should cluster in false-breakout/range-reversion regimes. |
| Regime preference | Volatility-expansion / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fcee8d26-0910-56f3-a0f4-7a0d0a1dfdc9`
**Source type:** webinar / local PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\374755020-My-5-Favorite-Entries.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11400_davey-big-range-momentum-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | ae37c429-6786-4617-9a10-cfe46e925a8f |

# QM5_11560_lien-xtreme-fade-bb3-adx25-m15 - Strategy Spec

**EA ID:** QM5_11560
**Slug:** lien-xtreme-fade-bb3-adx25-m15
**Source:** f8b7c68d-870a-5568-81ff-9b825dcddd32 (see `strategy-seeds/sources/f8b7c68d-870a-5568-81ff-9b825dcddd32/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA implements Kathy Lien's M15 X-Treme Fade setup using two Bollinger envelopes and an ADX range filter. A signal requires a completed bar to close outside the 3-standard-deviation Bollinger Band, followed by the next completed bar retracing back inside the matching 2-standard-deviation band while ADX(14) is below 25. Per the card's explicit labels, the upper-band retrace is opened as a buy and the lower-band retrace is opened as a sell at the next bar open. The position uses a side-correct 5-bar structural protective stop with a 2-pip buffer, capped at 20 pips, and a 2R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 5-100 | Bollinger lookback used for both 2SD and 3SD bands. |
| `strategy_bb_dev_outer` | 3.0 | 1.0-5.0 | Outer Bollinger deviation that defines the extreme bar. |
| `strategy_bb_dev_inner` | 2.0 | 1.0-4.0 | Inner Bollinger deviation that confirms the retrace. |
| `strategy_adx_period` | 14 | 5-50 | ADX lookback for range-market filtering. |
| `strategy_adx_max` | 25.0 | 5.0-50.0 | Maximum ADX value allowed for entry. |
| `strategy_swing_lookback` | 5 | 2-30 | Number of closed bars used for the structural stop. |
| `strategy_sl_buffer_pips` | 2 | 0-20 | Pip buffer added beyond the structural swing. |
| `strategy_sl_cap_pips` | 20 | 5-100 | Maximum protective stop distance in pips. |
| `strategy_tp_rr` | 2.0 | 0.5-5.0 | Take-profit multiple of the realized stop distance. |
| `strategy_spread_cap_pips` | 5 | 0-20 | Entry is blocked only when modeled spread is genuinely wider than this. |
| `strategy_no_friday_entry` | true | true/false | Blocks new Friday entries while preserving framework Friday close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with M15 DWX data available.
- `GBPUSD.DWX` - card-listed major FX pair with M15 DWX data available.

**Explicitly NOT for:**
- Non-FX index, metal, energy, or equity symbols - the approved card only lists EURUSD/GBPUSD.DWX for this Lien FX setup.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Expected trade frequency | Not specified in card frontmatter; card implies frequent M15 range-reversion trades. |
| Typical hold time | Not specified in card frontmatter; expected intraday until 20-pip-capped SL or 2R TP. |
| Expected drawdown profile | Not specified in card frontmatter; bounded per-trade by fixed structural stop and HR4 risk. |
| Regime preference | Mean-revert / range market, enforced by ADX(14) < 25. |
| Win rate target (qualitative) | Not specified in card; 2R target suggests medium win-rate tolerance. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f8b7c68d-870a-5568-81ff-9b825dcddd32
**Source type:** book / strategy deck
**Pointer:** Kathy Lien, "Battle Tested Forex Trading Strategies" (BKForex), X-Treme Fade strategy, approximately 2012.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11560_lien-xtreme-fade-bb3-adx25-m15.md`

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
| v1 | 2026-06-20 | Initial build from card | 119884fa-ffe7-405d-815a-093f6ea4fbdc |

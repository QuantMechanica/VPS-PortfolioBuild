# QM5_11663_fps-ema25-50-100-m1 - Strategy Spec

**EA ID:** QM5_11663
**Slug:** `fps-ema25-50-100-m1`
**Source:** `c6118ff9-b7f0-5cb1-95cd-7cb0fff06f35` (see `strategy-seeds/sources/c6118ff9-b7f0-5cb1-95cd-7cb0fff06f35/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a one-minute triple-EMA scalp. It opens long when the just-closed bar closes above EMA(25) and EMA(25) is above EMA(50), which is above EMA(100). It opens short when the just-closed bar closes below EMA(25) and EMA(25) is below EMA(50), which is below EMA(100). Trades are only allowed during the card's UTC London and New York open windows, and positions close only through the fixed 10 pip stop loss, fixed 7 pip take profit, or framework-level exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 25 | 2-500 | Fast EMA used as the price-side reference and top or bottom of the EMA stack. |
| `strategy_ema_mid_period` | 50 | 2-500 | Middle EMA in the trend stack. |
| `strategy_ema_slow_period` | 100 | 2-500 | Slow EMA in the trend stack. |
| `strategy_sl_pips` | 10 | 1-200 | Fixed stop-loss distance in pips. |
| `strategy_tp_pips` | 7 | 1-200 | Fixed take-profit distance in pips. |
| `strategy_spread_pct_of_stop` | 15.0 | 0-100 | Maximum modeled spread as a percent of the 10 pip stop; 15% equals the card's 1.5 pip cap. |
| `strategy_sess1_start_utc` | 7 | 0-23 | First UTC trading-window start hour. |
| `strategy_sess1_end_utc` | 10 | 0-23 | First UTC trading-window end hour. |
| `strategy_sess2_start_utc` | 12 | 0-23 | Second UTC trading-window start hour. |
| `strategy_sess2_end_utc` | 15 | 0-23 | Second UTC trading-window end hour. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX M1 pair available in the DWX matrix.
- `GBPUSD.DWX` - card-listed liquid FX M1 pair available in the DWX matrix.
- `USDJPY.DWX` - card-listed liquid FX M1 pair available in the DWX matrix.
- `USDCHF.DWX` - card-listed liquid FX M1 pair available in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts keep the `.DWX` suffix.
- Non-FX index, metal, energy, and crypto symbols - the card only approves the four listed FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `500` |
| Typical hold time | Not specified in frontmatter; fixed 7/10 pip M1 scalp implies short intraday holds. |
| Expected drawdown profile | Tight fixed-pip scalping drawdown profile; spread-sensitive by card note. |
| Regime preference | EMA-aligned intraday trend during London and New York open windows. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c6118ff9-b7f0-5cb1-95cd-7cb0fff06f35`
**Source type:** forum compilation
**Pointer:** `Anonymous (DayTradeForex.com), "'Scalp' Trading the 1min Charts", in: 9 Forex Systems (MoneyTec compilation, ~2006), p. 8.`
**R1-R4 verdict (Q00):** frontmatter records R1-R4 PASS under `g0_status: APPROVED`; see `artifacts/cards_approved/QM5_11663_fps-ema25-50-100-m1.md`.

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
| v1 | 2026-06-20 | Initial build from card | 08500eb3-9657-4ff5-9292-9277305c05b5 |

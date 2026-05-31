# QM5_10580_mql5-lsma-ang - Strategy Spec

**EA ID:** QM5_10580
**Slug:** `mql5-lsma-ang`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes a linear regression moving average endpoint on each closed H4 bar and converts the one-bar LSMA change into symbol points. It buys when the closed-bar LSMA angle rises out of the negative threshold zone or breaks through the positive threshold, and sells when the closed-bar LSMA angle falls out of the positive threshold zone or breaks through the negative threshold. Open trades close when the LSMA angle crosses back through zero, or through the framework stop, target, Friday close, news handling, or kill-switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lsma_period` | 25 | 2-200 | Number of bars used for the LSMA regression endpoint. |
| `strategy_angle_threshold` | 5.0 | >0 | LSMA one-bar angle threshold measured in symbol points. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | Stop distance as a multiple of ATR. |
| `strategy_take_profit_rr` | 1.5 | >0 | Profit target in R multiples from entry to stop. |
| `strategy_max_spread_points` | 40 | 0-1000 | Per-tick spread guard; zero disables this strategy guard. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - Card primary FX symbol and source-test family member.
- `EURUSD.DWX` - Liquid major FX pair suitable for closed-bar LSMA threshold logic.
- `GBPJPY.DWX` - Liquid JPY cross suitable for LSMA slope and threshold behavior.
- `XAUUSD.DWX` - DWX metal symbol explicitly listed in the card's P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker or custom-symbol data is available for build validation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `several H4 bars to several days` |
| Expected drawdown profile | `ATR hard stops with 1.5R targets should keep per-trade loss bounded by the framework risk model.` |
| Regime preference | `closed-bar threshold breakout / slope expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/14046`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10580_mql5-lsma-ang.md`

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
| v1 | 2026-05-29 | Initial build from card | bead6443-7092-4367-8a02-f5e69064ff18 |

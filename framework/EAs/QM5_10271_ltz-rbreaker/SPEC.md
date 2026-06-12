# QM5_10271_ltz-rbreaker - Strategy Spec

**EA ID:** QM5_10271
**Slug:** ltz-rbreaker
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `sources/github-topic-algorithmic-trading`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades Letian Wang's R-Breaker daily pivot levels on intraday bars. Each bar computes yesterday's pivot ladder from the previous daily high, low, and close; if the closed intraday bar is above R3 it opens long, and if it is below S3 it opens short. While in a long position, a move above R2 followed by a close below R1 or a direct close below S3 reverses to short. While in a short position, a move below S2 followed by a close above S1 or a direct close above R3 reverses to long.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiplier for the catastrophic stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - canonical S&P 500 custom symbol for the source SPX index exposure; backtest-only routing caveat applies.
- `NDX.DWX` - live-tradable US large-cap index proxy from the card's R3 validation basket.
- `WS30.DWX` - live-tradable US large-cap index proxy from the card's R3 validation basket.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not valid canonical DWX symbols in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 pivot levels from previous daily HLC; current D1 high/low for reversal conditions |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Expected trade frequency | Not provided in frontmatter; card body describes intraday/day-trading behaviour. |
| Typical hold time | Not provided in frontmatter; card body says generally not overnight. |
| Expected drawdown profile | Not provided in frontmatter; catastrophic stop is 2.0 * ATR(14). |
| Regime preference | Pivot breakout with intraday reversal. |
| Win rate target (qualitative) | Not provided in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository/topic catalog
**Pointer:** `https://github.com/letianzj/QuantResearch/blob/master/backtest/r_breaker.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10271_ltz-rbreaker.md`

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
| v1 | 2026-06-12 | Initial build from card | cf727ad0-884b-41de-883f-7f8bd3d2c88f |

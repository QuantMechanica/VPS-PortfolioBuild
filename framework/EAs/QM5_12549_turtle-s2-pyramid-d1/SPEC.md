# QM5_12549_turtle-s2-pyramid-d1 - Strategy Spec

**EA ID:** QM5_12549
**Slug:** `turtle-s2-pyramid-d1`
**Source:** `faith-way-of-turtle-2007-appendix-a` (see `strategy-seeds/sources/faith-way-of-turtle-2007-appendix-a/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades Turtle System 2 from Curtis Faith (2007), Way of the Turtle, Appendix A. On each new D1 bar, it checks whether the last closed bar broke above the highest high of the prior 55 D1 bars or below the lowest low of the prior 55 D1 bars, then opens a long or short unit at market. It adds one unit after each further half-N favorable move, up to four units total, and moves every unit's stop to 2N from the newest fill. All units close together when price reaches the 20-day channel exit or a broker hard stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_period` | 55 | 20-100 | Donchian channel lookback for System 2 breakout entry |
| `strategy_exit_period` | 20 | 5-50 | Donchian channel lookback for full-position exit |
| `strategy_n_stop_mult` | 2.0 | 1.0-3.0 | ATR/N multiple for initial stop and stop convergence on pyramid adds |
| `strategy_n_pyramid_mult` | 0.5 | 0.25-1.0 | ATR/N multiple between pyramid add trigger levels |
| `strategy_max_units` | 4 | 1-4 | Maximum pyramid units per symbol instance |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - card-listed D1 FX trend market; part of the minimum diversified System 2 basket
- `USDJPY.DWX` - card-listed D1 FX trend market; part of the minimum diversified System 2 basket
- `USDCHF.DWX` - card-listed D1 FX trend market; part of the minimum diversified System 2 basket
- `USDCAD.DWX` - card-listed D1 FX trend market; part of the minimum diversified System 2 basket
- `XAUUSD.DWX` - card-listed gold market; D1 trend instrument in the Turtle-style commodity universe

**Explicitly NOT for:**
- Intraday timeframes (M1-H4) - the N calculation and Donchian periods are calibrated to D1 bars
- Index-only baskets - the approved card specifies FX pairs plus XAUUSD, not equity indices

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with D1 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 3 |
| Typical hold time | multi-week trend holds; exact value not specified in frontmatter |
| Expected drawdown profile | 30% expected drawdown from card frontmatter |
| Regime preference | trend-following / breakout |
| Win rate target (qualitative) | low-to-medium, with expectancy driven by large trend winners |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `faith-way-of-turtle-2007-appendix-a`
**Source type:** book
**Pointer:** `D:/QM/strategy_farm/source_cache/faith-way-of-turtle.txt`; Faith, C.M. (2007), "Way of the Turtle", McGraw-Hill, Appendix A pp. 263-270
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12549_turtle-s2-pyramid-d1.md`

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
| v1 | 2026-06-13 | Initial build from card | 1be2c053-029e-4df6-aa87-fc97c1ef5225 |

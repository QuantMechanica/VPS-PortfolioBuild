# QM5_10850_tv-bbmr-long - Strategy Spec

**EA ID:** QM5_10850
**Slug:** `tv-bbmr-long`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView script pointer below)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades long-only Bollinger Band mean reversion. On each closed bar, it computes a 20-period Bollinger Band with 2.0 standard deviations and opens a buy when the prior closed bar was not below the lower band and the latest closed bar is below the lower band. The initial stop is 1.5 percent below the entry price, the initial take profit is the SMA middle band, and an open long is also closed when current price returns to that middle band. The framework enforces one open position per symbol/magic, Friday close, news handling, and V5 risk sizing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 20 | >= 2 | Period for the Bollinger middle SMA and bands. |
| `strategy_band_deviation` | 2.0 | > 0.0 | Standard-deviation multiplier for the Bollinger bands. |
| `strategy_stop_loss_pct` | 1.5 | > 0.0 | Initial stop distance as percent below the entry price. |
| `strategy_spread_guard_pct` | 15.0 | >= 0.0 | Blocks entries when spread exceeds this percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card says the source works well on XAUUSD and the symbol exists in the DWX matrix.
- `GDAXI.DWX` - DAX custom symbol used as the available DWX equivalent for card-stated `GER40.DWX`.
- `NDX.DWX` - Liquid US index CFD from the card's primary P2 basket.
- `WS30.DWX` - Liquid US index CFD from the card's primary P2 basket.
- `EURUSD.DWX` - Liquid FX symbol from the card's primary P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; registered DAX equivalent is `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M45`, `H1`, `H2` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Not specified in frontmatter; expected hours to days from mean-reversion-to-SMA exit. |
| Expected drawdown profile | Medium; main risk is catching downside trend breaks. |
| Regime preference | Mean reversion after downside Bollinger extensions. |
| Win rate target (qualitative) | Medium to high, with bounded fixed-percent stop losses. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `BB Mean Reversion Long + SL`, author handle `a4nti`, Apr 21, https://www.tradingview.com/script/z1xM8YnZ/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10850_tv-bbmr-long.md`

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
| v1 | 2026-06-06 | Initial build from card | 2ac11128-cbf3-4416-9c78-e0d001926d6f |

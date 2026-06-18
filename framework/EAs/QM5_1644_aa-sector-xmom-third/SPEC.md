# QM5_1644_aa-sector-xmom-third - Strategy Spec

**EA ID:** QM5_1644
**Slug:** `aa-sector-xmom-third`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA ranks a fixed equity-index proxy basket once per monthly rebalance using `ROC_12_2 = Close(3) / Close(13) - 1`. It goes long symbols in the top third of the rank and short symbols in the bottom third, with one position per symbol and magic number. Because MN1 data is not usable in the DWX tester, the implementation uses a D1-native 21-trading-day monthly proxy and rebalances at broker-time month changes. Existing positions are closed when the symbol leaves its target side or flips direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_month_proxy_bars` | 21 | 10-31 | Number of D1 bars used as the month proxy for closed monthly ranks. |
| `strategy_roc_recent_months` | 3 | 1-15 | Month index used as the ROC numerator, matching Close(3). |
| `strategy_roc_old_months` | 13 | 2-16 | Month index used as the ROC denominator, matching Close(13). |
| `strategy_min_monthly_bars` | 14 | 14-15 | Minimum completed monthly observations before targets are valid. |
| `strategy_atr_period` | 20 | 5-100 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.5-10.0 | Initial stop distance as a multiple of ATR(20,D1). |
| `strategy_max_long_slots` | 5 | 1-5 | Maximum number of long symbols selected from the top third. |
| `strategy_max_short_slots` | 5 | 1-5 | Maximum number of short symbols selected from the bottom third. |
| `strategy_spread_mult` | 2.5 | 1.0-10.0 | Blocks entries only when current spread exceeds 2.5 times the 20-bar median modeled spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 country/index proxy; valid backtest-only DWX custom symbol.
- `NDX.DWX` - Nasdaq 100 US equity-index proxy.
- `WS30.DWX` - Dow 30 US equity-index proxy.
- `GDAXI.DWX` - German DAX 40 country/index proxy.
- `UK100.DWX` - FTSE 100 country/index proxy.

**Explicitly NOT for:**
- `FCHI.DWX` - named in the card's proxy basket but absent from `dwx_symbol_matrix.csv`.
- `SPA35.DWX` - named in the card's proxy basket but absent from `dwx_symbol_matrix.csv`.
- Sector ETF symbols such as `XLK` and `XLF` - true sector CFDs are unavailable in the DWX matrix for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | D1 closes for all basket symbols and ATR(20,D1) for the traded symbol |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` latched once per tick before monthly state refresh |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | About one monthly rebalance cycle |
| Expected drawdown profile | Trend-momentum drawdowns during rank reversals and broad equity-index whipsaws |
| Regime preference | Cross-sectional momentum / sector-rotation proxy |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `blog`
**Pointer:** Jack Vogel, PhD, "The World's Longest Multi-Asset Momentum Investing Backtest!", 2018-04-24, `https://alphaarchitect.com/the-worlds-longest-multi-asset-momentum-investing-backtest/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1644_aa-sector-xmom-third.md`

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
| v1 | 2026-06-18 | Initial build from card | dd89e103-7f98-4fc6-b88b-9ff77177696e |

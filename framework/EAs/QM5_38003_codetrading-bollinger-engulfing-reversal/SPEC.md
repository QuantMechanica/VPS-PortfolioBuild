# QM5_38003_codetrading-bollinger-engulfing-reversal — Strategy Spec

**EA ID:** QM5_38003
**Slug:** `codetrading-bollinger-engulfing-reversal`
**Source:** `codetrading-bollinger-engulfing-reversal-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

On each completed H1 bar, the EA buys when a bullish engulfing candle touches the
lower 20-period, 2-standard-deviation Bollinger Band and RSI(14) is at or below
35. It sells on the symmetric bearish engulfing, upper-band touch, and RSI at or
above 65. The stop is two pips beyond the engulfing candle and the take-profit is
two times the stop distance; half the position is closed when price reaches the
Bollinger middle band. Entries are blocked during 23:55–00:05 UTC, for a spread
above 1.8 × closed-bar ATR(14), after 2% daily realized loss, after 5% total
drawdown, or while this strategy already has a position; open trades are closed
at 2.5% daily equity drawdown or 5% total equity drawdown.

The card's lifecycle illustration mentions break-even and trailing states but
does not define their triggers or distances. Those states are intentionally
inactive so the build does not invent mechanics outside the approved exact exit
rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `InpBBPeriod` | 20 | 14–30 | Bollinger Bands SMA period. |
| `InpBBDev` | 2.00 | 1.5–2.5 | Bollinger Bands standard-deviation multiplier. |
| `InpRSIPeriod` | 14 | 7–21 | RSI momentum-filter period. |
| `InpDailyLossHaltPct` | 2.0 | fixed by card | Daily realized-loss threshold that blocks new entries. |
| `InpDailyDrawdownStopPct` | 2.5 | fixed by card | Daily equity-drawdown hard exit threshold. |
| `InpTotalDrawdownStopPct` | 5.0 | fixed by card | Total equity-drawdown entry halt and hard exit threshold. |

The card's `InpRiskPercent` is implemented by the governed framework
`RISK_PERCENT` input rather than duplicated as a strategy input. It remains 0 in
backtests while `RISK_FIXED=1000`; a future OWNER-approved live setfile may set
`RISK_PERCENT=0.50` and must set `RISK_FIXED=0`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — the card's primary liquid FX target.
- `GBPJPY.DWX` — the card's higher-volatility FX cross target.
- `AUDUSD.DWX` — the card's liquid commodity-currency target.

**Explicitly NOT for:**

- Symbols outside the three approved targets — no portability claim or magic
  allocation is present for them.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — the governed
  tester has no canonical data contract for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)`; all indicator and candle reads use completed H1 bar `[1]` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 conservative ordering prior; card also states 80–160 high-conviction trades/year |
| Typical hold time | Not specified; held until SL/TP, middle-band partial, Friday close, or a capital-preservation exit |
| Expected drawdown profile | 15% conservative frontmatter expectation; 2.5% daily and 5% total strategy circuit breakers |
| Regime preference | Mean reversion after outer-band rejection |
| Win rate target (qualitative) | High source claim; unverified until governed testing |

---

## 6. Source Citation

**Source ID:** `codetrading-bollinger-engulfing-reversal-official-source`
**Source type:** video
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38003_codetrading-bollinger-engulfing-reversal.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per
`artifacts/cards_approved/QM5_38003_codetrading-bollinger-engulfing-reversal.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by the portfolio manifest |

ENV→mode validation is enforced by `QM_FrameworkInit`. This build does not
authorize live use.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-24 | Initial build from approved card | build-QM5_38003_codetrading-bollinger-engulfing-reversal |

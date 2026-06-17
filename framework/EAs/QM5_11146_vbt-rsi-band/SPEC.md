# QM5_11146_vbt-rsi-band — Strategy Spec

**EA ID:** QM5_11146
**Slug:** `vbt-rsi-band`
**Source:** `3f3833d9-8676-52e4-a822-2c5fc87bbe20` (see `strategy-seeds/sources/3f3833d9-8676-52e4-a822-2c5fc87bbe20/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Long-only RSI band mean reversion ported from Oleg Polakow's vectorbt
`PortingBTStrategy` notebook. On the close of each M15 bar, RSI(14) is computed
on the bar Open price (matching the pure-vectorbt section of the source). The EA
goes long when RSI crosses down through the oversold threshold of 35 (RSI two
bars ago was at/above 35 and the last closed bar is below 35) and no position is
already open. The position is closed when RSI crosses up through the overbought
threshold of 70, after a maximum hold of 96 M15 bars (time stop), or if a fixed
1.5×ATR(14) safety stop frozen at entry is hit. There is no take-profit and no
shorting — the source strategy is buy-oversold / sell-to-flat only.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 7-21 | RSI lookback period (on PRICE_OPEN) |
| `strategy_rsi_bottom` | 35.0 | 30-40 | Oversold entry threshold (cross below = long) |
| `strategy_rsi_top` | 70.0 | 60-70 | Overbought exit threshold (cross above = close) |
| `strategy_atr_period` | 14 | 7-21 | ATR period for the safety stop |
| `strategy_sl_atr_mult` | 1.5 | 1.0-3.0 | Safety stop distance = mult × ATR, frozen at entry |
| `strategy_max_hold_bars` | 96 | 48-192 | Time stop: max M15 bars held before forced close |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip entry if spread > this % of the stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX, tight spreads suit frequent intraday RSI entries.
- `GBPUSD.DWX` — liquid major FX with intraday mean-reversion tendencies.
- `USDJPY.DWX` — liquid major FX; pip-scale handled by framework stop helpers.
- `XAUUSD.DWX` — volatile metal; ATR-scaled safety stop adapts to its range.
- `GDAXI.DWX` — DAX 40 index; ported from the card's `GER40.DWX` (GER40 is not in
  `dwx_symbol_matrix.csv`; GDAXI.DWX is the matrix DAX symbol). Flagged in build.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only custom symbol; not in the card's R3 portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~100` (card estimate 80-180) |
| Typical hold time | `hours to ~1 day` (≤96 M15 bars ≈ 1 trading day) |
| Expected drawdown profile | `mean-reversion risk = catching a persistent downtrend; ATR + time stop bound exposure` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3f3833d9-8676-52e4-a822-2c5fc87bbe20`
**Source type:** `notebook (GitHub)`
**Pointer:** `https://github.com/polakowo/vectorbt/blob/master/examples/PortingBTStrategy.ipynb`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11146_vbt-rsi-band.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | board-advisor worktree build |

# QM5_11857_blade-macd-stoch-divergence-h1 — Strategy Spec

**EA ID:** QM5_11857
**Slug:** `blade-macd-stoch-divergence-h1`
**Source:** `7f6f2831-ea66-58f6-a7ff-a8c89a44803d` (see `strategy-seeds/sources/7f6f2831-ea66-58f6-a7ff-a8c89a44803d/`)
**Author of this spec:** Development
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Trades counter-trend reversals on H1 using MACD divergence confirmed by a Stochastic overbought/oversold cross-back. For a short entry, the EA detects two successive price swing highs where the second high is higher while the corresponding MACD main-line peaks form a lower high (bearish divergence); once active, it waits for the Stochastic K line to rise above 80 and then cross back below 80 on bar close. The reverse mirror applies for long entries: two lower price lows with rising MACD troughs, followed by Stochastic crossing back above 20. Stop loss is placed behind the most recent swing extreme (5-bar highest high or lowest low plus a 1-pip buffer); take profit is fixed at 2× the initial risk distance. A break-even shift is applied when floating profit equals initial risk and Stochastic has crossed the 50 midline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 5–50 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 10–100 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 3–30 | MACD signal EMA period |
| `strategy_stoch_k` | 9 | 3–21 | Stochastic K period |
| `strategy_stoch_d` | 3 | 1–9 | Stochastic D period |
| `strategy_stoch_slow` | 3 | 1–9 | Stochastic slowing period |
| `strategy_stoch_overbought` | 80.0 | 70–90 | Stochastic overbought level (short trigger) |
| `strategy_stoch_oversold` | 20.0 | 10–30 | Stochastic oversold level (long trigger) |
| `strategy_swing_lookback` | 50 | 20–100 | Bars scanned for the two swing high/low pairs |
| `strategy_sl_bars` | 5 | 3–10 | Bars used to find the SL reference swing |
| `strategy_sl_min_pips` | 20 | 10–30 | Minimum SL distance in pips; widen stop if the swing stop is tighter |
| `strategy_sl_max_pips` | 35 | 25–60 | Maximum SL distance in pips; skip trade if wider |
| `strategy_div_window` | 10 | 5–20 | Bars divergence remains valid after detection |
| `strategy_take_profit_rr` | 2.0 | 1.0–4.0 | Fixed reward-to-risk take-profit multiple |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — primary pair per source; liquid, strong H1 divergence patterns
- `EURUSD.DWX` — primary pair per source; high liquidity and reliable MACD divergence
- `AUDUSD.DWX` — secondary; commodity-correlated, complements basket diversification
- `USDJPY.DWX` — secondary; risk-on/off characteristics add regime diversity

**Explicitly NOT for:**
- Index CFDs (NDX.DWX, WS30.DWX) — strategy designed for FX majors with spread economics

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~6 |
| Typical hold time | 4–24 hours (H1 counter-trend, exits via 2×R TP or BE+reversal) |
| Expected drawdown profile | Shallow; BE reduces tail; majority of losses closed at SL (20–35 pips) |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium (counter-trend + divergence filter = selective) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7f6f2831-ea66-58f6-a7ff-a8c89a44803d`
**Source type:** book/PDF
**Pointer:** Anonymous, "The Blade Forex Strategies", ForexSuccessSecrets.com, ~2010, System 3 "Divergence System"; local PDF `C:/Users/Administrator/Dropbox/Finanzen/Forex/### Forex to read/219755537-Blade-Forex-Strategies.pdf`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11857_blade-macd-stoch-divergence-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 9c1c2379-eb70-46bc-b654-7e3f3bd1a618 |
